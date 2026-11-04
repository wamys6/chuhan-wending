/*
 * 八关难度叠加扫描（1.1 扩容后的难度校准）
 *
 * 用法：node test/tune-difficulty.js <局数> <叠加项,逗号分隔> [军师|none]
 *   叠加项：
 *     mana=1          敌方每关开局军粮 +N（只对没有自带加成的关生效也可，默认全加）
 *     php=-2          固定血量关卡的主将血量 ±N
 *     preset=n_shi1:mid  每关追加一支预置部队（baseId:rank）
 *
 * 口径：不设军师时是"基线"，设军师是"该军师下的曲线"。逐关胜率是条件胜率
 * （只统计进入过该关的局），末尾一行是整轮通关率 —— 校准看这两个的乘积关系。
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
var D = Data, E = Engine;
var AI = require('../js/ai.js');
var C = require('../js/campaign.js');

var N = parseInt(process.argv[2] || '100', 10);
var SPEC = (process.argv[3] || '').trim();
var ADVISOR = (process.argv[4] || 'none') === 'none' ? null : process.argv[4];

var cfg = { mana: 0, php: 0, preset: null, skipManaStages: false };
SPEC.split(',').forEach(function (tok) {
  var kv = tok.split('=');
  if (kv[0] === 'mana') cfg.mana = parseInt(kv[1], 10) || 0;
  if (kv[0] === 'php') cfg.php = parseInt(kv[1], 10) || 0;
  if (kv[0] === 'preset') {
    var body = (kv[1] || '').split(':');
    if (body[0]) cfg.preset = { baseId: body[0], rank: body[1] || 'front' };
  }
  if (kv[0] === 'skipmana') cfg.skipManaStages = kv[1] !== '0';
});

function overlaid(stage) {
  var r = JSON.parse(JSON.stringify(stage.rules || {}));
  var hasMana = (stage.rules && stage.rules.enemyStartMana) || 0;
  if (cfg.mana && !(cfg.skipManaStages && hasMana)) {
    r.enemyStartMana = (r.enemyStartMana || 0) + cfg.mana;
  }
  if (cfg.php && r.playerHp) {
    r.playerHp = Math.max(6, r.playerHp + cfg.php);
  }
  if (cfg.preset) {
    var list = r.enemyOpeningUnits || [];
    list.push({ baseId: cfg.preset.baseId, rank: cfg.preset.rank });
    r.enemyOpeningUnits = list;
  }
  var out = {};
  for (var k in stage) out[k] = stage[k];
  out.rules = r;
  return out;
}

function applyEventSim(prog, ev) {
  var idx = Math.floor(Math.random() * ev.options.length);
  var res = C.applyEvent(prog, ev.id, idx);
  var fx = res.fx || {};
  if (fx.card) {
    var need = fx.cardCount || 1;
    var cards = C.rollRewards({ id: '_ev', rewards: [], tier: 3 }, 'han', need, prog,
      { kind: fx.card === 'any' ? null : fx.card });
    for (var i = 0; i < need && cards.length; i++) {
      prog.deck.push(cards[Math.floor(Math.random() * cards.length)]);
    }
  }
  if (fx.remove) {
    for (var j = 0; j < fx.remove && prog.deck.length > 0; j++) {
      prog.deck.splice(Math.floor(Math.random() * prog.deck.length), 1);
    }
  }
}

function runOne() {
  var prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  prog.advisor = ADVISOR;
  var entered = 0, won = 0;
  for (var i = 0; i < C.STAGES.length; i++) {
    var stage = overlaid(C.STAGES[i]);
    var st = E.newGame('liubang', stage.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
      stage.aiLevel, { p1: prog.deck },
      { rules: C.engineRules(stage, prog), p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    var g = 0;
    while (!st.over && g++ < 800) AI.applyAction(st, st.current, AI.aiNextAction(st, st.current));
    entered++;
    if (st.winner !== 'p1') return { entered: entered, won: won };
    won++;
    var cands = C.rollRewards(stage, 'han', 3, prog);
    C.clearStage(prog, stage.id, cands[Math.floor(Math.random() * cands.length)]);
    C.consumeBoosts(prog);
    if (C.needsEvent(prog, stage)) applyEventSim(prog, C.pickEvent(prog));
  }
  return { entered: entered, won: won };
}

var enter = new Array(C.STAGES.length).fill(0);
var win = new Array(C.STAGES.length).fill(0);
var full = 0;
for (var k = 0; k < N; k++) {
  var r = runOne();
  for (var i = 0; i < r.entered; i++) enter[i]++;
  for (var j = 0; j < r.won; j++) win[j]++;
  if (r.won === C.STAGES.length) full++;
}
var cond = [];
for (var i = 0; i < C.STAGES.length; i++) {
  cond.push(enter[i] ? Math.round(win[i] / enter[i] * 100) : 0);
}
var uncond = [];
for (var i2 = 0; i2 < C.STAGES.length; i2++) {
  uncond.push(Math.round(win[i2] / N * 100));
}
console.log('=== ' + (ADVISOR || '无军师') + '  叠加[' + (SPEC || '无') + ']  ' + N + ' 局 ===');
console.log('  条件胜率 ' + cond.join('/'));
console.log('  绝对胜率 ' + uncond.join('/'));
console.log('  通关率   ' + Math.round(full / N * 100) + '%');
