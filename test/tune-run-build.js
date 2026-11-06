/*
 * 整轮（8 关）口径的构筑强度测试 —— 1.1 卡池扩容专用
 *
 * 为什么不复用 tune-builds.js：那版是"AI 对 AI + 20 张满配牌组"，测的是极端浓度下的上限。
 * 真实战役里每关只加 1 张牌，浓度永远到不了 30%，两者给出过完全相反的信号
 * （AI 对 AI：死战流 +34pp；战役：死战流每关都更差）。**构筑强度必须在整轮口径下测。**
 *
 * 用法：
 *   node test/tune-run-build.js [局数] [重复次数] [军师id|none] [选牌偏好]
 *   选牌偏好：random（默认）| death（优先死战）| taunt（优先守御）| combo（优先连击）| quality（优先总属性）
 *
 * 输出：逐关胜率曲线 + 整轮通关率；多轮取中位数（单轮 100 局噪声约 ±5pp）。
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
const D = Data, E = Engine;
const AI = require('../js/ai.js');
const C = require('../js/campaign.js');

const N = parseInt(process.argv[2] || '80', 10);
const REPEAT = parseInt(process.argv[3] || '2', 10);
const ADVISOR = (process.argv[4] || 'none') === 'none' ? null : process.argv[4];
const PREFER = process.argv[5] || 'random';

/* 同种子配对：整轮口径的通关率方差极大（60 局时 7%~17% 都在噪声内），
   不同配置各自随机等于在比较噪声。这里把 Math.random 换成可重置的 PRNG，
   每局开局按 seedBase+i 重置 —— 各配置跑的是同一批牌序，差异才是真信号。 */
const SEED_BASE = parseInt(process.argv[6] || '20261103', 10);
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

/* CH_NO_ADV=1：关掉军师主动技（同种子 A/B 量它值多少） */
if (process.env.CH_NO_ADV === '1' && C.setAdvisorActive) C.setAdvisorActive(false);
/* CH_EVENT_POOL=base：事件走解锁式 meta 的初始池（量新玩家口径的难度） */
const EVENT_POOL = process.env.CH_EVENT_POOL === 'base' ? C.baseEvents() : null;

/* 第 7 个参数：奖励倾斜开关（0 = 关掉，用来分离"双亡语"与"奖励倾斜"各自值多少） */
const BIAS_ON = (process.argv[7] || '1') !== '0';
if (!BIAS_ON) C.setRewardBias && C.setRewardBias(0);

/* 行军事作用"随机选项 + 随机加牌"处理，口径与 tune-roguelike 一致 */
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

function score(id) {
  const c = D.CARDS[id];
  if (!c) return -1;
  const body = (c.atk || 0) + (c.hp || 0);
  if (PREFER === 'death') return (c.deathrattle ? 100 : 0) + body;
  if (PREFER === 'taunt') return (c.taunt ? 100 : 0) + body;
  if (PREFER === 'combo') return (c.combo ? 100 : 0) + body;
  if (PREFER === 'quality') return body - (c.cost || 0) * 1.5;
  return Math.random();
}

/* CH_ADVUSE=1：额外打印「军师技发动率」——一个按钮如果 AI 整轮一次都不按，
   数值差自然等于 0，那不是「技能弱」，是「技能不存在」（夏侯婴 0 费的坑）。 */
const ADV_USE = process.env.CH_ADVUSE === '1';
let advUsedBattles = 0, battles = 0;

function runOne() {
  const prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  prog.advisor = ADVISOR;
  /* CH_MODE=chuben 走初阵档位（主将 +6 血 / 敌首回合 -1 军粮），默认常规 */
  prog.mode = process.env.CH_MODE === 'chuben' ? 'chuben' : 'regular';
  const stages = [];
  for (let i = 0; i < C.STAGES.length; i++) {
    const stage = C.STAGES[i];
    const st = E.newGame('liubang', stage.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
      stage.aiLevel, { p1: prog.deck },
      { rules: C.engineRules(stage, prog), p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    let guard = 0;
    while (!st.over && guard++ < 800) AI.applyAction(st, st.current, AI.aiNextAction(st, st.current));
    const win = st.winner === 'p1';
    battles++;
    if (st.players.p1.advUsed) advUsedBattles++;
    stages.push(win);
    if (!win) return { cleared: i, stages: stages };
    const cands = C.rollRewards(stage, 'han', 3, prog);
    let reward = cands[0], best = -Infinity;
    for (const id of cands) {
      const s = score(id);
      if (s > best) { best = s; reward = id; }
    }
    C.clearStage(prog, stage.id, reward);
    C.consumeBoosts(prog);
    if (C.needsEvent(prog, stage)) applyEventSim(prog, C.pickEvent(prog, EVENT_POOL));
  }
  return { cleared: C.STAGES.length, stages: stages };
}

function batch() {
  const per = new Array(C.STAGES.length).fill(0);
  let full = 0;
  for (let i = 0; i < N; i++) {
    resetRng(i);
    const r = runOne();
    r.stages.forEach((w, idx) => { if (w) per[idx]++; });
    if (r.cleared === C.STAGES.length) full++;
  }
  return { curve: per.map(x => Math.round(x / N * 100)), clear: Math.round(full / N * 100) };
}

const label = (ADVISOR || '无军师') + ' · ' + PREFER;
const runs = [];
for (let k = 0; k < REPEAT; k++) runs.push(batch());
const clears = runs.map(r => r.clear).sort((a, b) => a - b);
const median = clears[Math.floor(clears.length / 2)];
const mid = runs[Math.floor(runs.length / 2)];
console.log('=== ' + label + '（' + N + ' 局 × ' + REPEAT + '）===');
runs.forEach((r, i) => console.log('  第 ' + (i + 1) + ' 轮  八关 ' + r.curve.join('/') + '  通关 ' + r.clear + '%'));
console.log('  中位  八关 ' + mid.curve.join('/') + '  通关 ' + median + '%');
if (ADV_USE) {
  console.log('  军师技发动 ' + advUsedBattles + '/' + battles + ' 场（'
    + Math.round(advUsedBattles / Math.max(1, battles) * 100) + '%）');
}
