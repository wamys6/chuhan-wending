/*
 * 奖励结构诊断 —— 1.2 前置数据
 *
 * 11.5 的结论是「死战路线靠卡堆起不来，只能靠军师」。这句话有两种可能的成因，
 * 对应的解法完全不同，必须先分清：
 *   A. 选不到 —— 三选一里根本刷不出死战牌（池子大、带死战的牌占比低）
 *   B. 选了没用 —— 刷得出、也拿了，但每张只值 1~2 点属性，8 张也构不成质变
 * 这个脚本把两者分开量：刷出率、拿取数、牌组最终浓度。
 *
 * 用法：node test/diag-reward.js [局数] [选牌偏好 random|death]
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
const D = Data, E = Engine;
const AI = require('../js/ai.js');
const C = require('../js/campaign.js');

const N = parseInt(process.argv[2] || '200', 10);
const PREFER = process.argv[3] || 'death';

const isDeath = (id) => !!(D.CARDS[id] && D.CARDS[id].deathrattle);
const isTaunt = (id) => !!(D.CARDS[id] && D.CARDS[id].taunt);

/* 固定种子，两个偏好跑同一批牌序 */
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

/* 池子构成：不看随机，直接算每关的可选范围 */
console.log('=== 各关奖励池构成（汉阵营视角，tier 内、同名<2）===');
const poolStats = [];
for (const stage of C.STAGES) {
  const prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  const pool = C.rollRewards(stage, 'han', 999, prog);   // 抽满 = 全池（去重后仍限同名次数）
  const total = pool.length;
  const death = pool.filter(isDeath).length;
  const taunt = pool.filter(isTaunt).length;
  poolStats.push({ id: stage.id, total, death, taunt });
  console.log(`  ${stage.id}  池 ${String(total).padStart(3)}  死战 ${String(death).padStart(2)}` +
    ` (${(death / total * 100).toFixed(0)}%)  守御 ${taunt}  三选一含死战 ${(100 * (1 - comb(total - death, 3) / comb(total, 3))).toFixed(0)}%`);
}
function comb(n, k) { if (n < k) return 0; let r = 1; for (let i = 0; i < k; i++) r = r * (n - i) / (i + 1); return r; }

function score(id) {
  const c = D.CARDS[id];
  if (!c) return -1;
  const body = (c.atk || 0) + (c.hp || 0);
  if (PREFER === 'death') return (c.deathrattle ? 100 : 0) + body;
  return Math.random();
}

function runOne() {
  const prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  const stat = { offers: 0, noDeathOffer: 0, pickedDeath: 0, picks: 0 };
  for (let i = 0; i < C.STAGES.length; i++) {
    const stage = C.STAGES[i];
    const st = E.newGame('liubang', stage.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
      stage.aiLevel, { p1: prog.deck }, { rules: C.engineRules(stage, prog), p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    let guard = 0;
    while (!st.over && guard++ < 800) AI.applyAction(st, st.current, AI.aiNextAction(st, st.current));
    if (st.winner !== 'p1') return { cleared: i, stat: stat, deck: prog.deck.slice() };

    const cands = C.rollRewards(stage, 'han', 3, prog);
    stat.offers++;
    if (!cands.some(isDeath)) stat.noDeathOffer++;
    let reward = cands[0], best = -Infinity;
    for (const id of cands) { const s = score(id); if (s > best) { best = s; reward = id; } }
    if (isDeath(reward)) stat.pickedDeath++;
    stat.picks++;
    C.clearStage(prog, stage.id, reward);
    C.consumeBoosts(prog);
  }
  return { cleared: C.STAGES.length, stat: stat, deck: prog.deck.slice() };
}

let offers = 0, noDeath = 0, picked = 0, full = 0, deathInDeck = 0, deckSize = 0, samples = 0;
for (let i = 0; i < N; i++) {
  resetRng(i);
  const r = runOne();
  offers += r.stat.offers; noDeath += r.stat.noDeathOffer; picked += r.stat.pickedDeath;
  if (r.cleared === C.STAGES.length) {
    full++;
    deathInDeck += r.deck.filter(isDeath).length;
    deckSize += r.deck.length;
    samples++;
  }
}
const base = D.DECKS.han.filter(isDeath).length;
console.log(`\n=== ${PREFER} 策略（${N} 局，通关 ${full}）===`);
console.log(`  奖励次数 ${offers}，其中三张里没有死战牌 ${noDeath} 次 (${(noDeath / offers * 100).toFixed(0)}%)`);
console.log(`  主动选了死战牌 ${picked} 次，占拿到奖励的 ${(picked / offers * 100).toFixed(1)}%`);
if (samples) {
  console.log(`  通关牌组：死战 ${ (deathInDeck / samples).toFixed(1) } 张 / 共 ${(deckSize / samples).toFixed(1)} 张` +
    `（初始 ${base} 张，浓度 ${(deathInDeck / deckSize * 100).toFixed(0)}%）`);
}
