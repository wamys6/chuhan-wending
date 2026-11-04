/* 「跳过 = 删一张牌」是否成立？对比：20 张原牌组 / 删 2 张最弱 / 删 2 张最高费
 * 用法：node test/_tune-skip2.js [每格局数]
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
globalThis.Campaign = require('../js/campaign.js');
var D = Data, E = Engine, C = Campaign, AIx = AI;

var N = Number(process.argv[2]) || 100;
var STAGE_IDX = [3, 7];

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

function run(stage, deck, n) {
  var win = 0;
  for (var i = 0; i < n; i++) {
    var st = E.newGame('liubang', stage.enemy.heroId,
      Math.random() < 0.5 ? 'p1' : 'p2', stage.aiLevel,
      { p1: deck }, { rules: C.engineRules(stage), p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    var g = 0;
    while (!st.over && g++ < 600) AIx.applyAction(st, st.current, AIx.aiNextAction(st, st.current));
    if (st.over && st.winner === 'p1') win++;
  }
  return Math.round(win / n * 100);
}

function dropWeakest(deck, k) {
  var d = deck.slice();
  for (var i = 0; i < k; i++) {
    /* 最弱 = 攻+血最低的费用效率，先拿 1/2 的兵开刀 */
    var worst = 0, worstScore = 999;
    for (var j = 0; j < d.length; j++) {
      var c = D.CARDS[d[j]];
      if (!c) continue;
      var score = (c.atk || 0) + (c.hp || 0) - (c.cost || 0) * 1.5;
      if (score < worstScore) { worstScore = score; worst = j; }
    }
    d.splice(worst, 1);
  }
  return d;
}

function dropCostliest(deck, k) {
  var d = deck.slice();
  for (var i = 0; i < k; i++) {
    var hi = 0, hc = -1;
    for (var j = 0; j < d.length; j++) {
      var c = D.CARDS[d[j]];
      if (c && c.cost > hc) { hc = c.cost; hi = j; }
    }
    d.splice(hi, 1);
  }
  return d;
}

console.log('\n===== 「跳过 = 删一张牌」定价（每格 ' + N + ' 局）=====');
STAGE_IDX.forEach(function (si) {
  var stage = C.STAGES[si];
  var deck = deckAt(si);
  var a = run(stage, deck, N);
  var b = run(stage, dropWeakest(deck, 2), N);
  var c = run(stage, dropCostliest(deck, 2), N);
  var e = run(stage, dropWeakest(deck, 4), N);
  console.log('  第 ' + (si + 1) + ' 关 ' + stage.name + '（牌组 ' + deck.length + ' 张）');
  console.log('    原样        ' + a + '%');
  console.log('    删 2 张最弱  ' + b + '%  (Δ' + (b - a >= 0 ? '+' : '') + (b - a) + 'pp)');
  console.log('    删 2 张最贵  ' + c + '%  (Δ' + (c - a >= 0 ? '+' : '') + (c - a) + 'pp)');
  console.log('    删 4 张最弱  ' + e + '%  (Δ' + (e - a >= 0 ? '+' : '') + (e - a) + 'pp)');
});
console.log('');
