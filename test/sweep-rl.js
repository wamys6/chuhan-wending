/* 单关难度扫描：在"真实奖励流程"的牌组下，逐关试敌将血量
   用法：node test/sweep-rl.js [局数] */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
globalThis.Campaign = require('../js/campaign.js');
var D = Data, E = Engine, A = AI, C = Campaign;
var N = parseInt(process.argv[2], 10) || 50;

/* 模拟打到第 i 关时的牌组：初始预组 + 前 i 关各随机一张奖励 */
function sampleDeck(i) {
  var prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  for (var k = 0; k < i; k++) {
    var r = C.rollRewards(C.STAGES[k], 'han', 1, prog)[0];
    if (r) prog.deck.push(r);
  }
  return prog.deck;
}

function trial(stage, hp, deck, n) {
  var win = 0, turns = 0;
  var copy = JSON.parse(JSON.stringify(stage));
  copy.enemy.meta.hp = hp;
  for (var i = 0; i < n; i++) {
    var st = E.newGame('liubang', copy.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
      copy.aiLevel, { p1: deck }, { rules: C.engineRules(copy), p2Meta: copy.enemy.meta });
    st.levels.p1 = copy.aiLevel;
    E.beginGame(st);
    var g = 0;
    while (!st.over && g++ < 800) A.applyAction(st, st.current, A.aiNextAction(st, st.current));
    if (st.winner === 'p1') win++;
    turns += st.turnNo;
  }
  return Math.round(win / n * 100) + '%(' + Math.round(turns / n) + ')';
}

C.STAGES.forEach(function (s, i) {
  var deck = sampleDeck(i);
  var base = s.enemy.meta.hp;
  var cells = [];
  [-6, -3, 0, 3, 6, 9].forEach(function (d) {
    var hp = Math.max(8, base + d);
    cells.push((hp === base ? '*' : '') + hp + '血 ' + trial(s, hp, deck, N));
  });
  console.log((i + 1) + '. ' + s.name.padEnd(6) + ' [' + deck.length + '张] ' + cells.join('  '));
});
/* 带 * 的是当前数值 */
