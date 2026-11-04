/* 《楚汉·问鼎》多语言核心
   - 数据层：把 lang-en.js 的文案按 id 覆盖到 Data / Campaign / Codex 对象上，
     原中文保存在对象 _zh 里，切回中文即恢复——渲染代码无需感知语言
   - UI 层：I18N.t('中文') 按整串查字典（支持 {a} 占位符），供动态拼接的界面文案用
   - 静态 DOM：I18N.applyDOM() 扫描文本节点与 title 属性做整串替换（带原文记忆，可来回切）
   存档 key: chuhan_lang */
(function (root) {
  'use strict';

  var STORE_KEY = 'chuhan_lang';
  var lang = 'zh';
  try {
    var saved = root.localStorage && root.localStorage.getItem(STORE_KEY);
    if (saved === 'en' || saved === 'zh') lang = saved;
  } catch (e) {}

  var listeners = [];
  var EN = null;          /* js/lang-en.js 注入的字典，结构见该文件头部注释 */
  var DICT = {};          /* UI 字典：中文（trim 后）→ 英文 */

  function t(src, vars) {
    if (!src) return src;
    var out = src;
    if (lang === 'en' && DICT) {
      var key = String(src).trim();
      if (Object.prototype.hasOwnProperty.call(DICT, key)) out = DICT[key];
    }
    if (vars) {
      out = out.replace(/\{(\w+)\}/g, function (m, k) {
        return vars[k] !== undefined ? vars[k] : m;
      });
    }
    return out;
  }

  /* ---------- 数据层覆盖 ---------- */

  /* 首次接触时把中文原文拍快照，之后可随意来回切 */
  function snap(obj, fields) {
    if (obj._zh) return;
    var z = {};
    for (var i = 0; i < fields.length; i++) z[fields[i]] = obj[fields[i]];
    obj._zh = z;
  }

  function pick(o, f, zhVal, en) {
    return (en && o && o[f] != null) ? o[f] : zhVal;
  }

  function applyData(l) {
    var en = l === 'en';
    var Data = root.Data || (typeof require !== 'undefined' ? require('./data.js') : null);
    if (!Data) return;
    var Campaign = root.Campaign || (typeof require !== 'undefined' ? require('./campaign.js') : null);
    var Codex = root.Codex || (typeof require !== 'undefined' ? require('./codex.js') : null);
    var Tut = root.Tutorial;
    if (!EN) return;

    /* 卡牌 */
    Object.keys(Data.CARDS).forEach(function (id) {
      var c = Data.CARDS[id];
      snap(c, ['name', 'desc']);
      var tr = EN.cards[id];
      c.name = pick(tr, 'name', c._zh.name, en);
      c.desc = pick(tr, 'desc', c._zh.desc, en);
    });

    /* 英雄（含技能） */
    Object.keys(Data.HEROES).forEach(function (id) {
      var h = Data.HEROES[id];
      snap(h, ['name', 'title', 'intro']);
      snap(h.skill, ['name', 'desc']);
      var tr = EN.heroes[id];
      h.name = pick(tr, 'name', h._zh.name, en);
      h.title = pick(tr, 'title', h._zh.title, en);
      h.intro = pick(tr, 'intro', h._zh.intro, en);
      var sk = tr && tr.skill;
      h.skill.name = sk ? (en ? sk.name : h.skill._zh.name) : h.skill._zh.name;
      h.skill.desc = sk ? (en ? sk.desc : h.skill._zh.desc) : h.skill._zh.desc;
    });

    /* 列名 */
    if (EN.ranks) {
      if (!Data.RANK_NAMES._zh) {
        Data.RANK_NAMES._zh = { front: Data.RANK_NAMES.front, mid: Data.RANK_NAMES.mid, back: Data.RANK_NAMES.back };
      }
      ['front', 'mid', 'back'].forEach(function (k) {
        Data.RANK_NAMES[k] = en ? (EN.ranks[k] || Data.RANK_NAMES._zh[k]) : Data.RANK_NAMES._zh[k];
      });
    }

    if (Campaign) {
      /* 关卡 */
      Campaign.STAGES.forEach(function (s) {
        snap(s, ['chapter', 'name', 'year', 'subtitle', 'lore', 'goalText']);
        var tr = EN.stages[s.id];
        s.chapter = pick(tr, 'chapter', s._zh.chapter, en);
        s.name = pick(tr, 'name', s._zh.name, en);
        s.year = pick(tr, 'year', s._zh.year, en);
        s.subtitle = pick(tr, 'subtitle', s._zh.subtitle, en);
        s.lore = pick(tr, 'lore', s._zh.lore, en);
        s.goalText = pick(tr, 'goalText', s._zh.goalText, en);
        if (s.enemy && s.enemy.meta) {
          snap(s.enemy.meta, ['name', 'title']);
          var em = tr && tr.enemy;
          s.enemy.meta.name = em ? (en ? em.name : s.enemy.meta._zh.name) : s.enemy.meta._zh.name;
          s.enemy.meta.title = em ? (en ? em.title : s.enemy.meta._zh.title) : s.enemy.meta._zh.title;
        }
      });
      /* 军师 */
      Campaign.ADVISORS.forEach(function (a) {
        snap(a, ['name', 'title', 'desc', 'flavor']);
        var tr = EN.advisors[a.id];
        a.name = pick(tr, 'name', a._zh.name, en);
        a.title = pick(tr, 'title', a._zh.title, en);
        a.desc = pick(tr, 'desc', a._zh.desc, en);
        a.flavor = pick(tr, 'flavor', a._zh.flavor, en);
      });
      /* 行军事件 */
      Campaign.EVENTS.forEach(function (ev) {
        snap(ev, ['name', 'text']);
        ev.options.forEach(function (o) { snap(o, ['label', 'hint']); });
        var tr = EN.events[ev.id];
        ev.name = pick(tr, 'name', ev._zh.name, en);
        ev.text = pick(tr, 'text', ev._zh.text, en);
        (tr && tr.options ? tr.options : []).forEach(function (o, i) {
          if (!ev.options[i]) return;
          ev.options[i].label = en ? o.label : ev.options[i]._zh.label;
          ev.options[i].hint = en ? o.hint : ev.options[i]._zh.hint;
        });
      });
    }

    if (Codex) {
      /* 成就 */
      Codex.ACHIEVEMENTS.forEach(function (a) {
        snap(a, ['name', 'desc']);
        var tr = EN.achievements[a.id];
        a.name = pick(tr, 'name', a._zh.name, en);
        a.desc = pick(tr, 'desc', a._zh.desc, en);
      });
      if (EN.groups) {
        if (!Codex.GROUP_NAMES._zh) Codex.GROUP_NAMES._zh = {
          battle: Codex.GROUP_NAMES.battle, campaign: Codex.GROUP_NAMES.campaign, career: Codex.GROUP_NAMES.career
        };
        ['battle', 'campaign', 'career'].forEach(function (k) {
          Codex.GROUP_NAMES[k] = en ? (EN.groups[k] || Codex.GROUP_NAMES._zh[k]) : Codex.GROUP_NAMES._zh[k];
        });
      }
    }

    /* 关键词释义（引导气泡）：key 也要按语言换，牌面描述里的词才能对上 */
    if (Tut && EN.keywords) {
      if (!Tut.KEYWORDS._zh) Tut.KEYWORDS._zh = (function () {
        var z = {}; for (var k in Tut.KEYWORDS) if (Tut.KEYWORDS.hasOwnProperty(k) && k !== '_zh') z[k] = Tut.KEYWORDS[k]; return z;
      })();
      /* 清掉旧语言的键，写入新语言的键 */
      Object.keys(Tut.KEYWORDS).forEach(function (k) { if (k !== '_zh') delete Tut.KEYWORDS[k]; });
      var src = en ? EN.keywords : Tut.KEYWORDS._zh;
      for (var k in src) if (src.hasOwnProperty(k)) Tut.KEYWORDS[k] = src[k];
      Tut.setKeywordList(en ? EN.keywordList : null);   /* null = 用默认中文列表 */
    }
  }

  /* ---------- 静态 DOM 翻译（整串匹配，带原文记忆） ---------- */

  function hasCJK(s) { return /[\u4e00-\u9fff]/.test(s); }

  function applyDOM(rootEl) {
    if (typeof document === 'undefined') return;
    var scope = rootEl || document.body;
    if (!scope) return;
    var w = document.createTreeWalker(scope, NodeFilter.SHOW_TEXT, null, false);
    var nodes = [];
    while (w.nextNode()) nodes.push(w.currentNode);
    nodes.forEach(function (n) {
      if (n._i18nZh === undefined) n._i18nZh = n.nodeValue;
      if (!n._i18nZh) return;
      if (lang === 'en') {
        var key = n._i18nZh.trim();
        if (key && Object.prototype.hasOwnProperty.call(DICT, key)) {
          /* 保留原文前后的空白，避免破坏排版 */
          var lead = n._i18nZh.match(/^\s*/)[0], tail = n._i18nZh.match(/\s*$/)[0];
          n.nodeValue = lead + DICT[key] + tail;
        }
      } else {
        n.nodeValue = n._i18nZh;
      }
    });
    /* title / placeholder 属性 */
    var els = scope.querySelectorAll ? scope.querySelectorAll('[title],[placeholder]') : [];
    Array.prototype.forEach.call(els, function (el) {
      ['title', 'placeholder'].forEach(function (attr) {
        var v = el.getAttribute(attr);
        if (!v || !hasCJK(v)) return;
        if (el._i18nZhA === undefined) el._i18nZhA = {};
        if (el._i18nZhA[attr] === undefined) el._i18nZhA[attr] = v;
        var key = el._i18nZhA[attr].trim();
        if (lang === 'en' && Object.prototype.hasOwnProperty.call(DICT, key)) {
          el.setAttribute(attr, DICT[key]);
        } else if (lang !== 'en') {
          el.setAttribute(attr, el._i18nZhA[attr]);
        }
      });
    });
    /* <title> 标签 */
    if (!rootEl && document.title) {
      if (document._i18nZhTitle === undefined) document._i18nZhTitle = document.title;
      var tk = document._i18nZhTitle.trim();
      document.title = (lang === 'en' && DICT[tk]) ? DICT[tk] : document._i18nZhTitle;
    }
  }

  /* ---------- 对外 API ---------- */

  /* 引擎战报（保留中文协议）→ 显示层翻译；卡名/列名/人名已被数据层本地化 */
  function matchAll(patterns, s) {
    if (lang !== 'en' || !EN) return s;
    for (var i = 0; i < patterns.length; i++) {
      var m = s.match(patterns[i][0]);
      if (m) return patterns[i][1](m);
    }
    return s;
  }

  function setLang(l, opts) {
    if (l !== 'zh' && l !== 'en') return false;
    if (l === lang && !(opts && opts.force)) return true;
    lang = l;
    try { root.localStorage.setItem(STORE_KEY, l); } catch (e) {}
    if (EN) applyData(lang);
    listeners.forEach(function (fn) {
      try { fn(lang); } catch (e) {}
    });
    if (typeof document !== 'undefined' && !(opts && opts.noDom)) applyDOM();
    return true;
  }

  root.I18N = {
    t: t,
    trLog: function (line) { return EN && EN.logPatterns ? matchAll(EN.logPatterns, line) : line; },
    trReason: function (r) { return EN && EN.reasons ? matchAll(EN.reasons, r) : r; },
    glyph: function (ch) {
      return (lang === 'en' && EN && EN.glyphs && EN.glyphs[ch]) ? EN.glyphs[ch] : ch;
    },
    lang: function () { return lang; },
    isEN: function () { return lang === 'en'; },
    setLang: setLang,
    applyData: function () { applyData(lang); },
    applyDOM: applyDOM,
    onChange: function (fn) { listeners.push(fn); },
    /* js/lang-en.js 调用：注入字典并立即生效 */
    load: function (dict) {
      EN = dict;
      DICT = dict.ui || {};
      applyData(lang);
      if (typeof document !== 'undefined') applyDOM();
    },
    /* 测试用 */
    _dict: function () { return DICT; },
    _en: function () { return EN; }
  };
  /* node（require）与浏览器（全局）双通道 */
  if (typeof module === 'object' && module.exports) module.exports = root.I18N;
})(typeof self !== 'undefined' ? self : (typeof globalThis !== 'undefined' ? globalThis : this));
