/*
 * 疲劳探针（五·十 前置测量）—— 疲劳是不是死机制、闹钟何时该响
 *
 * 用法：node test/_probe-fatigue.js [局数] [模式]
 *   模式 campaign（默认）：整轮口径，逐场记录
 *   模式 plain：20v20 单场（快速开战口径）
 *
 * 记录：己方回合序分布 / 疲劳触发率 / 疲劳跳数与单方总伤 /
 *       疲劳直接致死（游戏结束前最后一条疲劳行属于败方）/ 疲劳占败方总失血比
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
const D = Data, E = Engine;
const AI = require('../js/ai.js');
const C = require('../js/campaign.js');

const N = parseInt(process.argv[2] || '150', 10);
const MODE = process.argv[3] || 'campaign';

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
let rng = mulberry32(20261107);
Math.random = function () { return rng(); };
function resetRng(i) { rng = mulberry32(20261107 + i * 7919); }

/* 从 log 提取某方的疲劳事件序列（[跳数1, 跳数2, ...] 与累计伤害） */
function fatigueOf(log, mine) {
  const ticks = [];
  let total = 0;
  for (const line of log) {
    if (line.indexOf('疲劳受') < 0) continue;
    const isMine = line.indexOf('我方') >= 0;
    if (isMine !== mine) continue;
    const m = line.match(/疲劳受 (\d+) 点/);
    const v = m ? parseInt(m[1], 10) : 0;
    ticks.push(v); total += v;
  }
  return { ticks, total };
}

const stats = {
  battles: 0, halfTurns: [], deckSize: [], stageHalf: {}, stageDeck: {},
  fatigueGames: 0, fatigueTicks: [], fatigueDmg: [], deckEmptyTurn: [],
  fatigueLethal: 0, fatigueShare: [], p1FatGames: 0, p2FatGames: 0,
  stageFat: {}, winnerFatSide: { p1: 0, p2: 0 }, loserFatSide: { p1: 0, p2: 0 },
};

/* 跑一场，返回统计（half = 胜负分出时的己方回合数，粗口径） */
function runOneBattle(deck, stage, aiLevel, rulesCtx) {
  const st = E.newGame('liubang', stage.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
    aiLevel, { p1: deck },
    { rules: C.engineRules(stage, rulesCtx), p2Meta: stage.enemy.meta });
  st.levels.p1 = aiLevel;
  E.beginGame(st);
  let myTurns = 0, last = null;
  let guard = 0;
  let emptyTurn = 0;            // 任一方首跳发生在其第几个己方回合
  const sideTurns = { p1: 0, p2: 0 };
  while (!st.over && guard++ < 800) {
    const cur = st.current;
    if (cur !== last) {
      last = cur;
      sideTurns[cur]++;
      if (cur === 'p1') myTurns++;
      /* 翻到 cur 的那一刻，cur 的回合开始抽牌已发生：deck==0 即刚吃第一跳疲劳 */
      if (!emptyTurn && st.players[cur].deck.length === 0) emptyTurn = sideTurns[cur];
    }
    AI.applyAction(st, cur, AI.aiNextAction(st, cur));
  }
  const f1 = fatigueOf(st.log, true), f2 = fatigueOf(st.log, false);
  const looser = st.winner === 'p1' ? 'p2' : 'p1';
  const looserF = looser === 'p1' ? f1 : f2;
  const p = st.players[looser];
  const lost = (p.maxHp || 30) - p.hp; // 总失血（近似，含治疗误差）
  /* 疲劳直接致死：败方疲劳总伤 >= 败方最大血（疲劳单挑致死） */
  const fatigueLethal = looserF.total >= (p.maxHp || 30);
  const share = lost > 0 ? Math.min(1, looserF.total / lost) : 0;
  return { st, myTurns, fatAny: (f1.ticks.length + f2.ticks.length) > 0,
    p1Fat: f1.ticks.length > 0, p2Fat: f2.ticks.length > 0,
    fatTicksMax: Math.max(f1.ticks.length, f2.ticks.length),
    fatDmgMax: Math.max(f1.total, f2.total), fatigueLethal, share, emptyTurn };
}

function record(stageId, r, deckSize) {
  stats.battles++;
  stats.halfTurns.push(r.myTurns);
  stats.deckSize.push(deckSize);
  stats.stageHalf[stageId] = stats.stageHalf[stageId] || [];
  stats.stageHalf[stageId].push(r.myTurns);
  stats.stageFat[stageId] = stats.stageFat[stageId] || { n: 0, fat: 0 };
  stats.stageFat[stageId].n++;
  if (r.fatAny) {
    stats.fatigueGames++;
    stats.stageFat[stageId].fat++;
    stats.fatigueTicks.push(r.fatTicksMax);
    stats.fatigueDmg.push(r.fatDmgMax);
    if (r.emptyTurn) stats.deckEmptyTurn.push(r.emptyTurn);
    if (r.fatigueLethal) stats.fatigueLethal++;
    stats.fatigueShare.push(r.share);
    if (r.p1Fat) stats.p1FatGames++;
    if (r.p2Fat) stats.p2FatGames++;
    const winSide = r.st.winner;
    if (winSide === 'p1' ? r.p1Fat : r.p2Fat) stats.winnerFatSide[winSide]++;
    else stats.loserFatSide[winSide === 'p1' ? 'p2' : 'p1']++;
  }
}

/* ---------- 主流程 ---------- */
if (MODE === 'campaign') {
  let clearedRuns = 0;
  for (let i = 0; i < N; i++) {
    resetRng(i);
    const prog = C.emptyProgress('liubang');
    prog.deck = D.DECKS.han.slice();
    for (let s = 0; s < C.STAGES.length; s++) {
      const stage = C.STAGES[s];
      const r = runOneBattle(prog.deck, stage, stage.aiLevel,
        { mode: 'regular', hpBonus: 0, manaBonus: 0, drawBonus: 0, enemyManaBonus: 0 });
      const win = r.st.winner === 'p1';
      record(stage.id, r, prog.deck.length);
      if (!win) break;
      const cands = C.rollRewards(stage, 'han', 3, prog);
      C.clearStage(prog, stage.id, cands[0]);
      C.consumeBoosts(prog);
      if (C.needsEvent(prog, stage)) {
        const ev = C.pickEvent(prog);
        const res = C.applyEvent(prog, ev.id, Math.floor(Math.random() * ev.options.length));
        const fx = (res && res.fx) || {};
        if (fx.card) {
          const need = fx.cardCount || 1;
          const cards = C.rollRewards({ id: '_ev', rewards: [], tier: 3 }, 'han', need, prog, {});
          for (let k = 0; k < need && cards.length; k++) {
            prog.deck.push(cards[Math.floor(Math.random() * cards.length)]);
          }
        }
        if (fx.remove) {
          for (let k = 0; k < fx.remove && prog.deck.length > 0; k++) {
            prog.deck.splice(Math.floor(Math.random() * prog.deck.length), 1);
          }
        }
      }
      if (s === C.STAGES.length - 1) clearedRuns++;
    }
  }
  console.log('=== 整轮口径 ' + N + ' 轮（通关 ' + clearedRuns + '）===');
} else {
  for (let i = 0; i < N; i++) {
    resetRng(i);
    const stage = { id: 'plain', enemy: { heroId: 'xiangyu', meta: null } };
    const r = runOneBattle(D.DECKS.han.slice(), stage, 'mingjiang',
      { mode: 'regular', hpBonus: 0, manaBonus: 0, drawBonus: 0, enemyManaBonus: 0 });
    record('plain', r, 20);
  }
  console.log('=== 单场口径 ' + N + ' 局 ===');
}

/* ---------- 汇总 ---------- */
function pct(a, q) { if (!a.length) return 0; const s = a.slice().sort((x, y) => x - y); return s[Math.min(s.length - 1, Math.floor(s.length * q))]; }
function avg(a) { return a.length ? (a.reduce((x, y) => x + y, 0) / a.length) : 0; }
const half = stats.halfTurns;
console.log('战斗数 ' + stats.battles + '，己方回合 p50/p90/p99/max: '
  + pct(half, .5) + '/' + pct(half, .9) + '/' + pct(half, .99) + '/' + Math.max.apply(null, half));
const hist = {};
for (const h of half) hist[h] = (hist[h] || 0) + 1;
const hs = Object.keys(hist).map(Number).sort((a, b) => a - b);
let acc = 0; const cum = [];
for (const h of hs) { acc += hist[h]; cum.push(h + 't:' + Math.round(acc / stats.battles * 100) + '%'); }
console.log('己方回合累计: ' + cum.slice(0, 14).join(' '));
console.log('开局牌库 p50/p90: ' + pct(stats.deckSize, .5) + '/' + pct(stats.deckSize, .9));
console.log('出现疲劳的战斗: ' + stats.fatigueGames + '/' + stats.battles
  + '（' + Math.round(stats.fatigueGames / stats.battles * 100) + '%）');
if (stats.fatigueGames) {
  console.log('最大疲劳跳数 p50/p90/max: ' + pct(stats.fatigueTicks, .5) + '/' + pct(stats.fatigueTicks, .9) + '/' + Math.max.apply(null, stats.fatigueTicks));
  console.log('单方疲劳总伤 avg/p90/max: ' + Math.round(avg(stats.fatigueDmg)) + '/' + pct(stats.fatigueDmg, .9) + '/' + Math.max.apply(null, stats.fatigueDmg));
  console.log('首跳时己方回合 p50/p90/max: ' + pct(stats.deckEmptyTurn, .5) + '/' + pct(stats.deckEmptyTurn, .9) + '/' + Math.max.apply(null, stats.deckEmptyTurn));
  console.log('疲劳单挑致死: ' + stats.fatigueLethal + ' 场');
  console.log('疲劳占败方总失血 avg/p50/p90: ' + Math.round(avg(stats.fatigueShare) * 100) + '%/'
    + Math.round(pct(stats.fatigueShare, .5) * 100) + '%/' + Math.round(pct(stats.fatigueShare, .9) * 100) + '%');
}
for (const sid of Object.keys(stats.stageHalf)) {
  const arr = stats.stageHalf[sid];
  const sf = stats.stageFat[sid];
  console.log('  ' + sid + ': n=' + sf.n + ' 疲劳率 ' + Math.round(sf.fat / sf.n * 100) + '%'
    + ' 回合 p50/p90 ' + pct(arr, .5) + '/' + pct(arr, .9));
}
console.log('我方疲劳 ' + stats.p1FatGames + ' 场 / 敌方疲劳 ' + stats.p2FatGames + ' 场'
  + '；疲劳方胜 ' + (stats.winnerFatSide.p1 + stats.winnerFatSide.p2) + ' / 疲劳方败 '
  + (stats.loserFatSide.p1 + stats.loserFatSide.p2));
