/* 奖励「跳过」的补偿定价：一张奖励牌值多少胜率？给多少血上限才等价？
 * 口径与 tune-8 一致（玩家侧 AI 代打、20 张裸牌组、失败即止）。
 * 用法：node test/_tune-skip.js [每格局数]
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
globalThis.Campaign = require('../js/campaign.js');
var D = Data, E = Engine, C = Campaign, AIx = AI;

var N = Number(process.argv[2]) || 80;
var STAGE_IDX = [3, 7];          /* 第 4 关（中段）与第 8 关（终点） */
var HP_BONUS = [0, 4, 8, 12, 16];

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

function run(stage, deck, hpBonus, n) {
  var win = 0;
  for (var i = 0; i < n; i++) {
    var rules = C.engineRules(stage);
    if (hpBonus) rules.playerHpBonus = hpBonus;
    var st = E.newGame('liubang', stage.enemy.heroId,
      Math.random() < 0.5 ? 'p1' : 'p2', stage.aiLevel,
      { p1: deck }, { rules: rules, p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    var g = 0;
    while (!st.over && g++ < 600) AIx.applyAction(st, st.current, AIx.aiNextAction(st, st.current));
    if (st.over && st.winner === 'p1') win++;
  }
  return Math.round(win / n * 100);
}

console.log('\n===== 奖励跳过的补偿定价（每格 ' + N + ' 局，刘邦·汉预组）=====');
STAGE_IDX.forEach(function (si) {
  var stage = C.STAGES[si];
  var deck = deckAt(si);                       /* 到达该关时的正常牌组 */
  var bare = deckAt(0);                        /* 若前面全部跳过：只有 20 张 */
  var withCards = run(stage, deck, 0, N);
  var noCards = run(stage, bare, 0, N);
  var line = '  第 ' + (si + 1) + ' 关 ' + stage.name + '：带 ' + deck.length + ' 张牌 ' + withCards +
    '%，若前面全跳过（20 张）' + noCards + '%';
  console.log(line);
  var perCard = (withCards - noCards) / Math.max(1, deck.length - bare.length);
  console.log('    每张奖励牌 ≈ ' + perCard.toFixed(1) + 'pp');
  var base = run(stage, bare, 0, N);
  var curve = [];
  HP_BONUS.forEach(function (hp) {
    if (hp === 0) { curve.push('+' + hp + '血 ' + base + '%'); return; }
    curve.push('+' + hp + '血 ' + run(stage, bare, hp, N) + '%');
  });
  console.log('    20 张牌组 + 血量补偿：' + curve.join(' / '));
});
console.log('');
