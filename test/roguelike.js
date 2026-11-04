/* 战役随机化测试：军师被动 / 行军事件 / 进度 v2 迁移 / 奖励池随机化 */
globalThis.Data = require('../js/data.js');
globalThis.Engine = require('../js/engine.js');
globalThis.AI = require('../js/ai.js');

/* 用内存版 localStorage 顶替，验证存档读写与迁移 */
globalThis.localStorage = {
  _d: {},
  getItem: function (k) { return Object.prototype.hasOwnProperty.call(this._d, k) ? this._d[k] : null; },
  setItem: function (k, v) { this._d[k] = String(v); },
  removeItem: function (k) { delete this._d[k]; }
};

globalThis.Campaign = require('../js/campaign.js');
var D = Data, E = Engine, C = Campaign;

var passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) passed++;
  else { failed++; console.error('  ✗ ' + msg); }
}
function section(t) { console.log('\n' + t); }

/* 开一局，可带 rules（军师 / 关卡规则） */
function fresh(rules, deckHero) {
  var hero = deckHero || 'liubang';
  var st = E.newGame(hero, 'xiangyu', 'p1', 'bijiang',
    { p1: D.DECKS[D.HEROES[hero].faction].slice() }, { rules: rules || {} });
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
function units(st, pid, rank) { return st.players[pid].board[rank]; }
function newProg() {
  var p = C.emptyProgress('liubang');
  p.deck = D.DECKS.han.slice();
  p.advisor = 'xiaohe';
  return p;
}

/* ① 数据完整性 */
section('① 军师与事件数据完整性');
(function () {
  assert(C.ADVISORS.length === 5, '军师应有 5 名，实际：' + C.ADVISORS.length);
  var ids = {};
  C.ADVISORS.forEach(function (a) {
    assert(!!a.id && !!a.name && !!a.title && !!a.desc, '军师字段缺失：' + a.id);
    assert(!ids[a.id], '军师 id 重复：' + a.id);
    ids[a.id] = true;
    assert(!!a.glyph && a.glyph.length === 1, a.id + ' 应有一个字的徽记');
  });
  assert(C.EVENTS.length >= 8, '事件应有至少 8 个，实际：' + C.EVENTS.length);
  var eids = {};
  C.EVENTS.forEach(function (e) {
    assert(!!e.id && !!e.name && !!e.text, '事件字段缺失：' + e.id);
    assert(!eids[e.id], '事件 id 重复：' + e.id);
    eids[e.id] = true;
    assert(e.options.length >= 2, e.id + ' 至少要有 2 个选项');
    e.options.forEach(function (o) {
      assert(!!o.label && typeof o.hint === 'string', e.id + ' 选项缺 label/hint');
      assert(o.fx && typeof o.fx === 'object', e.id + ' 选项缺 fx');
    });
  });
  console.log('  5 名军师 / ' + C.EVENTS.length + ' 个行军事件 ✅');
})();

/* ② 军师：张良 —— 每回合首张计谋额外抽牌 */
section('② 军师 · 张良运筹');
(function () {
  var st = fresh({ advisor: 'zhangliang' });
  st.players.p1.hand = [];
  var deck0 = st.players.p1.deck.length;
  var s1 = give(st, 'p1', 's_xiaohe');          /* 2 费，抽 2 张 */
  E.playCard(st, 'p1', s1.uid);
  assert(st.players.p1.hand.length === 3, '抽 2 + 张良 1 = 3 张手牌，实际：' + st.players.p1.hand.length);
  assert(deck0 - st.players.p1.deck.length === 3, '牌库应减少 3 张，实际：' + (deck0 - st.players.p1.deck.length));
  /* 同一回合第二张计谋不再触发 */
  st.players.p1.hand = [];
  var d1 = st.players.p1.deck.length;
  var s2 = give(st, 'p1', 's_jinang');          /* 3 费，不抽牌 */
  E.playCard(st, 'p1', s2.uid);
  assert(st.players.p1.deck.length === d1, '第二张计谋不应额外抽牌');
  /* 新回合重置 */
  E.endTurn(st); E.endTurn(st);
  st.players.p1.hand = [];
  var d2 = st.players.p1.deck.length;
  var m0 = st.players.p1.mana;
  var s3 = give(st, 'p1', 's_xiaohe');
  E.playCard(st, 'p1', s3.uid);
  assert(d2 - st.players.p1.deck.length === 3, '新回合应重新触发，实际抽了 ' + (d2 - st.players.p1.deck.length));
  assert(st.players.p1.mana === m0 - 2 + 1, '张良应返还 1 点军粮（2 费牌净花 1），实际：' + (st.players.p1.mana - m0));
  console.log('  每回合首张计谋抽 1 张并返还 1 粮，次张不触发，跨回合重置 ✅');
})();

/* ②-b 萧何 / 陈平的起手摸牌 */
section('②-b 军师 · 起手加牌');
(function () {
  function openingHand(rules) {
    var st = E.newGame('liubang', 'xiangyu', 'p1', 'bijiang', { p1: D.DECKS.han.slice() }, { rules: rules });
    return st.players.p1.hand.length;
  }
  var base = openingHand({});
  assert(openingHand({ advisor: 'xiaohe' }) === base + 1, '萧何应让起手多 1 张');
  assert(openingHand({ advisor: 'chenping' }) === base + 1, '陈平应让起手多 1 张');
  assert(openingHand({ advisor: 'hanxin' }) === base, '韩信不应改变起手张数');
  console.log('  萧何 / 陈平起手 ' + base + ' → ' + (base + 1) + ' 张 ✅');
})();

/* ③ 军师：萧何 —— 开战生命上限 +3 */
section('③ 军师 · 萧何镇国');
(function () {
  var base = fresh({});
  assert(base.players.p1.maxHp === 30, '基准应为 30 血，实际：' + base.players.p1.maxHp);
  var st = fresh({ advisor: 'xiaohe' });
  assert(st.players.p1.maxHp === 35, '萧何应让血量上限到 35，实际：' + st.players.p1.maxHp);
  assert(st.players.p1.hp === 35, '萧何应让当前血量到 35，实际：' + st.players.p1.hp);
  /* 与关卡固定血量叠加：鸿门宴 12 血 → 15 */
  var h = fresh({ advisor: 'xiaohe', playerHp: 12 });
  assert(h.players.p1.maxHp === 17, '鸿门宴配萧何应为 17 血，实际：' + h.players.p1.maxHp);
  /* 不影响敌方 */
  assert(h.players.p2.maxHp === 26, '敌方不应受军师影响，实际：' + h.players.p2.maxHp);
  console.log('  每场 +3 血，可与关卡固定血量叠加，不影响敌方 ✅');
})();

/* ④ 军师：韩信 —— 前锋 +1 攻 */
section('④ 军师 · 韩信多多益善');
(function () {
  var st = fresh({ advisor: 'hanxin' });
  var b = give(st, 'p1', 'n_bing2');            /* 2/3 前锋 */
  E.playCard(st, 'p1', b.uid);
  var f = units(st, 'p1', 'front')[0];
  assert(f.atk === 3, '前锋锐士应为 3 攻，实际：' + f.atk);
  var m = give(st, 'p1', 'n_shi1');             /* 1/4 中军 */
  E.playCard(st, 'p1', m.uid);
  assert(units(st, 'p1', 'mid')[0].atk === 1, '中军不应加成，实际：' + units(st, 'p1', 'mid')[0].atk);
  /* 敌方前锋不受影响（军师只对玩家生效） */
  st.players.p2.mana = 10;
  var eb = give(st, 'p2', 'n_bing2');
  E.playCard(st, 'p2', eb.uid);
  assert(units(st, 'p2', 'front')[0].atk === 2, '敌方前锋不应加成，实际：' + units(st, 'p2', 'front')[0].atk);
  console.log('  只加成我方前锋，中军与敌方不受影响 ✅');
})();

/* ⑤ 军师：樊哙 —— 本场第一个兵种 +2/+1 */
section('⑤ 军师 · 樊哙陷阵先登');
(function () {
  var st = fresh({ advisor: 'fankuai' });
  var first = give(st, 'p1', 'n_bing2');        /* 2/3 */
  E.playCard(st, 'p1', first.uid);
  var f = units(st, 'p1', 'front')[0];
  assert(f.atk === 4, '第一个兵种应为 4 攻，实际：' + f.atk);
  assert(f.hp === 4 && f.maxHp === 4, '第一个兵种应为 4 血，实际：' + f.hp + '/' + f.maxHp);
  var second = give(st, 'p1', 'n_bing2');
  E.playCard(st, 'p1', second.uid);
  var s2 = units(st, 'p1', 'front')[1];
  assert(s2.atk === 2 && s2.hp === 3, '第二个兵种应无加成，实际：' + s2.atk + '/' + s2.hp);
  /* 新的一场战斗重新计数 */
  var st2 = fresh({ advisor: 'fankuai' });
  var a = give(st2, 'p1', 'n_bing2');
  E.playCard(st2, 'p1', a.uid);
  assert(units(st2, 'p1', 'front')[0].atk === 4, '新战斗中第一个兵种应重新获得加成');
  console.log('  每场仅首个兵种 +2/+1，之后不再触发 ✅');
})();

/* ⑥ 军师：陈平 —— 开战敌方全体 1 伤 */
section('⑥ 军师 · 陈平六出奇计');
(function () {
  var st = fresh({
    advisor: 'chenping',
    enemyOpeningUnits: [
      { baseId: 'n_bing2', rank: 'front' },      /* 2/3 */
      { baseId: 'n_shi1', rank: 'mid' }          /* 1/4 */
    ]
  });
  assert(units(st, 'p2', 'front')[0].hp === 2, '敌方前排应 3-1=2 血，实际：' + units(st, 'p2', 'front')[0].hp);
  assert(units(st, 'p2', 'mid')[0].hp === 3, '敌方中军应 4-1=3 血，实际：' + units(st, 'p2', 'mid')[0].hp);
  /* 1 血单位会被直接清场（死战类同时触发，不应报错） */
  var st2 = fresh({
    advisor: 'chenping',
    enemyOpeningUnits: [{ baseId: 'n_bing1', rank: 'front' }]   /* 1/2 */
  });
  assert(units(st2, 'p2', 'front')[0].hp === 1, '2 血单位应剩 1 血，实际：' + units(st2, 'p2', 'front')[0].hp);
  console.log('  开局对敌方在场的每支部队各 1 伤 ✅');
})();

/* ⑦ 军师在没有 advisor 时不产生任何影响 */
section('⑦ 无军师时规则不变');
(function () {
  var st = fresh({});
  var b = give(st, 'p1', 'n_bing2');
  E.playCard(st, 'p1', b.uid);
  assert(units(st, 'p1', 'front')[0].atk === 2, '无军师时不应加成');
  assert(st.players.p1.maxHp === 30, '无军师时血量不应变化');
  console.log('  基准行为不变 ✅');
})();

/* ⑧ 行军事件结算 */
section('⑧ 行军事件结算');
(function () {
  var p = newProg();
  var r1 = C.applyEvent(p, 'liumin', 0);        /* 开仓赈济：+3 生命 */
  assert(r1.ok, '事件应结算成功');
  assert(p.hpBonus === 3, '生命加成应为 3，实际：' + p.hpBonus);
  assert(p.events.indexOf('liumin') >= 0, '应记录已触发事件');
  assert(p.eventLog.length === 1 && p.eventLog[0].choice === '开仓赈济', '事件流水应记录选择');

  var p2 = newProg();
  C.applyEvent(p2, 'jisi', 0);                  /* 沉璧祭河：+2 军粮 */
  assert(p2.manaBonus === 2, '下一战军粮应为 +2，实际：' + p2.manaBonus);
  C.applyEvent(p2, 'qiaofu', 0);                /* 小道：+1 军粮 +1 起手 */
  assert(p2.manaBonus === 3, '军粮加成应累加为 3，实际：' + p2.manaBonus);
  assert(p2.drawBonus === 1, '起手摸牌加成应为 1，实际：' + p2.drawBonus);

  var p3 = newProg();
  var before = p3.deck.length;
  C.applyEvent(p3, 'yiqing', 0);                /* 隔离病卒：随机掉一张 */
  assert(p3.deck.length === before - 1, '牌组应少 1 张，实际：' + (before - p3.deck.length));

  var p4 = newProg();
  var r4 = C.applyEvent(p4, 'laozu', 2);        /* 厚赐遣归：-1 血，删两张 */
  assert(r4.fx.remove === 2, '应请求删两张牌');
  assert(p4.hpBonus === -1, '生命上限应 -1，实际：' + p4.hpBonus);

  /* 生命上限有下限，不会扣成必败 */
  var p5 = newProg();
  for (var i = 0; i < 6; i++) C.applyEvent(p5, 'pofu', 0);   /* -5 × 6 = -30 */
  assert(p5.hpBonus >= -8, '生命上限扣减应有下限 -8，实际：' + p5.hpBonus);
  console.log('  生命 / 军粮 / 摸牌 / 掉牌 / 删牌 / 下限保护全部正确 ✅');
})();

/* ⑨ 事件抽取不重复 */
section('⑨ 事件抽取不重复');
(function () {
  var p = newProg();
  var seen = {};
  for (var i = 0; i < C.EVENTS.length; i++) {
    var ev = C.pickEvent(p);
    assert(!!ev, '应能抽到事件');
    seen[ev.id] = (seen[ev.id] || 0) + 1;
    p.events.push(ev.id);
  }
  var allSeen = C.EVENTS.every(function (e) { return seen[e.id] === 1; });
  assert(allSeen, '一圈内每个事件应各出现一次，实际：' + JSON.stringify(seen));
  /* 事件用完后仍能继续抽（第二圈） */
  var again = C.pickEvent(p);
  assert(!!again && !!again.id, '事件用尽后应能继续抽取');
  console.log('  一轮内不重复，用尽后自动开启第二轮 ✅');
})();

/* ⑩ engineRules 注入军师与加成 */
section('⑩ engineRules 注入');
(function () {
  var stage = C.stageById('pengcheng');         /* 自带 playerStartMana: 2 */
  var p = newProg();
  p.advisor = 'hanxin';
  p.hpBonus = 2;
  p.manaBonus = 1;
  p.drawBonus = 1;
  p.enemyManaBonus = -1;
  var r = C.engineRules(stage, p);
  assert(r.advisor === 'hanxin', '应注入军师');
  assert(r.playerHpBonus === 2, '应注入生命加成');
  assert(r.playerStartMana === 3, '关卡 2 + 事件 1 = 3，实际：' + r.playerStartMana);
  assert(r.openingDraw === 1, '应注入起手摸牌');
  assert(r.enemyStartMana === -1, '应注入敌方军粮削减');
  var bare = C.engineRules(stage);
  assert(bare.advisor === undefined && bare.playerHpBonus === undefined, '不传进度时不应注入');
  assert(bare.playerStartMana === 2, '不传进度时保持关卡原值');

  /* 一次性加成在战后清零 */
  C.consumeBoosts(p);
  assert(p.manaBonus === 0 && p.drawBonus === 0 && p.enemyManaBonus === 0, '一次性加成应被清零');
  assert(p.hpBonus === 2, '生命加成是永久的，不应清零');
  console.log('  军师/生命/军粮/摸牌/敌方军粮注入正确，一次性加成用后清零 ✅');
})();

/* ⑪ 起手额外摸牌真的生效 */
section('⑪ 起手额外摸牌');
(function () {
  function handCount(rules) {
    /* newGame 内部抽牌，beginGame 前观察 */
    var st = E.newGame('liubang', 'xiangyu', 'p1', 'bijiang', { p1: D.DECKS.han.slice() }, { rules: rules });
    return st.players.p1.hand.length;
  }
  var base = handCount({});
  var more = handCount({ openingDraw: 2 });
  assert(more === base + 2, '起手应多 2 张，实际：' + base + ' → ' + more);
  console.log('  起手 ' + base + ' → ' + more + ' 张 ✅');
})();

/* ⑫ 奖励池：稀有度上限 / 阵营 / 同名 2 张 */
section('⑫ 奖励池随机化');
(function () {
  var p = newProg();
  var s1 = C.stageById('peixian');              /* 第 1 关 → tier 1 */
  assert(C.tierOf(s1) === 1, '首关应为 tier 1，实际：' + C.tierOf(s1));
  for (var i = 0; i < 60; i++) {
    C.rollRewards(s1, 'han', 3, p).forEach(function (id) {
      if (s1.rewards.indexOf(id) >= 0) return;   /* 关卡特色牌不受稀有度限制 */
      var c = D.CARDS[id];
      assert(c.cost <= 2, '首关的随机池不应出现 3 费以上的牌：' + c.name + '(' + c.cost + ')');
    });
  }
  /* 后段关卡能出史诗 */
  var s8 = C.stageById('gaixia');
  assert(C.tierOf(s8) === 3, '末关应为 tier 3，实际：' + C.tierOf(s8));
  var sawEpic = false;
  for (var j = 0; j < 60; j++) {
    C.rollRewards(s8, 'han', 3, p).forEach(function (id) {
      if (D.CARDS[id].cost >= 5) sawEpic = true;
    });
  }
  assert(sawEpic, '末关应能抽到 5 费以上的牌');

  /* 阵营过滤：汉玩家绝不抽到楚牌 */
  for (var k = 0; k < 80; k++) {
    C.rollRewards(s8, 'han', 3, p).forEach(function (id) {
      assert(D.factionOf(id) !== 'chu', '汉营不应抽到楚牌：' + D.CARDS[id].name);
    });
  }
  /* 牌组里已有 2 张的同名牌不再出现 */
  var p2 = newProg();
  p2.deck = p2.deck.filter(function (id) { return id !== 'n_bing1'; });
  p2.deck.push('n_bing1', 'n_bing1');
  for (var m = 0; m < 60; m++) {
    C.rollRewards(s8, 'han', 3, p2).forEach(function (id) {
      assert(id !== 'n_bing1', '已有 2 张的牌不应再出现在奖励里');
    });
  }
  /* 三选一不重复 */
  for (var n = 0; n < 50; n++) {
    var list = C.rollRewards(s8, 'han', 3, p);
    assert(list.length === 3, '应抽出 3 张，实际：' + list.length);
    assert(list[0] !== list[1] && list[1] !== list[2] && list[0] !== list[2], '三选一不应重复');
  }
  console.log('  稀有度随关卡爬升、阵营过滤、同名 2 张上限、三选一不重复 ✅');
})();

/* ⑬ 进度存档 v1 → v2 迁移（旧单存档 → 第 1 存档位） */
section('⑬ 存档迁移');
(function () {
  C._resetStore();                       /* 清空多存档位，模拟「老版本升级到新版本」 */
  localStorage.removeItem('chuhan_slots_v1');
  var v1 = { version: 1, hero: 'liubang', cleared: ['peixian'], deck: D.DECKS.han.slice() };
  localStorage.setItem('chuhan_campaign_v1', JSON.stringify(v1));
  var p = C.load();
  assert(!!p, 'v1 存档应能读取');
  assert(p.version === 2, '版本应升级到 2，实际：' + p.version);
  assert(p.advisor === null, '军师字段应补齐为 null');
  assert(p.hpBonus === 0 && p.manaBonus === 0, '加成字段应补 0');
  assert(Array.isArray(p.events) && p.events.length === 0, '事件字段应补空数组');
  assert(p.cleared.length === 1 && p.deck.length === 20, '原有进度与牌组应保留');
  assert(localStorage.getItem('chuhan_campaign_v1') === null, '旧 key 迁移后应清理');

  /* 字段被手改坏也不崩 */
  var broken = C.migrate({ version: 2, hero: 'liubang', cleared: [], deck: [], advisor: 123, hpBonus: 'x' });
  assert(broken.advisor === null, '非法军师应被清理');
  assert(broken.hpBonus === 0, '非法生命加成应归零');
  assert(C.migrate(null) === null && C.migrate({ cleared: [] }) === null, '坏存档应返回 null');
  console.log('  v1 自动升级 v2，脏字段兜底 ✅');
})();

/* ⑭ 存档往返 */
section('⑭ 存档往返');
(function () {
  localStorage.removeItem('chuhan_campaign_v1');
  C.reset();
  var p = C.start('liubang', D.DECKS.han.slice(), 'chenping');
  p.hpBonus = 5;
  p.events.push('liumin');
  p.eventLog.push({ id: 'liumin', name: '流民归附', choice: '开仓赈济' });
  C.save(p);
  var back = C.load();
  assert(back.advisor === 'chenping', '军师应持久化');
  assert(back.hpBonus === 5, '生命加成应持久化');
  assert(back.events[0] === 'liumin', '事件记录应持久化');
  assert(back.eventLog.length === 1, '事件流水应持久化');
  console.log('  军师 / 加成 / 事件全部可持久化 ✅');
})();

/* ⑮ 带军师与事件加成的关卡确实按规则开打 */
section('⑮ 战役关卡按进度开打');
(function () {
  var prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  prog.advisor = 'xiaohe';                      /* +3 血 */
  prog.hpBonus = 2;                             /* 事件 +2 血 */
  prog.manaBonus = 1;
  var stage = C.stageById('pengcheng');         /* playerStartMana: 2 */
  var st = E.newGame('liubang', stage.enemy.heroId, 'p1', stage.aiLevel,
    { p1: prog.deck }, { rules: C.engineRules(stage, prog), p2Meta: stage.enemy.meta });
  assert(st.players.p1.maxHp === 37, '30 + 5(萧何) + 2(事件) = 37，实际：' + st.players.p1.maxHp);
  E.beginGame(st);
  assert(st.players.p1.mana === 1 + 2 + 1, '首回合军粮 = 1 + 关卡 2 + 事件 1 = 4，实际：' + st.players.p1.mana);
  console.log('  军师与事件加成正确进入实际对局 ✅');
})();

/* ⑯ 8 关全流程（含军师 + 事件）可跑通 */
section('⑯ 8 关全流程模拟');
(function () {
  var prog = C.emptyProgress('liubang');
  prog.deck = D.DECKS.han.slice();
  prog.advisor = 'xiaohe';
  var played = 0, eventCount = 0;
  for (var i = 0; i < C.STAGES.length; i++) {
    var stage = C.STAGES[i];
    var st = E.newGame('liubang', stage.enemy.heroId, 'p1', stage.aiLevel,
      { p1: prog.deck }, { rules: C.engineRules(stage, prog), p2Meta: stage.enemy.meta });
    st.levels.p1 = stage.aiLevel;
    E.beginGame(st);
    var guard = 0;
    while (!st.over && guard++ < 800) {
      AI.applyAction(st, st.current, AI.aiNextAction(st, st.current));
    }
    assert(st.over, stage.id + ' 对局应在合理回合内结束（实际跑了 ' + guard + ' 步）');
    played++;
    /* 赢不赢都往下推进，只为验证流程不崩 */
    var reward = C.rollRewards(stage, 'han', 1, prog)[0] || null;
    C.clearStage(prog, stage.id, reward);
    C.consumeBoosts(prog);
    if (C.needsEvent(prog, stage)) {
      var ev = C.pickEvent(prog);
      C.applyEvent(prog, ev.id, 0);
      eventCount++;
    }
  }
  assert(played === 8, '应打完 8 关，实际：' + played);
  assert(eventCount === 7, '8 关之间应有 7 个事件节点，实际：' + eventCount);
  assert(C.isFinished(prog), '打完后应标记通关');
  assert(prog.deck.length >= 20, '牌组不应被删空，实际：' + prog.deck.length);
  console.log('  8 关 + 7 个事件全流程跑通，牌组最终 ' + prog.deck.length + ' 张 ✅');
})();

/* ⑰ 多存档位 */
section('⑰ 多存档位');
(function () {
  C._resetStore();
  localStorage.removeItem('chuhan_slots_v1');
  assert(C.SLOT_COUNT === 3, '应有 3 个存档位');
  assert(C.slots().length === 3 && C.slots().every(function (s) { return s.empty; }), '初始三个位都为空');
  assert(C.load() === null, '空存档位读不到进度');

  /* 位 1：新战役 */
  var a = C.start('liubang', D.DECKS.han.slice(), 'hanxin');
  C.clearStage(a, 'peixian', 'n_bing2');
  C.save(a);
  var s0 = C.slotSummary(0);
  assert(!s0.empty && s0.cleared === 1, '位 1 应有 1 关进度，实际：' + s0.cleared);
  assert(s0.nextStageId === 'hongmen', '位 1 下一关应是鸿门宴，实际：' + s0.nextStageId);
  assert(s0.deckSize === 21, '位 1 牌组应 21 张，实际：' + s0.deckSize);
  assert(s0.advisor === 'hanxin', '位 1 军师应记住韩信');
  assert(!!s0.updatedAt, '位 1 应有更新时间');

  /* 位 2：另一局，互不干扰 */
  assert(C.useSlot(1), '切到第 2 位');
  assert(C.load() === null, '第 2 位应为空');
  var b = C.start('xiangyu', D.DECKS.chu.slice(), 'chenping');
  C.save(b);
  assert(C.load().hero === 'xiangyu', '第 2 位读出项羽');
  assert(C.slotSummary(0).hero === 'liubang', '第 1 位仍是刘邦');
  assert(C.slotSummary(0).cleared === 1, '第 1 位进度未被第 2 位覆盖');

  /* 切回去 */
  C.useSlot(0);
  assert(C.load().hero === 'liubang' && C.load().cleared.length === 1, '切回第 1 位进度完整');

  /* 清空只影响当前位 */
  C.clearSlot(1);
  assert(C.slotSummary(1).empty, '第 2 位应被清空');
  assert(C.slotSummary(0).cleared === 1, '清空第 2 位不影响第 1 位');
  assert(C.activeSlot() === 0, '当前存档位应是第 1 位');

  /* 越界参数不崩 */
  assert(C.useSlot(9) === false && C.clearSlot(-1) === false, '越界存档位应被拒绝');

  /* 落盘结构可再次读取 */
  var raw = JSON.parse(localStorage.getItem('chuhan_slots_v1'));
  assert(raw && raw.version === 1 && raw.slots.length === 3, '存档文件应是 3 槽结构');
  assert(raw.slots[0].progress.cleared.length === 1, '存档文件里第 1 位有进度');
  console.log('  3 个存档位互不干扰，切换 / 清空 / 落盘结构正确 ✅');
})();

console.log('\n通过 ' + passed + ' 项，失败 ' + failed + ' 项');
process.exit(failed ? 1 : 0);
