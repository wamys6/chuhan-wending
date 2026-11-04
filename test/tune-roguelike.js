/* 战役随机化难度体检：逐关胜率 + 通关率（AI 代打玩家，含军师与行军事件）
   用法：node test/tune-roguelike.js [局数] [军师id...] */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
globalThis.Campaign = require('../js/campaign.js');

var D = Data, E = Engine, A = AI, C = Campaign;
var N = parseInt(process.argv[2], 10) || 15;
var only = process.argv.slice(3);

/* 模拟玩家点事件：随机选一个选项；得牌/删牌按 UI 的逻辑落地 */
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

function runOne(advisorId) {
  var prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  prog.advisor = advisorId;
  var log = [];
  for (var i = 0; i < C.STAGES.length; i++) {
    var stage = C.STAGES[i];
    var st = E.newGame('liubang', stage.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
      stage.aiLevel, { p1: prog.deck }, { rules: C.engineRules(stage, prog), p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    var guard = 0;
    while (!st.over && guard++ < 800) A.applyAction(st, st.current, A.aiNextAction(st, st.current));
    var win = st.winner === 'p1';
    log.push({ id: stage.id, win: win, turns: st.turnNo });
    if (!win) return { cleared: i, stages: log, deck: prog.deck.length };
    var reward = C.rollRewards(stage, 'han', 1, prog)[0] || null;
    C.clearStage(prog, stage.id, reward);
    C.consumeBoosts(prog);
    if (C.needsEvent(prog, stage)) applyEventSim(prog, C.pickEvent(prog));
  }
  return { cleared: C.STAGES.length, stages: log, deck: prog.deck.length };
}

var groups = [{ id: null, label: '无军师' }].concat(C.ADVISORS.map(function (a) {
  return { id: a.id, label: a.name + '·' + a.title };
}));
if (only.length) groups = groups.filter(function (g) { return only.indexOf(g.id || 'none') >= 0; });

var rows = [];
groups.forEach(function (g) {
  var enter = C.STAGES.map(function () { return 0; });
  var wins = C.STAGES.map(function () { return 0; });
  var full = 0, turnsAt8 = [];
  for (var n = 0; n < N; n++) {
    var r = runOne(g.id);
    r.stages.forEach(function (s) {
      var idx = C.stageIndex(s.id);
      enter[idx]++;
      if (s.win) wins[idx]++;
      if (idx === 7 && s.win) turnsAt8.push(s.turns);
    });
    if (r.cleared >= C.STAGES.length) full++;
  }
  var cells = C.STAGES.map(function (s, i) {
    return enter[i] ? Math.round(wins[i] / enter[i] * 100) + '%' : '—';
  });
  rows.push({
    label: g.label,
    cells: cells,
    full: Math.round(full / N * 100) + '%',
    avgTurns: turnsAt8.length
      ? Math.round(turnsAt8.reduce(function (a, b) { return a + b; }, 0) / turnsAt8.length) : '-'
  });
});

var head = '军师'.padEnd(18) + C.STAGES.map(function (s, i) { return ('关' + (i + 1)).padEnd(6); }).join('') +
  '通关率  末关回合';
console.log(head);
console.log('-'.repeat(head.length));
rows.forEach(function (r) {
  console.log(r.label.padEnd(18) + r.cells.map(function (c) { return c.padEnd(6); }).join('') +
    r.full.padEnd(8) + r.avgTurns);
});
console.log('\n（每格 = 进入该关的局数中，打赢的比例；' + N + ' 局 / 组）');
