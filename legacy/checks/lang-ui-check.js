/* 界面多语言检查：切 EN 后可见文本无 CJK 残留 + 关键界面截图 + 切回 zh 恢复 */
var http = require('http');
var net = require('net');
var crypto = require('crypto');
var cp = require('child_process');
var path = require('path');
var fs = require('fs');

// 浏览器路径可用 CHROME 环境变量覆盖（本机 Chrome 已卸时指向 Edge 即可跑）
var CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
var PORT = 9337;
var PROFILE = path.resolve(__dirname, '_cdp-lang');
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
        if (r.result && r.result.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails).slice(0, 200));
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

  /* CJK 残留扫描：跳过有立绘遮盖的装饰字符（.has-art 内的 glyph） */
  var scanExpr = "(function(){var out=[];var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,null,false);" +
    "var n;while(n=w.nextNode()){if(!/[\\u4e00-\\u9fff]/.test(n.nodeValue))continue;" +
    "var el=n.parentElement;if(el&&el.closest&&el.closest('.has-art'))continue;" +
    "if(el&&el.closest&&el.closest('#log,#coach-layer,#kw-tip,#coach-tip,#card-preview'))continue;" +
    "var vis=true,e=el;while(e&&e!==document.body){var st=getComputedStyle(e);if(st.display==='none'||st.visibility==='hidden'){vis=false;break}e=e.parentElement}" +
    "if(vis)out.push(n.nodeValue.trim().slice(0,40));}return out;})()";

  console.log('== 切换到 English ==');
  await evalJS("document.getElementById('btn-settings').click()");
  await sleep(400);
  await evalJS("document.querySelector('.lang-btn[data-lang=\"en\"]').click()");
  await sleep(700);
  var lang = await evalJS('I18N.lang()');
  check('语言已切到 en', lang === 'en', lang);
  var btnSel = await evalJS("(function(){var b=document.querySelector('.lang-btn[data-lang=\"en\"]');return b.classList.contains('selected')})()");
  check('English 按钮高亮', btnSel);
  await evalJS("document.getElementById('set-close').click()");

  console.log('== 各屏 CJK 残留扫描 ==');
  var left = await evalJS(scanExpr);
  check('主菜单无残留', left.length === 0, left.slice(0, 5).join(' | '));
  await sleep(400); await shot('_lang-menu.png');

  await evalJS("document.getElementById('link-codex').click()");
  await sleep(700);
  var left2 = await evalJS(scanExpr);
  check('图鉴页无残留', left2.length === 0, left2.slice(0, 6).join(' | '));
  await sleep(300); await shot('_lang-codex.png');

  await evalJS("document.getElementById('btn-codex-back').click()");
  await sleep(300);
  await evalJS("(function(){var c=document.querySelectorAll('#start-screen .hero-card')[0];if(c)c.click();var b=document.getElementById('btn-start');if(b)b.click();})()");
  await sleep(2600);   /* 等对局与换牌屏 */
  var left3 = await evalJS(scanExpr);
  check('换牌/对局屏无残留', left3.length === 0, left3.slice(0, 8).join(' | '));
  await sleep(300); await shot('_lang-battle.png');

  /* AI 打几个回合，制造战报，检查战报翻译 */
  await evalJS("(function(){var b=document.getElementById('btn-mull-ok');if(b)b.click();})()");
  await sleep(800);
  for (var i = 0; i < 3; i++) { await evalJS("document.getElementById('btn-end').click()"); await sleep(2400); }
  var left4 = await evalJS(scanExpr);
  check('对局进行中（含战报）无残留', left4.length === 0, left4.slice(0, 8).join(' | '));
  var logSample = await evalJS("(function(){return document.getElementById('log').innerText.split('\\n').filter(Boolean).slice(0,3)})()");
  console.log('  战报样例: ' + (logSample || []).join(' / '));
  await sleep(300); await shot('_lang-battle-mid.png');

  console.log('== 切回中文 ==');
  await evalJS("document.getElementById('btn-settings').click()");
  await sleep(400);
  await evalJS("document.querySelector('.lang-btn[data-lang=\"zh\"]').click()");
  await sleep(700);
  var back = await evalJS("(function(){return {lang: I18N.lang(), title: document.querySelector('#over-title')?document.title:null, hero: document.querySelector('.hero-name').textContent.trim()}})()");
  check('语言切回 zh', back.lang === 'zh');
  check('主菜单恢复中文', /刘邦/.test(JSON.stringify(back)), JSON.stringify(back));
  await evalJS("document.getElementById('set-close').click()");

  check('无 JS 报错', errors.length === 0, errors.length ? errors[0].slice(0, 200) : '');

  await ws.close();
  chrome.kill();
  console.log(failed ? ('\n失败 ' + failed + ' 项') : '\n界面多语言检查全部通过');
  process.exit(failed ? 1 : 0);
})().catch(function (e) { console.error('脚本错误:', e.message); process.exit(2); });
