/* 《楚汉·问鼎》图鉴 · 成就 · 战绩
   - 图鉴：按阵营/类型筛选全部卡牌，标出哪些已在战役牌组里
   - 成就：18 项，覆盖战阵 / 战役 / 阅历三类，达成即永久记录
   - 战绩：总场次、胜率、连胜、最高关卡、累计伤害等长期数据
   存档 key: chuhan_career_v1（localStorage 不可用时退内存副本） */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.Codex = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var SAVE_KEY = 'chuhan_career_v1';

  /* ------------------------------------------------------------------
     成就定义
     test(c, b)：c 是累计战绩，b 是刚结束的这一场（非战斗场景为 null）
     注意：判定基于“已累加”的战绩，所以判 c.wins >= 1 就等于“首胜”
  ------------------------------------------------------------------ */
  var ACHIEVEMENTS = [
    /* ---- 战阵：单场表现 ---- */
    {
      id: 'first_win', group: 'battle', glyph: '捷', name: '首战告捷',
      desc: '赢下第一场战斗。', test: function (c, b) { return b && b.win && c.wins >= 1; }
    },
    {
      id: 'flawless', group: 'battle', glyph: '全', name: '全师而归',
      desc: '一兵未折，以满血取胜。', test: function (c, b) { return b && b.win && b.hp >= b.maxHp; }
    },
    {
      id: 'last_stand', group: 'battle', glyph: '险', name: '背水一战',
      desc: '只剩 5 点血时反败为胜。', test: function (c, b) { return b && b.win && b.hp <= 5; }
    },
    {
      id: 'swift', group: 'battle', glyph: '速', name: '速战速决',
      desc: '12 个回合内结束战斗。', test: function (c, b) { return b && b.win && b.turns <= 12; }
    },
    {
      id: 'decapitate', group: 'battle', glyph: '斩', name: '直取黄龙',
      desc: '单场对敌方主将造成 20 点以上伤害。',
      test: function (c, b) { return b && (b.heroDmg || 0) >= 20; }
    },
    {
      id: 'army', group: 'battle', glyph: '军', name: '兵强马壮',
      desc: '单场派出 10 员兵将。', test: function (c, b) { return b && (b.units || 0) >= 10; }
    },
    {
      id: 'strategist', group: 'battle', glyph: '谋', name: '运筹帷幄',
      desc: '单场使用 6 张计谋牌。', test: function (c, b) { return b && (b.spells || 0) >= 6; }
    },
    {
      id: 'mingjiang', group: 'battle', glyph: '名', name: '力敌名将',
      desc: '在「名将」智力下取胜。',
      test: function (c, b) { return b && b.win && b.level === 'mingjiang'; }
    },

    /* ---- 战役：推进进度 ---- */
    {
      id: 'stage_1', group: 'campaign', glyph: '沛', name: '沛县起兵',
      desc: '通关第壹关「沛县起兵」。', test: function (c) { return (c.clearedCount || 0) >= 1; }
    },
    {
      id: 'stage_4', group: 'campaign', glyph: '荥', name: '挺进中原',
      desc: '通关第肆关「荥阳对峙」。', test: function (c) { return (c.clearedCount || 0) >= 4; }
    },
    {
      id: 'stage_all', group: 'campaign', glyph: '鼎', name: '问鼎中原',
      desc: '通关全部 8 关，走到垓下。', test: function (c) { return !!c.finished; }
    },
    {
      id: 'deck_26', group: 'campaign', glyph: '众', name: '兵多将广',
      desc: '把战役牌组养到 26 张。', test: function (c) { return (c.maxDeck || 0) >= 26; }
    },
    {
      id: 'two_heroes', group: 'campaign', glyph: '楚', name: '楚河汉界',
      desc: '刘邦与项羽各取胜一场。',
      test: function (c) {
        return !!(c.heroes && c.heroes.liubang > 0 && c.heroes.xiangyu > 0);
      }
    },

    /* ---- 阅历：长期积累 ---- */
    {
      id: 'veteran', group: 'career', glyph: '百', name: '百战之将',
      desc: '累计进行 20 场战斗。', test: function (c) { return (c.battles || 0) >= 20; }
    },
    {
      id: 'legend', group: 'career', glyph: '五', name: '五十战',
      desc: '累计进行 50 场战斗。', test: function (c) { return (c.battles || 0) >= 50; }
    },
    {
      id: 'streak_5', group: 'career', glyph: '连', name: '五连捷',
      desc: '连胜 5 场。', test: function (c) { return (c.bestStreak || 0) >= 5; }
    },
    {
      id: 'advisors_3', group: 'career', glyph: '师', name: '三军之师',
      desc: '用过 3 位不同的军师。',
      test: function (c) { return Object.keys(c.advisors || {}).length >= 3; }
    },
    {
      id: 'events_6', group: 'career', glyph: '行', name: '阅尽行军',
      desc: '经历 6 个不同的行军事件。',
      test: function (c) { return Object.keys(c.events || {}).length >= 6; }
    },
    {
      id: 'damage_500', group: 'career', glyph: '伤', name: '千里杀将',
      desc: '累计造成 500 点伤害。', test: function (c) { return (c.dmg || 0) >= 500; }
    }
  ];

  var GROUP_NAMES = { battle: '战阵', campaign: '战役', career: '阅历' };

  /* ------------------------------------------------------------------
     存档
  ------------------------------------------------------------------ */
  var memory = null;

  function emptyCareer() {
    return {
      version: 1,
      battles: 0, wins: 0, losses: 0,
      streak: 0, bestStreak: 0,
      turns: 0, dmg: 0, heroDmg: 0, units: 0, spells: 0,
      bestHpWin: null, fastestWin: null,
      levels: {},                 /* 各难度胜场 */
      heroes: {},                 /* 各主将胜场 */
      advisors: {},               /* 用过的军师 */
      events: {},                 /* 经历过的行军事件 */
      clearedStages: {},          /* 通关过的关卡（首次） */
      clearedCount: 0,
      maxStage: -1,
      maxStageId: null,
      maxDeck: 0,
      finished: false,
      ach: {},                    /* 已解锁成就 id */
      firstPlayed: null,
      lastPlayed: null
    };
  }

  function migrate(p) {
    if (!p || typeof p !== 'object') return null;
    if (typeof p.battles !== 'number') return null;
    var base = emptyCareer();
    for (var k in base) if (!(k in p)) p[k] = base[k];
    p.version = 1;
    return p;
  }

  function load() {
    try {
      var raw = localStorage.getItem(SAVE_KEY);
      if (raw) {
        var p = migrate(JSON.parse(raw));
        if (p) { memory = p; return p; }
      }
    } catch (e) { /* 读不到就用内存副本 */ }
    return memory;
  }

  function save(c) {
    memory = c;
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(c)); } catch (e) {}
  }

  function current() {
    var c = load();
    return c || emptyCareer();
  }

  function reset() {
    memory = null;
    try { localStorage.removeItem(SAVE_KEY); } catch (e) {}
  }

  /* ------------------------------------------------------------------
     成就判定
  ------------------------------------------------------------------ */
  function checkAll(c, b) {
    var out = [];
    ACHIEVEMENTS.forEach(function (a) {
      if (c.ach[a.id]) return;
      var ok = false;
      try { ok = a.test(c, b); } catch (e) { ok = false; }
      if (ok) { c.ach[a.id] = Date.now(); out.push(a); }
    });
    return out;
  }

  function unlockedCount(c) {
    return Object.keys((c || current()).ach || {}).length;
  }

  /* ------------------------------------------------------------------
     记录入口
  ------------------------------------------------------------------ */

  /* 一场战斗结束。b: {win, turns, hp, maxHp, heroId, level, dmg, heroDmg, units, spells} */
  function recordBattle(b) {
    var c = current();
    var now = Date.now();
    if (!c.firstPlayed) c.firstPlayed = now;
    c.lastPlayed = now;

    c.battles += 1;
    c.turns += b.turns || 0;
    c.dmg += b.dmg || 0;
    c.heroDmg += b.heroDmg || 0;
    c.units += b.units || 0;
    c.spells += b.spells || 0;

    if (b.win) {
      c.wins += 1;
      c.streak += 1;
      if (c.streak > c.bestStreak) c.bestStreak = c.streak;
      if (b.heroId) c.heroes[b.heroId] = (c.heroes[b.heroId] || 0) + 1;
      if (b.level) c.levels[b.level] = (c.levels[b.level] || 0) + 1;
      if (c.bestHpWin === null || b.hp < c.bestHpWin) c.bestHpWin = b.hp;
      if (c.fastestWin === null || b.turns < c.fastestWin) c.fastestWin = b.turns;
    } else {
      c.losses += 1;
      c.streak = 0;
    }

    var unlocked = checkAll(c, b);
    save(c);
    return { career: c, unlocked: unlocked };
  }

  /* 首次通关某关。idx 从 0 起，total 为关卡总数 */
  function recordClear(stageId, idx, deckSize, total) {
    var c = current();
    if (!c.clearedStages) c.clearedStages = {};
    var first = !c.clearedStages[stageId];
    if (first) {
      c.clearedStages[stageId] = Date.now();
      c.clearedCount = Object.keys(c.clearedStages).length;
      if (typeof idx === 'number' && idx > c.maxStage) {
        c.maxStage = idx;
        c.maxStageId = stageId;
      }
      if (total && c.clearedCount >= total) c.finished = true;
    }
    if (deckSize && deckSize > (c.maxDeck || 0)) c.maxDeck = deckSize;
    var unlocked = checkAll(c, null);
    save(c);
    return { career: c, unlocked: unlocked };
  }

  function recordAdvisor(id) {
    if (!id) return { unlocked: [] };
    var c = current();
    c.advisors[id] = (c.advisors[id] || 0) + 1;
    var unlocked = checkAll(c, null);
    save(c);
    return { career: c, unlocked: unlocked };
  }

  function recordEvent(id) {
    if (!id) return { unlocked: [] };
    var c = current();
    c.events[id] = (c.events[id] || 0) + 1;
    var unlocked = checkAll(c, null);
    save(c);
    return { career: c, unlocked: unlocked };
  }

  /* 战绩摘要（界面直接渲染） */
  function summary() {
    var c = current();
    return {
      battles: c.battles, wins: c.wins, losses: c.losses,
      winRate: c.battles ? Math.round(c.wins / c.battles * 100) : 0,
      streak: c.streak, bestStreak: c.bestStreak,
      turns: c.turns, dmg: c.dmg, heroDmg: c.heroDmg,
      units: c.units, spells: c.spells,
      bestHpWin: c.bestHpWin, fastestWin: c.fastestWin,
      clearedCount: c.clearedCount || 0,
      maxStage: c.maxStage, maxStageId: c.maxStageId,
      maxDeck: c.maxDeck || 0,
      finished: !!c.finished,
      advisors: Object.keys(c.advisors || {}).length,
      events: Object.keys(c.events || {}).length,
      heroes: c.heroes || {},
      levels: c.levels || {}
    };
  }

  /* ------------------------------------------------------------------
     图鉴筛选
     opts: { faction: 'all'|'neutral'|'han'|'chu', type: 'all'|'piece'|'spell' }
     需要外部传入 Data（本模块不依赖 data.js）
  ------------------------------------------------------------------ */
  function filterCards(Data, opts) {
    opts = opts || {};
    var faction = opts.faction || 'all';
    var type = opts.type || 'all';
    var out = [];
    Object.keys(Data.CARDS).forEach(function (id) {
      var c = Data.CARDS[id];
      if (!c || id === 's_xianji') return;          /* 先机虎符不算构筑卡 */
      if (type !== 'all' && c.type !== type) return;
      var f = Data.factionOf(id);
      if (faction !== 'all' && f !== faction) return;
      out.push(id);
    });
    out.sort(function (a, b) {
      var ca = Data.CARDS[a], cb = Data.CARDS[b];
      if (ca.cost !== cb.cost) return ca.cost - cb.cost;
      if (ca.type !== cb.type) return ca.type === 'piece' ? -1 : 1;
      return ca.name.localeCompare(cb.name, 'zh');
    });
    return out;
  }

  /* 卡池统计：总数 / 按阵营 / 按类型 */
  function cardStats(Data) {
    var all = filterCards(Data, {});
    var byFaction = { neutral: 0, han: 0, chu: 0 };
    var byType = { piece: 0, spell: 0 };
    all.forEach(function (id) {
      byFaction[Data.factionOf(id)]++;
      byType[Data.CARDS[id].type]++;
    });
    return { total: all.length, byFaction: byFaction, byType: byType };
  }

  return {
    ACHIEVEMENTS: ACHIEVEMENTS,
    GROUP_NAMES: GROUP_NAMES,
    emptyCareer: emptyCareer,
    current: current,
    load: load,
    save: save,
    reset: reset,
    recordBattle: recordBattle,
    recordClear: recordClear,
    recordAdvisor: recordAdvisor,
    recordEvent: recordEvent,
    unlockedCount: unlockedCount,
    summary: summary,
    filterCards: filterCards,
    cardStats: cardStats,
    isUnlocked: function (id) { return !!current().ach[id]; }
  };
});
