/* Electron 桌面壳验收：连本机已运行的 electron（--remote-debugging-port=9333）
 * 用法：先 env -u ELECTRON_RUN_AS_NODE npx electron . --remote-debugging-port=9333 &
 *       再 node test/desktop-check.js
 */
var http = require('http');
var net = require('net');
var crypto = require('crypto');
var path = require('path');
var fs = require('fs');

var PORT = Number(process.argv[2]) || 9333;

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
  var list = await getJSON('/json/list');
  var page = list.filter(function (t) { return t.type === 'page'; })[0];
  if (!page) { console.log('✗ 未找到 Electron 页面'); process.exit(1); }
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
    return new Promise(function (res, rej) {
      var myId = ++id;
      var to = setTimeout(function () { delete pending[myId]; rej(new Error(method + ' 超时')); }, 10000);
      pending[myId] = function (m) { clearTimeout(to); res(m); };
      ws.send(JSON.stringify({ id: myId, method: method, params: params || {} }));
    });
  }
  function evalJS(expr) {
    return cmd('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })
      .then(function (r) { return r.result && r.result.result && r.result.result.value; });
  }
  async function shot(name) {
    await cmd('Page.bringToFront', {});
    await sleep(150);
    var s = await cmd('Page.captureScreenshot', { format: 'png' });
    if (s.result && s.result.data) fs.writeFileSync(path.resolve(__dirname, name), Buffer.from(s.result.data, 'base64'));
  }

  await cmd('Runtime.enable');
  await cmd('Page.enable');
  await sleep(800);

  console.log('== 桌面桥 ==');
  var bridge = await evalJS("(function(){return {isDesktop: !!(window.Desktop && window.Desktop.isDesktop), hasToggle: !!(window.Desktop && window.Desktop.toggleFullscreen), ua: navigator.userAgent.indexOf('Electron') >= 0}})()");
  check('window.Desktop 桥已注入', bridge && bridge.isDesktop && bridge.hasToggle);
  check('运行于 Electron 环境', bridge && bridge.ua);

  console.log('== 原生全屏 ==');
  /* 复位：若上次运行残留全屏，先退出来（全屏态下 captureScreenshot 会挂起） */
  var fsPre = await evalJS('window.Desktop.fullscreenState()');
  if (fsPre) { await evalJS('window.Desktop.toggleFullscreen()'); await sleep(800); }
  var fs0 = await evalJS('window.Desktop.fullscreenState()');
  check('初始非全屏', fs0 === false, String(fs0));
  await evalJS("(function(){var b=document.getElementById('btn-settings');if(b)b.click();})()");
  await sleep(400);
  var fsBtnOn = await evalJS("(function(){var b=document.getElementById('set-fs');return b && b.textContent;})()");
  check('设置面板全屏按钮存在', fsBtnOn === '开' || fsBtnOn === '关', String(fsBtnOn));
  await evalJS("(function(){var b=document.getElementById('set-fs');if(b)b.click();})()");
  await sleep(700);
  var fs1 = await evalJS('window.Desktop.fullscreenState()');
  check('点击后进入原生全屏', fs1 === true, String(fs1));
  await evalJS("(function(){var b=document.getElementById('set-fs');if(b)b.click();})()");
  await sleep(700);
  var fs2 = await evalJS('window.Desktop.fullscreenState()');
  check('再次点击退出全屏', fs2 === false, String(fs2));
  await sleep(400); await shot('_desktop-fs.png');
  await evalJS("(function(){var b=document.getElementById('set-close');if(b)b.click();})()");

  console.log('== 游戏可玩性抽查 ==');
  await evalJS("(function(){var c=document.querySelectorAll('#start-screen .hero-card')[0];if(c)c.click();var b=document.getElementById('btn-start');if(b)b.click();})()");
  await sleep(3500);
  var game = await evalJS("(function(){var s=window.__ui.gameState();var sh=document.getElementById('game-screen');return {inGame: s && !!s.players, shown: sh && !sh.classList.contains('hidden')}})()");
  check('快速开战进入对局', game && game.inGame && game.shown);
  await sleep(600); await shot('_desktop-battle.png');

  check('无 JS 报错', errors.length === 0, errors.length ? errors[0].slice(0, 160) : '');

  await ws.close();
  console.log(failed ? ('失败 ' + failed + ' 项') : '全部通过');
  process.exit(failed ? 1 : 0);
})().catch(function (e) { console.error('脚本错误:', e.message); process.exit(2); });
