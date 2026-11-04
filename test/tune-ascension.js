/* 心魔梯度与天时修正的难度体检
   用法：node test/tune-ascension.js [每格局数]
   输出：心魔 0..5 各一级的整轮通关率（AI 代打、含军师与事件），以及 6 个天时的通关率 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
globalThis.Campaign = require('../js/campaign.js');
var D = Data, E = Engine, A = AI, C = Campaign;

var N = parseInt(process.argv[2], 10) || 150;
/* 基准军师：取中间档，避免用最强/最弱影响结论 */
var ADVISOR = 'zhangliang';

function applyEventSim(prog, ev) {
  var idx = Math.floor(Math.random() * ev.options.length);
  var res = C.applyEvent(prog, ev.id, idx);
  var fx = res.fx || {};
  if (fx.card) {
    var need = fx.cardCount || 1;
    var simStage = { id: '_ev', rewards: [], tier: 3 };
    var cards = C.rollRewards(simStage, 'han', need, prog, { kind: fx.card === 'any' ? null : fx.card });
    for (var i = 0; i < need && cards.length; i++) {
      prog.deck.push(cards[Math.floor(Math.random() * cards.length)]);
    }
  }
  if (fx.remove) {
    for (var j = 0; j < fx.remove && prog.deck.length > 0; j++) {
      prog.deck.splice(Math.floor(Math.random() * prog.deck.length), 1);
    }
  }
  return res;
}

function runOne(ascension, tianShi) {
  var prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  prog.advisor = ADVISOR;
  prog.ascension = ascension;
  prog.tianShi = tianShi || null;
  for (var i = 0; i < C.STAGES.length; i++) {
    var stage = C.STAGES[i];
    var st = E.newGame('liubang', stage.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
      stage.aiLevel, { p1: prog.deck }, { rules: C.engineRules(stage, prog), p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    var guard = 0;
    while (!st.over && guard++ < 800) A.applyAction(st, st.current, A.aiNextAction(st, st.current));
    if (st.winner !== 'p1') return { cleared: i };
    var reward = C.rollRewards(stage, 'han', 1, prog)[0] || null;
    C.clearStage(prog, stage.id, reward);
    C.consumeBoosts(prog);
    if (C.needsEvent(prog, stage)) applyEventSim(prog, C.pickEvent(prog));
  }
  return { cleared: C.STAGES.length };
}

function rate(ascension, tianShi, n) {
  var full = 0;
  for (var i = 0; i < n; i++) if (runOne(ascension, tianShi).cleared >= C.STAGES.length) full++;
  return Math.round(full / n * 100);
}

console.log('\n===== 心魔梯度（每组 ' + N + ' 局，军师 ' + ADVISOR + '，无天时）=====');
for (var lv = 0; lv <= C.ASCENSION.length; lv++) {
  var label = lv === 0 ? '常规' : '心魔 ' + lv + '　' + C.ASCENSION[lv - 1].name;
  var mods = C.ascensionMods(lv);
  console.log('  ' + label.padEnd(22) + String(rate(lv, null, N)).padStart(3) + '%   ' + JSON.stringify(mods));
}

console.log('\n===== 天时（每组 ' + N + ' 局，常规难度）=====');
C.TIANSHI.forEach(function (t) {
  console.log('  ' + (t.name + '　' + t.desc).padEnd(30) + String(rate(0, t.id, N)).padStart(3) + '%');
});
console.log('\n（噪声参考：' + N + ' 局时约 ±3pp，判读差异要看 4pp 以上）\n');
