/* 8 关战役难度体检：玩家侧用汉预组（+ 已得奖励）跑每一关 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
globalThis.Campaign = require('../js/campaign.js');
var D = Data, E = Engine, C = Campaign, AIx = globalThis.AI;

var N = Number(process.argv[2]) || 60;

function runStage(stage, deck, n) {
  var win = 0, turns = 0;
  for (var i = 0; i < n; i++) {
    var st = E.newGame('liubang', stage.enemy.heroId,
      Math.random() < 0.5 ? 'p1' : 'p2', stage.aiLevel,
      { p1: deck },
      { rules: C.engineRules(stage), p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    var g = 0;
    while (!st.over && g++ < 600) AIx.applyAction(st, st.current, AIx.aiNextAction(st, st.current));
    if (st.winner === 'p1') win++;
    turns += st.turnNo;
  }
  return { rate: Math.round(win / n * 100), turns: Math.round(turns / n) };
}

/* 玩家抵达第 i 关时，牌组 = 汉预组 + 前 i 关各拿一张奖励（随机取该关奖励池第一张，模拟"每次都选"） */
function deckAt(i) {
  var d = D.DECKS.han.slice();
  for (var k = 0; k < i; k++) {
    var pool = C.STAGES[k].rewards.filter(function (id) {
      var f = D.factionOf(id);
      return f === 'neutral' || f === 'han';
    });
    d.push(pool[0]);
  }
  return d;
}

console.log('\n===== 8 关难度体检（每关 ' + N + ' 局，玩家也由 AI 操作）=====');
var base = deckAt(0);
C.STAGES.forEach(function (s, i) {
  var withRewards = deckAt(i);
  var a = runStage(s, base, N);          /* 保守：只有初始 20 张 */
  var b = runStage(s, withRewards, N);   /* 真实：带上前面拿的奖励牌 */
  console.log('  ' + (i + 1) + '. ' + s.name.padEnd(6) +
    ' 20 张牌组 ' + String(a.rate).padStart(3) + '%（' + a.turns + ' 回合）' +
    '   ' + withRewards.length + ' 张牌组 ' + String(b.rate).padStart(3) + '%（' + b.turns + ' 回合）');
});
console.log('');
