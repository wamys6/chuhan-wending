/* 《楚汉·问鼎》战役模式：关卡数据 + 战役进度存档 */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.Campaign = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var SAVE_KEY = 'chuhan_campaign_v1';          /* 旧版单存档（只用于迁移） */
  var SLOT_KEY = 'chuhan_slots_v1';             /* 多存档位：{version,active,slots:[{progress,updatedAt}]} */
  var SLOT_COUNT = 3;

  /* ------------------------------------------------------------------
     军师（战役开局的永久被动，每局三选一）
     被动由引擎识别：rules.advisor = <id>，只对玩家（p1）生效
     active = 每场战斗 1 次的手动技（P6，2026-11-06 加）：cost + fx，
     fx 走引擎 resolveEffect 的同一套词汇（draw/healHero/summon/buffAll/
     dmgHighest 等），个别特例（xyCap）由引擎单独认字段。
     为什么要它：8 位军师都是「选完就再没交互」的纯被动，开局三选一之后
     玩家和军师之间没有任何操作；一个每场 1 次的技，成本可控（一场一次），
     又让「这场要不要留给他」变成一次真决策。
  ------------------------------------------------------------------ */
  /* 调参开关：量「主动技值多少」时用它做同种子 A/B */
  var ADVISOR_ACTIVE_ON = true;
  function setAdvisorActive(on) { ADVISOR_ACTIVE_ON = !!on; }

  var ADVISORS = [
    {
      id: 'zhangliang', name: '张良', title: '运筹帷幄', glyph: '张',
      desc: '每回合第一次打出计谋牌时，额外抽一张牌。',
      active: { name: '献策', cost: 2, desc: '抽两张牌。', fx: { draw: 2 } },
      flavor: '运筹帷幄之中，决胜千里之外。'
    },
    {
      id: 'xiaohe', name: '萧何', title: '镇国抚民', glyph: '萧',
      desc: '每场战斗开始时，主将生命上限 +5，起手多摸一张牌。',
      active: { name: '转输', cost: 2, desc: '主将恢复 2 点血量。', fx: { healHero: 2 } },
      flavor: '镇国家，抚百姓，给馈饷，不绝粮道。'
    },
    {
      id: 'hanxin', name: '韩信', title: '多多益善', glyph: '韩',
      desc: '你派到前锋列的兵种，攻击力 +1。',
      active: { name: '点兵', cost: 4, desc: '抽一张牌；前锋列兵种攻击力 +1。',
        fx: { draw: 1, buffCol: 'front', atk: 1 } },
      flavor: '臣多多而益善耳。'
    },
    {
      id: 'fankuai', name: '樊哙', title: '陷阵先登', glyph: '樊',
      desc: '每场战斗你派出的第一个兵种，攻击力 +1、生命 +1。',
      active: { name: '冲阵', cost: 3, desc: '我方全体兵种攻击力 +1。', fx: { buffAll: 1 } },
      flavor: '臣请入，与之同命！'
    },
    {
      id: 'xiangying', name: '夏侯婴', title: '滕公护军', glyph: '夏',
      desc: '你的每个死战效果都额外发动一次（每场战斗至多额外发动两次）。安置流散，护军有方。',
      active: { name: '救驾', cost: 1, desc: '主将恢复 2 点血量；本场战斗死战额外发动的次数 +1。',
        fx: { healHero: 2, xyCap: 1 } },
      flavor: '上虽急，可以勉生，奈何弃之？'
    },
    {
      id: 'chenping', name: '陈平', title: '六出奇计', glyph: '陈',
      desc: '每场战斗开始时起手多摸两张牌；敌军已列阵时，再对其全体造成 1 点伤害。',
      active: { name: '反间', cost: 3, desc: '对敌方攻击力最高的兵种造成 1 点伤害。', fx: { dmgHighest: 1 } },
      flavor: '凡六出奇计，辄益邑。'
    },
    {
      id: 'zhoubo', name: '周勃', title: '安刘定倾', glyph: '周',
      desc: '每个我方回合开始时，你攻击力最高的兵种获得 +1/+1（每场战斗至多一次）。',
      active: { name: '整军', cost: 4, desc: '我方全体兵种生命上限 +1。', fx: { buffAllHp: 1 } },
      flavor: '绛侯厚重少文，然安刘氏者必勃也。'
    },
    {
      id: 'liyiji', name: '郦食其', title: '舌下齐城', glyph: '郦',
      desc: '每个敌方回合开始时，敌方攻击力最高的兵种攻击力 -1（每场战斗至多一次）。',
      active: { name: '说降', cost: 2, desc: '敌方攻击力最高的兵种攻击力 -1。', fx: { debuffHighest: { atk: 1 } } },
      flavor: '一士之辩，下齐七十余城。'
    }
  ];

  /* ------------------------------------------------------------------
     心魔：通关后解锁的难度层级，累计叠加（第 N 级 = 1..N 全部生效）
     只用军粮 / 生命上限两个杠杆。预置部队不做梯度——单关就 -19pp，
     八关连乘会直接打到 0%，它是"单关开关"而不是"难度旋钮"。
     数值按 test/tune-ascension.js 实测校准，目标是每级约折半。
  ------------------------------------------------------------------ */
  /* ------------------------------------------------------------------
     心魔：通关后解锁的难度层级，累计叠加（第 N 级 = 1..N 全部生效）
     只做 3 级是有实测依据的：整轮通关率是 8 关连乘，可用的负向杠杆
     （起手张数 / 手牌上限 / 军粮 / 生命）每一个都值 -6~-13pp，
     第 4 级就会掉进 1% 的"不可玩"区间。与其摆 5 级好看，
     不如 3 级每一级都真的能打通。数值见 test/tune-ascension.js。
  ------------------------------------------------------------------ */
  var ASCENSION = [
    { level: 1, name: '心魔·初动', desc: '主将生命上限 -3', mods: { playerHpBonus: -3 } },
    { level: 2, name: '心魔·困顿', desc: '起手少摸一张牌', mods: { openingDraw: -1 } },
    { level: 3, name: '心魔·绝境', desc: '敌军首回合 +1 军粮', mods: { enemyStartMana: 1 } }
  ];

  /* ------------------------------------------------------------------
     天时：每局开局随机一个全局修正，八关全程生效
     三利三弊，强度都控制在 ±1 军粮 / ±1 摸牌 / ±4 生命以内，
     目的是"每局手感不一样"，不是"抽到坏天时就输"。
  ------------------------------------------------------------------ */
  var TIANSHI = [
    { id: 'qingfeng', name: '天时·清风', desc: '顺风行军：你首回合 +1 军粮', mods: { playerStartMana: 1 } },
    { id: 'fengnian', name: '天时·丰年', desc: '粮秣充足：你起手多摸一张牌', mods: { openingDraw: 1 } },
    { id: 'shuangjiang', name: '天时·霜降', desc: '敌营冻馁：敌军首回合 -1 军粮', mods: { enemyStartMana: -1 } },
    { id: 'kuhan', name: '天时·苦寒', desc: '风雪交加：你首回合 -1 军粮', mods: { playerStartMana: -1 } },
    { id: 'lihuo', name: '天时·离火', desc: '暑气伤军：你生命上限 -4', mods: { playerHpBonus: -4 } },
    { id: 'xingbian', name: '天时·星变', desc: '妖星示警：敌军首回合 +1 军粮', mods: { enemyStartMana: 1 } }
  ];

  /* ------------------------------------------------------------------
     解锁式 meta：军师与事件按生涯进度分批解锁（通关不再只是「更难」）。
     career = { runWins: 整轮通关次数, ascensionBest: 已通关的最高心魔 }，
     两个字段都缺按 0 处理；不给 career（老调用/调参工具）= 全解锁。
     初始池刻意放被动最简单的四位军师；破釜沉舟/夜闻楚歌这些后期剧情
     事件留到二周目之后，让「再打一局」真的有新东西。
  ------------------------------------------------------------------ */
  var BASE_ADVISORS = ['zhangliang', 'xiaohe', 'fankuai', 'xiangying'];
  var BASE_EVENTS = ['liumin', 'liangdao', 'pofu', 'jiangjiang', 'yiqing',
    'laozu', 'jisi', 'qiaofu', 'jieqi', 'shibing'];
  var UNLOCK_LADDER = [
    { level: 1, cond: { runWins: 1 }, advisor: 'hanxin',
      events: ['dujiang', 'qishu'], desc: '整轮通关 1 次' },
    { level: 2, cond: { runWins: 2 }, advisor: 'chenping',
      events: ['chuge', 'guren'], desc: '整轮通关 2 次' },
    { level: 3, cond: { ascensionBest: 1 }, advisor: 'zhoubo',
      events: ['qiufeng', 'honggou'], desc: '通关心魔一' },
    { level: 4, cond: { ascensionBest: 2 }, advisor: 'liyiji',
      events: [], desc: '通关心魔二' }
  ];

  /* 生涯进度 → 解锁状态。advisors/events 为已解锁 id 表，level 为已达梯级 */
  function unlockState(career) {
    var runWins = (career && career.runWins) || 0;
    var ascBest = (career && career.ascensionBest) || 0;
    var advisors = BASE_ADVISORS.slice(), events = BASE_EVENTS.slice(), level = 0;
    UNLOCK_LADDER.forEach(function (u) {
      var need = u.cond.runWins || 0, needAsc = u.cond.ascensionBest || 0;
      if (runWins >= need && ascBest >= needAsc) {
        if (advisors.indexOf(u.advisor) < 0) advisors.push(u.advisor);
        u.events.forEach(function (id) { if (events.indexOf(id) < 0) events.push(id); });
        level = Math.max(level, u.level);
      }
    });
    return { advisors: advisors, events: events, level: level };
  }

  function baseAdvisors() { return BASE_ADVISORS.slice(); }
  function baseEvents() { return BASE_EVENTS.slice(); }
  function unlockLadder() { return UNLOCK_LADDER; }

  function ascensionLevels() { return ASCENSION; }

  function ascensionById(level) {
    var n = Math.max(0, Math.min(ASCENSION.length, level | 0));
    return n > 0 ? ASCENSION[n - 1] : null;
  }

  /* 累计效果：1..level 全部叠加 */
  function ascensionMods(level) {
    var out = {};
    var n = Math.max(0, Math.min(ASCENSION.length, level | 0));
    for (var i = 0; i < n; i++) {
      var m = ASCENSION[i].mods;
      for (var k in m) out[k] = (out[k] || 0) + m[k];
    }
    return out;
  }

  function tianshiById(id) {
    for (var i = 0; i < TIANSHI.length; i++) if (TIANSHI[i].id === id) return TIANSHI[i];
    return null;
  }

  function rollTianShi() {
    return TIANSHI[Math.floor(Math.random() * TIANSHI.length)];
  }

  /* ------------------------------------------------------------------
     行军事件（关卡之间随机触发，必在三选一奖励之后）
     选项的 fx 字段：
       hp     主将生命上限增减（跨战斗累计，可为负）
       mana   下一场战斗首回合额外军粮（可负）
       draw   下一场战斗起手额外摸牌
       card   得牌：'piece' / 'spell' / 'any'，由 UI 弹出三选一
       remove 从牌组移除一张，由 UI 弹出删牌界面
  ------------------------------------------------------------------ */
  var EVENTS = [
    {
      id: 'liumin', name: '流民归附', glyph: '民',
      text: '关中大饥，流民数千携老幼随军而行。军中粮草只够吃到下月，而前面的路还长。',
      options: [
        { label: '开仓赈济', hint: '得两张兵种牌，下一战首回合 -1 军粮', fx: { card: 'piece', cardCount: 2, mana: -1 } },
        { label: '编入行伍', hint: '得一张随机兵种牌', fx: { card: 'piece' } },
        { label: '闭门不纳', hint: '下一战首回合 +1 军粮', fx: { mana: 1 } }
      ]
    },
    {
      id: 'liangdao', name: '粮道被断', glyph: '粮',
      text: '楚军游骑截断粮道，敖仓之粟三日不至。军中已有人开始杀马。',
      options: [
        { label: '派兵护粮', hint: '得一张精良牌，下一战首回合 -1 军粮', fx: { card: 'any', mana: -1 } },
        { label: '弃粮轻行', hint: '随机失去牌组一张牌', fx: { removeRandom: 1 } },
        { label: '杀马充饥', hint: '得一张兵种牌，下一战起手少摸一张', fx: { card: 'piece', draw: -1 } }
      ]
    },
    {
      id: 'qishu', name: '奇书偶得', glyph: '书',
      text: '行军途中掘得竹简一束，似是兵家旧籍，字迹大半漫灭，唯余数策可辨。',
      options: [
        { label: '展卷夜读', hint: '三选一计谋牌', fx: { card: 'spell' } },
        { label: '付之一炬', hint: '下一战首回合 +1 军粮，随机失去一张牌', fx: { mana: 1, removeRandom: 1 } }
      ]
    },
    {
      id: 'jiangjiang', name: '降将归心', glyph: '降',
      text: '一名楚军校尉率部来降，言其家小皆在关中。诸将疑其诈。',
      options: [
        { label: '收为帐下', hint: '得一张随机牌', fx: { card: 'any' } },
        { label: '遣归故里', hint: '下一战敌军首回合 -1 军粮', fx: { enemyMana: -1 } },
        { label: '斩之以立威', hint: '得一张精良牌，随机失去一张牌', fx: { card: 'any', removeRandom: 1 } }
      ]
    },
    {
      id: 'yiqing', name: '军中疫病', glyph: '疫',
      text: '夏雨连月，营中疫气弥漫。医者说：要么断臂求生，要么倾尽全力。',
      options: [
        { label: '隔离病卒', hint: '随机失去牌组一张牌', fx: { removeRandom: 1 } },
        { label: '倾力救治', hint: '牌组无损，下一战首回合 -2 军粮', fx: { mana: -2 } }
      ]
    },
    {
      id: 'laozu', name: '老卒请归', glyph: '归',
      text: '一名从沛县起就跟着你的老卒跪在帐前，说腿疾已重，走不动了。',
      options: [
        { label: '准其归乡', hint: '从牌组移除一张牌（你来挑）', fx: { remove: 1 } },
        { label: '强留军中', hint: '下一战起手少摸一张', fx: { draw: -1 } },
        { label: '厚赐遣归', hint: '移除两张牌，下一战首回合 -1 军粮', fx: { remove: 2, mana: -1 } }
      ]
    },
    {
      id: 'jisi', name: '河神祭祀', glyph: '祭',
      text: '大军将渡河，军中旧俗要沉璧祭河。巫祝说：河神不悦，舟不可行。',
      options: [
        { label: '沉璧祭河', hint: '下一战首回合 +2 军粮，起手少摸一张', fx: { mana: 2, draw: -1 } },
        { label: '撤祭省费', hint: '下一战首回合 +1 军粮', fx: { mana: 1 } }
      ]
    },
    {
      id: 'qiaofu', name: '樵夫指路', glyph: '路',
      text: '山中有樵夫言：有条小道可绕至敌后，只是崎岖难行，辎重怕是要丢。',
      options: [
        { label: '从小道进兵', hint: '下一战 +2 军粮、起手多摸一张，随机失去一张牌', fx: { mana: 2, draw: 1, removeRandom: 1 } },
        { label: '依大道行军', hint: '下一战首回合 +1 军粮', fx: { mana: 1 } }
      ]
    },
    {
      id: 'pofu', name: '破釜沉舟', glyph: '釜',
      text: '前有强敌，后无退路。诸将问：是把锅砸了，还是留着万一？',
      options: [
        { label: '沉船破釜', hint: '删两张牌，换三张牌', fx: { remove: 2, card: 'any', cardCount: 3 } },
        { label: '保全辎重', hint: '下一战起手多摸一张', fx: { draw: 1 } }
      ]
    },
    {
      id: 'chuge', name: '夜闻楚歌', glyph: '歌',
      text: '夜半，营外传来楚地歌声，凄婉入骨。士卒皆起，有泣下者。',
      options: [
        { label: '令军中习楚歌', hint: '下一战敌军首回合 -1 军粮', fx: { enemyMana: -1 } },
        { label: '杖责惑众者', hint: '得一张随机牌，下一战起手少摸一张', fx: { card: 'any', draw: -1 } },
        { label: '抚慰士卒', hint: '下一战起手多摸一张', fx: { draw: 1 } }
      ]
    },

    /* ---- 第二批（2026-11-03）：补「短期爆发 vs 长期续航」与「代价前置」两类抉择 ----
       现有 10 个事件的代价多是扣血，这里是军粮/摸牌/牌组三条新轴：
       mana +3、draw +2、draw -1（代价型）、enemyMana +1（自加难度换资源）、cardCount 3。 */
    {
      id: 'jieqi', name: '借粮于民', glyph: '借',
      text: '荥阳被围，敖仓之粟已尽。本地父老聚在辕门外，说愿借粮三万石，只求战后免其三年赋税。',
      options: [
        { label: '立券借粮', hint: '下一战首回合 +3 军粮，起手少摸一张', fx: { mana: 3, draw: -1 } },
        { label: '强征军粮', hint: '得一张兵种牌，下一战起手少摸一张', fx: { card: 'piece', draw: -1 } },
        { label: '分兵屯田', hint: '下一战起手多摸两张，首回合 -1 军粮', fx: { draw: 2, mana: -1 } }
      ]
    },
    {
      id: 'guren', name: '故人夜访', glyph: '访',
      text: '夜半有人叩营门，是项羽的季父项伯。当年在下邳，你曾救过他一命。他说：明日霸王要亲率铁骑冲阵。',
      options: [
        { label: '厚赠遣归', hint: '下一战敌军首回合 -2 军粮', fx: { enemyMana: -2 } },
        { label: '恳其缓颊', hint: '敌军首回合 -1 军粮，起手多摸一张', fx: { enemyMana: -1, draw: 1 } },
        { label: '闭门不见', hint: '下一战首回合 +1 军粮', fx: { mana: 1 } }
      ]
    },
    {
      id: 'shibing', name: '士卒思归', glyph: '思',
      text: '入关已三年，营中夜夜有人低唱沛县小调。军正捧着名册来问：再不给个说法，怕要出事。',
      options: [
        { label: '许诺还乡', hint: '下一战首回合 +2 军粮，起手少摸一张', fx: { mana: 2, draw: -1 } },
        { label: '严防哗变', hint: '得两张牌，随机失去一张牌', fx: { card: 'any', cardCount: 2, removeRandom: 1 } },
        { label: '就地休整', hint: '下一战起手多摸一张', fx: { draw: 1 } }
      ]
    },
    {
      id: 'dujiang', name: '渡河沉舟', glyph: '渡',
      text: '河水暴涨，渡船不足。诸将请减辎重急渡，或等水退再走。',
      options: [
        { label: '减装急渡', hint: '下一战首回合 +2 军粮，随机失去牌组一张牌', fx: { mana: 2, removeRandom: 1 } },
        { label: '等水退去', hint: '下一战起手多摸两张，敌军首回合 +1 军粮', fx: { draw: 2, enemyMana: 1 } },
        { label: '沿河缓行', hint: '下一战首回合 +1 军粮', fx: { mana: 1 } }
      ]
    },
    {
      id: 'qiufeng', name: '假王之举', glyph: '封',
      text: '使者自齐地来，说韩信已定齐，遣人求为「假齐王」。帐中一时无人作声。',
      options: [
        { label: '立封齐王', hint: '得两张牌，下一战起手少摸一张', fx: { card: 'any', cardCount: 2, draw: -1 } },
        { label: '遣使安抚', hint: '下一战起手多摸一张', fx: { draw: 1 } },
        { label: '斥其僭越', hint: '下一战首回合 +1 军粮', fx: { mana: 1 } }
      ]
    },
    {
      id: 'honggou', name: '鸿沟之约', glyph: '和',
      text: '项羽送还太公与吕后，请以鸿沟为界，中分天下。诸将都说：可以歇兵了。',
      options: [
        { label: '就此约和', hint: '下一战敌军首回合 -2 军粮，起手少摸一张', fx: { enemyMana: -2, draw: -1 } },
        { label: '追而击之', hint: '得三张牌，随机失去一张牌', fx: { card: 'any', cardCount: 3, removeRandom: 1 } },
        { label: '虚与委蛇', hint: '下一战首回合 +2 军粮', fx: { mana: 2 } }
      ]
    }
  ];

  /* ------------------------------------------------------------------
     关卡定义
     enemy.meta  覆盖敌方主将的显示信息（复用英雄技能，但换个身份）
     rules       传给引擎的关卡规则，字段见 engine.js 的 newGame
     goal        'defeat' 击破敌将 | 'survive' 存活指定回合
     rewards     胜利后三选一的奖励池（只会抽玩家阵营可用的牌）
  ------------------------------------------------------------------ */
  var STAGES = [
    {
      id: 'peixian',
      chapter: '第一章',
      name: '沛县起兵',
      year: '秦二世元年 · 前 209 年',
      subtitle: '斩白蛇，举义旗',
      lore: '陈胜、吴广在大泽乡揭竿而起，天下苦秦久矣。\n\n沛县父老杀了县令，开城门迎你入城，尊你为「沛公」。你手里只有三千子弟兵，而秦军的郡监已率部开到城下。\n\n这是你的第一战。赢了，才有后来的汉。',
      enemy: {
        heroId: 'xiangyu',
        meta: { name: '秦·泗水郡监', title: '秦军校尉', glyph: '秦', hp: 14, art: 'h_sishui' }
      },
      aiLevel: 'jianxi',
      goal: 'defeat',
      rules: {},
      goalText: '击破秦军校尉（敌方只有 14 点血）',
      rewards: ['n_bing2', 'n_shi1', 'n_pao1', 'n_ma1', 'h_caocan', 's_xiaohe']
    },
    {
      id: 'hongmen',
      chapter: '第二章',
      name: '鸿门宴',
      year: '汉元年 · 前 206 年',
      subtitle: '人为刀俎，我为鱼肉',
      lore: '你率先入关，破了咸阳。项羽率四十万大军驻在鸿门，你只有十万。\n\n你来赴宴。席上范增三次举起玉玦，项羽默然不应。项庄起身舞剑，剑锋一次次擦过你的席位——项伯以身遮护，樊哙闯帐怒目。\n\n这一战不必赢。活着走出这道帐门，就是胜利。',
      enemy: {
        heroId: 'xiangyu',
        meta: { name: '项羽', title: '西楚霸王', glyph: '项', hp: 26 }
      },
      aiLevel: 'bijiang',
      goal: 'survive',
      goalTurns: 10,
      rules: { handLimit: 3, playerHp: 12 },
      goalText: '存活 10 个回合（你只有 12 点血，手牌上限 3）',
      rewards: ['s_jinang', 's_xiaohe', 'n_hanxin', 'n_xiang1', 'h_zhoub', 'n_che1']
    },
    {
      id: 'pengcheng',
      chapter: '第三章',
      name: '彭城之战',
      year: '汉二年 · 前 205 年',
      subtitle: '睢水为之不流',
      lore: '你趁项羽北上伐齐，率五十六万诸侯兵攻下彭城。你以為大局已定，日日置酒高会。\n\n项羽亲率三万精骑回师，半日之内击溃五十六万人。睢水为之不流。\n\n他的骑兵已经列好阵了。你只有一次机会。',
      enemy: {
        heroId: 'xiangyu',
        meta: { name: '项羽', title: '西楚霸王', glyph: '项', hp: 22 }
      },
      aiLevel: 'mingjiang',
      goal: 'defeat',
      /* 预置部队是难度最大的杠杆，但强度全在「预置哪张」上：
         预置轻骑（3 费 3/2）通关率仅 32%，换戍卒（1 费 1/2）是 53%。
         中途试过的补偿都无效——敌将 22→18 血 34%、玩家首回合 +4 粮 37%。
         玩家过不了这关不是因为打不死将，是被那张白给的 3 费身材压住了整个前中期。 */
      rules: {
        enemyOpeningUnits: [
          { baseId: 'n_bing1', rank: 'front' }
        ],
        playerStartMana: 2
      },
      goalText: '击破项羽（敌方 1 队先锋已列阵，你首回合 +2 军粮）',
      rewards: ['n_che2', 'n_pao2', 'n_ma2', 'n_hanxin', 's_bawang', 'n_xiang2']
    },
    {
      id: 'xingyang',
      chapter: '第四章',
      name: '荥阳对峙',
      year: '汉三年 · 前 204 年',
      subtitle: '纪信焚身，汉王夜出',
      lore: '项羽围荥阳，断你粮道。城中粮尽，士卒饥疲。\n\n陈平设反间，使项羽疑走范增；纪信换上你的衣冠，乘你的车驾出东门诈降，被项羽烧死。你带着数十骑从西门连夜突围。\n\n要走出这座城，先得凿穿楚军的重甲。',
      enemy: {
        heroId: 'xiangyu',
        meta: { name: '项羽', title: '西楚霸王', glyph: '项', hp: 22 }
      },
      aiLevel: 'mingjiang',
      goal: 'defeat',
      rules: {
        playerStartMana: 2,
        enemyDeck: [
          'n_shi1', 'n_shi1', 'n_shi2', 'n_bing2', 'n_bing2', 'n_bing2',
          'n_pao1', 'n_pao1', 'n_pao2', 'n_che1', 'n_che1', 'n_ma1',
          'n_ma1', 'c_zhongli', 'n_bing3', 's_fanzeng', 's_fanzeng',
          's_bawang', 'n_ma2', 'n_ma2'
        ]
      },
      goalText: '击破项羽（敌将 22 血，楚军据城死守；你首回合 +2 军粮）',
      rewards: ['h_chenping', 'h_jixin', 'n_shi3', 'n_bing4', 's_simian', 'n_xiang3']
    },
    {
      id: 'jingxing',
      chapter: '第五章',
      name: '井陉背水',
      year: '汉三年 · 前 204 年',
      subtitle: '陷之死地而后生',
      lore: '韩信率数万新兵东下井陉，赵军二十万扼守隘口。他背靠河水列阵，全军无路可退。\n\n「陷之死地而后生，置之亡地而后存。」——这支新兵不是不想跑，是跑不了。\n\n你只有十四点血。要么破阵，要么死在这条河边。',
      enemy: {
        heroId: 'xiangyu',
        meta: { name: '赵·成安君', title: '代王陈馀', glyph: '赵', hp: 22, art: 'h_chenyu' }
      },
      aiLevel: 'bijiang',
      goal: 'defeat',
      rules: {
        playerHp: 16,
        playerStartMana: 2,
        enemyOpeningUnits: [
          { baseId: 'n_bing1', rank: 'front' }
        ],
        enemyDeck: [
          'n_bing1', 'n_bing1', 'n_bing2', 'n_bing2', 'n_bing4', 'n_bing4',
          'n_shi1', 'n_shi1', 'n_shi2', 'n_shi2', 'n_ma1', 'n_ma1',
          'n_che1', 'n_che1', 'n_pao1', 'n_pao1', 'n_xiang1', 'n_xiang1',
          'n_ma2', 'n_ma2'
        ]
      },
      goalText: '击破赵军（你只有 16 点血、首回合 +2 军粮，敌军 1 队已列阵）',
      rewards: ['h_fankuai', 'n_ma3', 'n_bing3', 'n_shi3', 'n_zengyuan', 'h_guanying']
    },
    {
      id: 'weishui',
      chapter: '第六章',
      name: '潍水之战',
      year: '汉四年 · 前 203 年',
      subtitle: '沙囊壅水，半渡而击',
      lore: '韩信东进伐齐，龙且率二十万楚军来救。两军夹潍水而阵。\n\n夜里，韩信令人以万余沙囊壅住上游。天明佯败渡水，龙且大喜，涉水来追；汉军决囊放水，楚军大半不得渡。\n\n水退之前，把龙且的三阵一并击穿。',
      enemy: {
        heroId: 'xiangyu',
        meta: { name: '龙且', title: '西楚大司马', glyph: '龙', hp: 24, art: 'h_longqie2' }
      },
      aiLevel: 'mingjiang',
      goal: 'defeat',
      rules: {
        playerStartMana: 3,
        enemyDeck: [
          'n_bing2', 'n_bing2', 'n_bing3', 'n_bing3', 'n_ma1', 'n_ma1',
          'n_ma2', 'n_ma2', 'n_che1', 'n_che1', 'n_che2', 'n_shi1',
          'n_shi1', 'n_pao1', 'n_pao1', 'c_longqie', 'c_longqie',
          'c_zhuiqi', 'c_zhuiqi', 's_bawang'
        ]
      },
      goalText: '击破龙且（敌将 24 血、楚军二十万压境；你首回合 +3 军粮）',
      rewards: ['h_guanying', 'n_che3', 'n_pao3', 'n_ma3', 'n_zengyuan', 'h_chenping']
    },
    {
      id: 'guling',
      chapter: '第七章',
      name: '固陵之战',
      year: '汉五年 · 前 202 年',
      subtitle: '援军不至，孤军当锋',
      lore: '鸿沟之约既定，项羽引兵东归。你撕毁和约，尾随追击，约韩信、彭越会师固陵。\n\n日期到了，两路援军一兵未至。项羽回师反击，汉军大败，你只能深沟高垒自守。\n\n等不到援军，就自己撑住这条线。',
      enemy: {
        heroId: 'xiangyu',
        meta: { name: '项羽', title: '西楚霸王', glyph: '项', hp: 24 }
      },
      aiLevel: 'mingjiang',
      goal: 'defeat',
      rules: {
        playerHp: 18,
        handLimit: 4,
        enemyStartMana: 2,
        playerStartMana: 2,
        /* 这一关原本还预置 1 队戍卒，实测通关率 36%，和垓下（34%）几乎一样，
           连着两关都是"最后一堵墙"，收尾没有层次。撤掉后 46%，
           与第 6 关 61%、第 8 关 34% 构成 61 → 46 → 34 的两级收窄。 */
        enemyDeck: [
          'n_bing2', 'n_bing2', 'n_bing3', 'n_bing3', 'n_ma1', 'n_ma1',
          'n_ma2', 'n_ma2', 'n_che1', 'n_che1', 'n_shi2', 'n_shi2',
          'n_pao1', 'n_pao1', 'c_longqie', 'c_longqie', 'c_jibu', 'c_jibu',
          's_fanzeng', 's_bawang'
        ]
      },
      goalText: '击破项羽（你 18 血、手牌上限 4、首回合 +2 军粮；敌方首回合 +2 军粮）',
      rewards: ['n_xiang3', 'n_pao3', 's_simian', 'h_luyi', 'h_jixin', 'n_che3']
    },
    {
      id: 'gaixia',
      chapter: '第八章',
      name: '垓下决战',
      year: '汉五年 · 前 202 年',
      subtitle: '十面埋伏，四面楚歌',
      lore: '韩信三十万居中，孔熙居左，陈贺居右，周勃、柴武随后——十面合围，层层叠叠，把楚军困在垓下。\n\n夜半，汉军营中四面唱起楚歌。项羽惊起：「汉皆已得楚乎？是何楚人之多也！」\n\n这是最后一战。他仍是那个力能扛鼎的霸王。',
      enemy: {
        heroId: 'xiangyu',
        meta: { name: '项羽', title: '西楚霸王', glyph: '项', hp: 30 }
      },
      aiLevel: 'mingjiang',
      goal: 'defeat',
      rules: {
        playerStartMana: 3,
        enemyStartMana: 2,
        enemyOpeningUnits: [
          { baseId: 'n_ma2', rank: 'mid' }
        ],
        enemyDeck: [
          'n_bing2', 'n_bing2', 'n_bing3', 'n_bing3', 'n_ma2', 'n_ma2',
          'n_che1', 'n_che1', 'n_che2', 'n_shi2', 'n_shi2', 'n_xiang2',
          'n_pao2', 'n_pao2', 'c_longqie', 'c_zhongli', 's_bawang',
          's_bawang', 's_fanzeng', 's_juding'
        ]
      },
      goalText: '击破项羽（敌将 30 血、开局骠骑压阵、首回合 +2 军粮；你首回合 +3 军粮）',
      rewards: ['h_chenping', 'h_fankuai', 'h_guanying', 's_simian', 'n_xiang3', 'n_che3', 'h_luyi']
    }
  ];

  function stageById(id) {
    for (var i = 0; i < STAGES.length; i++) if (STAGES[i].id === id) return STAGES[i];
    return null;
  }

  function stageIndex(id) {
    for (var i = 0; i < STAGES.length; i++) if (STAGES[i].id === id) return i;
    return -1;
  }

  /* ------------------------------------------------------------------
     进度存档 v2
     { version:2, hero, cleared:[stageId], deck:[cardId],
       advisor,             军师 id（整局固定）
       hpBonus,             生命上限累计增减
       manaBonus,           下一场首回合额外军粮（用后清零）
       drawBonus,           下一场起手额外摸牌（用后清零）
       enemyManaBonus,      下一场敌军首回合额外军粮（用后清零）
       events:[eventId],    已触发过的事件
       eventLog:[...] }     事件流水（地图上展示）
     v1 存档（无军师/事件字段）会被自动升级
  ------------------------------------------------------------------ */

  function emptyProgress(heroId) {
    return {
      version: 2, hero: heroId || null, cleared: [], deck: [],
      advisor: null, hpBonus: 0, manaBonus: 0, drawBonus: 0, enemyManaBonus: 0,
      ascension: 0, tianShi: null, mode: 'regular',
      events: [], eventLog: [], retried: []
    };
  }

  /* localStorage 在某些环境不可用（隐私模式、内嵌浏览器、部分 file:// 打开方式），
     此时完全靠内存副本兜底，保证一局游戏内战役流程照常可玩 */
  var memoryStore = null;

  /* v1 → v2：补上随机化新增的字段，老存档照常可玩 */
  function migrate(p) {
    if (!p || typeof p !== 'object') return null;
    if (!Array.isArray(p.cleared) || !Array.isArray(p.deck)) return null;
    if (!p.version || p.version < 2) {
      p.version = 2;
      p.advisor = p.advisor || null;
      p.hpBonus = p.hpBonus || 0;
      p.manaBonus = p.manaBonus || 0;
      p.drawBonus = p.drawBonus || 0;
      p.enemyManaBonus = p.enemyManaBonus || 0;
      p.events = p.events || [];
      p.eventLog = p.eventLog || [];
    }
    /* 字段缺漏兜底（手改存档 / 旧版本残留） */
    if (typeof p.advisor !== 'string') p.advisor = null;
    if (typeof p.hpBonus !== 'number') p.hpBonus = 0;
    if (typeof p.manaBonus !== 'number') p.manaBonus = 0;
    if (typeof p.drawBonus !== 'number') p.drawBonus = 0;
    if (typeof p.enemyManaBonus !== 'number') p.enemyManaBonus = 0;
    if (!Array.isArray(p.events)) p.events = [];
    if (!Array.isArray(p.eventLog)) p.eventLog = [];
    /* 心魔 / 天时：老存档没有这两个字段，按「常规难度、无天时」处理 */
    if (typeof p.ascension !== 'number') p.ascension = 0;
    p.ascension = Math.max(0, Math.min(ASCENSION.length, p.ascension | 0));
    if (typeof p.tianShi !== 'string') p.tianShi = null;
    /* 初阵档位（P3）：老存档没有 mode，一律按常规难度 */
    if (p.mode !== 'chuben') p.mode = 'regular';
    /* 重整记录（P5）：老存档视为一次都没用过 */
    if (!Array.isArray(p.retried)) p.retried = [];
    return p;
  }

  /* ------------------------------------------------------------------
     多存档位存储层
     store = { version: 1, active: 0..2, slots: [ {progress, updatedAt} × 3 ] }
     旧版单存档（chuhan_campaign_v1）在首次读取时自动搬进第 1 个存档位
  ------------------------------------------------------------------ */
  function emptyStore() {
    var slots = [];
    for (var i = 0; i < SLOT_COUNT; i++) slots.push(null);
    return { version: 1, active: 0, slots: slots };
  }

  function normalizeStore(s) {
    if (!s || typeof s !== 'object' || !Array.isArray(s.slots)) return null;
    var out = emptyStore();
    if (typeof s.active === 'number' && s.active >= 0 && s.active < SLOT_COUNT) out.active = s.active;
    for (var i = 0; i < SLOT_COUNT; i++) {
      var cell = s.slots[i];
      if (!cell || !cell.progress) continue;
      var p = migrate(cell.progress);
      if (!p) continue;
      out.slots[i] = { progress: p, updatedAt: cell.updatedAt || null };
    }
    return out;
  }

  function readStore() {
    if (memoryStore) return memoryStore;
    var legacy = null;
    try {
      var raw = localStorage.getItem(SLOT_KEY);
      if (raw) {
        var s = normalizeStore(JSON.parse(raw));
        if (s) { memoryStore = s; return s; }
      }
      var old = localStorage.getItem(SAVE_KEY);
      if (old) legacy = migrate(JSON.parse(old));
    } catch (e) { /* 读不到就走空存档 */ }
    var store = emptyStore();
    if (legacy) {
      store.slots[0] = { progress: legacy, updatedAt: Date.now() };
      memoryStore = store;
      writeStore();                       /* 迁移完成，写回新结构 */
      try { localStorage.removeItem(SAVE_KEY); } catch (e) {}
      return store;
    }
    memoryStore = store;
    return store;
  }

  function writeStore() {
    try { localStorage.setItem(SLOT_KEY, JSON.stringify(memoryStore)); } catch (e) {}
  }

  function activeSlot() { return readStore().active; }

  /* 存档位摘要：给界面用，不含整份进度 */
  function slotSummary(i) {
    var store = readStore();
    var cell = store.slots[i];
    if (!cell || !cell.progress) {
      return { index: i, empty: true, active: store.active === i, updatedAt: null };
    }
    var p = cell.progress;
    var next = null;
    for (var k = 0; k < STAGES.length; k++) {
      if (statusOf(p, STAGES[k].id) === 'open') { next = STAGES[k]; break; }
    }
    var adv = p.advisor ? advisorById(p.advisor) : null;
    return {
      index: i, empty: false, active: store.active === i,
      hero: p.hero || 'liubang',
      cleared: p.cleared.length, total: STAGES.length,
      nextStageId: next ? next.id : null,
      finished: p.cleared.length >= STAGES.length,
      deckSize: p.deck.length,
      advisor: p.advisor || null,
      hpBonus: p.hpBonus || 0,
      mode: p.mode === 'chuben' ? 'chuben' : 'regular',
      retries: (p.retried || []).length,
      updatedAt: cell.updatedAt || null
    };
  }

  function slots() {
    var out = [];
    for (var i = 0; i < SLOT_COUNT; i++) out.push(slotSummary(i));
    return out;
  }

  /* 切换当前存档位；越界忽略 */
  function useSlot(i) {
    var store = readStore();
    if (typeof i !== 'number' || i < 0 || i >= SLOT_COUNT) return false;
    store.active = i;
    writeStore();
    return true;
  }

  /* 清空某个存档位（不影响其他位，也不影响成就战绩） */
  function clearSlot(i) {
    var store = readStore();
    if (typeof i !== 'number' || i < 0 || i >= SLOT_COUNT) return false;
    store.slots[i] = null;
    writeStore();
    return true;
  }

  /* ---------------- 重整机会（P5） ----------------
     每关 1 次：第一次兵败回地图可再战；同一关第二次兵败 → 本局终结。
     放弃本局与兵败同等消耗（否则玩家会在必败时退出躲惩罚）。 */

  function retryLeft(progress, stageId) {
    if (!progress || !stageId) return 0;
    var used = 0, arr = progress.retried || [];
    for (var i = 0; i < arr.length; i++) if (arr[i] === stageId) used++;
    return Math.max(0, RETRY_PER_STAGE - used);
  }

  function canRetry(progress, stageId) { return retryLeft(progress, stageId) > 0; }

  /* 消耗一次重整；返回 false 表示已用完（调用方应终结本局） */
  function takeRetry(progress, stageId) {
    if (!canRetry(progress, stageId)) return false;
    progress.retried = (progress.retried || []).concat([stageId]);
    save(progress);
    return true;
  }

  /* 本局终结：清空当前存档位（成就/生涯是独立存档，不受影响） */
  function endRun() {
    var i = activeSlot();
    if (typeof i === 'number' && i >= 0) clearSlot(i);
    return i;
  }

  /* 开始新战役写进当前存档位（会覆盖该位） */
  function save(progress) {
    var store = readStore();
    store.slots[store.active] = { progress: progress, updatedAt: Date.now() };
    memoryStore = store;
    writeStore();
  }

  function load() {
    var store = readStore();
    var cell = store.slots[store.active];
    if (!cell || !cell.progress) return null;
    return migrate(cell.progress);
  }

  function reset() {
    var store = readStore();
    store.slots[store.active] = null;
    memoryStore = store;
    writeStore();
  }

  /* 关卡状态：locked（未解锁）/ open（可挑战）/ cleared（已通关） */
  function statusOf(progress, stageId) {
    if (!progress) return 'locked';
    var idx = stageIndex(stageId);
    if (idx < 0) return 'locked';
    if (progress.cleared.indexOf(stageId) >= 0) return 'cleared';
    if (idx === 0) return 'open';
    var prev = STAGES[idx - 1].id;
    return progress.cleared.indexOf(prev) >= 0 ? 'open' : 'locked';
  }

  /* 开新战役：清空进度，牌组用该英雄的官方预组。
     mode = 'chuben'（初阵，宽容档）| 'regular'（常规），整条战役跟随存档 */
  function start(heroId, presetDeck, advisorId, ascension, mode) {
    var p = emptyProgress(heroId);
    p.deck = (presetDeck || []).slice();
    p.advisor = advisorId || null;
    p.ascension = Math.max(0, Math.min(ASCENSION.length, (ascension || 0) | 0));
    p.mode = mode === 'chuben' ? 'chuben' : 'regular';
    p.tianShi = rollTianShi().id;
    save(p);
    return p;
  }

  /* 通关一关：记录进度 + 把奖励牌加入战役牌组（奖励只在首次通关时发放） */
  function clearStage(progress, stageId, rewardCardId) {
    var firstClear = progress.cleared.indexOf(stageId) < 0;
    if (firstClear) progress.cleared.push(stageId);
    if (rewardCardId && firstClear) progress.deck.push(rewardCardId);
    save(progress);
    return progress;
  }

  /* 取数据层引用（浏览器用全局 Data，Node 里走 require） */
  function dataRef() {
    if (typeof self !== 'undefined' && self.Data) return self.Data;
    if (typeof globalThis !== 'undefined' && globalThis.Data) return globalThis.Data;
    try { return require('./data.js'); } catch (e) { return null; }
  }

  /* 把关卡定义整理成引擎认识的规则对象
     （goal / goalTurns 是关卡属性，引擎只认 rules，所以在这里合并）
     第二参数传进度时，会把「军师被动」和「行军事件积累」一并注入 */
  /* 全局难度旋钮（1.1 卡池扩容后的校准）
     扩容把奖励池的平均质量抬上去了：24 张新卡都是"标准属性 + 一条效果"，
     比旧池里大量白板强，8 次三选一累积后整轮通关率翻了一倍多。
     这里用「八关统一 +1 敌方开局军粮」把基线压回个位数。
     为什么是军粮而不是预置部队：预置是最强杠杆，一加就 0%（实测），军粮可以细调。 */
  var GLOBAL_ENEMY_MANA = 1;
  var GLOBAL_PLAYER_HP = 0;
  /* 只给后四关加敌方开局军粮：
     前四关是低费铺场（死战流）积累场面的地盘，在这里加军粮会把铺场节奏直接掐死
     （实测：八关统加 → 死战构筑的优势从 +7pp 掉到 +1pp）；
     后四关本来就是拼质量与收尾，加军粮惩罚的是"拖后期"，对节奏流相对中性。 */
  var MANA_BOOST_STAGES = {};

  /* ------------------------------------------------------------------
     死战专精（1.2）

     1.1 的结论是「死战路线靠卡堆起不来」。1.2 先量了原因，不是选不到：
     死战优先的玩家已经能拿到 7.6 张、浓度 27%，通关却只比随机高 3.5pp。
     问题是每多一张死战牌只值 1~2 点属性，8 张也不产生质变。

     所以这里换的不是「发更多牌」，而是「同类的张数改变牌本身的效果强度」：
     牌组里的死战牌越多，死战唤来的援军越硬。刻意构筑的人吃高档，
     随手选的人也吃低档，完全不碰死战牌的不触发——这是它和「全体加强」的区别。
  ------------------------------------------------------------------ */

  /* 死战专精：档位按「死战牌占牌组的比例」算，不按绝对张数。
     为什么是比例——牌组从 20 张长到 28 张，绝对张数的门槛会随规模漂移：
     早期 6 张是 30%，晚期 6 张只有 21%，同一个门槛在不同关卡含义完全不同。
     实测分布（test/diag-tier.js）：初始 3/20=15%，专精流第 8 关约 7.4/28=26%，
     按质量选牌约 5.0/28=18%。20% 这条线正好夹在中间：专精流第 3~4 关开始吃到，
     按质量选的普通玩家全程吃不到。
     幅度「血先走、攻跟上」：首版每档 +1/+1 递增实测过猛（专精 28%、军师叠加 38%）。 */
  var LAST_STAND_RATIO = [0.20, 0.25, 0.30];
  var LAST_STAND_BONUS = [[0, 1], [1, 1], [2, 2]];

  function lastStandTier(deck) {
    if (!deck || !deck.length) return 0;
    var Data = dataRef();
    if (!Data) return 0;
    var n = 0;
    for (var i = 0; i < deck.length; i++) {
      var c = Data.CARDS[deck[i]];
      if (c && c.deathrattle) n++;
    }
    var ratio = n / deck.length;
    var tier = 0;
    for (var s = 0; s < LAST_STAND_RATIO.length; s++) if (ratio >= LAST_STAND_RATIO[s]) tier = s + 1;
    return tier;
  }

  /* 档位 → [攻, 血]。拆成两个数字注入 rules，引擎不必知道档位表长什么样 */
  function lastStandBonus(deck) {
    var tier = lastStandTier(deck);
    return tier > 0 ? LAST_STAND_BONUS[tier - 1] : [0, 0];
  }

  /* 初阵档位（P3 难度宽容度）：新建战役时可选的宽容档，给不熟卡牌对战的玩家。
     跟存档走（progress.mode），中途不变；与心魔/天时叠加；
     敌方首回合军粮最低到 0（1 全局 - 1 初阵 - 1 霜降天时），不会为负。 */
  var CHUBEN_HP = 6;
  var CHUBEN_ENEMY_MANA = -1;

  /* 每关的重整机会：同一关兵败第二次即本局终结（牌组、进度一起作废）。
     判据：无穷重试让「19% 通关率」对真人等于 100%，run 一点风险都没有；
     给一次机会后，理论上限 = Π(1−(1−p)²) ≈ p×1.35，只抬高约 5pp，不破坏难度曲线。 */
  var RETRY_PER_STAGE = 1;

  function engineRules(stage, progress) {
    var r = {};
    for (var k in stage.rules) r[k] = stage.rules[k];
    if (stage.goal) r.goal = stage.goal;
    if (stage.goalTurns) r.goalTurns = stage.goalTurns;
    r.enemyStartMana = (r.enemyStartMana || 0) + GLOBAL_ENEMY_MANA;
    if (MANA_BOOST_STAGES[stage.id]) r.enemyStartMana += MANA_BOOST_STAGES[stage.id];
    if (GLOBAL_PLAYER_HP) r.playerHpBonus = (r.playerHpBonus || 0) + GLOBAL_PLAYER_HP;
    if (progress) {
      if (progress.advisor) {
        r.advisor = progress.advisor;
        /* 主动技跟着军师走：引擎只认规则里的这份数据，不反向依赖 campaign */
        var advDef = advisorById(progress.advisor);
        r.advisorActive = (advDef && advDef.active && ADVISOR_ACTIVE_ON) ? advDef.active : null;
      }
      /* 死战专精：只跟牌组，不跟军师。军师是「这一局怎么打」，专精是「我选了哪些牌」 */
      var lsb = lastStandBonus(progress.deck);
      r.lastStandTier = lastStandTier(progress.deck);
      r.lastStandAtk = lsb[0];
      r.lastStandHp = lsb[1];
      var hpBonus = progress.hpBonus || 0;
      /* 初阵档位：主将 +6 血、敌军首回合 -1 军粮，与心魔/天时叠加 */
      if (progress.mode === 'chuben') {
        hpBonus += CHUBEN_HP;
        r.enemyStartMana = (r.enemyStartMana || 0) + CHUBEN_ENEMY_MANA;
      }
      if (progress.manaBonus) r.playerStartMana = (r.playerStartMana || 0) + progress.manaBonus;
      if (progress.drawBonus) r.openingDraw = (r.openingDraw || 0) + progress.drawBonus;
      if (progress.enemyManaBonus) r.enemyStartMana = (r.enemyStartMana || 0) + progress.enemyManaBonus;
      /* 心魔（累计）+ 本局天时：两者都只改军粮与生命上限 */
      var ts = progress.tianShi ? tianshiById(progress.tianShi) : null;
      var layers = [ascensionMods(progress.ascension || 0), ts ? ts.mods : {}];
      layers.forEach(function (m) {
        if (m.playerStartMana) r.playerStartMana = (r.playerStartMana || 0) + m.playerStartMana;
        if (m.enemyStartMana) r.enemyStartMana = (r.enemyStartMana || 0) + m.enemyStartMana;
        if (m.openingDraw) r.openingDraw = (r.openingDraw || 0) + m.openingDraw;
        if (m.playerHpBonus) hpBonus += m.playerHpBonus;
      });
      if (hpBonus) r.playerHpBonus = hpBonus;
    }
    /* 加成钳到 ≥0：初阵(-1)与霜降天时(-1)叠加时把全局(+1)抵穿，按 0 算 */
    if (typeof r.enemyStartMana === 'number' && r.enemyStartMana < 0) r.enemyStartMana = 0;
    return r;
  }

  /* 用完即清的临时加成（战役每场战斗开打时调用） */
  function consumeBoosts(progress) {
    if (!progress) return;
    progress.manaBonus = 0;
    progress.drawBonus = 0;
    progress.enemyManaBonus = 0;
    save(progress);
  }

  /* 稀有度按费用分档：1 = 普通（≤2 费）/ 2 = 精良（3-4 费）/ 3 = 史诗（≥5 费） */
  function rarityOf(card) {
    var r = card.cost <= 2 ? 1 : card.cost <= 4 ? 2 : 3;
    /* 连击牌后置一档（P2）：它们全是低成本牌，若按费用分档会挤进第 1 关的三选一，
       把早期强牌稀释掉（实测随机玩家 -2pp）。后置后第 1 关池子不变，
       连击流从第 2 关开始成型——本来也是"先铺路再连击"的节奏。 */
    if (card.combo && r < 3) r = 3;
    return r;
  }

  /* 关卡可给的稀有度上限：越靠后的关卡池子越深 */
  function tierOf(stage) {
    if (typeof stage.tier === 'number') return stage.tier;
    var idx = stageIndex(stage.id);
    return idx <= 0 ? 1 : idx <= 2 ? 2 : 3;
  }

  /* 构筑规则：同名牌最多 2 张 */
  function deckCount(deck, id) {
    var n = 0;
    for (var i = 0; i < (deck || []).length; i++) if (deck[i] === id) n++;
    return n;
  }

  /* 全局可奖励卡池：
     - 按关卡稀有度上限过滤（越靠后越深）
     - 按玩家阵营过滤（汉营不出楚牌）
     - 同名不超过 2 张（与构筑规则一致）
     - 关卡自带的特色牌不受稀有度限制（那是设计者特意给的） */
  /* P2 连击 8 张：调参时用 CH_FILTER_NEW=1 把它们从奖励池排除，做同种子 A/B 对照。
     整轮通关率对"池子里有什么"很敏感（牌池一变，每次三选一的随机结果全变），
     不同 seed 单跑差异能到 7pp，必须同种子开关对照才看得出新卡的真实影响。*/
  var P2_NEW_CARDS = ['h_zhiji', 's_liannu', 's_lianhuan', 'h_qimen',
    'h_diezhen', 'h_jiewu', 'h_xiandeng', 's_lianying'];
  var FILTER_P2 = (typeof process !== 'undefined' && process.env
    && process.env.CH_FILTER_NEW === '1');

  function rewardPool(stage, heroFaction, deck, opts) {
    opts = opts || {};
    var Data = dataRef();
    if (!Data) return [];
    var tier = opts.tier || tierOf(stage);
    var want = opts.kind || null;       /* 'piece' / 'spell' / null */
    var out = [];
    function usable(id) {
      var c = Data.CARDS[id];
      if (!c || c.cost === 0 || id === 's_xianji') return false;   /* 先机虎符不入池 */
      if (FILTER_P2 && P2_NEW_CARDS.indexOf(id) >= 0) return false; /* 调参 A/B */
      if (want && c.type !== want) return false;
      var f = Data.factionOf(id);
      if (f !== 'neutral' && f !== heroFaction) return false;
      if (deckCount(deck, id) >= 2) return false;
      return true;
    }
    Object.keys(Data.CARDS).forEach(function (id) {
      if (!usable(id)) return;
      if (rarityOf(Data.CARDS[id]) > tier) return;
      out.push(id);
    });
    (stage.rewards || []).forEach(function (id) {
      if (usable(id) && out.indexOf(id) < 0) out.push(id);
    });
    return out;
  }

  /* 从奖励池里抽 n 张不重复的牌；关卡自带的特色牌（stage.rewards）会优先进入候选 */
  function rollRewards(stage, heroFaction, n, progress, opts) {
    opts = opts || {};
    var deck = (progress && progress.deck) || null;
    var pool = rewardPool(stage, heroFaction, deck, opts);
    if (!pool.length) return [];
    /* 特色牌有更高权重：先按 40% 概率替换一张普通候补 */
    var featured = (stage.rewards || []).filter(function (id) { return pool.indexOf(id) >= 0; });
    var copy = pool.slice();
    var out = [];
    var need = n || 3;
    while (out.length < need && copy.length > 0) {
      var pick;
      if (featured.length && Math.random() < 0.45) {
        var fi = Math.floor(Math.random() * featured.length);
        pick = featured[fi];
        featured.splice(fi, 1);
        if (copy.indexOf(pick) < 0) continue;
      } else {
        pick = copy[Math.floor(Math.random() * copy.length)];
      }
      out.push(pick);
      copy.splice(copy.indexOf(pick), 1);
    }
    /* 构筑引导（P2 连击）：牌组里已有 2 张连击牌时，三选一有 45% 概率替换一张为连击牌。
       实测（test/_probe-ratio.js combo 120 局）：不加这条时，刻意选连击的玩家八关下来
       牌组里也只有 1~2 张连击牌（占比 4%，P90 7%），combo 策略通关率 11% = 与随机无异。
       原因不是连击牌弱，是池里 7/75、三选一几乎刷不出来。
       只服务"已经在走这条路"的人：牌组不足 2 张连击牌时不触发，其余玩家的奖励不变。 */
    var Data2 = dataRef();
    if (deck && Data2 && out.length) {
      var cn = 0;
      for (var di = 0; di < deck.length; di++) {
        var dc = Data2.CARDS[deck[di]];
        if (dc && dc.combo) cn++;
      }
      if (cn >= 2 && Math.random() < 0.30) {
        var comboPool = pool.filter(function (id) {
          return Data2.CARDS[id] && Data2.CARDS[id].combo && out.indexOf(id) < 0;
        });
        if (comboPool.length) {
          out[Math.floor(Math.random() * out.length)] = comboPool[Math.floor(Math.random() * comboPool.length)];
        }
      }
    }
    return out;
  }

  /* ------------------------------------------------------------------
     军师 & 行军事件
  ------------------------------------------------------------------ */

  function advisorById(id) {
    for (var i = 0; i < ADVISORS.length; i++) if (ADVISORS[i].id === id) return ADVISORS[i];
    return null;
  }

  /* 随机抽 n 个军师供玩家挑选；pool 传已解锁 id 表（缺省 = 全部，调参工具用） */
  function rollAdvisors(n, pool) {
    var src = ADVISORS;
    if (pool) src = ADVISORS.filter(function (a) { return pool.indexOf(a.id) >= 0; });
    var copy = src.slice(), out = [];
    for (var i = 0; i < (n || 3) && copy.length > 0; i++) {
      var k = Math.floor(Math.random() * copy.length);
      out.push(copy[k]);
      copy.splice(k, 1);
    }
    return out;
  }

  function eventById(id) {
    for (var i = 0; i < EVENTS.length; i++) if (EVENTS[i].id === id) return EVENTS[i];
    return null;
  }

  /* 抽一个本局还没触发过的事件；都触发完了就从剩下的里随便挑（第二圈） */
  function pickEvent(progress, unlockedIds) {
    var used = (progress && progress.events) || [];
    var all = EVENTS;
    if (unlockedIds) all = EVENTS.filter(function (e) { return unlockedIds.indexOf(e.id) >= 0; });
    var fresh = all.filter(function (e) { return used.indexOf(e.id) < 0; });
    var pool = fresh.length ? fresh : all;
    return pool[Math.floor(Math.random() * pool.length)];
  }

  /* 关卡之间是否需要事件节点：通关后、且后面还有关卡 */
  function needsEvent(progress, stage) {
    if (!progress || !stage) return false;
    var idx = stageIndex(stage.id);
    return idx >= 0 && idx < STAGES.length - 1;
  }

  /* 结算一个事件选项，把结果写进进度并返回效果（UI 依 fx 决定后续弹窗）
     负数生命上限不会低于 -8，避免玩家把血扣成必败 */
  function applyEvent(progress, eventId, optionIndex) {
    var ev = eventById(eventId);
    if (!progress || !ev) return { ok: false, reason: '事件不存在' };
    var opt = ev.options[optionIndex];
    if (!opt) return { ok: false, reason: '选项不存在' };
    var fx = opt.fx || {};
    if (fx.hp) progress.hpBonus = Math.max(-8, (progress.hpBonus || 0) + fx.hp);
    if (fx.mana) progress.manaBonus = (progress.manaBonus || 0) + fx.mana;
    if (fx.draw) progress.drawBonus = (progress.drawBonus || 0) + fx.draw;
    if (fx.enemyMana) progress.enemyManaBonus = (progress.enemyManaBonus || 0) + fx.enemyMana;
    if (fx.removeRandom) {
      for (var i = 0; i < fx.removeRandom && progress.deck.length > 0; i++) {
        var k = Math.floor(Math.random() * progress.deck.length);
        progress.deck.splice(k, 1);
      }
    }
    if (progress.events.indexOf(ev.id) < 0) progress.events.push(ev.id);
    progress.eventLog.push({ id: ev.id, name: ev.name, choice: opt.label });
    if (progress.eventLog.length > 12) progress.eventLog.shift();
    save(progress);
    return { ok: true, fx: fx, event: ev, option: opt };
  }

  function isFinished(progress) {
    return !!progress && progress.cleared.length >= STAGES.length;
  }

  return {
    STAGES: STAGES,
    ADVISORS: ADVISORS,
    setAdvisorActive: setAdvisorActive,
    EVENTS: EVENTS,
    ASCENSION: ASCENSION,
    TIANSHI: TIANSHI,
    ascensionLevels: ascensionLevels,
    ascensionById: ascensionById,
    ascensionMods: ascensionMods,
    tianshiById: tianshiById,
    rollTianShi: rollTianShi,
    stageById: stageById,
    stageIndex: stageIndex,
    advisorById: advisorById,
    eventById: eventById,
    rollAdvisors: rollAdvisors,
    pickEvent: pickEvent,
    unlockState: unlockState,
    baseAdvisors: baseAdvisors,
    baseEvents: baseEvents,
    unlockLadder: unlockLadder,
    needsEvent: needsEvent,
    applyEvent: applyEvent,
    rarityOf: rarityOf,
    tierOf: tierOf,
    lastStandTier: lastStandTier,
    lastStandBonus: lastStandBonus,
    LAST_STAND_RATIO: LAST_STAND_RATIO,
    LAST_STAND_BONUS: LAST_STAND_BONUS,
    CHUBEN_HP: CHUBEN_HP,
    CHUBEN_ENEMY_MANA: CHUBEN_ENEMY_MANA,
    RETRY_PER_STAGE: RETRY_PER_STAGE,
    retryLeft: retryLeft,
    canRetry: canRetry,
    takeRetry: takeRetry,
    endRun: endRun,
    rewardPool: rewardPool,
    engineRules: engineRules,
    consumeBoosts: consumeBoosts,
    statusOf: statusOf,
    emptyProgress: emptyProgress,
    migrate: migrate,
    deckCount: deckCount,
    load: load,
    save: save,
    reset: reset,
    /* 多存档位 */
    SLOT_COUNT: SLOT_COUNT,
    slots: slots,
    useSlot: useSlot,
    clearSlot: clearSlot,
    activeSlot: activeSlot,
    slotSummary: slotSummary,
    _store: function () { return readStore(); },
    _resetStore: function () { memoryStore = null; try { localStorage.removeItem(SLOT_KEY); } catch (e) {} },
    start: start,
    clearStage: clearStage,
    rollRewards: rollRewards,
    isFinished: isFinished
  };
});
