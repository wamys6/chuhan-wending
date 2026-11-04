/*
 * 死战专精的档位分布 —— 用来定门槛
 *
 * 关键问题：random 与 death 两种选牌策略的「死战牌张数」分布重叠多少。
 * 如果两边的分布几乎重合，那么无论门槛设在哪里，都会同时抬两组，
 * 「专精」就只是「整体加强」的另一种说法。
 *
 * 用法：node test/diag-tier.js [局数] [random|death]
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
const D = Data, E = Engine;
const AI = require('../js/ai.js');
const C = require('../js/campaign.js');

const N = parseInt(process.argv[2] || '120', 10);
const PREFER = process.argv[3] || 'death';
const SEED = 20261103;
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
let rng = mulberry32(SEED);
Math.random = function () { return rng(); };
function resetRng(i) { rng = mulberry32(SEED + i * 7919); }

const isDeath = (id) => !!(D.CARDS[id] && D.CARDS[id].deathrattle);
function score(id) {
  const c = D.CARDS[id];
  const body = (c.atk || 0) + (c.hp || 0);
  if (PREFER === 'death') return (c.deathrattle ? 100 : 0) + body;
  if (PREFER === 'quality') return body - (c.cost || 0) * 1.5;
  return Math.random();
}

/* 每局记录：打到第几关、第 5/8 关开打时的死战张数 */
const atStage5 = [], atStage8 = [], clearedAt = [];
let full = 0;
for (let i = 0; i < N; i++) {
  resetRng(i);
  const prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  for (let s = 0; s < C.STAGES.length; s++) {
    const stage = C.STAGES[s];
    if (s === 4) atStage5.push(prog.deck.filter(isDeath).length);
    if (s === 7) atStage8.push(prog.deck.filter(isDeath).length);
    const st = E.newGame('liubang', stage.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
      stage.aiLevel, { p1: prog.deck }, { rules: C.engineRules(stage, prog), p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    let guard = 0;
    while (!st.over && guard++ < 800) AI.applyAction(st, st.current, AI.aiNextAction(st, st.current));
    if (st.winner !== 'p1') break;
    if (s === C.STAGES.length - 1) { full++; clearedAt.push(prog.deck.filter(isDeath).length); }
    const cands = C.rollRewards(stage, 'han', 3, prog);
    let reward = cands[0], best = -Infinity;
    for (const id of cands) { const sc = score(id); if (sc > best) { best = sc; reward = id; } }
    C.clearStage(prog, stage.id, reward);
    C.consumeBoosts(prog);
  }
}
function hist(arr, label) {
  if (!arr.length) { console.log('  ' + label + '：无样本'); return; }
  const buckets = {};
  arr.forEach(v => { buckets[v] = (buckets[v] || 0) + 1; });
  const keys = Object.keys(buckets).map(Number).sort((a, b) => a - b);
  const line = keys.map(k => `${k}张:${(buckets[k] / arr.length * 100).toFixed(0)}%`).join('  ');
  const avg = (arr.reduce((a, b) => a + b, 0) / arr.length).toFixed(1);
  console.log(`  ${label}（均 ${avg}）  ${line}`);
}
console.log(`=== ${PREFER}（${N} 局，通关 ${full}）===`);
hist(atStage5, '第 5 关开局');
hist(atStage8, '第 8 关开局');
hist(clearedAt, '通关时牌组');
for (const th of [4, 5, 6, 7, 8]) {
  const a = atStage8.filter(v => v >= th).length / Math.max(1, atStage8.length);
  const b = atStage5.filter(v => v >= th).length / Math.max(1, atStage5.length);
  console.log(`  门槛 ${th}：第 5 关达标 ${(b * 100).toFixed(0)}%，第 8 关达标 ${(a * 100).toFixed(0)}%`);
}
