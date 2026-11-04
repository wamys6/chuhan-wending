/*
 * 临时诊断：整轮口径下，牌组里各关键词的占比分布（用来定专精门槛）
 *
 * 用法：node test/_probe-ratio.js [选牌偏好] [局数]
 * 输出：逐关占比的 P10 / 中位 / P90，以及各档位达标率
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
const D = Data, E = Engine;
const AI = require('../js/ai.js');
const C = require('../js/campaign.js');

const PREFER = process.argv[2] || 'taunt';
const N = parseInt(process.argv[3] || '120', 10);
const SEED_BASE = 20261103;

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
let rng = mulberry32(SEED_BASE);
Math.random = function () { return rng(); };
function resetRng(i) { rng = mulberry32(SEED_BASE + i * 7919); }

function ratioOf(deck, key) {
  let n = 0;
  for (const id of deck) { const c = D.CARDS[id]; if (c && c[key]) n++; }
  return n / deck.length;
}

function score(id) {
  const c = D.CARDS[id];
  const body = (c.atk || 0) + (c.hp || 0);
  if (PREFER === 'death') return (c.deathrattle ? 100 : 0) + body;
  if (PREFER === 'taunt') return (c.taunt ? 100 : 0) + body;
  if (PREFER === 'combo') return (c.combo ? 100 : 0) + body;
  if (PREFER === 'quality') return body - (c.cost || 0) * 1.5;
  return Math.random();
}

function applyEventSim(prog, ev) {
  const idx = Math.floor(Math.random() * ev.options.length);
  const res = C.applyEvent(prog, ev.id, idx);
  const fx = res.fx || {};
  if (fx.card) {
    const need = fx.cardCount || 1;
    const cards = C.rollRewards({ id: '_ev', rewards: [], tier: 3 }, 'han', need, prog,
      { kind: fx.card === 'any' ? null : fx.card });
    for (let i = 0; i < need && cards.length; i++) {
      prog.deck.push(cards[Math.floor(Math.random() * cards.length)]);
    }
  }
  if (fx.remove) {
    for (let j = 0; j < fx.remove && prog.deck.length > 0; j++) {
      prog.deck.splice(Math.floor(Math.random() * prog.deck.length), 1);
    }
  }
}

// 每关开始前的占比（第 0 关 = 初始牌组）
const perStage = C.STAGES.map(() => []);

function runOne() {
  const prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  for (let i = 0; i < C.STAGES.length; i++) {
    const stage = C.STAGES[i];
    perStage[i].push([ratioOf(prog.deck, 'taunt'), ratioOf(prog.deck, 'deathrattle'), ratioOf(prog.deck, 'combo')]);
    const st = E.newGame('liubang', stage.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
      stage.aiLevel, { p1: prog.deck }, { rules: C.engineRules(stage, prog), p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    let guard = 0;
    while (!st.over && guard++ < 800) AI.applyAction(st, st.current, AI.aiNextAction(st, st.current));
    if (st.winner !== 'p1') return;
    const cands = C.rollRewards(stage, 'han', 3, prog);
    let reward = cands[0], best = -Infinity;
    for (const id of cands) { const s = score(id); if (s > best) { best = s; reward = id; } }
    C.clearStage(prog, stage.id, reward);
    C.consumeBoosts(prog);
    if (C.needsEvent(prog, stage)) applyEventSim(prog, C.pickEvent(prog));
  }
}

for (let i = 0; i < N; i++) { resetRng(i); runOne(); }

function pct(a, p) {
  if (!a.length) return 0;
  const s = a.slice().sort((x, y) => x - y);
  return Math.round(s[Math.floor((s.length - 1) * p)] * 100);
}
const KEYS = ['taunt', 'deathrattle', 'combo'];
console.log('=== 占比分布 · ' + PREFER + ' · ' + N + ' 局 ===');
console.log('关卡  样本   守御 P10/中位/P90   死战 P10/中位/P90   连击 P10/中位/P90');
perStage.forEach((rows, i) => {
  if (!rows.length) return;
  const out = KEYS.map(k => {
    const idx = KEYS.indexOf(k);
    const arr = rows.map(r => r[idx]);
    return [pct(arr, 0.1), pct(arr, 0.5), pct(arr, 0.9)].join('/');
  });
  console.log('第' + (i + 1) + '关  ' + String(rows.length).padStart(4) + '   ' + out.join('        '));
});
// 各档达标率（用「打到该关且活到那里的样本」的最后一个有效值）
[0.20, 0.25, 0.30, 0.35].forEach(th => {
  const hits = perStage.map(rows => rows.filter(r => r[0] >= th).length);
  console.log('守御 ≥' + Math.round(th * 100) + '%  达标人数逐关：' + hits.join('/'));
});
