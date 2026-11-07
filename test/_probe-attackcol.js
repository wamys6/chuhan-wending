/*
 * 攻击来源列分布探针（五·十一 前置测量）
 *
 * 回答两个问题：
 *   1) 当前有多少输出/击杀来自中军列？（决定「只有前锋能攻击」是修骨架还是拆骨架）
 *   2) 前锋列如果 +1 攻，能触及多少实际伤害？（决定这个小改动的量级）
 *
 * 用法：node test/_probe-attackcol.js [整轮轮数]
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
const D = Data, E = Engine;
const AI = require('../js/ai.js');
const C = require('../js/campaign.js');

const N = parseInt(process.argv[2] || '120', 10);

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

const st = {
  attacks: { front: 0, mid: 0, back: 0, hero: 0 },
  dmg: { front: 0, mid: 0, back: 0, hero: 0 },
  kills: { front: 0, mid: 0, back: 0 },
  atkSum: { front: 0, mid: 0, back: 0 },   // 每次攻击的伤害合计（含溢出）
  unitsAlive: { front: 0, mid: 0, back: 0 }, // 每场开局后每列平均在场（回合快照）
  snaps: 0,
  rangedFromBack: 0, rangedFromMid: 0,
  midUnitAttackTurns: 0, turns: 0,
};

function colOf(pid, uid, board) {
  for (const r of E.RANKS) for (const u of board[r]) if (u.uid === uid) return r;
  return null;
}

function runBattle(deck, stage, aiLevel) {
  const stt = E.newGame('liubang', stage.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
    aiLevel, { p1: deck },
    { rules: C.engineRules(stage, { mode: 'regular', hpBonus: 0, manaBonus: 0, drawBonus: 0, enemyManaBonus: 0 }), p2Meta: stage.enemy.meta });
  stt.levels.p1 = aiLevel;
  E.beginGame(stt);
  let guard = 0;
  while (!stt.over && guard++ < 800) {
    const cur = stt.current;
    const board = stt.players[cur].board;
    // 每回合快照一次列人数（只看 p1，玩家口径）
    if (cur === 'p1') {
      st.turns++;
      for (const r of E.RANKS) st.unitsAlive[r] += board[r].length;
      st.snaps++;
    }
    const act = AI.aiNextAction(stt, cur);
    if (act && act.type === 'attack') {
      const col = colOf(cur, act.attacker, board);
      if (col) {
        let attacker = null;
        for (const u of board[col]) if (u.uid === act.attacker) attacker = u;
        const isHero = act.target && act.target.kind === 'hero';
        const key = isHero ? 'hero' : col;
        st.attacks[key]++;
        st.atkSum[col] += attacker ? attacker.atk : 0;
      }
    }
    const before = stt.winner;
    AI.applyAction(stt, cur, act);
    void before;
  }
  return stt;
}

let clearedRuns = 0;
for (let i = 0; i < N; i++) {
  resetRng(i);
  const prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  for (let s = 0; s < C.STAGES.length; s++) {
    const stage = C.STAGES[s];
    const stt = runBattle(prog.deck, stage, stage.aiLevel);
    const win = stt.winner === 'p1';
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
        for (let k = 0; k < need && cards.length; k++) prog.deck.push(cards[Math.floor(Math.random() * cards.length)]);
      }
      if (fx.remove) for (let k = 0; k < fx.remove && prog.deck.length > 0; k++) prog.deck.splice(Math.floor(Math.random() * prog.deck.length), 1);
    }
    if (s === C.STAGES.length - 1) clearedRuns++;
  }
}

const A = st.attacks;
const totAtk = A.front + A.mid + A.back;
console.log('=== ' + N + ' 轮（通关 ' + clearedRuns + '），玩家 ' + st.turns + ' 个己方回合 ===');
console.log('玩家攻击次数（打部队）：前锋 ' + A.front + ' / 中军 ' + A.mid + ' / 后军 ' + A.back
  + '；打主将 ' + A.hero);
console.log('占比：前锋 ' + Math.round(A.front / totAtk * 100) + '% · 中军 '
  + Math.round(A.mid / totAtk * 100) + '% · 后军 ' + Math.round(A.back / totAtk * 100) + '%');
console.log('平均攻击力（含溢出）：前锋 ' + (st.atkSum.front / Math.max(1, A.front)).toFixed(2)
  + ' · 中军 ' + (st.atkSum.mid / Math.max(1, A.mid)).toFixed(2)
  + ' · 后军 ' + (st.atkSum.back / Math.max(1, A.back)).toFixed(2));
const turns = st.snaps;
console.log('每回合均在场：前锋 ' + (st.unitsAlive.front / turns).toFixed(2)
  + ' · 中军 ' + (st.unitsAlive.mid / turns).toFixed(2)
  + ' · 后军 ' + (st.unitsAlive.back / turns).toFixed(2));
console.log('中军每回合平均出手 ' + (A.mid / turns).toFixed(2) + ' 次');
