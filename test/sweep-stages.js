/* 4-8 关参数扫描（第二轮）：预置部队是主要难度来源，重点测"少预置 + 多补偿" */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
globalThis.Campaign = require('../js/campaign.js');
var D = Data, E = Engine, C = Campaign, AIx = globalThis.AI;

var N = Number(process.argv[2]) || 50;

function deckAt(i) {
  var d = D.DECKS.han.slice();
  for (var k = 0; k < i; k++) {
    var pool = C.STAGES[k].rewards.filter(function (id) {
      var f = D.factionOf(id);
      return f === 'neutral' || f === 'han';
    });
    d.push(pool[0]);
  }
  return d;
}

function trial(stageId, patch, deck, n) {
  var s = JSON.parse(JSON.stringify(C.stageById(stageId)));
  if (patch.hp) s.enemy.meta.hp = patch.hp;
  if (patch.aiLevel) s.aiLevel = patch.aiLevel;
  if (patch.deck) s.rules.enemyDeck = patch.deck;
  if (patch.rules) for (var k in patch.rules) s.rules[k] = patch.rules[k];
  var win = 0, turns = 0;
  for (var i = 0; i < n; i++) {
    var st = E.newGame('liubang', s.enemy.heroId,
      Math.random() < 0.5 ? 'p1' : 'p2', s.aiLevel,
      { p1: deck }, { rules: C.engineRules(s), p2Meta: s.enemy.meta });
    st.levels.p1 = s.aiLevel;
    E.beginGame(st);
    var g = 0;
    while (!st.over && g++ < 600) AIx.applyAction(st, st.current, AIx.aiNextAction(st, st.current));
    if (st.winner === 'p1') win++;
    turns += st.turnNo;
  }
  return { rate: Math.round(win / n * 100), turns: Math.round(turns / n) };
}

function show(stageId, idx, label, patch) {
  var r = trial(stageId, patch, deckAt(idx), N);
  console.log('  ' + label.padEnd(50) + String(r.rate).padStart(3) + '%  （' + r.turns + ' 回合）');
}

/* 荥阳：敌人牌组减 2 张守御，换成进攻牌 */
var XY_LIGHT = [
  'n_shi1', 'n_shi1', 'n_shi2', 'n_bing2', 'n_bing2', 'n_bing2',
  'n_pao1', 'n_pao1', 'n_pao2', 'n_che1', 'n_che1', 'n_ma1',
  'n_ma1', 'c_zhongli', 'n_bing3', 's_fanzeng', 's_fanzeng',
  's_bawang', 'n_ma2', 'n_ma2'
];

console.log('\n【荥阳对峙】目标 55-70%');
show('xingyang', 3, '当前：30 血 / 无预置 / 名将', {});
show('xingyang', 3, '22 血 / 名将 / 玩家 +2 粮', { hp: 22, rules: { playerStartMana: 2 } });
show('xingyang', 3, '22 血 / 裨将 / 玩家 +2 粮', { hp: 22, aiLevel: 'bijiang', rules: { playerStartMana: 2 } });
show('xingyang', 3, '20 血 / 裨将 / 玩家 +2 粮', { hp: 20, aiLevel: 'bijiang', rules: { playerStartMana: 2 } });
show('xingyang', 3, '22 血 / 名将 / 玩家 +2 粮 / 敌军减守御', XY_LIGHT ? { hp: 22, deck: XY_LIGHT, rules: { playerStartMana: 2 } } : {});

console.log('\n【井陉背水】目标 50-65%');
show('jingxing', 4, '当前：24 血 / 玩家 14 / 2 队 / 裨将', {});
show('jingxing', 4, '20 血 / 玩家 16 / 无预置 / 裨将', { hp: 20, rules: { playerHp: 16, enemyOpeningUnits: [] } });
show('jingxing', 4, '22 血 / 玩家 16 / 1 队新卒 / 裨将', { hp: 22, rules: { playerHp: 16, enemyOpeningUnits: [{ baseId: 'n_bing1', rank: 'front' }] } });
show('jingxing', 4, '20 血 / 玩家 16 / 1 队新卒 / 裨将', { hp: 20, rules: { playerHp: 16, enemyOpeningUnits: [{ baseId: 'n_bing1', rank: 'front' }] } });
show('jingxing', 4, '20 血 / 玩家 18 / 1 队新卒 / 裨将', { hp: 20, rules: { playerHp: 18, enemyOpeningUnits: [{ baseId: 'n_bing1', rank: 'front' }] } });

console.log('\n【潍水之战】目标 45-60%');
show('weishui', 5, '当前：26 血 / 3 队 / 名将', {});
show('weishui', 5, '20 血 / 无预置 / 名将 / 玩家 +3 粮', { hp: 20, rules: { enemyOpeningUnits: [], playerStartMana: 3 } });
show('weishui', 5, '22 血 / 无预置 / 裨将 / 玩家 +3 粮', { hp: 22, aiLevel: 'bijiang', rules: { enemyOpeningUnits: [], playerStartMana: 3 } });
show('weishui', 5, '22 血 / 1 队戎车 / 名将 / 玩家 +3 粮', { hp: 22, rules: { playerStartMana: 3, enemyOpeningUnits: [{ baseId: 'n_che1', rank: 'mid' }] } });
show('weishui', 5, '20 血 / 1 队戎车 / 名将 / 玩家 +4 粮', { hp: 20, rules: { playerStartMana: 4, enemyOpeningUnits: [{ baseId: 'n_che1', rank: 'mid' }] } });

console.log('\n【固陵之战】目标 40-55%');
show('guling', 6, '当前：28 血 / 16 血 / 1 队骠骑 / 名将', {});
show('guling', 6, '24 血 / 20 血 / 无预置 / 名将 / 敌 +2 粮', { hp: 24, rules: { playerHp: 20, enemyOpeningUnits: [] } });
show('guling', 6, '26 血 / 20 血 / 无预置 / 名将 / 敌 +2 粮', { hp: 26, rules: { playerHp: 20, enemyOpeningUnits: [] } });
show('guling', 6, '26 血 / 18 血 / 无预置 / 名将', { hp: 26, rules: { playerHp: 18, enemyOpeningUnits: [] } });
show('guling', 6, '24 血 / 18 血 / 1 队新卒 / 名将 / 玩家 +2 粮', { hp: 24, rules: { playerHp: 18, playerStartMana: 2, enemyOpeningUnits: [{ baseId: 'n_bing1', rank: 'front' }] } });

console.log('\n【垓下决战】目标 30-45%');
show('gaixia', 7, '当前：30 血 / 3 队 / 名将', {});
show('gaixia', 7, '26 血 / 1 队新卒 / 名将 / 玩家 +3 粮', { hp: 26, rules: { playerStartMana: 3, enemyOpeningUnits: [{ baseId: 'n_bing1', rank: 'front' }] } });
show('gaixia', 7, '30 血 / 1 队骠骑 / 名将 / 玩家 +3 粮', { hp: 30, rules: { playerStartMana: 3, enemyOpeningUnits: [{ baseId: 'n_ma2', rank: 'mid' }] } });
show('gaixia', 7, '26 血 / 2 队新卒 / 名将 / 玩家 +4 粮', { hp: 26, rules: { playerStartMana: 4, enemyOpeningUnits: [{ baseId: 'n_bing1', rank: 'front' }, { baseId: 'n_bing1', rank: 'front' }] } });
show('gaixia', 7, '24 血 / 无预置 / 名将 / 玩家 +2 粮', { hp: 24, rules: { playerStartMana: 2, enemyOpeningUnits: [] } });
console.log('');
