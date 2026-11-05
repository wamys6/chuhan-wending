#!/usr/bin/env node
// relay.js 冒烟测试：起服 → create/join → 动作互发 → 断线重连拉日志 → 离开销房
//                → /health 运维口（监控探活用，同端口不额外开洞）
// 运行：node tools/relay-smoke.js
const { spawn } = require("child_process");
const path = require("path");
const http = require("http");
const WebSocket = require("ws");

const PORT = 27791;
let passed = 0, failed = 0;
function ok(cond, name) {
  if (cond) { passed++; console.log("  ✓ " + name); }
  else { failed++; console.log("  ✗ " + name); }
}

function connect() {
  return new Promise((res, rej) => {
    const ws = new WebSocket(`ws://127.0.0.1:${PORT}`);
    const box = { ws, inbox: [], waiters: [] };
    ws.on("open", () => res(box));
    ws.on("error", rej);
    ws.on("message", (raw) => {
      const m = JSON.parse(raw.toString());
      box.inbox.push(m);
      box.waiters = box.waiters.filter((w) => !w(m));
    });
  });
}

/** 拉一次 /health（超时 2s，失败返回 null 而不是抛，便于断言打印原始情况） */
function health() {
  return new Promise((res) => {
    const req = http.get(`http://127.0.0.1:${PORT}/health`, (r) => {
      let body = "";
      r.on("data", (c) => (body += c));
      r.on("end", () => {
        try { res({ status: r.statusCode, json: JSON.parse(body) }); }
        catch (_) { res({ status: r.statusCode, json: null }); }
      });
    });
    req.on("error", () => res({ status: 0, json: null }));
    req.setTimeout(2000, () => { req.destroy(); res({ status: 0, json: null }); });
  });
}
function send(box, obj) { box.ws.send(JSON.stringify(obj)); }
function wait(box, pred, ms = 3000) {
  const idx = box.inbox.findIndex(pred);
  if (idx >= 0) return Promise.resolve(box.inbox.splice(idx, 1)[0]);
  return new Promise((res, rej) => {
    const timer = setTimeout(() => rej(new Error("timeout waiting")), ms);
    box.waiters.push((m) => {
      if (!pred(m)) return false;
      const i = box.inbox.indexOf(m);
      if (i >= 0) box.inbox.splice(i, 1);
      clearTimeout(timer);
      res(m);
      return true;
    });
  });
}

(async () => {
  const srv = spawn(process.execPath, [path.join(__dirname, "relay.js"), String(PORT)], { stdio: "pipe" });
  await new Promise((r) => setTimeout(r, 600));

  try {
    const host = await connect();
    const guest = await connect();

    send(host, { t: "create", settings: { side: "han", seed: 12345 } });
    const created = await wait(host, (m) => m.t === "created");
    ok(typeof created.code === "string" && created.code.length === 6, "建房返回 6 位码");

    send(guest, { t: "join", code: created.code.toLowerCase() });
    const joined = await wait(guest, (m) => m.t === "joined");
    ok(joined.settings && joined.settings.seed === 12345, "加入方收到对局参数");
    ok((await wait(host, (m) => m.t === "peer_joined")).t === "peer_joined", "房主收到对手加入");

    send(host, { t: "action", a: { a: "play", uid: 7 } });
    send(guest, { t: "action", a: { a: "end" } });
    const got1 = await wait(host, (m) => m.t === "action");
    ok(got1.a.a === "end" && got1.seq === 2, "房主收到对方动作（seq=2）");
    const got2 = await wait(guest, (m) => m.t === "action");
    ok(got2.a.a === "play" && got2.seq === 1, "加入方收到对方动作（seq=1）");

    // 重连：guest 掉线 → 房主收到 peer_left → guest resume 拿到日志
    guest.ws.close();
    ok((await wait(host, (m) => m.t === "peer_left")).t === "peer_left", "掉线通知");
    const g2 = await connect();
    send(g2, { t: "resume", code: created.code });
    const resumed = await wait(g2, (m) => m.t === "resumed");
    ok(resumed.log.length === 2 && resumed.log[0].a === "play", "重连拿到完整动作日志");
    ok(resumed.asHost === false, "重连回到原槽位");
    ok((await wait(host, (m) => m.t === "peer_back")).t === "peer_back", "对端收到重连通知");
    send(g2, { t: "action", a: { a: "skill" } });
    ok((await wait(host, (m) => m.t === "action")).a.a === "skill", "重连后继续转发动作");

    // 运维口：同端口的 /health，监控与探活用
    const h = await health();
    ok(h.status === 200 && h.json && h.json.ok === true, "GET /health 返回 200 + ok:true");
    ok(h.json && h.json.rooms === 1, "健康检查报出房间数", h.json && String(h.json.rooms));
    ok(h.json && h.json.peers === 2, "健康检查报出在座人数", h.json && String(h.json.peers));
    ok(h.json && h.json.actions === 3, "健康检查累计动作数", h.json && String(h.json.actions));
    ok(h.json && h.json.peakRooms >= 1 && h.json.servedRooms >= 1, "健康检查带峰值/累计房间");
    ok(h.json && typeof h.json.uptimeSec === "number" && h.json.uptimeSec >= 0, "健康检查带 uptime");
    ok(h.json && h.json.clients === 2, "健康检查报出当前连接数",
      h.json && String(h.json.clients));

    // 错误路径：满房 join / 假码
    const stranger = await connect();
    send(stranger, { t: "join", code: created.code });
    ok((await wait(stranger, (m) => m.t === "error")).msg === "room full", "满房拒绝");
    send(stranger, { t: "join", code: "ZZZZZZ" });
    ok((await wait(stranger, (m) => m.t === "error")).msg === "room not found", "假码拒绝");

    // 房主离开销房
    host.ws.close();
    await new Promise((r) => setTimeout(r, 300));
    send(g2, { t: "action", a: { a: "end" } });
    ok((await wait(g2, (m) => m.t === "peer_left")).t === "peer_left", "房主离开通知对方");

    // 优雅退出：收到 SIGTERM 先通知在座客户端再关，客户端不会看到「连接莫名其妙断了」
    // Windows 上 child.kill() 是 TerminateProcess，没有信号语义可测，这条只在部署平台（Linux）跑
    if (process.platform === "win32") {
      console.log("  · 跳过「SIGTERM 优雅退出」：Windows 无信号语义（部署到 Linux 后由本脚本验证）");
    } else {
      srv.kill("SIGTERM");
      const bye = await wait(g2, (m) => m.t === "error", 4000);
      ok(bye.msg === "relay shutting down", "SIGTERM 先通知客户端再退出");
    }
  } catch (e) {
    failed++;
    console.log("  ✗ 异常: " + e.message);
  } finally {
    srv.kill();
  }

  console.log(`\nrelay-smoke: 通过 ${passed} 项，失败 ${failed} 项`);
  process.exit(failed ? 1 : 0);
})();
