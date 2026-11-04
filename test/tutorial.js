/* 新手引导引擎的纯逻辑测试（DOM 相关部分由 test/uicheck.js 覆盖） */
var path = require('path');
globalThis.Tutorial = require(path.join(__dirname, '..', 'js', 'tutorial.js')).Tutorial;
var Data = require(path.join(__dirname, '..', 'js', 'data.js'));
var T = globalThis.Tutorial;

var pass = 0, fail = 0;
function assert(cond, msg) {
  if (cond) pass++;
  else { fail++; console.log('  ✗ ' + msg); }
}
function section(name) { console.log('\n' + name); }

/* ① 关键词标注 */
section('① markKeywords');
(function () {
  var out = T.markKeywords('守御：厚实的护军巨象。');
  assert(out.indexOf('<b class="kw" data-kw="守御">守御</b>') >= 0, '应包裹「守御」，实际：' + out);
  assert(out.indexOf('厚实的护军巨象') >= 0, '正文不应被破坏');

  var out2 = T.markKeywords('冲锋：登场即刻出手。');
  assert(out2.indexOf('data-kw="冲锋"') >= 0, '应包裹「冲锋」');

  var out3 = T.markKeywords('平平无奇的一句话。');
  assert(out3.indexOf('class="kw"') < 0, '无关键词时不应插入标记');

  /* 同一句里出现多次都要标 */
  var out4 = T.markKeywords('守御与迂回兼备');
  assert(out4.split('data-kw="守御"').length - 1 === 1, '「守御」应只标一次');
  assert(out4.split('data-kw="迂回"').length - 1 === 1, '「迂回」应只标一次');

  /* HTML 注入防护：描述里的尖括号必须被转义 */
  var out5 = T.markKeywords('<script>守御</script>');
  assert(out5.indexOf('<script>') < 0, '尖括号必须转义，实际：' + out5);
  assert(out5.indexOf('&lt;script&gt;') >= 0, '应保留转义后的原文');

  console.log('  4 类场景（单关键词 / 多关键词 / 无关键词 / 转义）通过');
})();

/* ② 全部卡牌描述扫一遍：含关键词的描述必须被标注 */
section('② 全卡池描述标注覆盖');
(function () {
  var KW = ['守御', '迂回', '远程', '冲锋', '死战', '连击'];
  var hit = 0, bad = [];
  Object.keys(Data.CARDS).forEach(function (id) {
    var c = Data.CARDS[id];
    var d = c.desc || '';
    var has = KW.filter(function (k) { return d.indexOf(k) >= 0; });
    if (!has.length) return;
    hit++;
    var html = T.markKeywords(d);
    has.forEach(function (k) {
      if (html.indexOf('data-kw="' + k + '"') < 0) bad.push(c.name + ' 缺 ' + k);
    });
  });
  assert(hit >= 12, '至少应有 12 张牌的关键词描述被覆盖，实际：' + hit);
  assert(bad.length === 0, '漏标：' + bad.join('、'));
  console.log('  含关键词的卡牌 ' + hit + ' 张，全部标注正确');
})();

/* ③ 一次性提示 */
section('③ hint 只弹一次');
(function () {
  T.reset();
  assert(T.hint('demo', '第一句') === true, '首次应弹');
  assert(T.hint('demo', '第二句') === false, '第二次不应再弹');
  assert(T.hint('other', '别的') === true, '不同 id 互不影响');
  assert(T.hint('demo', '强制', { always: true }) === true, 'always 可绕过一次性限制');
  console.log('  首次弹出、重复静默、always 强制绕过 ✅');
})();

/* ④ 引导完成标记 */
section('④ done / markDone');
(function () {
  T.reset();
  assert(T.done('battleIntro') === false, '初始应为未完成');
  T.markDone('battleIntro');
  assert(T.done('battleIntro') === true, '标记后应为已完成');
  assert(T.done('其它引导') === false, '不同 flag 互不影响');
  T.reset();
  assert(T.done('battleIntro') === false, 'reset 后应清空');
  console.log('  标记 / 查询 / 重置正常 ✅');
})();

/* ⑤ 关键词释义完整性 */
section('⑤ 释义字典');
(function () {
  var KW = ['守御', '迂回', '远程', '冲锋', '死战', '连击', '召唤失调', '军粮'];
  KW.forEach(function (k) {
    assert(typeof T.KEYWORDS[k] === 'string' && T.KEYWORDS[k].length > 8,
      '「' + k + '」缺少释义或过短');
  });
  console.log('  ' + KW.length + ' 个关键词都有释义 ✅');
})();

console.log('\n通过 ' + pass + ' 项，失败 ' + fail + ' 项');
if (fail > 0) process.exit(1);
