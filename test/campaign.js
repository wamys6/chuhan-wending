/* 战役模式测试：关卡规则是否真正生效 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');
globalThis.Campaign = require('../js/campaign.js');

var C = globalThis.Campaign, E = globalThis.Engine, D = globalThis.Data;

var passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) { passed++; }
  else { failed++; console.error('  ✗ ' + msg); }
}
function section(t) { console.log('\n' + t); }

/* 用关卡定义起一局（跳过换牌） */
function openStage(stageId, playerHero) {
  var st = C.stageById(stageId);
  var st0 = E.newGame(
    playerHero || 'liubang',
    st.enemy.heroId,
    'p1',
    st.aiLevel,
    { p1: D.DECKS[D.HEROES[playerHero || 'liubang'].faction].slice() },
    { rules: C.engineRules(st), p2Meta: st.enemy.meta }
  );
  E.beginGame(st0);
  return { stage: st, state: st0 };
}

/* ① 关卡数据完整性 */
section('① 关卡数据完整性');
C.STAGES.forEach(function (s) {
  assert(!!s.id && !!s.name, s.id + ' 缺少 id/name');
  assert(!!D.HEROES[s.enemy.heroId], s.id + ' 敌方英雄不存在');
  assert(s.rewards.length >= 3, s.id + ' 奖励池不足 3 张');
  s.rewards.forEach(function (id) {
    assert(!!D.CARDS[id], s.id + ' 奖励牌不存在：' + id);
  });
  assert(s.goal === 'defeat' || s.goal === 'survive', s.id + ' goal 非法');
  if (s.goal === 'survive') assert(s.goalTurns > 0, s.id + ' survive 缺 goalTurns');
});
console.log('  关卡数：' + C.STAGES.length);
assert(C.STAGES.length === 8, '战役应为 8 关，实际：' + C.STAGES.length);

/* ①b 卡池规模 */
section('①b 卡池规模与数据完整性');
(function () {
  var pool = Object.keys(D.CARDS).filter(function (id) { return id !== 's_xianji'; });
  assert(pool.length === 77, '可构筑卡池应为 77 张（78 减去先机虎符），实际：' + pool.length);
  pool.forEach(function (id) {
    var c = D.CARDS[id];
    assert(c.id === id, id + ' 的 id 字段不一致');
    assert(c.cost >= 0 && c.cost <= 10, id + ' 费用异常：' + c.cost);
    if (c.type === 'piece') {
      assert(!!c.col, id + ' 兵种牌缺少站位列');
      assert(typeof c.atk === 'number' && typeof c.hp === 'number', id + ' 缺攻防');
    } else {
      assert(!!c.effect, id + ' 计谋牌缺少效果');
    }
    assert(!!c.desc && c.desc.length <= 34, id + ' 描述过长或缺失（' + (c.desc || '').length + ' 字）');
  });
  var byFac = { neutral: 0, han: 0, chu: 0 };
  pool.forEach(function (id) { byFac[D.factionOf(id)]++; });
  console.log('  卡池 ' + pool.length + ' 张：中立 ' + byFac.neutral + ' / 汉 ' + byFac.han + ' / 楚 ' + byFac.chu);
})();

/* ② 自定义敌将 meta 生效（沛县：秦军 20 血） */
section('② 敌方主将身份覆盖');
(function () {
  var r = openStage('peixian');
  var foe = r.state.players.p2;
  assert(foe.name === '秦·泗水郡监', '敌将名字未覆盖，实际：' + foe.name);
  assert(foe.hp === r.stage.enemy.meta.hp, '敌将血量应为关卡定义值，实际：' + foe.hp);
  assert(foe.heroId === 'xiangyu', '应复用项羽技能');
  console.log('  沛县敌将：' + foe.name + ' ' + foe.hp + ' 血，技能「' + foe.skill.name + '」');
  assert(r.stage.enemy.meta.hp < 26, '教学关敌将血量应低于标准英雄');
})();

/* ③ 鸿门宴：手牌上限 3，抽牌超过上限会被烧 */
section('③ 鸿门宴 · 手牌上限 3');
(function () {
  var r = openStage('hongmen');
  var st = r.state, me = st.players.p1;
  assert(st.rules.handLimit === 3, '规则未传给引擎');
  /* 把军粮清零，避免 AI 出牌消耗手牌；直接连抽 10 张 */
  me.hand = [];
  for (var i = 0; i < 10; i++) E.drawCard(st, 'p1');
  assert(me.hand.length === 3, '手牌应被限制在 3 张，实际：' + me.hand.length);
  console.log('  连抽 10 张后手牌：' + me.hand.length + ' 张 ✅');
})();

/* ④ 鸿门宴：存活满回合数即获胜
      双方都直接结束回合（不交战），专门验证「玩家回合计数 → 判胜」这条链路 */
section('④ 鸿门宴 · 存活 ' + C.stageById('hongmen').goalTurns + ' 回合获胜');
(function () {
  var r = openStage('hongmen');
  var st = r.state;
  var startHp = st.players.p1.hp;
  var guard = 0;
  while (!st.over && guard < 80) {
    guard++;
    st.players.p1.hp = startHp; /* 本测试只关心回合计数，不让玩家被疲劳之外的伤害带走 */
    E.endTurn(st);
  }
  assert(st.over, '对局未结束');
  assert(st.winner === 'p1', '存活目标应判玩家获胜，实际胜者：' + st.winner);
  assert(st.players.p1.turnsTaken === r.stage.goalTurns,
    '玩家回合数应为 ' + r.stage.goalTurns + '，实际：' + st.players.p1.turnsTaken);
  console.log('  玩家打完第 ' + r.stage.goalTurns + ' 回合判胜 ✅（起始血量 ' + startHp + '）');
})();

/* ⑤ 鸿门宴：如果活不到 6 回合就死了，不能判胜 */
section('⑤ 鸿门宴 · 提前阵亡不判胜');
(function () {
  var r = openStage('hongmen');
  var st = r.state;
  st.players.p1.hp = 1;
  /* 敌方回合直接打主将：清空玩家场上部队，让 AI 直击 */
  E.endTurn(st); /* p1 -> p2 */
  var guard = 0;
  while (!st.over && guard < 60) {
    guard++;
    var a = globalThis.AI.aiNextAction(st, 'p2');
    globalThis.AI.applyAction(st, 'p2', a);
    if (st.over) break;
    if (a.type === 'end') E.endTurn(st);
    if (st.current === 'p1') { E.endTurn(st); }
  }
  assert(st.over, '对局未结束');
  assert(st.winner === 'p2', '玩家阵亡应判敌方胜，实际：' + st.winner);
  console.log('  玩家提前阵亡判负 ✅');
})();

/* ⑥ 彭城：敌方开局预置部队 */
section('⑥ 彭城 · 敌方开局预置部队');
(function () {
  var r = openStage('pengcheng');
  var foe = r.state.players.p2;
  var expect = r.stage.rules.enemyOpeningUnits.length;
  assert(foe.board.front.length === expect, '敌方前锋应有 ' + expect + ' 个预置单位，实际：' + foe.board.front.length);
  /* 预置单位从「马·轻骑」改成「兵·戍卒」：轻骑压场让第 3 关胜率掉到 43%，
     成为新玩家第一道断崖（详见 docs/chuhan-card-game-design.md 第 3 关）。
     这里只钉住「有没有预置」和「是哪张」——数值平衡另有 tune-8 扫描负责。 */
  assert(foe.board.front[0].baseId === 'n_bing1', '预置单位应是兵·戍卒');
  assert(foe.board.front[0].canAttack === false, '预置单位首回合不能攻击');
  console.log('  敌方前锋：' + foe.board.front.map(function (u) { return u.name; }).join('、'));
})();

/* ⑦ 彭城：玩家首回合 +2 军粮 */
section('⑦ 彭城 · 玩家首回合额外军粮');
(function () {
  var r = openStage('pengcheng');
  var st = r.state;
  /* beginGame 已开始第一回合（若先手是 p1）。统一手动跑一次 p1 回合 */
  var mk = st.players.p1.maxMana;
  assert(st.players.p1.turnsTaken >= 1, '玩家应已进入第 1 回合');
  if (st.current === 'p1' || st.players.p1.turnsTaken === 1) {
    var expect = mk + 2;
    assert(st.players.p1.mana === expect, '首回合金粮应为 ' + expect + '，实际：' + st.players.p1.mana);
    console.log('  首回合金粮：' + st.players.p1.mana + '（上限 ' + mk + ' + 额外 2）✅');
  }
})();

/* ⑧ 标准模式不受关卡规则影响 */
section('⑧ 标准模式无副作用');
(function () {
  var st = E.newGame('liubang', 'xiangyu', 'p1', 'bijiang', null, {});
  E.beginGame(st);
  var me = st.players.p1;
  for (var i = 0; i < 20; i++) E.drawCard(st, 'p1');
  assert(me.hand.length === D.HAND_LIMIT, '标准模式手牌上限应为 ' + D.HAND_LIMIT + '，实际：' + me.hand.length);
  assert(Object.keys(st.rules).length === 0, '标准模式 rules 应为空');
  console.log('  标准模式手牌上限 ' + me.hand.length + ' ✅');
})();

/* ⑨ 奖励池抽取：只出玩家阵营可用的牌 */
section('⑨ 奖励池抽取');
(function () {
  C.STAGES.forEach(function (s) {
    for (var i = 0; i < 30; i++) {
      var rs = C.rollRewards(s, 'han', 3);
      assert(rs.length === 3, s.id + ' 应抽 3 张，实际：' + rs.length);
      var uniq = rs.filter(function (x, k) { return rs.indexOf(x) === k; });
      assert(uniq.length === 3, s.id + ' 奖励不应重复');
      rs.forEach(function (id) {
        var f = D.factionOf(id);
        assert(f === 'neutral' || f === 'han', s.id + ' 给刘邦抽到了楚牌：' + id);
      });
    }
  });
  console.log('  汉营玩家三选一均为可用牌 ✅');
})();

/* ⑩ 进度存档逻辑（8 关解锁链） */
section('⑩ 进度存档与解锁');
(function () {
  var p = C.emptyProgress('liubang');
  p.deck = D.DECKS.han.slice();
  assert(C.statusOf(p, 'peixian') === 'open', '首关应可挑战');
  assert(C.statusOf(p, 'hongmen') === 'locked', '第二章应锁定');
  C.STAGES.forEach(function (s, i) {
    assert(C.statusOf(p, s.id) === 'open', s.id + ' 应已解锁');
    if (i + 1 < C.STAGES.length) {
      assert(C.statusOf(p, C.STAGES[i + 1].id) === 'locked', C.STAGES[i + 1].id + ' 不应提前解锁');
    }
    C.clearStage(p, s.id, 'n_bing2');
    assert(C.statusOf(p, s.id) === 'cleared', s.id + ' 应标记已通关');
    assert(p.deck.length === 20 + i + 1, s.id + ' 后牌组应为 ' + (21 + i) + ' 张，实际：' + p.deck.length);
  });
  assert(C.isFinished(p), '全 8 关通关后应标记完成');
  console.log('  解锁链与牌组累积正常（20 → 28）✅');
})();

/* ⑪ 战役牌组可以被引擎使用（21 张不为 20 也能开战） */
section('⑪ 战役牌组（非 20 张）可用');
(function () {
  var deck = D.DECKS.han.slice();
  deck.push('n_che2');
  var st = E.newGame('liubang', 'xiangyu', 'p1', 'bijiang', { p1: deck });
  E.beginGame(st);
  var total = st.players.p1.deck.length + st.players.p1.hand.length;
  assert(total === 21, '牌库+手牌应为 21，实际：' + total);
  console.log('  21 张牌组开局正常 ✅');
})();

/* ⑫ 每关的专属敌军牌组 */
section('⑫ 关卡专属敌军牌组');
(function () {
  C.STAGES.forEach(function (s) {
    var ids = s.rules.enemyDeck;
    if (!ids) return;
    assert(ids.length === 20, s.id + ' 敌军牌组应为 20 张，实际：' + ids.length);
    ids.forEach(function (id) {
      assert(!!D.CARDS[id], s.id + ' 敌军牌组含不存在的牌：' + id);
    });
    var r = openStage(s.id);
    var foe = r.state.players.p2;
    /* 后手会多一张「先机」虎符，不计入牌组 */
    var xianji = foe.hand.filter(function (c) { return c.baseId === 's_xianji'; }).length;
    var total = foe.deck.length + foe.hand.length - xianji;
    assert(total === 20, s.id + ' 敌军实际牌数应为 20，实际：' + total);
  });
  var n = C.STAGES.filter(function (s) { return s.rules.enemyDeck; }).length;
  console.log('  ' + n + ' 关使用专属敌军牌组 ✅');
})();

/* ⑬ 敌方首回合额外军粮 */
section('⑬ 敌方首回合额外军粮');
(function () {
  var st = E.newGame('liubang', 'xiangyu', 'p2', 'mingjiang', null,
    { rules: { enemyStartMana: 2 } });
  E.beginGame(st);
  var foe = st.players.p2;
  assert(foe.turnsTaken === 1, '敌方应已进入第 1 回合');
  assert(foe.mana === foe.maxMana + 2, '敌方首回合金粮应 +2，实际：' + foe.mana + '/' + foe.maxMana);
  console.log('  敌方首回合金粮 ' + foe.mana + '/' + foe.maxMana + ' ✅');
})();

/* ⑭ 初阵档位（P3 难度宽容度） */
section('⑭ 初阵档位');
(function () {
  var st0 = C.STAGES[0];
  /* 默认常规：无加成，敌首回合 = 全局 1 */
  var r0 = C.engineRules(st0, C.emptyProgress('liubang'));
  assert(!r0.playerHpBonus || r0.playerHpBonus === 0, '常规档不应有生命加成');
  assert((r0.enemyStartMana || 0) === 1, '常规档敌首回合应为全局 +1，实际：' + (r0.enemyStartMana || 0));
  /* 初阵：+6 血、敌首回合 -1（叠加后为 0） */
  var p1 = C.emptyProgress('liubang'); p1.mode = 'chuben';
  var r1 = C.engineRules(st0, p1);
  assert(r1.playerHpBonus === C.CHUBEN_HP, '初阵主将应 +' + C.CHUBEN_HP + ' 血，实际：' + r1.playerHpBonus);
  assert((r1.enemyStartMana || 0) === 0, '初阵敌首回合应为 0（全局1-初阵1），实际：' + (r1.enemyStartMana || 0));
  /* 与心魔绝境（敌首回合+1）叠加 → 1 */
  var st3 = C.STAGES[2];
  var p2 = C.emptyProgress('liubang'); p2.mode = 'chuben'; p2.ascension = 3;
  var r2 = C.engineRules(st3, p2);
  assert((r2.enemyStartMana || 0) >= 0, '初阵与心魔叠加后敌首回合不得为负，实际：' + (r2.enemyStartMana || 0));
  /* 与霜降天时（敌首回合-1）叠加 → 最低 0 */
  var p3 = C.emptyProgress('liubang'); p3.mode = 'chuben'; p3.tianShi = 'shuangjiang';
  var r3 = C.engineRules(st0, p3);
  assert((r3.enemyStartMana || 0) === 0, '初阵+霜降应为 0（不打折成负数），实际：' + (r3.enemyStartMana || 0));
  /* start 落档位；未传 mode 一律 regular */
  var run = C.start('liubang', Data.DECKS.han.slice(), null, 0, 'chuben');
  assert(run.mode === 'chuben', 'start 应落 chuben 档');
  assert(C.start('liubang', Data.DECKS.han.slice()).mode === 'regular', 'start 不传 mode 应为 regular');
  /* 迁移：老存档无 mode → regular */
  var old = C.migrate({ version: 1, cleared: [], deck: [] });
  assert(old.mode === 'regular', '旧存档迁移后应为 regular');
  assert(C.migrate({ cleared: [], deck: [], mode: 'chuben' }).mode === 'chuben', 'chuben 存档迁移保留');
  /* 摘要带 mode */
  C.save(run);
  assert(C.slotSummary(C.activeSlot()).mode === 'chuben', '存档摘要应带 mode');
  console.log('  初阵 +6 血 / 敌首回合 -1（下限 0）✅');
})();

/* ⑮ 重整机会（P5）：把「无限重试」改成每关 1 次，第二次兵败本局终结 */
section('⑮ 重整机会');
(function () {
  var sid = C.STAGES[0].id;
  var run = C.start('liubang', Data.DECKS.han.slice(), null, 0, 'regular');
  assert(C.retryLeft(run, sid) === C.RETRY_PER_STAGE,
    '新局每关应有 ' + C.RETRY_PER_STAGE + ' 次重整，实际：' + C.retryLeft(run, sid));
  assert(C.canRetry(run, sid) === true, '首败前应可重整');
  assert(C.takeRetry(run, sid) === true, '第一次重整应消耗成功');
  assert(C.retryLeft(run, sid) === 0, '用完后剩余应为 0');
  assert(C.takeRetry(run, sid) === false, '第二次 takeRetry 应返回 false（不能无限重试）');
  assert(C.retryLeft(run, C.STAGES[1].id) === C.RETRY_PER_STAGE, '别的关卡不应占用重整次数');
  var reloaded = C.load();
  assert(C.retryLeft(reloaded, sid) === 0, '重整记录应随存档持久化（读档不能刷新次数）');
  assert(C.slotSummary(C.activeSlot()).retries === 1, '存档摘要应带兵败次数');
  var old = C.migrate({ version: 1, cleared: [], deck: [] });
  assert(Array.isArray(old.retried) && old.retried.length === 0, '旧存档迁移后 retried 应为空');
  /* 本局终结：只清当前槽位，别的槽不受影响 */
  var other = C.start('liubang', Data.DECKS.han.slice(), null, 0, 'regular');
  C.useSlot(2); C.save(other); C.useSlot(0);
  C.endRun();
  assert(C.slotSummary(0).empty === true, '本局终结后当前槽应清空');
  assert(C.slotSummary(2).empty === false, '别的存档位不应受影响');
  C.clearSlot(2);
  console.log('  每关 1 次 · 再败即终局 · 终结清当前槽 ✅');
})();

console.log('\n通过 ' + passed + ' 项，失败 ' + failed + ' 项');
if (failed > 0) process.exit(1);
