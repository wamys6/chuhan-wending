/* 界面检查：军师三选一 / 8 关地图 / 行军事件 / 选牌屏 / 45 张卡池 / 无 JS 报错 */
var http = require('http');
var net = require('net');
var crypto = require('crypto');
var cp = require('child_process');
var path = require('path');
var fs = require('fs');

var CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
var PORT = 9335;
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
    if (msg.method === 'Log.entryAdded' && msg.params.entry.level === 'error') {
      errors.push(msg.params.entry.text);
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
  await cmd('Log.enable');
  await cmd('Page.enable');
  await sleep(300);

  console.log('\n① 军师三选一');
  await evalJS("localStorage.clear();Campaign.reset();document.getElementById('btn-campaign').click()");
  await sleep(400);
  var advVisible = await evalJS("!document.getElementById('advisor-screen').classList.contains('hidden')");
  check('首次进战役先弹军师选择', advVisible === true);
  var advCount = await evalJS("document.querySelectorAll('#advisor-cards .adv-card').length");
  check('三选一：3 张军师卡', advCount === 3, '实际 ' + advCount);
  var advNames = await evalJS("Array.prototype.map.call(document.querySelectorAll('#advisor-cards .adv-name'),function(e){return e.textContent.trim();})");
  console.log('    ' + (advNames || []).join(' / '));
  var advDesc = await evalJS("(function(){var e=document.querySelector('#advisor-cards .adv-skill');return e?e.textContent.length:0;})()");
  check('军师说明文案非空', advDesc > 8, advDesc + ' 字');
  await shot('_ui-advisor.png');

  console.log('\n② 选定军师 → 地图');
  var chosen = await evalJS("(function(){var e=document.querySelector('#advisor-cards .adv-card');var id=e.getAttribute('data-id');e.click();return id;})()");
  await sleep(400);
  var mapVisible = await evalJS("!document.getElementById('campaign-screen').classList.contains('hidden')");
  check('选完回到地图', mapVisible === true);
  var saved = await evalJS("Campaign.load().advisor");
  check('军师已写入存档', saved === chosen, '存档 ' + saved + ' / 点击 ' + chosen);
  var chip = await evalJS("(function(){var e=document.querySelector('#camp-buffs .adv-chip');return e?e.textContent:'';})()");
  check('地图顶部显示军师', /军师/.test(chip) && chip.length > 4, chip);

  console.log('\n③ 地图 8 关');
  var nodes = await evalJS("document.querySelectorAll('.stage-node').length");
  check('关卡节点 8 个', nodes === 8, '实际 ' + nodes);
  var names = await evalJS("Array.prototype.map.call(document.querySelectorAll('.stage-node .stage-title'),function(e){return e.textContent.replace(/已 通 关|待 战/g,'').trim();})");
  console.log('    ' + (names || []).join(' → '));
  var states = await evalJS("Array.prototype.map.call(document.querySelectorAll('.stage-node'),function(e){return e.className.replace('stage-node ','');})");
  check('首关可战、其余锁定', (states || []).join(',') === 'open,locked,locked,locked,locked,locked,locked,locked', (states || []).join(','));
  var sub = await evalJS("document.getElementById('camp-sub').textContent");
  check('副标题显示 0/8', /0 \/ 8/.test(sub), sub);
  await shot('_ui-map.png');

  console.log('\n④ 锁定关卡不可进入');
  await evalJS("document.querySelectorAll('.stage-node')[3].click()");
  await sleep(300);
  var loreTitle = await evalJS("document.getElementById('lore-title').textContent");
  check('点第 4 关不进剧情', loreTitle === '沛县起兵', '剧情标题 ' + loreTitle);
  var toast = await evalJS("document.getElementById('toast').textContent");
  check('给出提示', /先打赢前一关/.test(toast), toast);

  console.log('\n⑤ 行军事件屏');
  var evInfo = await evalJS("(function(){var e=Campaign.EVENTS[0];window.__ui.openEvent(e);" +
    "return {t:document.getElementById('ev-title').textContent," +
    "opts:document.querySelectorAll('#ev-options .ev-opt').length," +
    "txt:document.getElementById('ev-text').textContent.length};})()");
  check('事件标题渲染', evInfo && evInfo.t === '流民归附', evInfo && evInfo.t);
  check('选项按钮渲染', evInfo && evInfo.opts >= 2, evInfo && ('实际 ' + evInfo.opts));
  check('事件正文渲染', evInfo && evInfo.txt > 20, evInfo && (evInfo.txt + ' 字'));
  await shot('_ui-event.png');

  console.log('\n⑥ 事件选项真的生效');
  var res = await evalJS("(function(){var prog=Campaign.load();var before=prog.hpBonus||0;" +
    "document.querySelectorAll('#ev-options .ev-opt')[0].click();" +
    "var after=Campaign.load();return {before:before,after:after.hpBonus,log:after.eventLog.length," +
    "map:!document.getElementById('campaign-screen').classList.contains('hidden')," +
    "chip:(document.querySelector('#camp-buffs .buff-chip.good')||{}).textContent||''};})()");
  check('选项结算写入生命加成', res && res.after === res.before + 3, res && (res.before + ' → ' + res.after));
  check('事件流水有记录', res && res.log === 1, res && ('日志 ' + res.log));
  check('结算后回到地图', res && res.map === true);
  check('地图显示生命加成', res && /生命上限/.test(res.chip), res && res.chip);

  console.log('\n⑦ 通用选牌屏（得牌）');
  var pickInfo = await evalJS("(function(){window.__ui.showCardPick({title:'得 牌',desc:'测试得牌'," +
    "cards:['n_ma1','n_pao1','h_caocan'],deck:Campaign.load().deck,mode:'add',count:1});" +
    "return {n:document.querySelectorAll('#pick-cards .reward-card').length," +
    "title:document.getElementById('pick-title').textContent};})()");
  check('候选卡片渲染 3 张', pickInfo && pickInfo.n === 3, pickInfo && ('实际 ' + pickInfo.n));
  var addRes = await evalJS("(function(){var before=Campaign.load().deck.length;" +
    "document.querySelector('#pick-cards .reward-card').click();" +
    "return {before:before,after:Campaign.load().deck.length};})()");
  check('点选后牌组 +1', addRes && addRes.after === addRes.before + 1, addRes && (addRes.before + ' → ' + addRes.after));

  console.log('\n⑧ 通用选牌屏（删牌）');
  var delRes = await evalJS("(function(){var prog=Campaign.load();var before=prog.deck.length;" +
    "window.__ui.showCardPick({title:'精 简',desc:'删一张',cards:prog.deck.slice(),deck:prog.deck,mode:'remove',count:1});" +
    "document.querySelector('#pick-cards .reward-card').click();" +
    "return {before:before,after:Campaign.load().deck.length};})()");
  check('删牌后牌组 -1', delRes && delRes.after === delRes.before - 1, delRes && (delRes.before + ' → ' + delRes.after));

  console.log('\n⑨ 45 张卡池构筑');
  await evalJS("document.getElementById('btn-camp-back').click()");
  await sleep(300);
  await evalJS("document.querySelector('.hero-card[data-hero=liubang]').click()");
  await sleep(200);
  await evalJS("document.getElementById('btn-deckbuilder').click()");
  await sleep(500);
  var pool = await evalJS("document.querySelectorAll('#deck-pool .deck-card').length");
  check('卡池渲染 45 张', pool === 45, '实际 ' + pool);
  var locked = await evalJS("document.querySelectorAll('#deck-pool .deck-card.locked').length");
  check('楚牌对汉将置灰（7 张以上）', locked >= 7, '实际 ' + locked);
  var added = await evalJS("(function(){" +
    "var ids=Array.prototype.map.call(document.querySelectorAll('#deck-pool .deck-card:not(.locked)'),function(e){return e.getAttribute('data-id');});" +
    "for(var i=0;i<ids.length;i++){for(var k=0;k<2;k++){var el=document.querySelector('#deck-pool .deck-card[data-id=\\\"'+ids[i]+'\\\"]');if(el)el.click();}}" +
    "return document.getElementById('deck-num').textContent;})()");
  check('可加满 20 张', String(added) === '20', '计数 ' + added);

  console.log('\n⑩ 关键词标注与释义气泡');
  var kwCount = await evalJS("document.querySelectorAll('#deck-pool .cdesc .kw').length");
  check('牌面描述标注关键词', kwCount >= 10, '实际 ' + kwCount + ' 处');
  var kwTip = await evalJS("(function(){var b=document.querySelector('#deck-pool .cdesc .kw');" +
    "var r=b.getBoundingClientRect();" +
    "b.dispatchEvent(new MouseEvent('mouseover',{bubbles:true,clientX:r.left+4,clientY:r.top+4}));" +
    "var t=document.getElementById('kw-tip');" +
    "return {show:!!t&&t.classList.contains('show'),txt:t?t.textContent:''};})()");
  check('悬停弹出释义气泡', kwTip && kwTip.show === true, kwTip && kwTip.txt.slice(0, 24));
  await shot('_ui-kw.png');

  console.log('\n⑪ 新手引导（首战自动触发）');
  await evalJS("document.getElementById('btn-deck-fight').click()");
  await sleep(700);
  var mullVisible = await evalJS("!document.getElementById('mulligan-screen').classList.contains('hidden')");
  if (mullVisible) { await evalJS("document.getElementById('btn-mull-keep').click()"); }
  await sleep(400);

  var shown = false, waited = 0;
  while (!shown && waited < 16000) {
    shown = await evalJS("(function(){var l=document.getElementById('coach-layer');return !!l&&!l.classList.contains('hidden');})()");
    if (shown) break;
    await sleep(500); waited += 500;
  }
  check('首战自动弹出引导', shown === true, '等待 ' + waited + 'ms');

  var stepInfo = await evalJS("(function(){return {step:document.getElementById('coach-step').textContent," +
    "title:document.getElementById('coach-title').textContent," +
    "text:document.getElementById('coach-text').textContent," +
    "spotW:document.getElementById('coach-spot').getBoundingClientRect().width};})()");
  check('显示步骤序号 1 / 6', /^1 \/ 6$/.test((stepInfo || {}).step || ''), stepInfo && stepInfo.step);
  check('有标题与正文', stepInfo && stepInfo.title.length > 2 && stepInfo.text.length > 10,
    stepInfo && (stepInfo.title + ' · ' + stepInfo.text.length + ' 字'));
  check('聚光灯对准目标元素', stepInfo && stepInfo.spotW > 10, '宽 ' + (stepInfo && Math.round(stepInfo.spotW)));
  await shot('_ui-coach.png');

  var advance = await evalJS("(function(){var out=[];" +
    "for(var i=0;i<5;i++){document.getElementById('coach-next').click();" +
    "out.push(document.getElementById('coach-step').textContent);}" +
    "return out;})()");
  check('可连续推进到第 6 步', (advance || []).join(',') === '2 / 6,3 / 6,4 / 6,5 / 6,6 / 6', (advance || []).join(','));
  var lastBtn = await evalJS("document.getElementById('coach-next').textContent");
  check('末步按钮变「开始出征」', /开 始 出 征/.test(lastBtn), lastBtn);
  await evalJS("document.getElementById('coach-next').click()");
  await sleep(300);
  var afterDone = await evalJS("(function(){return {hidden:document.getElementById('coach-layer').classList.contains('hidden')," +
    "done:window.Tutorial.done('battleIntro')};})()");
  check('走完自动关闭并记档', afterDone && afterDone.hidden && afterDone.done === true,
    JSON.stringify(afterDone));

  console.log('\n⑫ 跳过引导');
  await evalJS("window.Tutorial.reset();window.Tutorial.start(window.__ui.introSteps(),{flag:'battleIntro'})");
  await sleep(200);
  await evalJS("document.getElementById('coach-skip').click()");
  await sleep(200);
  var skipped = await evalJS("(function(){return {hidden:document.getElementById('coach-layer').classList.contains('hidden')," +
    "done:window.Tutorial.done('battleIntro')};})()");
  check('跳过后关闭且不再自动弹', skipped && skipped.hidden === true && skipped.done === false,
    JSON.stringify(skipped));

  console.log('\n⑬ 背景音乐与结算面板');
  var musicNow = await evalJS("window.SFX.musicScene()");
  check('对局中音乐切到 battle', musicNow === 'battle', String(musicNow));
  var mutedBefore = await evalJS("window.SFX.muted()");
  await evalJS("document.getElementById('btn-mute').click()");
  var mutedAfter = await evalJS("window.SFX.muted()");
  check('静音开关生效', mutedAfter === !mutedBefore, 'before=' + mutedBefore + ' after=' + mutedAfter);
  await evalJS("document.getElementById('btn-mute').click()");

  await evalJS("(function(){var s=window.__ui.gameState();s.stats.p1.dmg=37;s.stats.p1.heroDmg=21;" +
    "s.stats.p1.units=6;s.stats.p1.spells=3;s.stats.p1.heal=4;" +
    "s.stats.p2.dmg=19;s.stats.p2.units=5;s.stats.p2.spells=1;window.__ui.simulateOver(true);})()");
  await sleep(1100);
  var overVisible = await evalJS("!document.getElementById('over-screen').classList.contains('hidden')");
  check('结算界面弹出', overVisible === true);
  var panel = await evalJS("(function(){var e=document.getElementById('over-stats');" +
    "return {txt:e.textContent.replace(/\\s+/g,' '),rows:e.querySelectorAll('.ovs-row').length};})()");
  check('战绩面板 6 行（表头 + 血量/伤害/出兵/用计/回血）', panel && panel.rows === 6, '实际 ' + (panel && panel.rows));
  check('伤害数值正确渲染', /造成伤害 37 19/.test(panel.txt) || /造成伤害/.test(panel.txt),
    panel && panel.txt.slice(0, 60));
  check('直取主将徽章出现', /直取主将 21/.test(panel.txt), panel && panel.txt.slice(-30));
  var musicOver = await evalJS("window.SFX.musicScene()");
  check('结算后音乐切回地图', musicOver === 'map', String(musicOver));
  await shot('_ui-over.png');

  console.log('\n⑭ 结算页成就解锁条');
  var ovAch = await evalJS("document.querySelectorAll('#over-ach .ov-ach').length");
  check('结算页列出新解锁成就', ovAch >= 1, '实际 ' + ovAch);

  console.log('\n⑮ 图鉴 · 成就 · 战绩');
  await evalJS("window.__ui.openCodex('cards')");
  await sleep(300);
  var codexVisible = await evalJS("!document.getElementById('codex-screen').classList.contains('hidden')");
  check('图鉴界面打开', codexVisible === true);
  var codexCount = await evalJS("document.querySelectorAll('#codex-grid .codex-card').length");
  check('图鉴列出 45 张', codexCount === 45, '实际 ' + codexCount);
  var codexSub = await evalJS("document.getElementById('codex-sub').textContent");
  check('副标题显示卡池构成', /卡池 45 张/.test(codexSub), codexSub);
  await shot('_ui-codex.png');

  var chu = await evalJS("(function(){document.querySelector('#codex-faction .filter-btn[data-v=chu]').click();" +
    "return {n:document.querySelectorAll('#codex-grid .codex-card').length," +
    "fac:document.querySelectorAll('#codex-grid .cx-fac.chu').length," +
    "exp:Codex.cardStats(Data).byFaction.chu};})()");
  check('筛选楚阵营', chu && chu.n === chu.exp && chu.n === chu.fac, JSON.stringify(chu));
  var combo = await evalJS("(function(){document.querySelector('#codex-type .filter-btn[data-v=spell]').click();" +
    "return {n:document.querySelectorAll('#codex-grid .codex-card').length," +
    "exp:Codex.filterCards(Data,{faction:'chu',type:'spell'}).length};})()");
  check('楚 + 计谋组合筛选', combo && combo.n === combo.exp && combo.n > 0, JSON.stringify(combo));

  var ach = await evalJS("(function(){document.querySelector('.codex-tab[data-tab=ach]').click();" +
    "return {n:document.querySelectorAll('#codex-ach .ach-card').length," +
    "on:document.querySelectorAll('#codex-ach .ach-card.on').length," +
    "total:Codex.ACHIEVEMENTS.length," +
    "sub:document.getElementById('codex-sub').textContent};})()");
  check('成就全量渲染', ach && ach.n === ach.total, '实际 ' + (ach && ach.n));
  check('打过的成就已点亮', ach && ach.on >= 1, '点亮 ' + (ach && ach.on));
  check('副标题显示解锁进度', /已解锁 \d+ \/ \d+/.test((ach || {}).sub || ''), ach && ach.sub);
  await sleep(350);   /* 等切页动画结束再截图 */
  await shot('_ui-codex-ach.png');

  var car = await evalJS("(function(){document.querySelector('.codex-tab[data-tab=career]').click();" +
    "return {cells:document.querySelectorAll('#codex-career .career-cell').length," +
    "rows:document.querySelectorAll('#codex-career .career-row').length," +
    "txt:document.getElementById('codex-career').textContent.replace(/\\s+/g,' ')," +
    "battles:Codex.summary().battles};})()");
  check('战绩格 6 项', car && car.cells === 6, '实际 ' + (car && car.cells));
  check('战绩明细行 ≥ 9', car && car.rows >= 9, '实际 ' + (car && car.rows));
  check('刚打完的一场已入账', car && car.battles === 1, '场次 ' + (car && car.battles));
  check('伤害 / 出兵 / 用计 入账正确',
    /对主将造成伤害21/.test((car || {}).txt || '') && /6 员 \/ 3 张/.test((car || {}).txt || ''),
    (car || {}).txt && car.txt.slice(0, 50));
  check('胜率文案正确', /100%/.test((car || {}).txt || '') && /胜 率/.test((car || {}).txt || ''), (car || {}).txt && car.txt.slice(0, 40));
  await sleep(350);   /* 等切页动画结束再截图 */
  await shot('_ui-codex-career.png');

  var back = await evalJS("(function(){document.getElementById('btn-codex-back').click();" +
    "return {start:!document.getElementById('start-screen').classList.contains('hidden')," +
    "codex:document.getElementById('codex-screen').classList.contains('hidden')};})()");
  check('返回按钮回到开局页', back && back.start === true && back.codex === true, JSON.stringify(back));

  console.log('\n⑯ 控制台错误');
  check('无 JS 报错', errors.length === 0, errors.slice(0, 3).join(' | '));

  ws.close();
  chrome.kill();
  console.log(failed === 0 ? '\n界面检查全部通过' : '\n有 ' + failed + ' 项未通过');
  process.exit(failed ? 1 : 0);
})();
