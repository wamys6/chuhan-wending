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
// 运维接口（同端口 HTTP，不占额外端口）：
//   GET /health → {ok, version, uptimeSec, rooms, peers, clients, actions, peakRooms}
//   每 5 分钟一行 [relay] stats 日志；SIGINT/SIGTERM 会通知客户端后干净退出
//
// 用法：node tools/relay.js [端口]   （默认 27775）

const PORT = Number(process.argv[2]) || 27775;
const VERSION = "1.1.0";
const STARTED_AT = Date.now();
// 房间码字母表：去掉易混淆的 0/O/1/I/L
const ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";

const http = require("http");
const { WebSocketServer } = require("ws");

/** 累计动作数（不随房间回收清零，用来判断「服务器是不是在干活」） */
let totalActions = 0;
/** 同时存在的房间数峰值（看容量水位） */
let peakRooms = 0;
/** 已服务过的房间数（含已销毁，用来估算负载） */
let servedRooms = 0;

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

const wss = new WebSocketServer({ noServer: true });

// ── 运维口：同端口 HTTP，/health 给监控/负载均衡探活，其余路径 404 ──
const httpServer = http.createServer((req, res) => {
  if (req.url === "/health" || req.url === "/healthz") {
    const body = JSON.stringify({
      ok: true,
      version: VERSION,
      uptimeSec: Math.round((Date.now() - STARTED_AT) / 1000),
      rooms: rooms.size,
      peers: countPeers(),
      clients: wss.clients.size,
      actions: totalActions,
      peakRooms,
      servedRooms,
    });
    res.writeHead(200, {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    });
    res.end(body);
    return;
  }
  res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
  res.end("chuhan relay — GET /health\n");
});
httpServer.on("upgrade", (req, socket, head) => {
  wss.handleUpgrade(req, socket, head, (ws) => wss.emit("connection", ws, req));
});

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
        servedRooms++;
        if (rooms.size > peakRooms) peakRooms = rooms.size;
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
        totalActions++;
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

/** 在座人数（房间里的槽位占用数，与「连上但没进房」的客户端区分开） */
function countPeers() {
  let n = 0;
  for (const room of rooms.values()) {
    if (room.host) n++;
    if (room.guest) n++;
  }
  return n;
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

// 定期指标：有人玩的时候每 5 分钟一行，没人玩就静默（避免日志被空转刷满）
setInterval(() => {
  if (rooms.size === 0 && wss.clients.size === 0) return;
  console.log("[relay] stats " + JSON.stringify({
    uptimeSec: Math.round((Date.now() - STARTED_AT) / 1000),
    rooms: rooms.size,
    peers: countPeers(),
    clients: wss.clients.size,
    actions: totalActions,
    peakRooms,
  }));
}, 5 * 60 * 1000);

// 退出：先告诉客户端「不是我踢你，是服务器下线」，让它们停在断线界面而不是崩掉
let closing = false;
function shutdown(sig) {
  if (closing) return;
  closing = true;
  console.log(`[relay] ${sig} 收到，通知 ${wss.clients.size} 个连接后退出`);
  const msg = JSON.stringify({ t: "error", msg: "relay shutting down" });
  wss.clients.forEach((ws) => {
    try { ws.send(msg); } catch (_) {}
    try { ws.close(1001, "server shutdown"); } catch (_) {}
  });
  httpServer.close(() => {});
  setTimeout(() => process.exit(0), 200);
}
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

httpServer.listen(PORT, () => {
  console.log(`[relay] listening on ws://0.0.0.0:${PORT}  ·  health http://0.0.0.0:${PORT}/health`);
});
