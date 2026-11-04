#!/usr/bin/env node
// 楚汉·问鼎 —— PvP 动作中继服务器
// 单文件、零数据库：房间放内存，只转发动作并留一份动作日志供断线重连。
//
// 协议（JSON 文本帧）：
//   C→S {t:"create", settings:{...}}        → S→C {t:"created", code}
//   C→S {t:"join", code}                    → S→加入方 {t:"joined", settings}
//                                             S→房主  {t:"peer_joined"}
//   C→S {t:"resume", code}                  → S→重连方 {t:"resumed", settings, log}
//                                             S→对端   {t:"peer_back"}
//   C→S {t:"action", a:{...}}               → S→对端 {t:"action", a, seq}（并写入房间日志）
//   C→S {t:"log"}                           → S→C {t:"log", log}（请求完整动作日志）
//   C→S {t:"ping"}                          → S→C {t:"pong"}
//   对端离开 → {t:"peer_left"}；房间销毁/码不存在/房间满 → {t:"error", msg}
//
// 用法：node tools/relay.js [端口]   （默认 27775）

const PORT = Number(process.argv[2]) || 27775;
// 房间码字母表：去掉易混淆的 0/O/1/I/L
const ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";

const { WebSocketServer } = require("ws");

/** @type {Map<string, Room>} */
const rooms = new Map();

class Room {
  constructor(code, settings) {
    this.code = code;
    this.settings = settings || {};
    this.host = null;   // 建房方的 WebSocket
    this.guest = null;  // 加入方的 WebSocket
    this.log = [];      // 动作日志（按序，重连重放用）
    this.touched = Date.now();
  }
  other(ws) { return ws === this.host ? this.guest : this.host; }
  send(ws, obj) {
    if (ws && ws.readyState === 1) { try { ws.send(JSON.stringify(obj)); } catch (_) {} }
  }
}

function makeCode() {
  for (let tries = 0; tries < 50; tries++) {
    let c = "";
    for (let i = 0; i < 6; i++) c += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
    if (!rooms.has(c)) return c;
  }
  return null;
}

function dropFromRooms(ws) {
  for (const room of rooms.values()) {
    let slot = null;
    if (room.host === ws) slot = "host";
    else if (room.guest === ws) slot = "guest";
    if (!slot) continue;
    room.touched = Date.now();
    // 先通知对端再清槽位（other() 依赖槽位判断）
    if (slot === "host") { room.send(room.guest, { t: "peer_left" }); room.host = null; }
    else { room.send(room.host, { t: "peer_left" }); room.guest = null; }
    if (room.host === null && room.guest === null) {
      // 两端都不在了，房间再留 10 分钟供双双重连，之后由清扫器回收
      setTimeout(() => {
        if (room.host === null && room.guest === null) rooms.delete(room.code);
      }, 10 * 60 * 1000);
    } else {
      room.send(room.other(ws), { t: "peer_left" });
    }
    return room;
  }
  return null;
}

const wss = new WebSocketServer({ port: PORT });

wss.on("connection", (ws) => {
  ws.isAlive = true;
  ws.on("pong", () => { ws.isAlive = true; });

  ws.on("message", (raw) => {
    let m = null;
    try { m = JSON.parse(raw.toString()); } catch (_) { return; }
    if (!m || typeof m.t !== "string") return;
    ws.isAlive = true;

    switch (m.t) {
      case "ping": ws.send(JSON.stringify({ t: "pong" })); return;

      case "create": {
        if (findRoomOf(ws)) return;
        const code = makeCode();
        if (!code) { ws.send(JSON.stringify({ t: "error", msg: "rooms exhausted" })); return; }
        const room = new Room(code, m.settings);
        room.host = ws;
        rooms.set(code, room);
        ws.send(JSON.stringify({ t: "created", code }));
        return;
      }

      case "join": {
        if (findRoomOf(ws)) return;
        const room = rooms.get(String(m.code || "").toUpperCase());
        if (!room) { ws.send(JSON.stringify({ t: "error", msg: "room not found" })); return; }
        if (room.guest) { ws.send(JSON.stringify({ t: "error", msg: "room full" })); return; }
        room.guest = ws;
        room.touched = Date.now();
        ws.send(JSON.stringify({ t: "joined", settings: room.settings }));
        room.send(room.host, { t: "peer_joined" });
        return;
      }

      case "resume": {
        if (findRoomOf(ws)) return;
        const room = rooms.get(String(m.code || "").toUpperCase());
        if (!room) { ws.send(JSON.stringify({ t: "error", msg: "room not found" })); return; }
        if (room.host && room.guest) { ws.send(JSON.stringify({ t: "error", msg: "room full" })); return; }
        const wasHost = room.host === null; // 空哪个槽就补哪个
        if (wasHost) room.host = ws; else room.guest = ws;
        room.touched = Date.now();
        ws.send(JSON.stringify({ t: "resumed", settings: room.settings, log: room.log, asHost: wasHost }));
        room.send(room.other(ws), { t: "peer_back" });
        return;
      }

      case "action": {
        const room = findRoomOf(ws);
        if (!room || !m.a || typeof m.a !== "object") return;
        room.log.push(m.a);
        room.touched = Date.now();
        room.send(room.other(ws), { t: "action", a: m.a, seq: room.log.length });
        return;
      }

      case "log": {
        const room = findRoomOf(ws);
        if (room) ws.send(JSON.stringify({ t: "log", log: room.log }));
        return;
      }

      case "leave": {
        const room = findRoomOf(ws);
        if (!room) return;
        // 房主主动离开 = 房间销毁；客方离开 = 对端收到 peer_left，可等待 resume
        room.send(room.other(ws), { t: "peer_left" });
        if (room.host === ws) rooms.delete(room.code);
        else room.guest = null;
        return;
      }
    }
  });

  ws.on("close", () => { dropFromRooms(ws); });
  ws.on("error", () => { dropFromRooms(ws); });
});

function findRoomOf(ws) {
  for (const room of rooms.values()) {
    if (room.host === ws || room.guest === ws) return room;
  }
  return null;
}

// 清扫：30 秒一次，踢掉 60 秒无心跳的连接、回收 2 小时无活动的房间
setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) { ws.terminate(); dropFromRooms(ws); return; }
    ws.isAlive = false;
    try { ws.ping(); } catch (_) {}
  });
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (now - room.touched > 2 * 60 * 60 * 1000) rooms.delete(code);
  }
}, 30 * 1000);

console.log(`[relay] listening on ws://0.0.0.0:${PORT}`);
