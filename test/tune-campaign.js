/* 战役关卡难度调参实验：扫描候选参数，找出合适的胜率 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
globalThis.Campaign = require('../js/campaign.js');
var C = Campaign, E = Engine, D = Data;

var N = Number(process.argv[2]) || 80;

/* 跑一个临时关卡配置，返回玩家胜率 */
function trial(cfg, hero, n) {
  var win = 0, turns = 0, tot = n || N;
  for (var i = 0; i < tot; i++) {
    var st = E.newGame(hero, cfg.enemy.heroId,
      Math.random() < 0.5 ? 'p1' : 'p2', cfg.aiLevel,
      { p1: D.DECKS[D.HEROES[hero].faction].slice() },
      { rules: C.engineRules(cfg), p2Meta: cfg.enemy.meta });
    st.levels.p1 = cfg.aiLevel;
    E.beginGame(st);
    var g = 0;
    while (!st.over && g++ < 400) {
      var pid = st.current;
      AI.applyAction(st, pid, AI.aiNextAction(st, pid));
    }
    if (st.winner === 'p1') win++;
    turns += st.turnNo;
  }
  return { rate: Math.round(win / tot * 100), turns: Math.round(turns / tot) };
}

function base(stageId) {
  var s = C.stageById(stageId);
  return JSON.parse(JSON.stringify(s));
}

function show(label, cfg) {
  var a = trial(cfg, 'liubang'), b = trial(cfg, 'xiangyu');
  console.log('  ' + label.padEnd(34) + '刘邦 ' + String(a.rate).padStart(3) + '%  项羽 ' +
    String(b.rate).padStart(3) + '%  回合 ' + a.turns + '/' + b.turns);
}

console.log('\n【沛县起兵】目标：教学关，胜率 70-85%');
[20, 18, 16, 14].forEach(function (hp) {
  var c = base('peixian');
  c.enemy.meta.hp = hp;
  show('敌将 ' + hp + ' 血', c);
});

console.log('\n【鸿门宴】目标：存活挑战，胜率 50-65%');
[6, 8, 10, 12].forEach(function (t) {
  var c = base('hongmen');
  c.goalTurns = t;
  show('存活 ' + t + ' 回合（手牌上限 3）', c);
});
[8, 10].forEach(function (t) {
  var c = base('hongmen');
  c.goalTurns = t; c.aiLevel = 'mingjiang';
  show('存活 ' + t + ' 回合 + 名将 AI', c);
});

console.log('\n【彭城之战】目标：最难关，胜率 30-45%');
(function () {
  var c = base('pengcheng'); show('2 轻骑 + 玩家 +2 粮（当前）', c);
})();
(function () {
  var c = base('pengcheng'); c.rules.enemyOpeningUnits = [{ baseId: 'n_ma1', rank: 'front' }];
  show('1 轻骑 + 玩家 +2 粮', c);
})();
(function () {
  var c = base('pengcheng'); c.rules.enemyOpeningUnits = [{ baseId: 'n_ma1', rank: 'front' }];
  c.rules.playerStartMana = 3;
  show('1 轻骑 + 玩家 +3 粮', c);
})();
(function () {
  var c = base('pengcheng'); c.rules.enemyOpeningUnits = [
    { baseId: 'n_ma1', rank: 'front' }, { baseId: 'n_bing1', rank: 'front' }
  ];
  show('1 轻骑 + 1 新卒 + 玩家 +2 粮', c);
})();
(function () {
  var c = base('pengcheng'); c.aiLevel = 'bijiang';
  show('2 轻骑 + 玩家 +2 粮 + 裨将 AI', c);
})();
(function () {
  var c = base('pengcheng'); c.aiLevel = 'bijiang';
  c.rules.enemyOpeningUnits = [{ baseId: 'n_ma1', rank: 'front' }];
  show('1 轻骑 + 玩家 +2 粮 + 裨将 AI', c);
})();
console.log('');
