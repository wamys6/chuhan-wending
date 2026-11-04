/* 单关「规则杠杆」对比：改一关的某个 rules 字段，看通关率抖动多少
   用法：node test/tune-stages.js [每格局数]
   用途：每次动关卡难度前先跑一遍——预置部队、敌方军粮、玩家军粮、敌将血量
        这四个杠杆的量级差很多，凭直觉调很容易一改就崩。 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
globalThis.Campaign = require('../js/campaign.js');
var D = Data, E = Engine, C = Campaign, AIx = globalThis.AI;

var N = Number(process.argv[2]) || 300;

/* 玩家打到第 i 关时的牌组 = 汉预组 + 前 i 关各拿一张奖励（取池子首张） */
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

function run(stage, rules, meta, deck, n) {
  var win = 0, turns = 0;
  for (var i = 0; i < n; i++) {
    var st = E.newGame('liubang', stage.enemy.heroId,
      Math.random() < 0.5 ? 'p1' : 'p2', stage.aiLevel,
      { p1: deck },
      { rules: Object.assign({}, C.engineRules(stage), rules), p2Meta: meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    var g = 0;
    while (!st.over && g++ < 600) AIx.applyAction(st, st.current, AIx.aiNextAction(st, st.current));
    if (st.winner === 'p1') win++;
    turns += st.turnNo;
  }
  return { rate: Math.round(win / n * 100), turns: Math.round(turns / n) };
}

function line(tag, stage, rules, meta) {
  var idx = C.stageIndex(stage.id);
  var r = run(stage, rules, meta || stage.enemy.meta, deckAt(idx), N);
  console.log('  ' + tag.padEnd(40) + String(r.rate).padStart(3) + '%  (' + r.turns + ' 回合)');
}

var op = function (id, rank) { return [{ baseId: id, rank: rank || 'front' }]; };

console.log('\n===== 第 3 关 彭城（' + N + ' 局/格）=====');
var s3 = C.STAGES[2];
line('现行：预置戍卒 1/2 + 玩家+2', s3, {});
line('旧版：预置轻骑 3/2（比现在难一倍）', s3, { enemyOpeningUnits: op('n_ma1') });
line('无预置', s3, { enemyOpeningUnits: [] });
line('去预置 + 敌方首回合 +1 粮', s3, { enemyOpeningUnits: [], enemyStartMana: 1 });
line('旧版 + 敌将 18 血（血量不是杠杆）', s3, { enemyOpeningUnits: op('n_ma1') },
  Object.assign({}, s3.enemy.meta, { hp: 18 }));

console.log('\n===== 第 7 关 固陵（' + N + ' 局/格）=====');
var s7 = C.STAGES[6];
line('现行：无预置 + 敌我各 +2 粮', s7, {});
line('加回预置戍卒（曾用过，收尾过陡）', s7, { enemyOpeningUnits: op('n_bing1') });

console.log('\n===== 第 5 关 井陉（' + N + ' 局/格）=====');
var s5 = C.STAGES[4];
line('现行：预置 1 队戍卒', s5, {});
line('再加 1 队（预置是最大杠杆，别叠）', s5,
  { enemyOpeningUnits: [{ baseId: 'n_bing1', rank: 'front' }, { baseId: 'n_bing1', rank: 'mid' }] });
console.log('');
