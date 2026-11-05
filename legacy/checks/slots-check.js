/* 多存档位界面检查：入口 / 三个槽 / 新建战役 / 切换不串档 / 清空 / 落盘
   用 headless Chrome + CDP，独立 profile 避免与 uicheck 互相污染 */
var http = require('http');
var net = require('net');
var crypto = require('crypto');
var cp = require('child_process');
var path = require('path');
var fs = require('fs');

// 浏览器路径可用 CHROME 环境变量覆盖（本机 Chrome 已卸时指向 Edge 即可跑）
var CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
var PORT = 9336;
var PROFILE = path.resolve(__dirname, '_cdp-slots');
var URL = 'file:///' + path.resolve(__dirname, '..', 'web', 'index.html').replace(/\\/g, '/');

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
  try { fs.rmSync(PROFILE, { recursive: true, force: true }); } catch (e) {}
  var chrome = cp.spawn(CHROME, ['--headless=new', '--disable-gpu', '--remote-debugging-port=' + PORT,
    '--window-size=1440,960', '--no-first-run', '--user-data-dir=' + PROFILE, URL], { stdio: 'ignore' });
  await sleep(2600);

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
      .then(function (r) {
        if (r.result && r.result.exceptionDetails) throw new Error(r.result.exceptionDetails.text);
        return r.result && r.result.result && r.result.result.value;
      });
  }
  async function shot(name) {
    var s = await cmd('Page.captureScreenshot', { format: 'png' });
    if (s.result && s.result.data) fs.writeFileSync(path.resolve(__dirname, name), Buffer.from(s.result.data, 'base64'));
  }

  await cmd('Runtime.enable');
  await cmd('Page.enable');
  await sleep(900);

  console.log('== 入口与初始状态 ==');
  await evalJS("localStorage.clear()");
  await evalJS("location.reload()");
  await sleep(2200);
  await evalJS("document.getElementById('link-slots').click()");
  await sleep(500);
  var m0 = await evalJS("(function(){var sc=document.getElementById('slots-screen');return {shown: !sc.classList.contains('hidden'), rows: document.querySelectorAll('#slot-list .slot-row').length, empty: document.querySelectorAll('#slot-list .slot-row.empty').length, active: window.Campaign.activeSlot()}})()");
  check('主菜单「存档位」可打开存档页', m0 && m0.shown);
  check('三个存档位', m0 && m0.rows === 3, '实际 ' + (m0 ? m0.rows : '?'));
  check('初始全为空位', m0 && m0.empty === 3);

  console.log('== 在第 2 位新建战役 ==');
  await evalJS("document.querySelector('#slot-list .slot-row[data-i=\"1\"] [data-act=\"new\"]').click()");
  await sleep(600);
  var m1 = await evalJS("(function(){return {adv: !document.getElementById('advisor-screen').classList.contains('hidden'), active: window.Campaign.activeSlot()}})()");
  check('新建后进入择师', m1 && m1.adv);
  check('当前存档位切到第 2 位', m1 && m1.active === 1, String(m1 && m1.active));
  await evalJS("document.querySelector('#advisor-cards .adv-card').click()");
  await sleep(700);
  var m2 = await evalJS("(function(){var c=document.getElementById('campaign-screen');return {camp: !c.classList.contains('hidden'), sub: document.getElementById('camp-sub').textContent, slots: document.querySelectorAll('#camp-stages .stage-node').length}})()");
  check('择师后落到战役地图', m2 && m2.camp);
  check('地图显示 8 关', m2 && m2.slots === 8, '实际 ' + (m2 ? m2.slots : '?'));
  check('副标题按存档显示进度', m2 && /刘邦视角/.test(m2.sub) && /0 \/ 8/.test(m2.sub), m2 && m2.sub);

  console.log('== 地图上打开存档位，标记当前位 ==');
  await evalJS("document.getElementById('btn-camp-slots').click()");
  await sleep(500);
  var m3 = await evalJS("(function(){var r=document.querySelector('#slot-list .slot-row[data-i=\"1\"]');return {rows: document.querySelectorAll('#slot-list .slot-row').length, activeRows: document.querySelectorAll('#slot-list .slot-row.active').length, badge: (r.querySelector('.slot-badge')||{}).textContent||'', info: r.querySelector('.slot-info').textContent, btn: r.querySelector('[data-act]').getAttribute('data-act')}})()");
  check('地图入口也能打开存档页', m3 && m3.rows === 3);
  check('第 2 位是高亮当前位', m3 && m3.activeRows === 1 && m3.badge === '当前');
  check('第 2 位已有进度文案', m3 && /刘邦/.test(m3.info) && /0 \/ 8/.test(m3.info), m3 && m3.info);
  check('已有进度的位给「进入」按钮', m3 && m3.btn === 'enter', m3 && m3.btn);

  console.log('== 造一点进度，验证摘要 ==');
  await evalJS("(function(){var p=window.Campaign.load();window.Campaign.clearStage(p,'peixian','n_bing2');window.Campaign.save(p);})()");
  await evalJS("document.getElementById('btn-camp-slots').click()");
  await sleep(400);
  var m4 = await evalJS("(function(){var r=document.querySelector('#slot-list .slot-row[data-i=\"1\"]');return {info: r.querySelector('.slot-info').textContent, meta: r.querySelector('.slot-meta').textContent}})()");
  check('进度摘要正确（1/8 · 下一关鸿门宴）', m4 && /1 \/ 8/.test(m4.info) && /鸿门宴/.test(m4.info), m4 && m4.info);
  check('牌组张数与时间入摘要', m4 && /牌组 21 张/.test(m4.meta) && /\d{4}-\d{2}-\d{2}/.test(m4.meta), m4 && m4.meta);
  await sleep(300); await shot('_slots.png');

  console.log('== 位 3 另开一局，确认不串档 ==');
  await evalJS("document.querySelector('#slot-list .slot-row[data-i=\"2\"] [data-act=\"new\"]').click()");
  await sleep(600);
  await evalJS("document.querySelector('#advisor-cards .adv-card').click()");
  await sleep(600);
  var m5 = await evalJS("(function(){var c=window.Campaign;c.useSlot(1);var a=c.load();c.useSlot(2);var b=c.load();return {aCleared:a.cleared.length,bCleared:b.cleared.length,active:c.activeSlot(),slots:c.slots().map(function(s){return s.empty?'-':s.cleared})}})()");
  check('第 2 位进度未被第 3 位覆盖', m5 && m5.aCleared === 1 && m5.bCleared === 0, JSON.stringify(m5));
  check('三位摘要各自独立', m5 && m5.slots.join(',') === '-,1,0', m5 && m5.slots.join(','));

  console.log('== 清空某位 ==');
  await evalJS("window.confirm = function(){return true}");
  await evalJS("document.getElementById('btn-camp-slots').click()");
  await sleep(400);
  await evalJS("document.querySelector('#slot-list .slot-row[data-i=\"2\"] [data-act=\"clear\"]').click()");
  await sleep(400);
  var m6 = await evalJS("(function(){var s=window.Campaign.slots();return {e2:s[2].empty,e1:s[1].empty,active:window.Campaign.activeSlot()}})()");
  check('第 3 位已清空', m6 && m6.e2 === true);
  check('第 2 位不受影响', m6 && m6.e1 === false);

  console.log('== 落盘 ==');
  var m7 = await evalJS("(function(){var raw=localStorage.getItem('chuhan_slots_v1');if(!raw)return null;var s=JSON.parse(raw);return {v:s.version,n:s.slots.length,active:s.active,has1:!!s.slots[1]}})()");
  check('存档文件 3 槽结构已落盘', m7 && m7.v === 1 && m7.n === 3 && m7.has1 === true, JSON.stringify(m7));

  check('无 JS 报错', errors.length === 0, errors.length ? errors[0].slice(0, 200) : '');

  await ws.close();
  chrome.kill();
  console.log(failed ? ('\n失败 ' + failed + ' 项') : '\n存档位检查全部通过');
  process.exit(failed ? 1 : 0);
})().catch(function (e) { console.error('脚本错误:', e.message); process.exit(2); });
