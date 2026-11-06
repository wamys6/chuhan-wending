/* 图鉴 / 成就 / 战绩 测试 */
globalThis.Data = require('../js/data.js');
globalThis.Codex = require('../js/codex.js');

var D = globalThis.Data, X = globalThis.Codex;

var passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) { passed++; }
  else { failed++; console.error('  ✗ ' + msg); }
}
function section(t) { console.log('\n' + t); }

function win(over) {
  var b = { win: true, turns: 20, hp: 12, maxHp: 30, heroId: 'liubang', level: 'bijiang',
    dmg: 20, heroDmg: 6, units: 5, spells: 2 };
  for (var k in (over || {})) b[k] = over[k];
  return X.recordBattle(b);
}
function lose(over) {
  var b = { win: false, turns: 15, hp: 0, maxHp: 30, heroId: 'liubang', level: 'bijiang',
    dmg: 8, heroDmg: 2, units: 3, spells: 1 };
  for (var k in (over || {})) b[k] = over[k];
  return X.recordBattle(b);
}

/* ① 空档案结构 */
section('① 空档案');
(function () {
  X.reset();
  var c = X.current();
  assert(c.battles === 0 && c.wins === 0 && c.losses === 0, '初始战绩应全为 0');
  assert(c.streak === 0 && c.bestStreak === 0, '初始连胜应为 0');
  assert(c.bestHpWin === null && c.fastestWin === null, '初始纪录应为 null');
  assert(typeof c.ach === 'object' && Object.keys(c.ach).length === 0, '初始无成就');
  assert(X.unlockedCount(c) === 0, '解锁数应为 0');
  var s = X.summary();
  assert(s.winRate === 0, '无战斗时胜率应为 0（不能除零）');
  console.log('  初始档案干净、胜率不除零 ✅');
})();

/* ② 首胜与连胜 */
section('② 胜负与连胜');
(function () {
  X.reset();
  var r = win();
  assert(r.career.battles === 1 && r.career.wins === 1, '首胜应记 1 场 1 胜');
  assert(r.career.streak === 1, '连胜应为 1');
  assert(r.unlocked.length === 1 && r.unlocked[0].id === 'first_win',
    '首胜应解锁「首战告捷」，实际：' + r.unlocked.map(function (a) { return a.id; }).join(','));
  /* 重复触发不重复解锁 */
  var r2 = win();
  assert(r2.career.streak === 2 && r2.career.bestStreak === 2, '连胜应累加到 2');
  assert(r2.unlocked.every(function (a) { return a.id !== 'first_win'; }), '成就不能重复解锁');
  lose();
  assert(X.current().streak === 0, '失败后连胜应归零');
  assert(X.current().bestStreak === 2, '最长连胜应保留');
  assert(X.current().losses === 1, '败场应记 1');
  console.log('  连胜累计 / 失败归零 / 成就只解锁一次 ✅');
})();

/* ③ 单场类成就 */
section('③ 单场类成就');
(function () {
  X.reset();
  var r = win({ hp: 30, maxHp: 30 });
  var ids = r.unlocked.map(function (a) { return a.id; });
  assert(ids.indexOf('flawless') >= 0, '满血获胜应解锁「全师而归」');

  X.reset();
  r = win({ hp: 3, turns: 10 });
  ids = r.unlocked.map(function (a) { return a.id; });
  assert(ids.indexOf('last_stand') >= 0, '残血获胜应解锁「背水一战」');
  assert(ids.indexOf('swift') >= 0, '10 回合获胜应解锁「速战速决」');

  X.reset();
  r = win({ heroDmg: 22, units: 11, spells: 6 });
  ids = r.unlocked.map(function (a) { return a.id; });
  assert(ids.indexOf('decapitate') >= 0, '主将 22 伤应解锁「直取黄龙」');
  assert(ids.indexOf('army') >= 0, '出兵 11 员应解锁「兵强马壮」');
  assert(ids.indexOf('strategist') >= 0, '用计 6 张应解锁「运筹帷幄」');

  X.reset();
  r = win({ level: 'mingjiang' });
  assert(r.unlocked.some(function (a) { return a.id === 'mingjiang'; }), '名将难度取胜应解锁');

  /* 门槛边界：刚好差一点不该解锁 */
  X.reset();
  r = win({ turns: 13, heroDmg: 19, units: 9, spells: 5 });
  ids = r.unlocked.map(function (a) { return a.id; });
  assert(ids.indexOf('swift') < 0, '13 回合不应解锁速战速决');
  assert(ids.indexOf('decapitate') < 0, '19 伤不应解锁直取黄龙');
  assert(ids.indexOf('army') < 0, '9 员不应解锁兵强马壮');
  assert(ids.indexOf('strategist') < 0, '5 张计谋不应解锁运筹帷幄');
  console.log('  满血/残血/速攻/斩杀/出兵/计谋/名将七项判定正确，边界不误判 ✅');
})();

/* ④ 战役进度类成就 */
section('④ 战役进度');
(function () {
  X.reset();
  var r = X.recordClear('peixian', 0, 21, 8);
  assert(r.career.clearedCount === 1, '通关 1 关后进度应为 1');
  assert(r.career.maxStage === 0 && r.career.maxStageId === 'peixian', '最远关卡应记录');
  assert(r.unlocked.some(function (a) { return a.id === 'stage_1'; }), '应解锁「沛县起兵」');

  /* 重复通关同一关不重复计数 */
  r = X.recordClear('peixian', 0, 21, 8);
  assert(r.career.clearedCount === 1, '重复通关不应重复计数');

  ['hongmen', 'pengcheng', 'xingyang'].forEach(function (id, i) {
    r = X.recordClear(id, i + 1, 22 + i, 8);
  });
  assert(r.career.clearedCount === 4, '四关后进度应为 4，实际：' + r.career.clearedCount);
  assert(r.unlocked.some(function (a) { return a.id === 'stage_4'; }), '应解锁「挺进中原」');
  assert(r.career.maxDeck === 24, '最大牌组应跟到 24，实际：' + r.career.maxDeck);

  /* 走完全部 8 关 */
  ['jingxing', 'weishui', 'guling', 'gaixia'].forEach(function (id, i) {
    r = X.recordClear(id, i + 4, 25 + i, 8);
  });
  assert(r.career.finished === true, '八关通关后应标记 finished');
  assert(r.unlocked.some(function (a) { return a.id === 'stage_all'; }), '应解锁「问鼎中原」');
  assert(r.career.deck_26 === undefined, '不应把成就 id 写进存档字段');
  assert(X.current().ach.deck_26, '牌组 26 张应解锁「兵多将广」');
  console.log('  首关 / 四关 / 通关 / 牌组规模 四项进度成就正确，重复通关不刷进度 ✅');
})();

/* ⑤ 双主将成就 */
section('⑤ 楚河汉界');
(function () {
  X.reset();
  win({ heroId: 'liubang' });
  var r = win({ heroId: 'xiangyu' });
  assert(r.unlocked.some(function (a) { return a.id === 'two_heroes'; }),
    '刘邦与项羽各胜一场后应解锁');
  assert(r.career.heroes.liubang === 1 && r.career.heroes.xiangyu === 1, '按英雄分别记胜场');
  console.log('  两个主将各一胜解锁 ✅');
})();

/* ⑥ 阅历类成就 */
section('⑥ 阅历积累');
(function () {
  X.reset();
  for (var i = 0; i < 19; i++) lose();
  var r = win();
  assert(r.career.battles === 20, '累计 20 场');
  assert(r.unlocked.some(function (a) { return a.id === 'veteran'; }), '应解锁「百战之将」');
  assert(!r.career.ach.legend, '20 场不应解锁 50 场成就');

  X.reset();
  ['zhangliang', 'xiaohe'].forEach(function (id) { X.recordAdvisor(id); });
  r = X.recordAdvisor('hanxin');
  assert(r.unlocked.some(function (a) { return a.id === 'advisors_3'; }), '三名军师应解锁「三军之师」');

  X.reset();
  ['a', 'b', 'c', 'd', 'e'].forEach(function (id) { X.recordEvent(id); });
  r = X.recordEvent('f');
  assert(r.unlocked.some(function (a) { return a.id === 'events_6'; }), '六个事件应解锁「阅尽行军」');

  /* 累计伤害 */
  X.reset();
  for (var j = 0; j < 25; j++) win({ dmg: 20, heroDmg: 4 });
  assert(X.current().dmg === 500, '累计伤害应为 500，实际：' + X.current().dmg);
  assert(X.current().ach.damage_500, '500 伤害应解锁「千里杀将」');
  console.log('  20 场 / 3 军师 / 6 事件 / 500 伤害 四项累积成就正确 ✅');
})();

/* ⑦ 战绩摘要 */
section('⑦ 战绩摘要');
(function () {
  X.reset();
  win({ turns: 18, hp: 9, dmg: 30 });
  lose({ turns: 12, dmg: 10 });
  var s = X.summary();
  assert(s.battles === 2 && s.wins === 1 && s.losses === 1, '场次统计错误');
  assert(s.winRate === 50, '胜率应为 50%，实际：' + s.winRate);
  assert(s.turns === 30, '回合数应累计 30，实际：' + s.turns);
  assert(s.dmg === 40, '伤害应累计 40，实际：' + s.dmg);
  assert(s.bestHpWin === 9, '最凶险胜仗应记 9 血，实际：' + s.bestHpWin);
  assert(s.fastestWin === 18, '最速取胜应记 18 回合');
  console.log('  摘要场次 / 胜率 / 回合 / 伤害 / 纪录全部正确 ✅');
})();

/* ⑧ 图鉴筛选 */
section('⑧ 图鉴筛选');
(function () {
  var all = X.filterCards(D, {});
  assert(all.indexOf('s_xianji') < 0, '先机虎符不应出现在图鉴');
  var stats = X.cardStats(D);
  assert(stats.total === all.length, '统计总数应与筛选结果一致');
  /* 别写死张数：卡池一直在加（45 → 78），写死等于每隔几版就假红一次（踩坑 48 同款）。
     图鉴口径 = 全部卡 − 先机虎符（token，不入图鉴）。 */
  var expectTotal = Object.keys(D.CARDS).length - 1;
  assert(stats.total === expectTotal, '卡池应为 ' + expectTotal + ' 张（全部卡 − 先机虎符），实际：' + stats.total);
  assert(stats.byFaction.neutral + stats.byFaction.han + stats.byFaction.chu === stats.total,
    '阵营分项之和应等于总数');
  assert(stats.byType.piece + stats.byType.spell === stats.total, '类型分项之和应等于总数');

  var han = X.filterCards(D, { faction: 'han' });
  assert(han.length === stats.byFaction.han, '汉阵营筛选数量应一致');
  han.forEach(function (id) {
    assert(D.factionOf(id) === 'han', id + ' 不应出现在汉阵营结果里');
  });

  var spells = X.filterCards(D, { type: 'spell' });
  spells.forEach(function (id) { assert(D.CARDS[id].type === 'spell', id + ' 不是计谋'); });

  var combo = X.filterCards(D, { faction: 'chu', type: 'piece' });
  combo.forEach(function (id) {
    assert(D.factionOf(id) === 'chu' && D.CARDS[id].type === 'piece', id + ' 不属于楚·兵种');
  });

  /* 排序：费用从小到大 */
  var prev = -1, sorted = true;
  all.forEach(function (id) {
    if (D.CARDS[id].cost < prev) sorted = false;
    prev = D.CARDS[id].cost;
  });
  assert(sorted, '图鉴应按费用升序排列');

  /* 每个结果都能拿到卡牌对象（防止脏 id） */
  all.forEach(function (id) { assert(!!D.CARDS[id], '图鉴出现不存在的卡：' + id); });
  console.log('  ' + stats.total + ' 张全量 / 阵营 / 类型 / 组合筛选与费用排序全部正确 ✅');
})();

/* ⑨ 存档重置与内存兜底 */
section('⑨ 存档');
(function () {
  X.reset();
  win();
  assert(X.current().battles === 1, '写入后应可读回');
  X.reset();
  assert(X.current().battles === 0, 'reset 后应回到空档案');
  assert(X.load() === null, 'reset 后 load 应为 null');

  /* 没有 localStorage 的环境（node / 隐私模式）靠内存副本 */
  var p = X.current();
  p.battles = 7;
  X.save(p);
  assert(X.current().battles === 7, 'localStorage 不可用时应走内存副本');
  X.reset();
  console.log('  重置清空、内存兜底可读写 ✅');
})();

/* ⑩ 成就定义完整性 */
section('⑩ 成就定义');
(function () {
  var ids = {};
  var groups = { battle: 0, campaign: 0, career: 0 };
  X.ACHIEVEMENTS.forEach(function (a) {
    assert(!!a.id && !!a.name && !!a.desc && !!a.glyph, '成就字段缺失：' + a.id);
    assert(!ids[a.id], '成就 id 重复：' + a.id);
    ids[a.id] = 1;
    assert(typeof a.test === 'function', a.id + ' 缺少判定函数');
    assert(groups[a.group] !== undefined, a.id + ' 分组非法：' + a.group);
    groups[a.group]++;
    assert(!a.test({ battles: 0, wins: 0, bestStreak: 0, advisors: {}, events: {}, heroes: {}, clearedCount: 0 }, null),
      a.id + ' 在空档案下不应解锁');
  });
  assert(X.ACHIEVEMENTS.length >= 18, '成就数量应不少于 18，实际：' + X.ACHIEVEMENTS.length);
  Object.keys(groups).forEach(function (g) {
    assert(groups[g] > 0, '分组 ' + g + ' 没有成就');
  });
  console.log('  ' + X.ACHIEVEMENTS.length + ' 项成就字段完整、id 唯一、空档案不误判 ✅');
})();

console.log('\n通过 ' + passed + ' 项，失败 ' + failed + ' 项');
if (failed) process.exit(1);
