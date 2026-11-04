/* 预组牌组对照实验：找出卡池扩充后失衡的来源 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
var D = Data, E = Engine, AIx = globalThis.AI;

var N = Number(process.argv[2]) || 100;

function rate(p1Deck, p2Deck, hero1, hero2, level) {
  var win = 0, turns = 0;
  for (var i = 0; i < N; i++) {
    var first = Math.random() < 0.5 ? 'p1' : 'p2';
    var st = E.newGame(hero1 || 'liubang', hero2 || 'xiangyu', first, level || 'bijiang',
      { p1: p1Deck, p2: p2Deck });
    st.levels.p1 = level || 'bijiang';
    E.beginGame(st);
    var g = 0;
    while (!st.over && g++ < 600) AIx.applyAction(st, st.current, AIx.aiNextAction(st, st.current));
    if (st.winner === 'p1') win++;
    turns += st.turnNo;
  }
  return { rate: Math.round(win / N * 100), turns: Math.round(turns / N) };
}

function show(label, han, chu) {
  var a = rate(han, chu);
  var b = rate(han, chu, 'liubang', 'xiangyu', 'mingjiang');
  console.log('  ' + label.padEnd(30) + ' 刘邦 ' + String(a.rate).padStart(3) + '%（' + a.turns +
    ' 回合）  名将 AI ' + String(b.rate).padStart(3) + '%');
}

/* 牌组构造小工具：把若干张替换进基准牌组 */
function deck(list) { return list.slice(); }
function replace(deckArr, outId, inId) {
  var i = deckArr.indexOf(outId);
  if (i < 0) throw new Error('牌组里没有 ' + outId);
  deckArr[i] = inId;
  return deckArr;
}

var CORE = ['n_bing1', 'n_bing1', 'n_bing2', 'n_bing2', 'n_shi1', 'n_shi1',
  'n_pao1', 'n_pao1', 'n_ma1', 'n_ma1'];
var CORE_CHU = CORE.slice();

console.log('\n【当前预组】');
show('汉预组 vs 楚预组（新）', D.DECKS.han, D.DECKS.chu);

console.log('\n【汉预组变体】');
var v1 = deck(D.DECKS.han);
replace(v1, 'h_jixin', 'h_zhoub');
show('纪信 → 周勃', v1, D.DECKS.chu);

var v2 = deck(D.DECKS.han);
replace(v2, 'n_bing4', 'n_che1');
show('戍卒 → 戎车', v2, D.DECKS.chu);

var v3 = deck(D.DECKS.han);
replace(v3, 'h_jixin', 'h_zhoub');
replace(v3, 'n_bing4', 'n_che1');
show('纪信 → 周勃 + 戍卒 → 戎车', v3, D.DECKS.chu);

var v4 = deck(D.DECKS.han);
replace(v4, 'h_jixin', 'h_zhoub');
replace(v4, 'n_hanxin', 'h_zhoub');
show('纪信 + 韩信 → 双周勃', v4, D.DECKS.chu);

var v5 = deck(D.DECKS.han);
replace(v5, 'n_bing4', 'h_zhoub');
replace(v5, 'h_jixin', 'h_zhoub');
show('戍卒 + 纪信 → 双周勃', v5, D.DECKS.chu);

console.log('\n【楚预组变体】');
var c1 = deck(D.DECKS.chu);
replace(c1, 'c_huanchu', 'n_shi1');
show('桓楚 → 持戟卫（汉不变）', D.DECKS.han, c1);

var c2 = deck(D.DECKS.chu);
replace(c2, 'c_zhuiqi', 'n_xiang1');
show('追风 → 护军象（汉不变）', D.DECKS.han, c2);

var c3 = deck(D.DECKS.chu);
replace(c3, 'n_bing3', 'n_bing2');
show('死士 → 锐士（汉不变）', D.DECKS.han, c3);

console.log('');
