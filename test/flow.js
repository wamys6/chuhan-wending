/* 端到端真实点击流程：战役地图 → 战前剧情 → 出战 → 换牌 → 对局出牌 */
var http = require('http');
var net = require('net');
var crypto = require('crypto');
var cp = require('child_process');
var path = require('path');

var CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
var PORT = 9334;
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
        if (buf.length < off + len) return;
        var payload = buf.slice(off, off + len).toString();
        buf = buf.slice(off + len);
        listeners.forEach(function (fn) { fn(payload); });
      }
    });
    sock.on('error', reject);
    function send(text) {
      var data = Buffer.from(text), head;
      if (data.length < 126) head = Buffer.from([0x81, 0x80 | data.length]);
      else { head = Buffer.alloc(4); head[0] = 0x81; head[1] = 0x80 | 126; head.writeUInt16BE(data.length, 2); }
      var mask = crypto.randomBytes(4), masked = Buffer.from(data);
      for (var i = 0; i < masked.length; i++) masked[i] ^= mask[i % 4];
      sock.write(Buffer.concat([head, mask, masked]));
    }
  });
}

function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

(async function () {
  var chrome = cp.spawn(CHROME, ['--headless=new', '--disable-gpu', '--remote-debugging-port=' + PORT,
    '--window-size=1440,960', '--no-first-run', '--user-data-dir=' + path.resolve(__dirname, '_cdp-profile2'), URL],
    { stdio: 'ignore' });
  await sleep(2500);

  var list = await getJSON('/json/list');
  var page = list.filter(function (t) { return t.type === 'page'; })[0];
  var ws = await connect(page.webSocketDebuggerUrl);
  var id = 0, pending = {};
  var errors = [];
  ws.on(function (raw) {
    var msg = JSON.parse(raw);
    if (msg.id && pending[msg.id]) { pending[msg.id](msg); delete pending[msg.id]; return; }
    if (msg.method === 'Runtime.exceptionThrown') {
      var d = msg.params.exceptionDetails;
      errors.push((d.exception && d.exception.description || d.text || 'err').split('\n')[0]);
    }
  });
  function cmd(method, params) {
    return new Promise(function (res) { var myId = ++id; pending[myId] = res; ws.send(JSON.stringify({ id: myId, method: method, params: params || {} })); });
  }
  function ev(expr) {
    return cmd('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })
      .then(function (r) { return r.result && r.result.result && r.result.result.value; });
  }
  async function clickSel(sel, dy) {
    var r = await ev("(function(){var e=document.querySelector('" + sel + "');if(!e)return null;var b=e.getBoundingClientRect();return {x:Math.round(b.left+b.width/2),y:Math.round(b.top+(b.height/2))};})()");
    if (!r) { console.log('  ✗ 找不到元素 ' + sel); return false; }
    await cmd('Input.dispatchMouseEvent', { type: 'mouseMoved', x: r.x, y: r.y });
    await cmd('Input.dispatchMouseEvent', { type: 'mousePressed', x: r.x, y: r.y, button: 'left', clickCount: 1 });
    await cmd('Input.dispatchMouseEvent', { type: 'mouseReleased', x: r.x, y: r.y, button: 'left', clickCount: 1 });
    await sleep(420);
    return true;
  }
  async function visible(sel) {
    return await ev("(function(){var e=document.querySelector('" + sel + "');if(!e)return false;var s=getComputedStyle(e);return e.className.indexOf('hidden')<0 && s.display!=='none' && s.visibility!=='hidden';})()");
  }

  ws.send(JSON.stringify({ id: 0, method: 'Runtime.enable' }));
  process.on('exit', function () { if (errors.length) console.log('\n页面异常：\n - ' + errors.join('\n - ')); });
  await sleep(300);

  console.log('① 点「楚汉战役」');
  await clickSel('#btn-campaign');
  if (await visible('#advisor-screen')) {
    console.log('   军师三选一出现，点第一位军师');
    await clickSel('#advisor-cards .adv-card');
  }
  console.log('   地图可见 =', await visible('#campaign-screen'));

  console.log('② 点「沛县起兵」');
  await clickSel('.stage-node');
  console.log('   剧情页可见 =', await visible('#lore-screen'), '| 标题 =', await ev("document.getElementById('lore-title').textContent"));

  console.log('③ 点「出战」');
  await clickSel('#btn-lore-fight');
  console.log('   换牌页可见 =', await visible('#mulligan-screen'), '| 对局页可见 =', await visible('#game-screen'));

  console.log('   换牌按钮探查：disabled =', await ev("document.getElementById('btn-mull-ok').disabled"),
    '| 位置命中 =', await ev("(function(){var e=document.getElementById('btn-mull-ok');var r=e.getBoundingClientRect();var t=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);return (t?t.tagName+'#'+t.id:'null')+' rect='+Math.round(r.left)+','+Math.round(r.top)+' wh='+Math.round(r.width)+'x'+Math.round(r.height)+' win='+window.innerWidth+'x'+window.innerHeight;})()"));
  console.log('   换牌页高度诊断 =', await ev("(function(){var o=[];var inner=document.querySelector('.mull-inner');o.push('inner='+Math.round(inner.getBoundingClientRect().height));['#mulligan-cards','.mull-inner h2','.mull-hint','.mull-actions'].forEach(function(sel){var e=document.querySelector(sel);if(e){var r=e.getBoundingClientRect();o.push(sel+'='+Math.round(r.height)+'@'+Math.round(r.top));}});var c=document.querySelector('.mull-card .card');if(c){var r2=c.getBoundingClientRect();o.push('card='+Math.round(r2.width)+'x'+Math.round(r2.height));}return o.join(' | ');})()"));
  if (await visible('#mulligan-screen')) {
    console.log('④ 点「全部保留」');
    await clickSel('#btn-mull-ok');
    console.log('   对局页可见 =', await visible('#game-screen'),
      '| 换牌页仍可见 =', await visible('#mulligan-screen'),
      '| 军粮 =', await ev("document.getElementById('player-mana').textContent"));
  }

  console.log('⑤ 对局信息');
  console.log('   我方主将 =', await ev("document.getElementById('player-name').textContent"),
    '| 敌方主将 =', await ev("document.getElementById('enemy-name').textContent"));
  console.log('   目标提示 =', await ev("document.getElementById('goal-banner').className + ' :: ' + document.getElementById('goal-banner').textContent"));
  console.log('   手牌张数 =', await ev("document.querySelectorAll('#hand .card').length"));

  async function waitMyTurn(timeout) {
    var t0 = Date.now();
    while (Date.now() - t0 < (timeout || 12000)) {
      var txt = await ev("document.getElementById('turn-banner').textContent");
      if (txt.indexOf('我') >= 0) return true;
      await sleep(250);
    }
    return false;
  }

  console.log('⑥ 过两个回合攒军粮');
  for (var t = 0; t < 2; t++) {
    await waitMyTurn();
    await clickSel('#btn-end');
    await clickSel('#btn-end');   /* 二次确认 */
    await sleep(300);
  }
  await waitMyTurn();
  console.log('   轮到我方，军粮 =', await ev("document.getElementById('player-mana').textContent"));

  console.log('⑦ 点手牌出牌');
  console.log('   手牌命中探查 =', await ev("(function(){var c=document.querySelector('#hand .card');if(!c)return 'no card';var r=c.getBoundingClientRect();var t=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);return 'rect='+Math.round(r.left)+','+Math.round(r.top)+' '+Math.round(r.width)+'x'+Math.round(r.height)+' top='+(t?t.tagName+'.'+t.className:'null');})()"));
  var handBefore = await ev("document.querySelectorAll('#hand .card').length");
  var unitBefore = await ev("document.querySelectorAll('.rank-row[data-side=\"player\"] .unit:not(.empty-slot)').length");
  var played = 0;
  for (var k = 1; k <= 6; k++) {
    var has = await ev("!!document.querySelector('#hand .card:nth-child(" + k + "')");
    if (!has) break;
    await clickSel('#hand .card:nth-child(' + k + ')');
    var handNow = await ev("document.querySelectorAll('#hand .card').length");
    var unitNow = await ev("document.querySelectorAll('.rank-row[data-side=\"player\"] .unit:not(.empty-slot)').length");
    if (handNow < handBefore || unitNow > unitBefore) { played = k; break; }
  }
  var handAfter = await ev("document.querySelectorAll('#hand .card').length");
  var unitAfter = await ev("document.querySelectorAll('.rank-row[data-side=\"player\"] .unit:not(.empty-slot)').length");
  console.log('   手牌 ' + handBefore + ' → ' + handAfter + '，我方场上单位 ' + unitBefore + ' → ' + unitAfter,
    played ? ('（第 ' + played + ' 张出牌成功 ✅）') : '（未出牌 ✗）');
  console.log('   战报 =', await ev("(document.getElementById('log').textContent||'').slice(-36)"));

  ws.close(); chrome.kill();
  process.exit(0);
})();
