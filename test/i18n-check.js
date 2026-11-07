/* 多语言测试：EN 数据完整性 / 来回切换幂等 / t() 占位符 / 战报与 reason 翻译 / 关键词切换 */
globalThis.Data = require('../js/data.js');
globalThis.Campaign = require('../js/campaign.js');
globalThis.Codex = require('../js/codex.js');
globalThis.Tutorial = require('../js/tutorial.js').Tutorial;
globalThis.I18N = require('../js/i18n.js');
require('../js/lang-en.js');

var I = I18N, D = Data, C = Campaign, X = Codex;

var passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) passed++;
  else { failed++; console.error('  ✗ ' + msg); }
}
function section(t) { console.log('\n' + t); }

section('① EN 数据完整性');
(function () {
  var miss = [];
  Object.keys(D.CARDS).forEach(function (id) {
    var tr = I._en().cards[id];
    if (!tr || !tr.name || !tr.desc) miss.push('card:' + id);
  });
  Object.keys(D.HEROES).forEach(function (id) {
    var tr = I._en().heroes[id];
    if (!tr || !tr.name || !tr.title || !tr.intro || !tr.skill || !tr.skill.name || !tr.skill.desc) miss.push('hero:' + id);
  });
  C.STAGES.forEach(function (s) {
    var tr = I._en().stages[s.id];
    if (!tr || !tr.chapter || !tr.name || !tr.year || !tr.subtitle || !tr.lore || !tr.goalText ||
        !tr.enemy || !tr.enemy.name || !tr.enemy.title) miss.push('stage:' + s.id);
  });
  C.ADVISORS.forEach(function (a) {
    var tr = I._en().advisors[a.id];
    if (!tr || !tr.name || !tr.title || !tr.desc || !tr.flavor) miss.push('advisor:' + a.id);
  });
  C.EVENTS.forEach(function (ev) {
    var tr = I._en().events[ev.id];
    if (!tr || !tr.name || !tr.text || !tr.options || tr.options.length !== ev.options.length) {
      miss.push('event:' + ev.id); return;
    }
    tr.options.forEach(function (o) { if (!o.label || o.hint === undefined) miss.push('event-opt:' + ev.id); });
  });
  X.ACHIEVEMENTS.forEach(function (a) {
    var tr = I._en().achievements[a.id];
    if (!tr || !tr.name || !tr.desc) miss.push('ach:' + a.id);
  });
  ['battle', 'campaign', 'career'].forEach(function (g) {
    if (!I._en().groups[g]) miss.push('group:' + g);
  });
  assert(miss.length === 0, 'EN 覆盖缺口：' + miss.join(', '));
  console.log('  卡 ' + Object.keys(I._en().cards).length + ' / 关 ' + Object.keys(I._en().stages).length +
    ' / 军师 ' + Object.keys(I._en().advisors).length + ' / 事件 ' + Object.keys(I._en().events).length +
    ' / 成就 ' + Object.keys(I._en().achievements).length + ' 项英文全覆盖 ✅');
})();

section('② 数据层来回切换');
(function () {
  I.setLang('en', { noDom: true });
  assert(D.CARDS.n_bing1.name === 'Infantry · Recruit', 'EN 卡名：' + D.CARDS.n_bing1.name);
  assert(D.CARDS.n_shi3.desc.indexOf('Taunt') === 0, 'EN 牌面应含 Taunt 关键词');
  // 「Hegemon-King of Chu」在主将卡名字栏（210px）里 16px 还有 260px，怎么降档都放不下，
  // 全项目统一收成 Hegemon-King（godot/tests/legibility_test.gd 会盯着这个宽度）
  assert(D.HEROES.xiangyu.title === 'Hegemon-King', 'EN 头衔');
  assert(C.STAGES[0].name === 'Rising at Pei County', 'EN 关名');
  assert(C.STAGES[0].enemy.meta.name === 'Qin · Sishui Commandant', 'EN 敌将名');
  assert(C.ADVISORS[0].name === 'Zhang Liang', 'EN 军师名');
  assert(C.EVENTS[0].options[0].label === 'Open the granaries', 'EN 事件选项');
  assert(X.ACHIEVEMENTS[0].name === 'First Blood', 'EN 成就名');
  assert(D.RANK_NAMES.front === 'Vanguard', 'EN 列名');

  I.setLang('zh', { noDom: true });
  assert(D.CARDS.n_bing1.name === '兵·新卒', '切回中文恢复原名');
  assert(D.HEROES.xiangyu.title === '西楚霸王', '切回中文恢复头衔');
  assert(C.STAGES[0].name === '沛县起兵', '切回中文恢复关名');
  assert(C.EVENTS[0].options[0].label === '开仓赈济', '切回中文恢复选项');
  assert(D.RANK_NAMES.front === '前锋', '切回中文恢复列名');
  assert(X.ACHIEVEMENTS[0].name === '首战告捷', '切回中文恢复成就');

  /* 幂等：再切一轮结果一致 */
  I.setLang('en', { noDom: true }); I.setLang('zh', { noDom: true }); I.setLang('en', { noDom: true });
  assert(D.CARDS.n_bing1.name === 'Infantry · Recruit', '反复切换仍正确');
  I.setLang('zh', { noDom: true });
  console.log('  zh ↔ en 来回切换（含幂等）✅');
})();

section('③ t() 与占位符');
(function () {
  assert(I.t('纯中文') === '纯中文', 'zh 模式原样返回');
  I.setLang('en', { noDom: true });
  assert(I.t('存档位 {n}', { n: 'II' }) === 'Save Slot II', '占位符替换：' + I.t('存档位 {n}', { n: 'II' }));
  assert(I.t('不存在于字典的字符串') === '不存在于字典的字符串', '缺词典键时回退原文');
  I.setLang('zh', { noDom: true });
  assert(I.t('存档位 {n}', { n: '贰' }) === '存档位 贰', 'zh 模式占位符也生效');
})();

section('④ 战报与 reason 翻译');
(function () {
  I.setLang('en', { noDom: true });
  assert(I.trLog('—— 第 3 回合 · 我方') === '—— Turn 3 · Your army',
    '回合行：' + I.trLog('—— 第 3 回合 · 我方'));
  assert(I.trLog('我方派出 ' + D.CARDS.n_bing1.name + ' → ' + D.RANK_NAMES.front) ===
    'Your army deploy Infantry · Recruit to the Vanguard column.',
    '出牌行：' + I.trLog('我方派出 ' + D.CARDS.n_bing1.name + ' → ' + D.RANK_NAMES.front));
  assert(I.trLog('敌方' + D.CARDS.c_zhuiqi.name + ' 死战发动') ===
    'The enemy ' + D.CARDS.c_zhuiqi.name + ' triggers Last Stand.',
    '死战行：' + I.trLog('敌方' + D.CARDS.c_zhuiqi.name + ' 死战发动'));
  assert(I.trLog('我方' + D.CARDS.n_bing2.name + ' 攻击 ' + D.CARDS.n_bing3.name + '（3 vs 2）') ===
    'Your army ' + D.CARDS.n_bing2.name + ' attacks ' + D.CARDS.n_bing3.name + ' (3 vs 2).',
    '攻击行：' + I.trLog('我方' + D.CARDS.n_bing2.name + ' 攻击 ' + D.CARDS.n_bing3.name + '（3 vs 2）'));
  assert(I.trReason('军粮不足') === 'Not enough Provisions.', 'reason 翻译');
  assert(I.trReason(D.RANK_NAMES.front + '列已满（每列最多 ' + D.COLUMN_LIMIT + ' 员）') ===
    'The Vanguard column is full (' + D.COLUMN_LIMIT + ' per column).',
    '组合 reason：' + I.trReason(D.RANK_NAMES.front + '列已满（每列最多 ' + D.COLUMN_LIMIT + ' 员）'));
  /* 上限若改成 4，文案要跟着走（数字来自 COLUMN_LIMIT，不是硬编码） */
  assert(I.t('每列最多站 {n} 员。先打完这一列，或把牌出到别的列。', { n: 4 }) ===
    'Each column holds at most 4 units. Clear this one first, or deploy into another column.',
    '列满提示数字随常量：' + I.t('每列最多站 {n} 员。先打完这一列，或把牌出到别的列。', { n: 4 }));
  assert(I.trLog('完全未知的战报') === '完全未知的战报', '未知战报回退原文');
  I.setLang('zh', { noDom: true });
  assert(I.trLog('我方派出 兵·新卒 → 前锋') === '我方派出 兵·新卒 → 前锋', 'zh 模式战报原样');
})();

section('⑤ 关键词随语言切换');
(function () {
  I.setLang('en', { noDom: true });
  assert(Tutorial.KEYWORDS['Taunt'] && Tutorial.KEYWORDS['Taunt'].indexOf('Enemies must') === 0, 'EN 释义');
  assert(!Tutorial.KEYWORDS['守御'], 'EN 模式下无中文键');
  var html = Tutorial.markKeywords('Taunt. Last Stand: gain +1 Attack.');
  assert(html.indexOf('<b class="kw" data-kw="Taunt">Taunt</b>') >= 0, 'EN 牌面标注：' + html);
  I.setLang('zh', { noDom: true });
  assert(Tutorial.KEYWORDS['守御'] && !Tutorial.KEYWORDS['Taunt'], 'zh 模式恢复中文释义');
  var html2 = Tutorial.markKeywords('守御。死战：阵亡时触发。');
  assert(html2.indexOf('data-kw="守御"') >= 0 && html2.indexOf('data-kw="死战"') >= 0, 'zh 牌面标注');
})();

console.log('\n通过 ' + passed + ' 项，失败 ' + failed + ' 项');
process.exit(failed ? 1 : 0);
