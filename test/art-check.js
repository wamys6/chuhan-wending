/* 立绘接入验收：军师图 / 事件图 / 关卡背景 / 敌将头像 + 全部 UI 素材可加载 */
var http = require('http');
var net = require('net');
var crypto = require('crypto');
var cp = require('child_process');
var path = require('path');
var fs = require('fs');

var CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
var PORT = 9336;
var URL = 'file:///' + path.resolve(__dirname, '..', 'index.html').replace(/\\/g, '/');

function getJSON(p) {
  return new Promise(function (res, rej) {
    http.get({ host: '127.0.0.1', port: PORT, path: p }, function (r) {
      var b = ''; r.on('data', function (d) { b += d; }); r.on('end', function () { try { res(JSON.parse(b)); } catch (e) { rej(e); } });
    }).on('error', rej);
  });
}

function connect(url) {
  return new Promise(function (resolve, reject) {
    var m = url.match(/^ws:\/\/([^:/]+):(\d+)(\/.*)$/);
    var sock = net.connect(+m[2], m[1], function () {
      var key = crypto.randomBytes(16).toString('base64');
      sock.write('GET ' + m[3] + ' HTTP/1.1\r\nHost: ' + m[1] + ':' + m[2] +
        '\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ' + key +
        '\r\nSec-WebSocket-Version: 13\r\n\r\n');
    });
    var handshook = false, buf = Buffer.alloc(0), listeners = [];
    sock.on('data', function (d) {
      buf = Buffer.concat([buf, d]);
      if (!handshook) {
        var i = buf.indexOf('\r\n\r\n');
        if (i < 0) return;
        handshook = true; buf = buf.slice(i + 4);
        resolve({ send: send, on: function (fn) { listeners.push(fn); }, close: function () { sock.end(); } });
      }
      while (buf.length >= 2) {
        var len = buf[1] & 127, off = 2;
        if (len === 126) { len = buf.readUInt16BE(2); off = 4; }
        else if (len === 127) { len = Number(buf.readBigUInt64BE(2)); off = 10; }
        if (buf.length < off + len) break;
        var payload = buf.slice(off, off + len).toString();
        buf = buf.slice(off + len);
        listeners.forEach(function (fn) { fn(payload); });
      }
    });
    sock.on('error', reject);
    function send(str) {
      var data = Buffer.from(str);
      var head;
      if (data.length < 126) { head = Buffer.alloc(2); head[0] = 0x81; head[1] = 0x80 | data.length; }
      else { head = Buffer.alloc(4); head[0] = 0x81; head[1] = 0x80 | 126; head.writeUInt16BE(data.length, 2); }
      var mask = crypto.randomBytes(4);
      var masked = Buffer.from(data);
      for (var i = 0; i < masked.length; i++) masked[i] ^= mask[i % 4];
      sock.write(Buffer.concat([head, mask, masked]));
    }
  });
}

function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

var failed = 0;
function check(label, cond, extra) {
  console.log((cond ? '  ✅ ' : '  ✗ ') + label + (extra ? '（' + extra + '）' : ''));
  if (!cond) failed++;
}

(async function () {
  var chrome = cp.spawn(CHROME, ['--headless=new', '--disable-gpu', '--remote-debugging-port=' + PORT,
    '--window-size=1440,960', '--no-first-run', '--user-data-dir=' + path.resolve(__dirname, '_cdp-profile'), URL],
    { stdio: 'ignore' });
  await sleep(2500);

  var list = await getJSON('/json/list');
  var page = list.filter(function (t) { return t.type === 'page'; })[0];
  var ws = await connect(page.webSocketDebuggerUrl);

  var id = 0, pending = {}, errors = [];
  ws.on(function (raw) {
    var msg = JSON.parse(raw);
    if (msg.id && pending[msg.id]) { pending[msg.id](msg); delete pending[msg.id]; }
    if (msg.method === 'Runtime.exceptionThrown') {
      errors.push((msg.params.exceptionDetails.exception || {}).description || 'exception');
    }
  });
  function cmd(method, params) {
    return new Promise(function (res) {
      var myId = ++id;
      pending[myId] = res;
      ws.send(JSON.stringify({ id: myId, method: method, params: params || {} }));
    });
  }
  function evalJS(expr) {
    return cmd('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })
      .then(function (r) { return r.result && r.result.result && r.result.result.value; });
  }
  async function shot(name) {
    var s = await cmd('Page.captureScreenshot', { format: 'png' });
    if (s.result && s.result.data) fs.writeFileSync(path.resolve(__dirname, name), Buffer.from(s.result.data, 'base64'));
  }

  await cmd('Runtime.enable');
  await cmd('Page.enable');
  await sleep(300);

  console.log('\n① UI 素材文件全部可加载（27 张：军师5+事件10+场景8+敌将3+刘邦）');
  var loadRes = await evalJS("(function(){var ids=[];var D=Data.UI_ART;" +
    "Object.keys(D.advisors).forEach(function(k){ids.push('ad_'+k)});" +
    "Object.keys(D.events).forEach(function(k){ids.push('ev_'+k)});" +
    "Object.keys(D.scenes).forEach(function(k){ids.push('sc_'+k)});" +
    "Object.keys(D.heroes).forEach(function(k){ids.push(k)});" +
    "return Promise.all(ids.map(function(n){return new Promise(function(r){var im=new Image();" +
    "im.onload=function(){r(n+':ok')};im.onerror=function(){r(n+':FAIL')};" +
    "im.src='assets/cards/'+n+'.png';});})).then(function(a){return a.filter(function(x){return x.indexOf('FAIL')>=0}).join(',')||'all-ok';});})()");
  check('全部素材图可加载', loadRes === 'all-ok', String(loadRes));

  console.log('\n② 军师三选一立绘');
  await evalJS("localStorage.clear();Campaign.reset();document.getElementById('btn-campaign').click()");
  await sleep(400);
  var advArt = await evalJS("(function(){var els=document.querySelectorAll('#advisor-cards .adv-art');var bg=[];" +
    "els.forEach(function(e){bg.push(e.style.backgroundImage);});" +
    "return {n:els.length,bg:bg.join('|')};})()");
  check('3 张军师头像图挂载', advArt && advArt.n === 3, '实际 ' + (advArt ? advArt.n : 0));
  check('头像指向 ad_*.png', advArt && advArt.bg.indexOf('assets/cards/ad_') >= 0);
  await sleep(600); await shot('_art-advisor.png');

  console.log('\n③ 关卡介绍场景背景（沛县起兵）');
  await evalJS("(function(){var e=document.querySelector('#advisor-cards .adv-card');e.click();})()");
  await sleep(400);
  await evalJS("(function(){document.querySelectorAll('.stage-node.open,[data-stage=peixian]').forEach(function(n){n.click()});" +
    "window.__ui.openLore(Campaign.STAGES[0]);})()");
  await sleep(500);
  var loreInfo = await evalJS("(function(){var s=document.getElementById('lore-screen');" +
    "return {art:s.classList.contains('lore-art'),bg:s.style.backgroundImage};})()");
  check('lore 页启用场景背景', loreInfo && loreInfo.art === true);
  check('背景指向 sc_peixian.png', loreInfo && loreInfo.bg.indexOf('sc_peixian') >= 0);
  await sleep(600); await shot('_art-lore.png');

  console.log('\n④ 行军事件插图（流民归附）');
  await evalJS("window.__ui.openEvent(Campaign.EVENTS[0])");
  await sleep(500);
  var evInfo = await evalJS("(function(){var g=document.getElementById('ev-glyph');" +
    "return {art:g.classList.contains('has-art'),bg:g.style.backgroundImage};})()");
  check('事件图挂载为圆形头像', evInfo && evInfo.art === true);
  check('指向 ev_liumin.png', evInfo && evInfo.bg.indexOf('ev_liumin') >= 0);
  await sleep(600); await shot('_art-event.png');

  console.log('\n⑤ 战场敌将专属头像（第一关·泗水郡监）');
  await evalJS("(function(){window.__ui.openLore(Campaign.STAGES[0]);})()");
  await sleep(300);
  await evalJS("document.getElementById('btn-lore-fight').click()");
  await sleep(900);
  var foeInfo = await evalJS("(function(){var a=document.getElementById('enemy-avatar');" +
    "var s=window.__ui.gameState();return {art:a.classList.contains('has-art')," +
    "bg:a.style.backgroundImage,name:s?s.players.p2.name:'?'};})()");
  check('敌将用专属头像 h_sishui', foeInfo && foeInfo.bg.indexOf('h_sishui') >= 0,
    (foeInfo ? foeInfo.name : '?') + ' ' + (foeInfo ? foeInfo.bg : ''));
  /* 确认出战，进入真实战场后再截一张敌将头像的视觉确认图 */
  await evalJS("document.getElementById('btn-mull-ok').click()");
  await sleep(900);
  await shot('_art-battle.png');

  console.log('\n⑥ 控制台错误');
  check('无 JS 报错', errors.length === 0, errors.slice(0, 2).join(' | '));

  console.log(failed === 0 ? '\n立绘接入验收全部通过' : '\n有 ' + failed + ' 项失败');
  chrome.kill();
  process.exit(failed === 0 ? 0 : 1);
})().catch(function (e) { console.error('FATAL', e); process.exit(1); });
