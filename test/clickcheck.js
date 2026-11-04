/* 用 Chrome DevTools Protocol 发真实鼠标事件，验证战役地图点击 */
var http = require('http');
var net = require('net');
var crypto = require('crypto');
var cp = require('child_process');
var path = require('path');

var CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
var PORT = 9333;
var URL = 'file:///' + path.resolve(__dirname, '..', 'index.html').replace(/\\/g, '/');

function getJSON(p) {
  return new Promise(function (res, rej) {
    http.get({ host: '127.0.0.1', port: PORT, path: p }, function (r) {
      var b = ''; r.on('data', function (d) { b += d; }); r.on('end', function () { try { res(JSON.parse(b)); } catch (e) { rej(e); } });
    }).on('error', rej);
  });
}

/* 极简 WebSocket 客户端 */
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
        handshook = true;
        buf = buf.slice(i + 4);
        resolve({ send: send, on: function (fn) { listeners.push(fn); }, close: function () { sock.end(); } });
      }
      while (buf.length >= 2) {
        var len = buf[1] & 127, off = 2;
        if (len === 126) { len = buf.readUInt16BE(2); off = 4; }
        else if (len === 127) { len = Number(buf.readBigUInt64BE(2)); off = 10; }
        if (buf.length < off + len) return;
        var payload = buf.slice(off, off + len).toString();
        buf = buf.slice(off + len);
        listeners.forEach(function (fn) { fn(payload); });
      }
    });
    sock.on('error', reject);
    function send(text) {
      var data = Buffer.from(text);
      var head;
      if (data.length < 126) head = Buffer.from([0x81, 0x80 | data.length]);
      else { head = Buffer.alloc(4); head[0] = 0x81; head[1] = 0x80 | 126; head.writeUInt16BE(data.length, 2); }
      var mask = crypto.randomBytes(4);
      var masked = Buffer.from(data);
      for (var i = 0; i < masked.length; i++) masked[i] ^= mask[i % 4];
      sock.write(Buffer.concat([head, mask, masked]));
    }
  });
}

function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

(async function () {
  var chrome = cp.spawn(CHROME, ['--headless=new', '--disable-gpu', '--remote-debugging-port=' + PORT,
    '--window-size=' + (process.env.WSIZE || '1440,960'), '--no-first-run', '--user-data-dir=' + path.resolve(__dirname, '_cdp-profile'), URL],
    { stdio: 'ignore' });
  await sleep(2500);

  var list = await getJSON('/json/list');
  var page = list.filter(function (t) { return t.type === 'page'; })[0];
  var ws = await connect(page.webSocketDebuggerUrl);

  var id = 0, pending = {};
  ws.on(function (raw) {
    var msg = JSON.parse(raw);
    if (msg.id && pending[msg.id]) { pending[msg.id](msg); delete pending[msg.id]; }
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

  ws.send(JSON.stringify({ id: 0, method: 'Runtime.enable' }));
  await sleep(300);

  console.log('打开战役地图：');
  await evalJS("document.getElementById('btn-campaign').click()");
  await sleep(400);
  console.log('  地图可见 =', await evalJS("!document.getElementById('campaign-screen').classList.contains('hidden')"));

  var rect = await evalJS("(function(){var n=document.querySelector('.stage-node');var r=n.getBoundingClientRect();return {x:Math.round(r.left+r.width/2), y:Math.round(r.top+42), cls:n.className};})()");
  console.log('  第一个关卡节点：', JSON.stringify(rect));

  console.log('发送真实鼠标点击 (mousedown+mouseup)...');
  await cmd('Input.dispatchMouseEvent', { type: 'mouseMoved', x: rect.x, y: rect.y });
  await cmd('Input.dispatchMouseEvent', { type: 'mousePressed', x: rect.x, y: rect.y, button: 'left', clickCount: 1 });
  await cmd('Input.dispatchMouseEvent', { type: 'mouseReleased', x: rect.x, y: rect.y, button: 'left', clickCount: 1 });
  await sleep(500);

  console.log('  剧情页 class =', await evalJS("document.getElementById('lore-screen').className"));
  console.log('  地图页 class =', await evalJS("document.getElementById('campaign-screen').className"));
  console.log('  剧情标题 =', await evalJS("document.getElementById('lore-title').textContent"));

  ws.close();
  chrome.kill();
  process.exit(0);
})();
