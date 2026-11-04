/* Build 路线验证：死战流 vs 基准牌组（AI vs AI，Node）
 *
 * 验收线（docs/build-lines.md 第八节）：
 *   协同成立 = 死战流比基准高 8~15pp
 *   < 8pp    → 协同不够（信号 D），回炉核心卡
 *   > 15pp   → 雪球失控（信号 A），先砍决死车/偏将
 *
 * 用法：node test/tune-builds.js [局数=300] [重复=3]
 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');

const D = Data, E = Engine;

/* 死战流：14 张死战（10 新 + 4 旧）+ 6 张通用（过牌/守御/AOE）。
 * 构牌原则：20 张里死战相关 ≥ 70%，让"亡语协同"成为主要赢法。 */
const DEATH_DECK = [
  /* 燃料：死了还留人 */
  'n_bing5', 'n_bing5', 'n_bing6', 'n_bing6', 'n_bing7',
  /* 雪球：死了加攻 */
  'n_shi4', 'n_shi4', 'n_shi5', 'n_shi5', 'n_jiang1', 'n_jiang1',
  /* 续航：死了抽牌 */
  'n_bing8', 'n_bing8', 'n_shi6',
  /* 现有死战 */
  'n_bing3', 'n_bing3', 'n_shi3', 'n_shi3', 'h_jixin',
  /* 过牌兜底 */
  's_xiaohe'
];

/* 基准流：从卡池按"费用-属性性价比"挑 20 张，无死战协同。
 * 这是"随便组一套好牌"的参照——若死战流打不过它，说明协同没做出来。 */
function baselineDeck() {
  const pool = Object.keys(D.CARDS).filter(function (id) {
    if (id === 's_xianji') return false;
    if (DEATH_DECK.indexOf(id) >= 0) return false;
    const c = D.CARDS[id];
    return c.type === 'piece' && !c.deathrattle;   /* 排除所有死战卡 */
  });
  /* 性价比 = (atk+hp)/cost，同名牌最多 2 张，凑 20 张 */
  const scored = pool.map(function (id) {
    const c = D.CARDS[id];
    return { id: id, score: (c.atk + c.hp) / Math.max(c.cost, 1) };
  }).sort(function (a, b) { return b.score - a.score; });
  const deck = [], used = {};
  for (let i = 0; i < scored.length && deck.length < 20; i++) {
    if ((used[scored[i].id] || 0) < 2) { deck.push(scored[i].id); used[scored[i].id] = (used[scored[i].id] || 0) + 1; }
  }
  return deck;
}

function play(p1Deck, p2Deck, p2Hero, level) {
  const first = Math.random() < 0.5 ? 'p1' : 'p2';
  const state = E.newGame('liubang', p2Hero, first, level, { p1: p1Deck.slice(), p2: p2Deck.slice() });
  state.levels.p1 = level; state.levels.p2 = level;
  E.beginGame(state);
  let steps = 0;
  while (!state.over && steps < 600) {
    steps++;
    const pid = state.current;
    const action = AI.aiNextAction(state, pid);
    const res = AI.applyAction(state, pid, action);
    if (!res.ok) throw new Error('非法动作 ' + JSON.stringify(action) + ' ' + res.reason);
  }
  return { over: state.over, winner: state.winner, first: first, turns: state.turnNo };
}

function runBatch(name, p1Deck, p2Deck, p2Hero, n) {
  let wins = 0, games = 0, turns = 0, timeouts = 0;
  for (let i = 0; i < n; i++) {
    const r = play(p1Deck, p2Deck, p2Hero, 'bijiang');
    if (!r.over) { timeouts++; continue; }
    games++;
    turns += r.turns;
    if (r.winner === 'p1') wins++;
  }
  const wr = games ? (wins / games * 100) : 0;
  console.log('  ' + name.padEnd(28) + ' 胜率 ' + wr.toFixed(1) + '%  (' + wins + '/' + games + ' 局, 超时 ' + timeouts + ', 均 ' + (games ? (turns / games).toFixed(1) : '-') + ' 回合)');
  return wr;
}

const N = parseInt(process.argv[2] || '300', 10);
const REPEAT = parseInt(process.argv[3] || '3', 10);
const base = baselineDeck();
const CHU = D.DECKS.chu.slice();
console.log('死战牌组:', DEATH_DECK.length, '张，死战卡', DEATH_DECK.filter(function (id) { return D.CARDS[id].deathrattle; }).length, '张');
console.log('对局设定: 玩家(刘邦·死战流) vs AI(项羽·预组楚)，AI 等级 bijiang');
console.log('');

/* 基准线：预组汉 vs 预组楚（无新卡） */
const results = [];
for (let k = 0; k < REPEAT; k++) {
  console.log('第 %d 轮：', k + 1);
  const wrBase = runBatch('基准：预组汉 vs 预组楚', D.DECKS.han, CHU, 'xiangyu', N);
  const wr1 = runBatch('死战流 vs 预组楚', DEATH_DECK, CHU, 'xiangyu', N);
  results.push({ base: wrBase, death: wr1 });
}
const meds = function (arr) {
  const s = arr.slice().sort(function (a, b) { return a - b; });
  return s[Math.floor(s.length / 2)];
};
const mBase = meds(results.map(function (r) { return r.base; }));
const mDeath = meds(results.map(function (r) { return r.death; }));
console.log('');
console.log('=== 基准 ' + mBase.toFixed(1) + '%  死战 ' + mDeath.toFixed(1) + '%  差值 +' + (mDeath - mBase).toFixed(1) + 'pp ===');
if (mDeath - mBase >= 8 && mDeath - mBase <= 15) {
  console.log('✅ 协同成立（8~15pp 预期区间）');
} else if (mDeath - mBase > 15) {
  console.log('⚠️ 雪球失控（>15pp），先砍决死车/偏将');
} else {
  console.log('⚠️ 协同不足（<8pp），回炉核心卡');
}
