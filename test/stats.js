/* 战绩统计（结算面板数据源）测试 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
var D = Data, E = Engine, AI = globalThis.AI;

var passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) passed++;
  else { failed++; console.error('  ✗ ' + msg); }
}
function section(t) { console.log('\n' + t); }

function fresh() {
  var st = E.newGame('liubang', 'xiangyu', 'p1', 'bijiang', { p1: D.DECKS.han.slice() });
  st.players.p1.hand = [];
  st.players.p2.hand = [];
  E.beginGame(st);
  ['p1', 'p2'].forEach(function (pid) {
    st.players[pid].mana = 10;
    st.players[pid].maxMana = 10;
  });
  return st;
}
function give(st, pid, baseId) {
  var c = E.newInstance(baseId);
  st.players[pid].hand.push(c);
  return c;
}

section('① 初始化为零');
(function () {
  var st = fresh();
  ['p1', 'p2'].forEach(function (pid) {
    var s = st.stats[pid];
    assert(s && s.dmg === 0 && s.units === 0 && s.spells === 0 && s.heal === 0 && s.heroDmg === 0,
      pid + ' 统计应全为 0，实际 ' + JSON.stringify(s));
  });
  console.log('  双方 5 项计数初始为 0 ✅');
})();

section('② 出兵 / 用计计数');
(function () {
  var st = fresh();
  E.playCard(st, 'p1', give(st, 'p1', 'n_bing2').uid);
  E.playCard(st, 'p1', give(st, 'p1', 'n_ma1').uid);
  E.playCard(st, 'p1', give(st, 'p1', 's_xiaohe').uid);
  assert(st.stats.p1.units === 2, '出兵应计 2，实际 ' + st.stats.p1.units);
  assert(st.stats.p1.spells === 1, '用计应计 1，实际 ' + st.stats.p1.spells);
  assert(st.stats.p2.units === 0, '敌方不应被计入');
  console.log('  出兵 2 / 用计 1，敌方不受影响 ✅');
})();

section('③ 攻击伤害与溢出');
(function () {
  var st = fresh();
  var atk = give(st, 'p1', 'n_che2');                 /* 7 攻 */
  E.playCard(st, 'p1', atk.uid);
  atk.canAttack = true;
  var foe = give(st, 'p2', 'n_bing1');                /* 1/2 */
  E.playCard(st, 'p2', foe.uid);
  var hpBefore = foe.hp;
  var r = E.attack(st, 'p1', atk.uid, { kind: 'unit', uid: foe.uid });
  assert(r.ok, '攻击应成功：' + r.reason);
  assert(st.stats.p1.dmg === hpBefore, '伤害应按实际血量计（' + hpBefore + '），实际 ' + st.stats.p1.dmg);
  console.log('  溢出伤害不计入（7 攻打 2 血兵 → 记 ' + st.stats.p1.dmg + '）✅');
})();

section('④ 直取主将');
(function () {
  var st = fresh();
  var atk = give(st, 'p1', 'n_che2');
  E.playCard(st, 'p1', atk.uid);
  atk.canAttack = true;
  E.attack(st, 'p1', atk.uid, { kind: 'hero' });
  assert(st.stats.p1.heroDmg === 7, '主将伤害应记 7，实际 ' + st.stats.p1.heroDmg);
  assert(st.stats.p1.dmg === 7, '总伤害应同步记 7，实际 ' + st.stats.p1.dmg);
  assert(st.stats.p2.dmg === 0, '被打的一方不应记账');
  console.log('  heroDmg 与 dmg 同步，受击方不记账 ✅');
})();

section('⑤ 治疗计数');
(function () {
  var st = fresh();
  st.players.p1.hp = 20;
  var r = E.useSkill(st, 'p1');                       /* 约法三章：+2 血 */
  assert(r.ok, '技能应可用：' + r.reason);
  assert(st.stats.p1.heal === 2, '回血应记 2，实际 ' + st.stats.p1.heal);
  /* 满血再放不该记治疗 */
  st.players.p1.hp = st.players.p1.maxHp;
  E.useSkill(st, 'p1');
  assert(st.stats.p1.heal === 2, '满血时不应累计治疗，实际 ' + st.stats.p1.heal);
  console.log('  回血 2，满血不累计 ✅');
})();

section('⑥ 整局对打不出现负数/NaN');
(function () {
  var win = 0;
  for (var n = 0; n < 30; n++) {
    var st = E.newGame('liubang', 'xiangyu', Math.random() < 0.5 ? 'p1' : 'p2', 'bijiang',
      { p1: D.DECKS.han.slice(), p2: D.DECKS.chu.slice() });
    E.beginGame(st);
    var guard = 0;
    while (!st.over && guard++ < 500) {
      var a = AI.aiNextAction(st, st.current);
      AI.applyAction(st, st.current, a);
    }
    if (st.winner === 'p1') win++;
    ['p1', 'p2'].forEach(function (pid) {
      var s = st.stats[pid];
      ['dmg', 'heroDmg', 'units', 'spells', 'heal'].forEach(function (k) {
        assert(typeof s[k] === 'number' && s[k] >= 0, pid + '.' + k + ' 异常：' + s[k]);
      });
      assert(s.heroDmg <= s.dmg, pid + ' 主将伤害不应超过总伤害');
    });
  }
  console.log('  30 局完整对局，10 项指标全部为合法非负数 ✅');
})();

console.log('\n通过 ' + passed + ' 项，失败 ' + failed + ' 项');
if (failed > 0) process.exit(1);
