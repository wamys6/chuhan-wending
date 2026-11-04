const WebSocket = require("ws");
const URL = "ws://101.200.235.68:27775";
function conn(name) {
  return new Promise((res, rej) => {
    const ws = new WebSocket(URL);
    ws.on("open", () => res(ws));
    ws.on("error", rej);
    ws._name = name;
  });
}
const wait = (ms) => new Promise(r => setTimeout(r, ms));
(async () => {
  const host = await conn("host"), guest = await conn("guest");
  let result = [];
  guest.on("message", d => result.push(JSON.parse(d.toString())));
  let hostMsgs = [];
  host.on("message", d => hostMsgs.push(JSON.parse(d.toString())));

  host.send(JSON.stringify({t:"create", settings:{seed:42}}));
  await wait(500);
  const created = hostMsgs.find(m => m.t === "created");
  if (!created) throw new Error("no created: " + JSON.stringify(hostMsgs));
  console.log("1.建房成功 房间码:", created.code);

  guest.send(JSON.stringify({t:"join", code: created.code}));
  await wait(500);
  if (!result.find(m => m.t === "joined")) throw new Error("guest not joined");
  console.log("2.加入成功 收到设置:", JSON.stringify(result.find(m=>m.t==="joined").settings));

  host.send(JSON.stringify({t:"action", a:{k:"play", id:1}}));
  host.send(JSON.stringify({t:"action", a:{k:"attack", a:2, b:3}}));
  await wait(500);
  const acts = result.filter(m => m.t === "action");
  console.log("3.动作转发:", acts.map(m => `seq${m.seq}:${m.a.k}`).join(", "));
  if (acts.length !== 2) throw new Error("action count wrong");

  // 模拟 guest 断线重连
  guest.close();
  await wait(300);
  const g2 = await conn("guest2");
  const g2msgs = [];
  g2.on("message", d => g2msgs.push(JSON.parse(d.toString())));
  g2.send(JSON.stringify({t:"resume", code: created.code}));
  await wait(500);
  const resumed = g2msgs.find(m => m.t === "resumed");
  if (!resumed) throw new Error("resume failed: " + JSON.stringify(g2msgs));
  console.log("4.断线重连成功 补发动作日志:", JSON.stringify(resumed.log));

  console.log("ALL_PASS");
  host.close(); g2.close();
  process.exit(0);
})().catch(e => { console.error("FAIL:", e.message); process.exit(1); });
