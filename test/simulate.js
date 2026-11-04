/* 引擎+AI 平衡性模拟（Node）：AI 打 AI，输出胜率统计 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');

function simulate(p1Hero, p2Hero, level, customDecks, maxSteps) {
  var first = Math.random() < 0.5 ? 'p1' : 'p2';
  var state = Engine.newGame(p1Hero, p2Hero, first, level, customDecks);
  state.levels.p1 = level; /* 双方都用 AI 驱动 */
  Engine.beginGame(state); /* 模拟中跳过换牌，直接开局 */
  var steps = 0;
  while (!state.over && steps < maxSteps) {
    steps++;
    var pid = state.current;
    var action = AI.aiNextAction(state, pid);
    var res = AI.applyAction(state, pid, action);
    if (!res.ok) {
      throw new Error('非法动作：pid=' + pid + ' action=' + JSON.stringify(action) + ' reason=' + res.reason);
    }
    ['p1', 'p2'].forEach(function (id) {
      var p = state.players[id];
      if (p.mana < 0) throw new Error('军粮为负');
      if (p.hand.length > Data.HAND_LIMIT) throw new Error('手牌超限');
      Engine.RANKS.forEach(function (r) {
        if (p.board[r].length > Data.COLUMN_LIMIT) throw new Error('列超员 ' + r);
        p.board[r].forEach(function (u) {
          if (u.hp <= 0) throw new Error('死人还在场上: ' + u.name);
        });
      });
    });
  }
  return { over: state.over, winner: state.winner, first: first, p1Hero: p1Hero, turns: state.turnNo };
}

var N = parseInt(process.argv[2] || '120', 10);
var stats = { games: 0, errors: 0, timeouts: 0, firstWins: 0, liubang: 0, xiangyu: 0,
  byLevel: {}, turnsSum: 0 };
['jianxi', 'bijiang', 'mingjiang'].forEach(function (l) {
  stats.byLevel[l] = { games: 0, liubang: 0, first: 0 };
});
var heroes = ['liubang', 'xiangyu'];
var levels = ['jianxi', 'bijiang', 'mingjiang'];

for (var i = 0; i < N; i++) {
  var h1 = heroes[i % 2], h2 = heroes[(i + 1) % 2], lv = levels[i % 3];
  var r = simulate(h1, h2, lv, null, 600);
  if (!r.over) { stats.timeouts++; console.log('未分胜负: ' + h1 + ' vs ' + h2 + ' (' + lv + ')'); continue; }
  stats.games++;
  stats.turnsSum += r.turns;
  var winnerHero = r.winner === 'p1' ? r.p1Hero : (r.p1Hero === 'liubang' ? 'xiangyu' : 'liubang');
  stats[winnerHero]++;
  if (r.winner === r.first) stats.firstWins++;
  var bl = stats.byLevel[lv];
  bl.games++;
  if (winnerHero === 'liubang') bl.liubang++;
  if (r.winner === r.first) bl.first++;
}

console.log('==== 《楚汉·问鼎》平衡性模拟（' + N + ' 局） ====');
console.log('正常终局: ' + stats.games + ' / 未分胜负: ' + stats.timeouts);
console.log('先手胜率: ' + (stats.firstWins / stats.games * 100).toFixed(1) + '%（理想 50-55%）');
console.log('刘邦胜率: ' + (stats.liubang / stats.games * 100).toFixed(1) + '%（理想 45-55%）');
console.log('项羽胜率: ' + (stats.xiangyu / stats.games * 100).toFixed(1) + '%');
console.log('平均局时长: ' + (stats.turnsSum / stats.games).toFixed(1) + ' 回合');
Object.keys(stats.byLevel).forEach(function (l) {
  var b = stats.byLevel[l];
  console.log('  ' + l + ': ' + b.games + ' 局, 刘邦 ' + (b.liubang / b.games * 100).toFixed(0) + '%, 先手 ' + (b.first / b.games * 100).toFixed(0) + '%');
});
if (stats.timeouts === 0 && stats.errors === 0) console.log('✅ 全部对局正常结束，引擎与 AI 逻辑通过');
else { console.log('⚠️ 存在异常对局'); process.exit(1); }
