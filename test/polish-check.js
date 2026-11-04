/* 表现层验收：主菜单氛围 / 设置面板 / 音乐场景 / 战斗张力与濒危提示 */
var http = require('http');
var net = require('net');
var crypto = require('crypto');
var cp = require('child_process');
var path = require('path');
var fs = require('fs');

var CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
var PORT = 9337;
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
      .then(function (r) { return r.result && r.result.result && r.result.result.value; });
  }
  async function shot(name) {
    var s = await cmd('Page.captureScreenshot', { format: 'png' });
    if (s.result && s.result.data) fs.writeFileSync(path.resolve(__dirname, name), Buffer.from(s.result.data, 'base64'));
  }

  await cmd('Runtime.enable');
  await cmd('Page.enable');
  await sleep(300);

  console.log('\n① 主菜单氛围');
  await evalJS("localStorage.clear();location.reload()");
  await sleep(2600);
  var scene = await evalJS("(function(){var h=document.querySelector('.ts-han'),c=document.querySelector('.ts-chu');" +
    "return {han:!!h,chu:!!c,hbg:h?getComputedStyle(h).backgroundImage:'',cbg:c?getComputedStyle(c).backgroundImage:''};})()");
  check('左右两位主将剪影层存在', scene && scene.han && scene.chu);
  check('左侧指向刘邦立绘', scene && scene.hbg.indexOf('liubang') >= 0);
  check('右侧指向项羽立绘', scene && scene.cbg.indexOf('xiangyu') >= 0);
  var titleAnim = await evalJS("(function(){var t=document.querySelector('.game-title');" +
    "var s=getComputedStyle(t);return {name:s.animationName,dur:s.animationDuration};})()");
  check('标题有墨迹入场动画', titleAnim && titleAnim.name.indexOf('title-in') >= 0, titleAnim && titleAnim.dur);
  var menuMusic = await evalJS("window.__ui.settingsState().music");
  check('主菜单音乐场景 = title', menuMusic === 'title', String(menuMusic));
  await sleep(900); await shot('_polish-menu.png');

  console.log('\n② 设置面板');
  await evalJS("document.getElementById('btn-settings').click()");
  await sleep(400);
  var opened = await evalJS("!document.getElementById('settings-screen').classList.contains('hidden')");
  check('齿轮打开设置面板', opened === true);
  var initVol = await evalJS("window.__ui.settingsState()");
  check('滑杆初值与音量一致', Math.round(initVol.bgm * 100) === Number(await evalJS("document.getElementById('set-bgm').value")),
    'bgm=' + initVol.bgm + ' sfx=' + initVol.sfx);
  await evalJS("(function(){var e=document.getElementById('set-bgm');e.value=25;e.dispatchEvent(new Event('input'));})()");
  await sleep(200);
  var volAfter = await evalJS("window.__ui.settingsState().bgm");
  check('拖动音乐滑杆改变音量', Math.abs(volAfter - 0.25) < 0.001, 'bgm=' + volAfter);
  var persisted = await evalJS("localStorage.getItem('chuhan_vol')");
  check('音量写入本地存档', persisted && persisted.indexOf('0.25') >= 0, String(persisted));
  await evalJS("document.getElementById('set-motion').click()");
  await sleep(150);
  var motionOff = await evalJS("({body:document.body.classList.contains('reduce-motion'),ui:window.__ui.settingsState().motion})");
  check('关闭动效 → 全局降级生效', motionOff.body === true && motionOff.ui === false);
  await evalJS("document.getElementById('set-motion').click()");
  await sleep(120);
  var motionOn = await evalJS("document.body.classList.contains('reduce-motion')");
  check('再开动效 → 恢复', motionOn === false);
  await evalJS("document.getElementById('set-mute').click()");
  await sleep(120);
  var muted = await evalJS("window.__ui.settingsState().muted");
  check('面板内静音开关生效', muted === true);
  await evalJS("document.getElementById('set-mute').click()");
  await sleep(120);
  await shot('_polish-settings.png');
  await evalJS("document.getElementById('set-close').click()");
  await sleep(200);
  var closed = await evalJS("document.getElementById('settings-screen').classList.contains('hidden')");
  check('返回按钮关闭面板', closed === true);
  /* 恢复默认音量，避免影响后续截图与体验 */
  await evalJS("localStorage.removeItem('chuhan_vol')");

  console.log('\n③ 进入战斗：音乐切场景');
  await evalJS("localStorage.clear();Campaign.reset();document.getElementById('btn-campaign').click()");
  await sleep(400);
  await evalJS("document.querySelector('#advisor-cards .adv-card').click()");
  await sleep(400);
  await evalJS("window.__ui.openLore(Campaign.STAGES[0]);document.getElementById('btn-lore-fight').click()");
  await sleep(800);
  var battleMusic = await evalJS("window.__ui.settingsState().music");
  check('战斗音乐场景 = battle', battleMusic === 'battle', String(battleMusic));
  await evalJS("document.getElementById('btn-mull-ok').click()");
  await sleep(700);

  console.log('\n④ 战斗张力与濒危提示');
  var t0 = await evalJS("window.__ui.settingsState().tension");
  check('满血时张力为 0', t0 < 0.1, String(t0));
  await evalJS("(function(){var s=window.__ui.gameState();s.players.p1.hp=6;window.__ui.render();})()");
  await sleep(300);
  var t1 = await evalJS("window.__ui.settingsState().tension");
  check('残血时音乐张力上升', t1 > 0.5, String(t1));
  var dg = await evalJS("(function(){var a=document.getElementById('player-avatar');" +
    "var b=document.getElementById('enemy-avatar');" +
    "return {me:a.classList.contains('danger'),foe:b.classList.contains('danger')};})()");
  check('我方主将濒危红边', dg.me === true);
  check('敌方主将未濒危', dg.foe === false);
  await sleep(600); await shot('_polish-battle.png');

  console.log('\n⑤ 控制台错误');
  check('无 JS 报错', errors.length === 0, errors.slice(0, 2).join(' | '));

  console.log(failed === 0 ? '\n表现层验收全部通过' : '\n有 ' + failed + ' 项失败');
  chrome.kill();
  process.exit(failed === 0 ? 0 : 1);
})().catch(function (e) { console.error('FATAL', e); process.exit(1); });
