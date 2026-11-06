/* 新关键词与扩充卡池机制测试：冲锋 / 死战 / 连击 / 新效果 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
var D = Data, E = Engine;

var passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) passed++;
  else { failed++; console.error('  ✗ ' + msg); }
}
function section(t) { console.log('\n' + t); }

/* 开一局干净的对局（玩家侧给满军粮，方便直接出牌） */
function fresh() {
  var st = E.newGame('liubang', 'xiangyu', 'p1', 'bijiang', { p1: D.DECKS.han.slice() });
  st.players.p1.hand = [];
  st.players.p2.hand = [];
  E.beginGame(st);
  ['p1', 'p2'].forEach(function (pid) {
    st.players[pid].mana = 10;
    st.players[pid].maxMana = 10;
  });
  return st;
}

function give(st, pid, baseId) {
  var c = E.newInstance(baseId);
  st.players[pid].hand.push(c);
  return c;
}

function unitsOn(st, pid, rank) { return st.players[pid].board[rank]; }

/* ① 冲锋：登场即可攻击 */
section('① 冲锋');
(function () {
  var st = fresh();
  var charge = give(st, 'p1', 'c_huanchu');
  var normal = give(st, 'p1', 'n_bing2');
  assert(E.playCard(st, 'p1', charge.uid).ok, '桓楚应能打出');
  assert(unitsOn(st, 'p1', 'front')[0].canAttack === true, '冲锋单位登场应可攻击');
  E.playCard(st, 'p1', normal.uid);
  assert(unitsOn(st, 'p1', 'front')[1].canAttack === false, '普通单位登场当回合不能攻击');
  /* 真的能打出去 */
  var foe = st.players.p2;
  var res = E.attack(st, 'p1', charge.uid, { kind: 'hero' });
  assert(res.ok, '冲锋单位应能立即攻击主将，实际：' + res.reason);
  assert(foe.hp === foe.maxHp - 2, '主将应受 2 点伤害，实际：' + (foe.maxHp - foe.hp));
  console.log('  冲锋单位登场当回合攻击成功，普通单位仍受召唤疲劳限制 ✅');
})();

/* ② 死战：阵亡时触发 */
section('② 死战');
(function () {
  var st = fresh();
  var dead = give(st, 'p1', 'n_bing3');           /* 3/1，死战：敌将 2 伤 */
  E.playCard(st, 'p1', dead.uid);
  var foeHp = st.players.p2.hp;
  var spell = give(st, 'p2', 's_pozhen');          /* 敌方前锋全体 2 伤 */
  E.playCard(st, 'p2', spell.uid);
  assert(unitsOn(st, 'p1', 'front').length === 0, '死士应该被 2 点伤害打死');
  assert(st.players.p2.hp === foeHp - 2, '死战应对敌方主将造成 2 点伤害，实际：' + (foeHp - st.players.p2.hp));
  console.log('  死士阵亡触发 2 点直伤 ✅');
})();

/* ③ 死战：友军全体 buff */
section('③ 死战 · 群体增益');
(function () {
  var st = fresh();
  var guard = give(st, 'p1', 'n_shi3');            /* 2/5 守御，死战：友军 +1 攻 */
  var ally = give(st, 'p1', 'n_shi1');             /* 1/4 守御，只做旁观者 */
  E.playCard(st, 'p1', guard.uid);
  E.playCard(st, 'p1', ally.uid);
  var atk0 = unitsOn(st, 'p1', 'mid')[1].atk;
  assert(atk0 === 1, '旁观的持戟卫应为 1 攻，实际：' + atk0);
  /* 敌方远程炮逐个点掉死士卫（3 伤 ×2 = 6 > 5） */
  var cannon = E.newInstance('n_pao2');
  st.players.p2.board.back.push(cannon);
  function shoot() {
    cannon.canAttack = true;
    return E.attack(st, 'p2', cannon.uid, { kind: 'unit', uid: guard.uid });
  }
  var r1 = shoot();
  assert(r1.ok, '炮应能攻击中军守御，实际：' + r1.reason);
  assert(unitsOn(st, 'p1', 'mid').length === 2, '死士卫 5 血应扛住第一炮');
  assert(unitsOn(st, 'p1', 'mid')[1].atk === atk0, '死战未触发时不应加攻');
  shoot();
  assert(unitsOn(st, 'p1', 'mid').length === 1, '第二炮后死士卫应阵亡');
  assert(unitsOn(st, 'p1', 'mid')[0].atk === atk0 + 1, '死战应让友军 +1 攻，实际：' + unitsOn(st, 'p1', 'mid')[0].atk);
  console.log('  死士卫阵亡后友军 +1 攻 ✅');
})();

/* ④ 连击：本回合出过牌才触发 */
section('④ 连击');
(function () {
  var st = fresh();
  var solo = give(st, 'p1', 'c_xiangzhuang');
  E.playCard(st, 'p1', solo.uid);
  assert(unitsOn(st, 'p1', 'mid')[0].atk === 3, '首张出项庄不应触发连击，实际：' + unitsOn(st, 'p1', 'mid')[0].atk);

  var st2 = fresh();
  var first = give(st2, 'p1', 'n_bing2');
  var zhuang = give(st2, 'p1', 'c_xiangzhuang');
  E.playCard(st2, 'p1', first.uid);
  E.playCard(st2, 'p1', zhuang.uid);
  var u = unitsOn(st2, 'p1', 'mid')[0];
  assert(u.atk === 5, '第二张出项庄应 +2 攻（3+2），实际：' + u.atk);
  console.log('  连击条件判定正确（单独 3 攻 / 连击 5 攻）✅');

  /* 跨回合重置 */
  var st3 = fresh();
  var a = give(st3, 'p1', 'n_bing2');
  E.playCard(st3, 'p1', a.uid);
  E.endTurn(st3);          /* p1 -> p2 */
  E.endTurn(st3);          /* p2 -> p1，新回合开始，出牌计数归零 */
  var b = give(st3, 'p1', 'c_xiangzhuang');
  E.playCard(st3, 'p1', b.uid);
  assert(unitsOn(st3, 'p1', 'mid')[0].atk === 3, '新回合首张牌不应触发连击');
  console.log('  连击计数在新回合归零 ✅');
})();

/* ⑤ 增援：召唤两个新卒，列满则截断 */
section('⑤ 召唤');
(function () {
  var st = fresh();
  var spell = give(st, 'p1', 'n_zengyuan');
  E.playCard(st, 'p1', spell.uid);
  assert(unitsOn(st, 'p1', 'front').length === 2, '应召唤 2 个新卒，实际：' + unitsOn(st, 'p1', 'front').length);

  var st2 = fresh();
  var a = give(st2, 'p1', 'n_bing1'), b = give(st2, 'p1', 'n_bing1');
  E.playCard(st2, 'p1', a.uid);
  E.playCard(st2, 'p1', b.uid);
  var s2 = give(st2, 'p1', 'n_zengyuan');
  E.playCard(st2, 'p1', s2.uid);
  assert(unitsOn(st2, 'p1', 'front').length === 3, '前锋最多 3 员，实际：' + unitsOn(st2, 'p1', 'front').length);
  console.log('  增援召唤与列上限正确 ✅');
})();

/* ⑥ 直接伤害与治疗 */
section('⑥ 主将直伤 / 治疗');
(function () {
  var st = fresh();
  var c = give(st, 'p1', 'c_yuji');               /* 主将 +3，抽 1 */
  st.players.p1.hp = 20;
  var hand0 = st.players.p1.hand.length;
  E.playCard(st, 'p1', c.uid);
  assert(st.players.p1.hp === 23, '应恢复 3 点血，实际：' + st.players.p1.hp);
  assert(st.players.p1.hand.length === hand0, '应抽 1 张（打出 -1 抽到 +1）');
  /* 满血不溢出 */
  st.players.p1.hp = st.players.p1.maxHp;
  var c2 = give(st, 'p1', 'c_yuji');
  E.playCard(st, 'p1', c2.uid);
  assert(st.players.p1.hp === st.players.p1.maxHp, '治疗不应超过血量上限');
  console.log('  虞姬和歌：+3 血、抽 1、不溢出 ✅');
})();

/* ⑦ 狙杀攻击力最高者 / 全军减攻 */
section('⑦ 反间与楚歌');
(function () {
  var st = fresh();
  var big = E.newInstance('n_che1');  /* 5/5 */
  var small = E.newInstance('n_bing1'); /* 1/2 */
  st.players.p2.board.mid.push(big);
  st.players.p2.board.front.push(small);
  var cp = give(st, 'p1', 'h_chenping');
  var hand0 = st.players.p1.hand.length;
  E.playCard(st, 'p1', cp.uid);
  assert(big.hp === 2, '反间应打中攻击力最高的戎车（5-3=2），实际：' + big.hp);
  assert(small.hp === 2, '新卒不应被反间命中，实际：' + small.hp);
  assert(st.players.p1.hand.length === hand0, '反间应抽 1 张（打出 -1，抽到 +1）');

  var st2 = fresh();
  var u1 = E.newInstance('n_ma1');    /* 3/2 */
  var u2 = E.newInstance('n_bing1');  /* 1/2 */
  st2.players.p2.board.front.push(u1);
  st2.players.p2.board.mid.push(u2);
  var song = give(st2, 'p1', 's_simian');
  E.playCard(st2, 'p1', song.uid);
  assert(u1.atk === 1, '楚歌应 -2 攻（3→1），实际：' + u1.atk);
  assert(u2.atk === 0, '攻击力不应为负，实际：' + u2.atk);
  console.log('  反间狙击最高攻、楚歌全军 -2 攻且不为负 ✅');
})();

/* ⑧ 扩充卡池的 AI 可用性（每种新效果都能被 AI 打出） */
section('⑧ AI 会使用新牌');
(function () {
  var effects = ['n_zengyuan', 'c_yuji', 'h_chenping', 'h_luyi', 's_simian',
    'n_ma3', 'c_huanchu', 'c_xiangzhuang'];
  effects.forEach(function (id) {
    var st = fresh();
    /* 给 AI 场面与手牌，看它会不会主动打出这张牌 */
    var foe = E.newInstance('n_bing2');
    st.players.p2.board.front.push(foe);
    var mine = E.newInstance('n_bing2');
    st.players.p1.board.mid.push(mine);
    var card = give(st, 'p2', id);
    var played = false;
    for (var i = 0; i < 6; i++) {
      var act = AI.aiNextAction(st, 'p2');
      if (act.type === 'play' && act.uid === card.uid) { played = true; break; }
      if (act.type === 'end') break;
      AI.applyAction(st, 'p2', act);
    }
    assert(played, 'AI 从不出「' + D.CARDS[id].name + '」');
  });
  console.log('  8 张新机制牌 AI 都会主动使用 ✅');
})();

/* ⑨ 敌方意图预告：威胁标记（围杀口径）与主将斩杀线 */
section('⑨ 敌方意图预告');
(function () {
  function put(st, pid, rank, baseId) {
    var u = E.newInstance(baseId);
    st.players[pid].board[rank].push(u);
    return u;
  }
  function killed(st, u) { return !!E.threatPreview(st, 'p1').kill[u.uid]; }

  /* 1. 单杀：够得着且攻击够打死才标；够不着的同列兄弟不标 */
  var st = fresh();
  var front = put(st, 'p1', 'front', 'n_bing2');   /* 2/3 */
  var mid = put(st, 'p1', 'mid', 'n_bing2');       /* 2/3，被前锋挡住 */
  put(st, 'p2', 'front', 'n_che1');                /* 5/5 */
  var pv = E.threatPreview(st, 'p1');
  assert(killed(st, front), '5 攻敌车够得着 2/3 前锋，应标「险」');
  assert(!killed(st, mid), '前锋挡路，中军不应被标');
  assert(!pv.hero, '我方有兵，主将不应告警');

  /* 2. 围杀：单杀不够、总攻够也算（两支 2 攻围死 3 血） */
  var st2 = fresh();
  var victim = put(st2, 'p1', 'mid', 'n_bing2');   /* 2/3，前锋空所以中军顶到一线 */
  put(st2, 'p2', 'front', 'n_bing2');              /* 2/3 */
  put(st2, 'p2', 'front', 'n_bing2');              /* 2/3 */
  assert(killed(st2, victim), '2+2 总攻 ≥ 3 血，围杀应标「险」');

  /* 3. 守御吸火力：火力被守御强制接管，别的部队解围 */
  var st3 = fresh();
  var guard = put(st3, 'p1', 'front', 'n_shi1');   /* 1/4 守御 */
  var safe = put(st3, 'p1', 'mid', 'n_bing2');     /* 2/3 */
  put(st3, 'p2', 'front', 'n_che1');               /* 5/5 */
  assert(killed(st3, guard), '守御必须先挨打，5 攻 ≥ 4 血应标「险」');
  assert(!killed(st3, safe), '有守御时中军不应被标');

  /* 4. 远程：后军炮可打任意列 */
  var st4 = fresh();
  var soft = put(st4, 'p1', 'mid', 'n_bing1');     /* 1/2 */
  var tough = put(st4, 'p1', 'mid', 'n_bing2');    /* 2/3 */
  put(st4, 'p2', 'back', 'n_pao1');                /* 2/4 远程 */
  assert(killed(st4, soft), '炮 2 攻 ≥ 2 血应标「险」');
  assert(!killed(st4, tough), '炮 2 攻打不死 3 血，不应标');

  /* 5. 主将斩杀线：全场无兵才暴露，项羽技能直伤算进斩杀 */
  var st5 = fresh();
  st5.players.p1.board = { front: [], mid: [], back: [] };
  st5.players.p2.board = { front: [], mid: [], back: [] };
  put(st5, 'p2', 'front', 'n_che1');               /* 5 攻 */
  st5.players.p1.hp = 30; st5.players.p1.maxHp = 30;
  st5.players.p2.mana = 1;
  assert(!E.threatPreview(st5, 'p1').hero, '5 攻打不死 30 血主将，不应告警');
  st5.players.p1.hp = 5;
  assert(E.threatPreview(st5, 'p1').hero, '5 攻 ≥ 5 血，主将应告警');
  st5.players.p1.hp = 6;
  assert(E.threatPreview(st5, 'p1').hero, '5 攻 + 项羽技 1 伤 ≥ 6 血，应告警');
  st5.players.p2.skillUsed = true;
  assert(!E.threatPreview(st5, 'p1').hero, '技能用过就只剩 5 攻，6 血不应告警');

  /* 6. 有兵挡路时主将不暴露 */
  var st6 = fresh();
  put(st6, 'p1', 'front', 'n_bing1');              /* 1/2 挡路 */
  put(st6, 'p2', 'front', 'n_che1');               /* 5/5 */
  st6.players.p1.hp = 3;
  assert(!E.threatPreview(st6, 'p1').hero, '场上还有兵，主将不应告警');

  /* 7. 只读：预览不改状态 */
  var st7 = fresh();
  put(st7, 'p1', 'front', 'n_bing2');
  put(st7, 'p2', 'front', 'n_che1');
  var before = JSON.stringify(st7);
  E.threatPreview(st7, 'p1');
  assert(JSON.stringify(st7) === before, 'threatPreview 必须是纯只读');

  console.log('  威胁标记（围杀/守御/远程）与主将斩杀线 ✅');
})();

console.log('\n通过 ' + passed + ' 项，失败 ' + failed + ' 项');
if (failed > 0) process.exit(1);
