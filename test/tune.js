/* 数值调参器：固定主对局（刘邦+汉预组 vs 项羽+楚预组），批量试候选数值，输出刘邦胜率
   用法：node test/tune.js   不加参数即跑全部候选 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');

function measure(n) {
  var firstWins = 0, liuWins = 0, turns = 0;
  for (var i = 0; i < n; i++) {
    var first = Math.random() < 0.5 ? 'p1' : 'p2';
    var st = Engine.newGame('liubang', 'xiangyu', first, 'bijiang');
    st.levels.p1 = 'bijiang';
    Engine.beginGame(st);
    var steps = 0;
    while (!st.over && steps < 700) { steps++; AI.applyAction(st, st.current, AI.aiNextAction(st, st.current)); }
    if (st.winner === 'p1') liuWins++;
    if (st.winner === first) firstWins++;
    turns += st.turnNo;
  }
  return {
    liu: (liuWins / n * 100).toFixed(1),
    first: (firstWins / n * 100).toFixed(1),
    turns: (turns / n).toFixed(1)
  };
}

function setHero(id, patch) {
  var h = Data.HEROES[id];
  Object.keys(patch).forEach(function (k) {
    if (k === 'skillCost') h.skill.cost = patch[k];
    else if (k === 'skillDesc') h.skill.desc = patch[k];
    else h[k] = patch[k];
  });
}

var base = { liubangHp: 30, xiangyuHp: 26, xiangyuSkillCost: 2, liubangSkillCost: 2 };
var N = Number(process.argv[2] || 400);

var cases = [
  { name: '基准（刘邦30 / 项羽26 / 双方技能2费）', patch: function () {
      setHero('liubang', { hp: 30, maxHp: 30, skillCost: 2 });
      setHero('xiangyu', { hp: 26, maxHp: 26, skillCost: 2 });
    } },
  { name: '项羽 27 血', patch: function () {
      setHero('liubang', { hp: 30, maxHp: 30, skillCost: 2 });
      setHero('xiangyu', { hp: 27, maxHp: 27, skillCost: 2 });
    } },
  { name: '项羽 28 血', patch: function () {
      setHero('liubang', { hp: 30, maxHp: 30, skillCost: 2 });
      setHero('xiangyu', { hp: 28, maxHp: 28, skillCost: 2 });
    } },
  { name: '项羽技能 1 费（破釜沉舟更频繁）', patch: function () {
      setHero('liubang', { hp: 30, maxHp: 30, skillCost: 2 });
      setHero('xiangyu', { hp: 26, maxHp: 26, skillCost: 1 });
    } },
  { name: '刘邦技能 3 费（续航变慢）', patch: function () {
      setHero('liubang', { hp: 30, maxHp: 30, skillCost: 3 });
      setHero('xiangyu', { hp: 26, maxHp: 26, skillCost: 2 });
    } },
  { name: '刘邦 28 血', patch: function () {
      setHero('liubang', { hp: 28, maxHp: 28, skillCost: 2 });
      setHero('xiangyu', { hp: 26, maxHp: 26, skillCost: 2 });
    } },
  { name: '项羽 28 血 + 技能 1 费', patch: function () {
      setHero('liubang', { hp: 30, maxHp: 30, skillCost: 2 });
      setHero('xiangyu', { hp: 28, maxHp: 28, skillCost: 1 });
    } }
];

console.log('==== 数值调参（每档 ' + N + ' 局，AI 均为裨将档）====');
cases.forEach(function (c) {
  c.patch();
  var r = measure(N);
  console.log(c.name.padEnd(34) + ' → 刘邦胜率 ' + r.liu + '%  先手 ' + r.first + '%  平均 ' + r.turns + ' 回合');
});
