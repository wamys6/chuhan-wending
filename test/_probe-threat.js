/*
 * 敌方意图预告 —— 纸上验证探针 v3（只测量，不改游戏）
 *
 * 口径：预测点 = 敌方回合开始（= 玩家结束回合那一刻所见战场，UI 实时重算后
 * 玩家最后看到的就是这一帧）。归因只看击杀者：
 *   board    —— 击杀者在预测点已在场（实时重算的 UI 必然能标出来）
 *   newcomer —— 击杀者是敌方回合内才下场的部队（冲锋，天然覆盖不了）
 *   cardfx   —— 出牌/计谋效果直接致死（没有攻击者）
 *
 * 两条标记规则对比：
 *   A 单杀：∃ 一支够得着的敌军 atk ≥ 该部队生命
 *   B 围杀：够得着的敌军总攻 ≥ 该部队生命（含接力围杀的近似）
 *
 * board 死亡中未被规则覆盖的原因拆解：
 *   multi   —— 单杀不满足但围杀满足（接力围杀）
 *   buffed  —— 击杀者被回合内加攻（樊哙冲阵/韩信点兵/buff 牌）
 *   other   —— 其余（守御变化导致够不着→够得着等）
 *
 * 用法：node test/_probe-threat.js [局数]
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
const D = Data, E = Engine;
const AI = require('../js/ai.js');

const N = parseInt(process.argv[2] || '400', 10);

const SEED_BASE = 20261107;
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = Math.imul(t ^ (t >>> 14), 1 | t) ^ t;
    t = Math.imul(t ^ (t >>> 7), 61 | t) ^ t;
    return ((t ^ (t >>> 16)) >>> 0) / 4294967296;
  };
}
let rng = mulberry32(SEED_BASE);
Math.random = function () { return rng(); };

/* 预测点的可达映射：我方部队 uid -> 够得着它的敌方部队列表 */
function attackerMap(state) {
  const map = new Map();
  const foe = state.players.p2;
  E.RANKS.forEach(function (r) {
    foe.board[r].forEach(function (a) {
      if (a.atk <= 0) return;
      const info = E.getAttackTargets(state, 'p2', a);
      info.units.forEach(function (t) {
        if (!map.has(t.unit.uid)) map.set(t.unit.uid, []);
        map.get(t.unit.uid).push(a);
      });
    });
  });
  return map;
}

function aliveUids(state, pid) {
  const set = new Set();
  E.RANKS.forEach(function (r) {
    state.players[pid].board[r].forEach(function (u) { set.add(u.uid); });
  });
  return set;
}

const stat = {
  turns: 0, markedFracA: 0, markedFracB: 0,
  deaths: 0, byBoard: 0, byNewcomer: 0, byCardfx: 0,
  covA: 0, covB: 0, missMulti: 0, missBuffed: 0, missOther: 0
};

function runOne() {
  const first = rng() < 0.5 ? 'p1' : 'p2';
  const st = E.newGame('liubang', 'xiangyu', first, 'bijiang', null, null);
  E.doMulligan(st, 'p1', AI.aiMulligan(st, 'p1'));
  E.doMulligan(st, 'p2', AI.aiMulligan(st, 'p2'));
  E.beginGame(st);

  let atkAtPredict = new Map();  // 预测点时各敌军 uid -> atk（识别回合内加攻）
  let mapA = new Map();          // 预测点可达映射
  let hpAtPredict = new Map();   // 预测点时我方各部队 uid -> hp（死了查不到，必须快照）
  let foeSet = new Set();
  let firstP2Action = false;

  let guard = 0;
  while (!st.over && guard++ < 800) {
    const cur = st.current;
    if (cur === 'p2' && !firstP2Action) {
      mapA = attackerMap(st);
      atkAtPredict = new Map();
      hpAtPredict = new Map();
      E.RANKS.forEach(function (r) {
        st.players.p2.board[r].forEach(function (u) { atkAtPredict.set(u.uid, u.atk); });
        st.players.p1.board[r].forEach(function (u) { hpAtPredict.set(u.uid, u.hp); });
      });
      foeSet = aliveUids(st, 'p2');
      stat.turns++;
      const mine = aliveUids(st, 'p1');
      if (mine.size) {
        let a = 0, b = 0;
        mine.forEach(function (uid) {
          const list = mapA.get(uid) || [];
          const hp = unitHp(st, uid);
          if (list.some(function (x) { return x.atk >= hp; })) a++;
          if (list.reduce(function (s, x) { return s + x.atk; }, 0) >= hp) b++;
        });
        stat.markedFracA += a / mine.size;
        stat.markedFracB += b / mine.size;
      }
      firstP2Action = true;
    }
    const act = AI.aiNextAction(st, cur);
    const before = cur === 'p2' ? aliveUids(st, 'p1') : null;
    AI.applyAction(st, cur, act);
    if (cur === 'p2' && before) {
      const after = aliveUids(st, 'p1');
      before.forEach(function (uid) {
        if (after.has(uid)) return;
        stat.deaths++;
        let cause;
        if (act.type === 'attack') {
          cause = foeSet.has(act.attacker) ? 'board' : 'newcomer';
        } else {
          cause = 'cardfx';
        }
        if (cause === 'newcomer') { stat.byNewcomer++; return; }
        if (cause === 'cardfx') { stat.byCardfx++; return; }
        /* board 击杀：检查 A/B 规则覆盖与缺口原因（hp 用预测点快照） */
        stat.byBoard++;
        const list = mapA.get(uid) || [];
        const hp = hpAtPredict.has(uid) ? hpAtPredict.get(uid) : 0;
        const single = list.some(function (x) { return x.atk >= hp; });
        const sum = list.reduce(function (s, x) { return s + x.atk; }, 0) >= hp;
        if (single) stat.covA++;
        if (sum) stat.covB++;
        if (!sum) {
          const killer = findUnit(st, act.attacker);
          const wasAtk = atkAtPredict.get(act.attacker);
          if (killer && wasAtk !== undefined && killer.atk > wasAtk) stat.missBuffed++;
          else stat.missOther++;
        } else if (!single) {
          stat.missMulti++;
        }
      });
    }
    if (cur === 'p2' && st.current === 'p1') firstP2Action = false;
  }
}

function unitHp(st, uid) {
  let hp = 0;
  E.RANKS.forEach(function (r) {
    st.players.p1.board[r].forEach(function (u) { if (u.uid === uid) hp = u.hp; });
  });
  return hp;
}
/* 死亡部队在预测点时的生命（死亡后查不到，近似用当前 hp+0；多由围杀口径用） */
function unitHpAtPredict(st, uid) { return unitHp(st, uid); }
function findUnit(st, uid) {
  let found = null;
  E.RANKS.forEach(function (r) {
    st.players.p2.board[r].forEach(function (u) { if (u.uid === uid) found = u; });
  });
  return found;
}

for (let i = 0; i < N; i++) runOne();

console.log('=== 敌方意图预告探针 v3（' + N + ' 局，双裨将）===');
console.log('敌方回合数 ' + stat.turns
  + '，平均被标占比：A单杀 ' + (stat.markedFracA / Math.max(1, stat.turns) * 100).toFixed(1) + '%'
  + ' / B围杀 ' + (stat.markedFracB / Math.max(1, stat.turns) * 100).toFixed(1) + '%');
const pct = function (x) { return stat.deaths ? (x / stat.deaths * 100).toFixed(1) : '0'; };
console.log('我方部队死亡共 ' + stat.deaths);
console.log('  场上既有部队击杀（可预告）' + stat.byBoard + '（' + pct(stat.byBoard) + '%）');
console.log('  当回合新下场击杀（冲锋）' + stat.byNewcomer + '（' + pct(stat.byNewcomer) + '%）');
console.log('  出牌/计谋直伤' + stat.byCardfx + '（' + pct(stat.byCardfx) + '%）');
console.log('可预告死亡 ' + stat.byBoard + ' 中：');
const pb = function (x) { return stat.byBoard ? (x / stat.byBoard * 100).toFixed(1) : '0'; };
console.log('  A 单杀规则覆盖 ' + stat.covA + '（' + pb(stat.covA) + '%）');
console.log('  B 围杀规则覆盖 ' + stat.covB + '（' + pb(stat.covB) + '%）');
console.log('  B 未覆盖 ' + (stat.byBoard - stat.covB) + '：回合内加攻 ' + stat.missBuffed
  + ' / 其他（守御变化等）' + stat.missOther + '；A 覆盖而 B 也覆盖的接力围杀 ' + stat.missMulti);
