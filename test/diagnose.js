/* 诊断：英雄技能强度 vs 卡组强度（交叉互换预组） */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');

function run(label, p1Hero, p1Deck, p2Hero, p2Deck, n) {
  var p1w = 0, turns = 0;
  for (var i = 0; i < n; i++) {
    var first = Math.random() < 0.5 ? 'p1' : 'p2';
    var st = Engine.newGame(p1Hero, p2Hero, first, 'bijiang', { p1: p1Deck, p2: p2Deck });
    st.levels.p1 = 'bijiang';
    Engine.beginGame(st); /* 模拟中跳过换牌，直接开局 */
    var steps = 0;
    while (!st.over && steps < 600) {
      steps++;
      var a = AI.aiNextAction(st, st.current);
      AI.applyAction(st, st.current, a);
    }
    if (st.over && st.winner === 'p1') p1w++;
    turns += st.turnNo;
  }
  console.log(label + ': 先手方(' + Data.HEROES[p1Hero].name + '+' + p1DeckName(p1Deck) + ') 胜率 ' +
    (p1w / n * 100).toFixed(0) + '%，平均 ' + (turns / n).toFixed(1) + ' 回合');
}
function p1DeckName(d) {
  if (!d) return '预组';
  return d.indexOf('s_xiaohe') >= 0 ? '汉预组' : '楚预组';
}
var N = 60;
var han = Data.DECKS.han, chu = Data.DECKS.chu;
run('A 基准  刘邦+汉预组 vs 项羽+楚预组 ', 'liubang', han, 'xiangyu', chu, N);
run('B 交叉  刘邦+楚预组 vs 项羽+汉预组 ', 'liubang', chu, 'xiangyu', han, N);
run('C 同门  刘邦+汉预组 vs 刘邦AI+楚预组', 'liubang', han, 'liubang', chu, N);
run('D 同门  项羽+汉预组 vs 项羽AI+楚预组', 'xiangyu', han, 'xiangyu', chu, N);
