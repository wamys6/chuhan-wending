/* 名将 AI 斩杀计算测试 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');

function assert(cond, msg) { if (!cond) throw new Error('FAIL: ' + msg); }

/* 造一个「敌方主将残血、我方几只骑兵可直取」的局面 */
function makeLethalState(enemyHp) {
  var st = Engine.newGame('liubang', 'xiangyu', 'p2', 'mingjiang'); /* p2 = 项羽AI，先手 */
  st.levels.p2 = 'mingjiang';
  Engine.beginGame(st);
  var me = st.players.p2, foe = st.players.p1;
  Engine.RANKS.forEach(function (r) { foe.board[r] = []; });
  var a = Engine.newInstance('n_ma1'); a.canAttack = true;
  var b = Engine.newInstance('n_ma1'); b.canAttack = true;
  me.board.mid = [a, b];           /* 3 + 3 = 6 点攻击 */
  me.hand = [];                    /* 清空手牌，确保动作只来自斩杀逻辑 */
  me.mana = 10; me.skillUsed = false;
  foe.hp = enemyHp;
  return { st: st, me: me, foe: foe };
}

/* ① 总攻 6 >= 敌血 6 → 应直取主将 */
(function () {
  var s = makeLethalState(6);
  var act = AI.aiNextAction(s.st, 'p2');
  assert(act.type === 'attack' && act.target.kind === 'hero', '血 6 总攻 6 应判断杀：实际 ' + JSON.stringify(act));

  /* 连续执行直到分出胜负 */
  var steps = 0;
  while (!s.st.over && steps < 10) { AI.applyAction(s.st, 'p2', AI.aiNextAction(s.st, 'p2')); steps++; }
  assert(s.st.over && s.st.winner === 'p2', '斩杀应直接结束对局');
  console.log('① 6 攻 vs 6 血 → 斩杀成功（' + steps + ' 步内取胜）✅');
})();

/* ② 总攻 6 < 敌血 7，但项羽技能（空列直击 1）可用 → 应先用技能补刀 */
(function () {
  var s = makeLethalState(7);
  var act = AI.aiNextAction(s.st, 'p2');
  assert(act.type === 'skill', '血 7 应先用技能补 1 点：实际 ' + JSON.stringify(act));
  AI.applyAction(s.st, 'p2', act);
  var act2 = AI.aiNextAction(s.st, 'p2');
  assert(act2.type === 'attack' && act2.target.kind === 'hero', '技能后应转为斩杀攻击');
  console.log('② 6 攻 + 技能 1 伤 vs 7 血 → 先技能后斩杀 ✅');
})();

/* ③ 敌血 20 远高于总攻 → 不应触发斩杀计划（正常出牌/攻击即可） */
(function () {
  var s = makeLethalState(20);
  var act = AI.aiNextAction(s.st, 'p2');
  var isLethalAttack = act.type === 'attack' && act.target.kind === 'hero';
  assert(!isLethalAttack, '血 20 不应判定为斩杀：实际 ' + JSON.stringify(act));
  console.log('③ 6 攻 vs 20 血 → 不误判斩杀 ✅');
})();

/* ④ 敌方还有兵挡路（heroOk=false）→ 不能判定为可斩杀 */
(function () {
  var s = makeLethalState(6);
  var blocker = Engine.newInstance('n_bing1');
  s.foe.board.front = [blocker];
  var act = AI.aiNextAction(s.st, 'p2');
  var isLethalAttack = act.type === 'attack' && act.target.kind === 'hero';
  assert(!isLethalAttack, '有兵挡路时不能直取主将：实际 ' + JSON.stringify(act));
  console.log('④ 有兵挡路 → 不误判斩杀 ✅');
})();

/* ⑤ 行为差异：斩杀可成时，名将先斩、裨将仍按「先出牌」的常规顺序 */
(function () {
  function firstActionOf(level) {
    var st = Engine.newGame('liubang', 'xiangyu', 'p2', level);
    Engine.beginGame(st);
    var me = st.players.p2, foe = st.players.p1;
    Engine.RANKS.forEach(function (r) { foe.board[r] = []; });
    var a = Engine.newInstance('n_che1'); a.canAttack = true;
    me.board.mid = [a];
    me.hand = [Engine.newInstance('n_bing1')]; /* 手里有能出的牌，干扰项 */
    me.mana = 10;
    foe.hp = 5; /* 一个 5 攻车即可斩 */
    return AI.aiNextAction(st, 'p2');
  }
  var m = firstActionOf('mingjiang');
  assert(m.type === 'attack' && m.target.kind === 'hero', '名将应优先斩杀：实际 ' + JSON.stringify(m));
  var b = firstActionOf('bijiang');
  assert(b.type === 'play', '裨将应先出牌（未走斩杀分支）：实际 ' + JSON.stringify(b));
  console.log('⑤ 斩杀可成时：名将先斩、裨将先出牌 ✅');
})();

console.log('✅ 名将斩杀测试全部通过');
