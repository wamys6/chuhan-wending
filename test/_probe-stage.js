/*
 * 逐关难度曲线探针 —— 找「断崖关」
 *
 * 为什么不用 tune-run-build.js 的输出：它打的是「第 i 关赢了多少局 / 总局数」（绝对曲线），
 * 会随累积淘汰单调下滑，永远看不出某一关本身有多难——第 3 关输掉的人根本没走到第 4 关。
 * 真正要看的是**条件通过率**：走到第 i 关的人里，有多少过了这一关。
 *
 * 用法：node test/_probe-stage.js [局数] [种子] [军师id|none]
 * 输出：
 *   1. 每关 reached / passed / 条件通过率
 *   2. 赢的时候剩多少血（惨胜 = 下一关必死）、输的时候敌方剩多少血（惜败 = 差一点）
 *   3. 到达该关时的牌组张数
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
const D = Data, E = Engine;
const AI = require('../js/ai.js');
const C = require('../js/campaign.js');

const N = parseInt(process.argv[2] || '200', 10);
const SEED = parseInt(process.argv[3] || '20261103', 10);
const ADVISOR = (process.argv[4] || 'none') === 'none' ? null : process.argv[4];
const MODE = process.env.CH_MODE === 'chuben' ? 'chuben' : 'regular';

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

/* CH_S7="hp=22,hand=5,mana=1"：临时改第 7 关参数做单变量归因（不动源文件）。
   key: hp=playerHp / hand=handLimit / mana=enemyStartMana / pmana=playerStartMana */
if (process.env.CH_S7) {
  const r = C.STAGES[6].rules;
  for (const kv of process.env.CH_S7.split(',')) {
    const [k, v] = kv.split('=');
    const n = parseInt(v, 10);
    if (k === 'hp') r.playerHp = n;
    if (k === 'hand') r.handLimit = n;
    if (k === 'mana') r.enemyStartMana = n;
    if (k === 'pmana') r.playerStartMana = n;
  }
}

const NST = C.STAGES.length;
/* 重整口径：真实玩家每关有 1 次重整（RETRY_PER_STAGE），即两次机会。
   不模拟重整得出的通关率是「一次都不许输」，会把难度系统性高估一倍。
   CH_NO_RESCUE=1 回到单次口径做对照。 */
const TRIES = process.env.CH_NO_RESCUE === '1' ? 1 : 2;
const retried = new Array(NST).fill(0);
const reached = new Array(NST).fill(0);
const passed = new Array(NST).fill(0);
const winHp = Array.from({ length: NST }, () => []);    // 赢：我方剩余血量比例
const loseHp = Array.from({ length: NST }, () => []);   // 输：敌方剩余血量比例
const deckAt = Array.from({ length: NST }, () => []);

function score(id) {
  const c = D.CARDS[id];
  return c ? (c.atk || 0) + (c.hp || 0) : -1;
}

function runOne() {
  const prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  prog.advisor = ADVISOR;
  prog.mode = MODE;
  for (let i = 0; i < NST; i++) {
    const stage = C.STAGES[i];
    reached[i]++;
    deckAt[i].push(prog.deck.length);
    let win = false, used = 0, st = null;
    for (let t = 0; t < TRIES && !win; t++) {
      st = E.newGame('liubang', stage.enemy.heroId, Math.random() < 0.5 ? 'p1' : 'p2',
        stage.aiLevel, { p1: prog.deck },
        { rules: C.engineRules(stage, prog), p2Meta: stage.enemy.meta });
      st.levels.p1 = stage.aiLevel;
      E.beginGame(st);
      let guard = 0;
      while (!st.over && guard++ < 800) AI.applyAction(st, st.current, AI.aiNextAction(st, st.current));
      win = st.winner === 'p1';
      used++;
      if (!win) loseHp[i].push(st.players.p2.hp / Math.max(1, st.players.p2.maxHp));
    }
    if (used > 1) retried[i]++;
    if (!win) return i;
    passed[i]++;
    winHp[i].push(st.players.p1.hp / Math.max(1, st.players.p1.maxHp));
    const cands = C.rollRewards(stage, 'han', 3, prog);
    let reward = cands[0], best = -Infinity;
    for (const id of cands) { const s = score(id); if (s > best) { best = s; reward = id; } }
    C.clearStage(prog, stage.id, reward);
    C.consumeBoosts(prog);
    if (C.needsEvent(prog, stage)) {
      const ev = C.pickEvent(prog, null);
      const idx = Math.floor(Math.random() * ev.options.length);
      C.applyEvent(prog, ev.id, idx);
    }
  }
  return NST;
}

for (let i = 0; i < N; i++) { resetRng(i); runOne(); }

const pct = (a, q) => {
  if (!a.length) return 0;
  const s = a.slice().sort((x, y) => x - y);
  return Math.round(s[Math.min(s.length - 1, Math.floor(s.length * q))] * 100);
};

console.log('=== 逐关难度曲线（' + N + ' 局 · 种子 ' + SEED + ' · ' + (ADVISOR || '无军师')
  + ' · ' + MODE + ' · 每关 ' + TRIES + ' 次机会）===');
console.log('关  关卡名           到达   过   条件通过   耗重整   赢时血量   输时敌血   牌组');
for (let i = 0; i < NST; i++) {
  const cond = reached[i] ? Math.round(passed[i] / reached[i] * 100) : 0;
  const name = C.STAGES[i].name || C.STAGES[i].id;
  console.log(
    String(i + 1).padEnd(3)
    + name.padEnd(16)
    + String(reached[i]).padStart(5)
    + String(passed[i]).padStart(5)
    + (cond + '%').padStart(9)
    + (Math.round(retried[i] / Math.max(1, reached[i]) * 100) + '%').padStart(8)
    + ('p50 ' + pct(winHp[i], 0.5) + '%').padStart(11)
    + ('p50 ' + pct(loseHp[i], 0.5) + '%').padStart(11)
    + String(Math.round(deckAt[i].reduce((a, b) => a + b, 0) / Math.max(1, deckAt[i].length))).padStart(7)
  );
}
const full = passed[NST - 1];
console.log('\n整轮通关 ' + full + '/' + N + ' = ' + Math.round(full / N * 100) + '%');
// 断崖判据：条件通过率出现「低于前后各 8pp 以上」的孤立低谷
for (let i = 1; i < NST - 1; i++) {
  const c0 = reached[i - 1] ? passed[i - 1] / reached[i - 1] * 100 : 0;
  const c1 = reached[i] ? passed[i] / reached[i] * 100 : 0;
  const c2 = reached[i + 1] ? passed[i + 1] / reached[i + 1] * 100 : 0;
  if (c1 < c0 - 8 && c1 < c2 - 8) {
    console.log('⚠ 疑似断崖：第 ' + (i + 1) + ' 关 ' + Math.round(c1) + '%（前一关 '
      + Math.round(c0) + '%，后一关 ' + Math.round(c2) + '%）');
  }
}
