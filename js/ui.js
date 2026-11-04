/* 《楚汉·问鼎》界面交互与渲染（M1） */
(function () {
  'use strict';

  var Engine = window.Engine, Data = window.Data, AI = window.AI, SFX = window.SFX;
  var Campaign = window.Campaign, Tut = window.Tutorial, Codex = window.Codex;
  var RANKS = ['front', 'mid', 'back'];

  var pickedHero = null;
  var aiLevel = 'bijiang';
  var state = null;
  var selectedUid = null;   /* 已选中的我方可攻击单位 */
  var busy = false;         /* AI 行动中 / 动画中 */
  var lastSnap = null;      /* 上一帧快照（驱动受击/入场动画） */
  var pendingFx = null;     /* 待播放的攻击特效 {attacker, attack} */
  var mullPicked = {};      /* 换牌阶段选中的 uid */

  var campaignRun = null;   /* 非空表示当前对局属于战役，值为 { stage } */
  var pendingStage = null;  /* 战前剧情里待出战的关卡 */
  var pendingRewards = [];  /* 战后三选一的候选牌 */

  /* ---------- 工具 ---------- */
  var T = (typeof I18N !== 'undefined') ? I18N.t : function (x) { return x; };

  function $(sel) { return document.querySelector(sel); }
  function $all(sel) { return Array.prototype.slice.call(document.querySelectorAll(sel)); }

  function showToast(text) {
    var t = $('#toast');
    t.textContent = text;
    t.classList.add('show');
    setTimeout(function () { t.classList.remove('show'); }, 1400);
  }

  function showBanner(text) {
    var b = $('#turn-banner');
    b.textContent = text;
    b.classList.add('show');
    setTimeout(function () { b.classList.remove('show'); }, 900);
  }

  function isPlayerTurn() {
    return state && !state.over && state.current === 'p1' && !busy && state.phase === 'play';
  }

  /* ---------- 音效开关 ---------- */

  function setMusic(scene) {
    try { if (SFX && SFX.music) SFX.music(scene); } catch (e) {}
  }

  function updateMuteBtn() {
    var b = $('#btn-mute');
    if (b) b.textContent = SFX.muted() ? '🔇' : '🔊';
    var t = $('#set-mute');
    if (t) {
      t.textContent = SFX.muted() ? T('开') : T('关');
      t.classList.toggle('on', SFX.muted());
    }
  }
  (function () {
    var b = $('#btn-mute');
    if (b) b.addEventListener('click', function () { SFX.toggle(); updateMuteBtn(); });
    updateMuteBtn();
  })();

  /* ---------- 设置面板（音量 / 静音 / 动效 / 全屏） ---------- */

  var SET_KEY = 'chuhan_settings';
  var settings = { motion: true };
  try {
    var savedSet = JSON.parse(localStorage.getItem(SET_KEY) || '{}');
    if (typeof savedSet.motion === 'boolean') settings.motion = savedSet.motion;
  } catch (e) {}

  function saveSettings() {
    try { localStorage.setItem(SET_KEY, JSON.stringify(settings)); } catch (e) {}
  }

  function applyMotionSetting() {
    document.body.classList.toggle('reduce-motion', !settings.motion);
    var b = $('#set-motion');
    if (b) {
      b.textContent = settings.motion ? T('开') : T('关');
      b.classList.toggle('on', settings.motion);
    }
  }

  function syncVolumeUI() {
    var v = SFX.volume ? SFX.volume() : { bgm: 0.6, sfx: 0.8 };
    var bgm = $('#set-bgm'), sfx = $('#set-sfx');
    if (bgm) { bgm.value = Math.round(v.bgm * 100); $('#set-bgm-val').textContent = Math.round(v.bgm * 100); }
    if (sfx) { sfx.value = Math.round(v.sfx * 100); $('#set-sfx-val').textContent = Math.round(v.sfx * 100); }
  }

  function toggleFullscreen() {
    if (window.Desktop && window.Desktop.toggleFullscreen) {
      /* Electron：走原生全屏，随后向主进程核实状态 */
      window.Desktop.toggleFullscreen().then(function () { setTimeout(syncFullscreenUI, 150); });
      return;
    }
    try {
      if (document.fullscreenElement || document.webkitFullscreenElement) {
        (document.exitFullscreen || document.webkitExitFullscreen || function () {}).call(document);
      } else {
        var de = document.documentElement;
        (de.requestFullscreen || de.webkitRequestFullscreen || function () {}).call(de);
      }
    } catch (e) {}
    setTimeout(syncFullscreenUI, 120);
  }

  function syncFullscreenUI() {
    var b = $('#set-fs');
    if (!b) return;
    if (window.Desktop && window.Desktop.fullscreenState) {
      window.Desktop.fullscreenState().then(function (on) {
        b.textContent = on ? T('开') : T('关');
        b.classList.toggle('on', !!on);
      });
      return;
    }
    var on = !!(document.fullscreenElement || document.webkitFullscreenElement);
    b.textContent = on ? T('开') : T('关');
    b.classList.toggle('on', on);
  }

  function openSettings() {
    syncVolumeUI();
    syncFullscreenUI();
    applyMotionSetting();
    updateMuteBtn();
    $('#settings-screen').classList.remove('hidden');
  }

  function closeSettings() {
    $('#settings-screen').classList.add('hidden');
  }

  (function () {
    var btn = $('#btn-settings');
    if (btn) btn.addEventListener('click', function () { openSettings(); SFX.play('click'); });
    var close = $('#set-close');
    if (close) close.addEventListener('click', function () { closeSettings(); SFX.play('click'); });
    var wrap = $('#settings-screen');
    if (wrap) wrap.addEventListener('click', function (ev) {
      if (ev.target === wrap) closeSettings();   /* 点遮罩空白处关闭 */
    });
    ['bgm', 'sfx'].forEach(function (kind) {
      var el = $('#set-' + kind);
      if (!el) return;
      el.addEventListener('input', function () {
        var v = Number(el.value) / 100;
        if (SFX.setVolume) SFX.setVolume(kind, v);
        $('#set-' + kind + '-val').textContent = el.value;
        if (kind === 'sfx') SFX.play('tick');   /* 拖音效条时即时试听 */
      });
    });
    var muteBtn = $('#set-mute');
    if (muteBtn) muteBtn.addEventListener('click', function () { SFX.toggle(); updateMuteBtn(); });
    var motionBtn = $('#set-motion');
    if (motionBtn) motionBtn.addEventListener('click', function () {
      settings.motion = !settings.motion;
      saveSettings();
      applyMotionSetting();
    });
    var fsBtn = $('#set-fs');
    if (fsBtn) fsBtn.addEventListener('click', function () { toggleFullscreen(); });
    document.addEventListener('fullscreenchange', syncFullscreenUI);
    document.addEventListener('webkitfullscreenchange', syncFullscreenUI);
    document.addEventListener('keydown', function (ev) {
      if (ev.key === 'Escape' && !$('#settings-screen').classList.contains('hidden')) closeSettings();
    });
    applyMotionSetting();
  })();

  /* ---------- 语言切换（中文 / English） ---------- */

  function syncLangUI() {
    var en = I18N.isEN();
    $all('.lang-btn').forEach(function (b) {
      b.classList.toggle('selected', (b.getAttribute('data-lang') === 'en') === en);
    });
  }

  /* 切语言后把「活着的界面」全部按新语言重画一遍 */
  function reapplyI18N() {
    document.body.classList.toggle('lang-en', I18N.isEN());
    if (state && !$('#game-screen').classList.contains('hidden')) render();
    if (!$('#campaign-screen').classList.contains('hidden')) renderCampaignMap(Campaign.load());
    if (!$('#slots-screen').classList.contains('hidden')) renderSlots();
    if (!$('#codex-screen').classList.contains('hidden')) openCodex(codexTab);
    syncVolumeUI();
    syncFullscreenUI();
    updateMuteBtn();
    applyMotionSetting();
    syncLangUI();
    I18N.applyDOM();          /* 静态屏（主菜单 / 说明 / 换牌等） */
  }

  $all('.lang-btn').forEach(function (b) {
    b.addEventListener('click', function () {
      var l = b.getAttribute('data-lang');
      if ((l === 'en') === I18N.isEN()) return;
      SFX.play('click');
      I18N.setLang(l);
      reapplyI18N();
    });
  });

  document.body.classList.toggle('lang-en', I18N.isEN());
  syncLangUI();

  /* 通用点击反馈音：任何按钮/链接/可点卡牌都有一记极轻的「嗒」 */
  (function () {
    var lastTick = 0;
    document.addEventListener('click', function (ev) {
      var t = ev.target;
      if (!t || !t.closest) return;
      if (!t.closest('button, a, .hero-card, .stage-node, .adv-card, .diff-btn, .filter-btn, .codex-tab, .set-toggle, input[type=range]')) return;
      var now = Date.now();
      if (now - lastTick < 45) return;
      lastTick = now;
      SFX.play('tick');
    }, true);
  })();

  /* ---------- 战斗特效辅助 ---------- */

  function artOf(id) { return Data.ART[id] ? 'assets/cards/' + id + '.png' : null; }

  function flash() {
    var f = $('#fx-flash');
    if (!f) return;
    f.classList.remove('show');
    void f.offsetWidth;
    f.classList.add('show');
  }

  function spawnFloat(el, text, cls) {
    if (!el) return;
    var d = document.createElement('div');
    d.className = 'float-dmg' + (cls ? ' ' + cls : '');
    d.textContent = text;
    el.appendChild(d);
    setTimeout(function () { if (d.parentNode) d.parentNode.removeChild(d); }, 950);
  }

  /* 对局快照：比较两次渲染之间的血量/攻击变化，驱动受击与入场动画 */
  function computeSnap(s) {
    var units = {}, heroes = { p1: s.players.p1.hp, p2: s.players.p2.hp };
    var hands = { p1: s.players.p1.hand.length, p2: s.players.p2.hand.length };
    ['p1', 'p2'].forEach(function (pid) {
      RANKS.forEach(function (r) {
        s.players[pid].board[r].forEach(function (u) {
          units[u.uid] = { hp: u.hp, atk: u.atk };
        });
      });
    });
    return { units: units, heroes: heroes, hands: hands };
  }

  /* ---------- 卡牌悬停放大预览 ---------- */

  var pvEl = null;

  function cardPreviewHTML(c) {
    var spellCls = c.type === 'spell' ? ' spell-card' : '';
    var hasArt = artOf(c.baseId || c.id) ? ' has-art' : '';
    return '<div class="card' + spellCls + hasArt + '">' +
      '<div class="cost">' + c.cost + '</div>' +
      artOrGlyph(c) +
      '<div class="cname">' + c.name + '</div>' +
      '<div class="cdesc">' + Tut.markKeywords(c.desc) + '</div>' +
      (c.type === 'piece' ? '<div class="atk">' + c.atk + '</div><div class="hpu">' + c.hp + '</div>' : '') +
      '</div>';
  }

  function showPreview(c, ev) {
    if (!c || !pvEl) return;
    pvEl.innerHTML = cardPreviewHTML(c);
    pvEl.classList.add('show');
    var w = 210, h = 288;
    var x = Math.min(window.innerWidth - w - 12, Math.max(12, (ev.clientX || 0) - w / 2));
    var y = Math.max(12, (ev.clientY || 0) - h - 18);
    pvEl.style.left = x + 'px';
    pvEl.style.top = y + 'px';
  }

  function hidePreview() { if (pvEl) pvEl.classList.remove('show'); }

  /* ---------- 战报文字条 ---------- */

  var lastLogTail = '';

  function showCallout(text) {
    var el = $('#callout');
    if (!el) return;
    el.textContent = text;
    el.classList.remove('show');
    void el.offsetWidth;
    el.classList.add('show');
  }

  /* 悬停预览：手牌 / 换牌 / 构筑 / 战场单位 */
  pvEl = $('#card-preview');
  document.addEventListener('mouseover', function (ev) {
    var t = ev.target;
    if (!t || !t.closest) { hidePreview(); return; }
    var mull = t.closest('#mulligan-cards .mull-card');
    if (mull && state) {
      var muid = parseInt(mull.getAttribute('data-uid'), 10), mc = null;
      state.players.p1.hand.forEach(function (x) { if (x.uid === muid) mc = x; });
      if (mc) return showPreview(mc, ev);
    }
    var hc = t.closest('#hand .card');
    if (hc && state) {
      var cv = state.players.p1.hand[parseInt(hc.getAttribute('data-idx'), 10)];
      if (cv) return showPreview(cv, ev);
    }
    var dc = t.closest('#deck-pool .deck-card, #codex-grid .codex-card');
    if (dc) {
      var dcCard = Data.CARDS[dc.getAttribute('data-id')];
      if (dcCard) return showPreview(dcCard, ev);
    }
    var ue = t.closest('.unit:not(.empty-slot)');
    if (ue && state) {
      var side = ue.getAttribute('data-side');
      var uu = findUnit(side === 'player' ? state.players.p1 : state.players.p2,
        parseInt(ue.getAttribute('data-uid'), 10));
      if (uu) {
        return showPreview({
          baseId: uu.baseId, glyph: uu.glyph, name: uu.name, type: uu.type,
          cost: uu.cost, desc: uu.desc, atk: uu.atk, hp: uu.hp
        }, ev);
      }
    }
    hidePreview();
  });
  document.addEventListener('mouseout', function (ev) {
    if (!ev.target || !ev.target.closest) return;
    var from = ev.target.closest('#hand .card, #deck-pool .deck-card, #codex-grid .codex-card, #mulligan-cards .mull-card, .unit');
    if (!from) return;
    /* 只是移动到同一张卡内部的其他元素时，不隐藏（否则会闪烁） */
    if (ev.relatedTarget && from.contains(ev.relatedTarget)) return;
    hidePreview();
  });

  function setHeroArt(el, heroId, artOverride) {
    if (!el) return;
    /* 敌将专属头像（战役 meta.art）优先于英雄默认立绘 */
    if (artOverride && Data.UI_ART && Data.UI_ART.heroes[artOverride]) {
      el.classList.add('has-art');
      el.style.backgroundImage = 'url(\'assets/cards/' + artOverride + '.png\')';
      return;
    }
    if (Data.HERO_ART[heroId]) {
      el.classList.add('has-art');
      el.style.backgroundImage = 'url(\'assets/cards/' + heroId + '.png\')';
    } else {
      el.classList.remove('has-art');
      el.style.backgroundImage = '';
    }
  }

  /* glyph 或立绘：有立绘用 <div class="art">，否则用文字 glyph */
  function artOrGlyph(c) {
    var art = artOf(c.baseId || c.id);
    if (art) return '<div class="art" style="background-image:url(\'' + art + '\')"></div>';
    return '<div class="glyph">' + c.glyph + '</div>';
  }

  /* ---------- 开局界面 ---------- */

  /* 开局选将页的英雄头像立绘 */
  $all('.hero-card').forEach(function (el) {
    var hid = el.getAttribute('data-hero');
    var av = el.querySelector('.hero-avatar');
    if (av) setHeroArt(av, hid);
  });

  $all('.hero-card').forEach(function (el) {
    el.addEventListener('click', function () {
      $all('.hero-card').forEach(function (c) { c.classList.remove('selected'); });
      el.classList.add('selected');
      pickedHero = el.getAttribute('data-hero');
      $('#btn-start').disabled = false;
      $('#btn-deckbuilder').disabled = false;
    });
  });

  $all('.diff-btn').forEach(function (el) {
    el.addEventListener('click', function () {
      $all('.diff-btn').forEach(function (c) { c.classList.remove('selected'); });
      el.classList.add('selected');
      aiLevel = el.getAttribute('data-level');
    });
  });

  /* ---------- 玩法说明 ---------- */

  $('#link-help').addEventListener('click', function () {
    $('#help-screen').classList.remove('hidden');
  });
  $('#link-codex').addEventListener('click', function () { openCodex('cards'); });
  $('#link-slots').addEventListener('click', function () { openSlots(); });
  $('#btn-help-close').addEventListener('click', function () {
    $('#help-screen').classList.add('hidden');
  });

  /* 重看引导：清掉引导与提示的一次性标记，下一局开场重新走一遍 */
  $('#link-replay-tut').addEventListener('click', function () {
    Tut.reset();
    showToast(T('已重置，下一局开场会重新引导'));
  });

  /* ---------- 开战 ---------- */

  /* 隐藏所有界面（开局页 / 牌库 / 战役地图 / 剧情 / 奖励 / 结算 / 换牌 / 对局） */
  function hideAllScreens() {
    ['#start-screen', '#deck-screen', '#campaign-screen', '#lore-screen',
      '#reward-screen', '#over-screen', '#mulligan-screen', '#game-screen',
      '#advisor-screen', '#event-screen', '#pick-screen', '#codex-screen', '#settings-screen',
      '#slots-screen'
    ].forEach(function (sel) {
      var el = $(sel);
      if (el) el.classList.add('hidden');
    });
    try { window.scrollTo(0, 0); } catch (e) {}
    if (Tut && Tut.active()) Tut.stop();
  }

  /* 通用开局：标准模式与战役模式共用 */
  function startBattle(cfg) {
    var first = Math.random() < 0.5 ? 'p1' : 'p2';
    var opts = {};
    if (cfg.rules) opts.rules = cfg.rules;
    if (cfg.enemyMeta) opts.p2Meta = cfg.enemyMeta;
    state = Engine.newGame(cfg.heroId, cfg.enemyHeroId, first, cfg.aiLevel,
      { p1: cfg.deck || null }, opts);
    selectedUid = null;
    lastSnap = null;
    pendingFx = null;
    lastLogTail = '';
    endConfirmUntil = 0;
    renderOverAchievements([]);
    hideAllScreens();
    $('#game-screen').classList.remove('hidden');
    setMusic('battle');
    render();
    if (state.phase === 'mulligan') { openMulligan(); return; }
    beginPlay();
  }

  function launchGame(playerDeck) {
    startBattle({
      heroId: pickedHero,
      enemyHeroId: pickedHero === 'liubang' ? 'xiangyu' : 'liubang',
      aiLevel: aiLevel,
      deck: playerDeck || null
    });
  }

  /* 换牌结束 / 无换牌阶段时正式开局 */
  function beginPlay() {
    Engine.beginGame(state);
    lastSnap = null;
    render();
    showBanner(state.current === 'p1' ? T('我 方 回 合') : T('敌 方 回 合'));
    SFX.play('turn');
    if (state.current === 'p2') scheduleAI();
    else maybeIntro();
  }

  /* ---------- 新手引导 ---------- */

  var INTRO_FLAG = 'battleIntro';

  /* 六步走完一局的完整循环：看到对手 → 认识军粮 → 出牌 → 攻击规则 → 技能 → 结束回合 */
  function introSteps() {
    return [
      {
        sel: '#enemy-avatar', title: T('这就是你的对手'),
        text: T('把敌方主将的血量打到 0 就赢了。反过来，你的主将一死，仗就打输了。')
      },
      {
        sel: '#player-mana', title: T('军粮就是出牌的费用'),
        text: T('第 1 回合 1 点，第 2 回合 2 点……每回合上限加 1（最多 10），开局回满。这里的「当前/上限」就是你现在有多少粮。')
      },
      {
        sel: '#hand', title: T('点一张牌，它就下场'),
        text: T('亮着的牌现在就能出；灰掉的是军粮不够，或者那一列已经站满 3 员。点一张试试。'),
        advanceOn: '#hand .card:not(.unplayable)'
      },
      {
        sel: '.rank-row[data-side="player"][data-rank="front"]', title: T('兵种下场要等一回合'),
        text: T('刚登场的兵种当回合不能攻击（带「冲锋」的除外）。到你的下一回合，它会亮起绿光——点它，再点敌人，就是一次进攻。')
      },
      {
        sel: '#btn-skill', title: T('别忘了主将技能'),
        text: T('每回合能用一次。刘邦「约法三章」回血续航，项羽「破釜沉舟」横扫敌方前锋——关键时刻能翻盘。')
      },
      {
        sel: '#btn-end', title: T('打完就交给对面'),
        text: T('手里还有能出的牌、或还有能攻击的部队时，会先提醒你一次，再点才真的结束回合。')
      }
    ];
  }

  /* 只在玩家的第一个回合开场时走一次，敌人先手就等它打完 */
  function maybeIntro() {
    if (!state || state.over || state.phase !== 'play') return;
    if (state.current !== 'p1') return;
    if (Tut.done(INTRO_FLAG) || Tut.active()) return;
    Tut.start(introSteps(), { flag: INTRO_FLAG });
  }

  /* 规则首次触发时说一句，避免"点了没反应"的困惑 */
  function hintFor(reason) {
    if (!reason) return false;
    if (reason === '军粮不足') {
      return Tut.hint('noMana', T('军粮不够。每回合上限 +1，撑到下个回合就出得起了。'));
    }
    if (reason === '该单位本回合不能攻击') {
      return Tut.hint('sick', T('它这一回合还不能攻击：刚登场，或者已经出手过了。'));
    }
    if (reason.indexOf('挡路') >= 0) {
      return Tut.hint('blocked', T('敌方最靠前的那一列还没清空，暂时打不到后面的部队。'));
    }
    if (reason.indexOf('已满') >= 0) {
      return Tut.hint('full', T('每列最多站 {n} 员。先打完这一列，或把牌出到别的列。', { n: Data.COLUMN_LIMIT }));
    }
    return false;
  }

  /* ---------- 开局换牌 ---------- */

  function mullCardHTML(c) {
    var spellCls = c.type === 'spell' ? ' spell-card' : '';
    var hasArt = artOf(c.baseId || c.id) ? ' has-art' : '';
    return '<div class="mull-card' + (mullPicked[c.uid] ? ' picked' : '') + '" data-uid="' + c.uid + '">' +
      '<div class="card' + spellCls + hasArt + '">' +
      '<div class="cost">' + c.cost + '</div>' +
      artOrGlyph(c) +
      '<div class="cname">' + c.name + '</div>' +
      '<div class="cdesc">' + Tut.markKeywords(c.desc) + '</div>' +
      (c.type === 'piece' ? '<div class="atk">' + c.atk + '</div><div class="hpu">' + c.hp + '</div>' : '') +
      '</div></div>';
  }

  function renderMulligan() {
    var html = '';
    state.players.p1.hand.forEach(function (c) { html += mullCardHTML(c); });
    $('#mulligan-cards').innerHTML = html;
  }

  function openMulligan() {
    mullPicked = {};
    renderMulligan();
    $('#mulligan-screen').classList.remove('hidden');
  }

  function confirmMulligan(uids) {
    if (!state || state.phase !== 'mulligan') return;
    Engine.doMulligan(state, 'p1', uids);
    Engine.doMulligan(state, 'p2', AI.aiMulligan(state, 'p2'));
    SFX.play('draw');
    $('#mulligan-screen').classList.add('hidden');
    beginPlay();
  }

  $('#mulligan-cards').addEventListener('click', function (ev) {
    var el = ev.target.closest('.mull-card');
    if (!el) return;
    var uid = parseInt(el.getAttribute('data-uid'), 10);
    if (mullPicked[uid]) delete mullPicked[uid];
    else mullPicked[uid] = true;
    SFX.play('click');
    renderMulligan();
  });

  $('#btn-mull-ok').addEventListener('click', function () {
    confirmMulligan(Object.keys(mullPicked).map(Number));
  });

  $('#btn-mull-keep').addEventListener('click', function () {
    confirmMulligan([]);
  });

  function savedDeckOf(heroId) {
    try {
      var raw = localStorage.getItem('chuhan_deck_' + heroId);
      var arr = raw ? JSON.parse(raw) : null;
      return (Array.isArray(arr) && arr.length === 20) ? arr : null;
    } catch (e) { return null; }
  }

  $('#btn-start').addEventListener('click', function () {
    if (!pickedHero) return;
    launchGame(savedDeckOf(pickedHero)); /* 有自定义牌库就用它，否则用官方预组 */
  });

  $('#btn-again').addEventListener('click', function () {
    /* 战役失败：重试本关（保留战役牌组与进度） */
    if (campaignRun && campaignRun.stage) {
      var stage = campaignRun.stage;
      $('#over-screen').classList.add('hidden');
      launchStage(stage);
      return;
    }
    $('#over-screen').classList.add('hidden');
    $('#game-screen').classList.add('hidden');
    $('#deck-screen').classList.add('hidden');
    $('#start-screen').classList.remove('hidden');
    setMusic('title');
    state = null;
  });

  /* ---------- 组建牌库 ---------- */

  var deckList = {};        /* baseId -> 数量 */
  var deckFilter = 'all';

  function myFaction() {
    return pickedHero ? Data.HEROES[pickedHero].faction : 'han';
  }

  function deckTotal() {
    var n = 0;
    for (var k in deckList) n += deckList[k];
    return n;
  }

  function openDeckBuilder() {
    setMusic('map');
    deckList = {};
    var saved = savedDeckOf(pickedHero);
    if (saved) saved.forEach(function (id) { deckList[id] = (deckList[id] || 0) + 1; });
    deckFilter = 'all';
    $all('.filter-btn').forEach(function (b) {
      b.classList.toggle('selected', b.getAttribute('data-f') === 'all');
    });
    $('#deck-hero-title').textContent = T('为 {h} 组建牌库', { h: Data.HEROES[pickedHero].name });
    $('#start-screen').classList.add('hidden');
    $('#deck-screen').classList.remove('hidden');
    renderDeckPool();
  }

  function cardLegal(id) {
    var fac = Data.factionOf(id);
    return fac === 'neutral' || fac === myFaction();
  }

  function deckCardHTML(baseId) {
    var c = Data.CARDS[baseId];
    var n = deckList[baseId] || 0;
    var legal = cardLegal(baseId);
    var cls = 'deck-card' + (n > 0 ? ' counted' : '') + (legal ? '' : ' locked');
    var body = '';
    if (c.type === 'piece') {
      body = artOrGlyph(c) +
        '<div class="cname">' + c.name + '</div>' +
        '<div class="cdesc">' + Tut.markKeywords(c.desc) + '</div>' +
        '<div class="atk">' + c.atk + '</div><div class="hpu">' + c.hp + '</div>';
    } else {
      body = artOrGlyph(c) +
        '<div class="cname">' + c.name + '</div>' +
        '<div class="cdesc">' + Tut.markKeywords(c.desc) + '</div>';
    }
    var spellCls = c.type === 'spell' ? ' spell-card' : '';
    return '<div class="' + cls + '" data-id="' + baseId + '">' +
      '<div class="card' + spellCls + (artOf(c.id) ? ' has-art' : '') + '">' +
      '<div class="cost">' + c.cost + '</div>' +
      body + '</div>' +
      (n > 0 ? '<div class="badge">' + n + '</div>' : '') +
      (n > 0 ? '<button class="minus">−</button>' : '') +
      '</div>';
  }

  function renderDeckPool() {
    var html = '';
    Object.keys(Data.CARDS).forEach(function (id) {
      if (id === 's_xianji') return;
      var fac = Data.factionOf(id);
      if (deckFilter === 'neutral' && fac !== 'neutral') return;
      if (deckFilter === 'own' && fac === 'neutral') return;
      if (deckFilter === 'own' && !cardLegal(id)) return;
      html += deckCardHTML(id);
    });
    $('#deck-pool').innerHTML = html;
    $('#deck-num').textContent = deckTotal();
    $('#btn-deck-fight').disabled = deckTotal() !== 20;
  }

  $('#btn-deckbuilder').addEventListener('click', function () {
    if (!pickedHero) return;
    openDeckBuilder();
  });

  $('#btn-deck-back').addEventListener('click', function () {
    $('#deck-screen').classList.add('hidden');
    $('#start-screen').classList.remove('hidden');
    setMusic('title');
  });

  $all('.filter-btn').forEach(function (b) {
    b.addEventListener('click', function () {
      $all('.filter-btn').forEach(function (x) { x.classList.remove('selected'); });
      b.classList.add('selected');
      deckFilter = b.getAttribute('data-f');
      renderDeckPool();
    });
  });

  $('#deck-pool').addEventListener('click', function (ev) {
    var minus = ev.target.closest('.minus');
    var wrap = ev.target.closest('.deck-card');
    if (!wrap) return;
    var id = wrap.getAttribute('data-id');
    if (minus) {
      if (deckList[id]) {
        deckList[id]--;
        if (deckList[id] <= 0) delete deckList[id];
      }
    } else if (cardLegal(id)) {
      if ((deckList[id] || 0) >= 2) { showToast(T('同名牌最多带 2 张')); return; }
      if (deckTotal() >= 20) { showToast(T('牌库已满 20 张')); return; }
      deckList[id] = (deckList[id] || 0) + 1;
    }
    renderDeckPool();
  });

  $('#btn-deck-save').addEventListener('click', function () {
    if (deckTotal() !== 20) { showToast(T('需正好 20 张才能保存')); return; }
    var arr = [];
    for (var id in deckList) {
      for (var i = 0; i < deckList[id]; i++) arr.push(id);
    }
    try { localStorage.setItem('chuhan_deck_' + pickedHero, JSON.stringify(arr)); } catch (e) {}
    showToast(T('牌库已保存，以后「快速开战」将自动使用'));
  });

  $('#btn-deck-fight').addEventListener('click', function () {
    if (deckTotal() !== 20) return;
    var arr = [];
    for (var id in deckList) {
      for (var i = 0; i < deckList[id]; i++) arr.push(id);
    }
    launchGame(arr);
  });

  /* ---------- 楚汉战役 ---------- */

  var CN_NUM = ['壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌'];

  /* 打开战役地图；没有存档就开新战役（刘邦视角） */
  function openCampaign() {
    setMusic('map');
    var prog = Campaign.load();
    if (!prog || !prog.hero) {
      prog = Campaign.start('liubang', Data.DECKS.han.slice());
    }
    /* 还没选军师：先择师（战役的核心随机变量，每局不同） */
    if (!prog.advisor) { openAdvisor(prog); return; }
    hideAllScreens();
    $('#campaign-screen').classList.remove('hidden');
    renderCampaignMap(prog);
  }

  /* ---------- 军师三选一 ---------- */

  var advisorChoices = [];

  function advisorCardHTML(a) {
    var head = (Data.UI_ART && Data.UI_ART.advisors[a.id])
      ? '<div class="adv-art" style="background-image:url(\'assets/cards/ad_' + a.id + '.png\')"></div>'
      : '<div class="adv-glyph">' + a.glyph + '</div>';
    return '<div class="adv-card" data-id="' + a.id + '">' +
      head +
      '<div class="adv-name">' + a.name + '<small>' + a.title + '</small></div>' +
      '<div class="adv-skill">' + a.desc + '</div>' +
      '<div class="adv-flavor">' + a.flavor + '</div>' +
      '</div>';
  }

  function openAdvisor(prog) {
    advisorChoices = Campaign.rollAdvisors(3);
    $('#advisor-cards').innerHTML = advisorChoices.map(advisorCardHTML).join('');
    hideAllScreens();
    $('#advisor-screen').classList.remove('hidden');
  }

  function chooseAdvisor(id) {
    var prog = Campaign.load();
    if (!prog) prog = Campaign.start('liubang', Data.DECKS.han.slice());
    var adv = Campaign.advisorById(id);
    if (!adv) return;
    prog.advisor = id;
    Campaign.save(prog);
    noteAchievements(Codex.recordAdvisor(id).unlocked);
    SFX.play('win');
    showToast(T('军师「{n}」入帐', { n: adv.name }));
    backToCampaign();
  }

  function renderCampaignMap(prog) {
    prog = prog || Campaign.load();
    if (!prog) return;
    var html = '';
    Campaign.STAGES.forEach(function (s, i) {
      var stt = Campaign.statusOf(prog, s.id);
      var tag = stt === 'cleared' ? '<span class="stage-tag">' + T('已 通 关') + '</span>'
        : stt === 'open' ? '<span class="stage-tag" style="background:var(--gold)">' + T('待 战') + '</span>' : '';
      var dot = stt === 'cleared' ? '✓' : (stt === 'locked' ? '·' : T(CN_NUM[i]));
      html += '<div class="stage-node ' + stt + '" data-id="' + s.id + '">' +
        '<div class="stage-dot">' + dot + '</div>' +
        '<div class="stage-card">' +
        '<div class="stage-meta">' + s.chapter + ' · ' + s.year + '</div>' +
        '<div class="stage-title">' + s.name + tag + '</div>' +
        '<div class="stage-sub">' + s.subtitle + '</div>' +
        '<div class="stage-goal">' + T('目标：') + s.goalText + '</div>' +
        '</div></div>';
    });
    $('#camp-stages').innerHTML = html;
    var hero = Data.HEROES[prog.hero || 'liubang'];
    $('#camp-sub').textContent = T('{h}视角 · 已通关 {a} / {b}',
      { h: hero.name, a: prog.cleared.length, b: Campaign.STAGES.length });
    $('#camp-deck-info').textContent = T('当前牌组 {n} 张', { n: prog.deck.length });
    renderCampBuffs(prog);
  }

  /* 地图顶部的军师 / 行军状态摘要 */
  function renderCampBuffs(prog) {
    var el = $('#camp-buffs');
    if (!el) return;
    var html = '';
    var adv = prog.advisor ? Campaign.advisorById(prog.advisor) : null;
    if (adv) {
      html += '<div class="buff-chip adv-chip" title="' + adv.desc + '">' +
        '<span class="buff-k">' + T('军师') + '</span>' + adv.name + '·' + adv.title + '</div>';
    } else {
      html += '<div class="buff-chip adv-chip muted" id="chip-choose-adv">' +
        '<span class="buff-k">' + T('军师') + '</span>' + T('尚未择师（点击选择）') + '</div>';
    }
    if (prog.hpBonus) {
      html += '<div class="buff-chip ' + (prog.hpBonus > 0 ? 'good' : 'bad') + '">' +
        '<span class="buff-k">' + T('生命上限') + '</span>' + (prog.hpBonus > 0 ? '+' : '') + prog.hpBonus + '</div>';
    }
    var next = [];
    if (prog.manaBonus) next.push(T('军粮 {v}', { v: (prog.manaBonus > 0 ? '+' : '') + prog.manaBonus }));
    if (prog.drawBonus) next.push(T('起手 +{n} 牌', { n: prog.drawBonus }));
    if (prog.enemyManaBonus) next.push(T('敌方军粮 {v}', { v: prog.enemyManaBonus }));
    if (next.length) {
      html += '<div class="buff-chip good"><span class="buff-k">' + T('下一战') + '</span>' + next.join(' · ') + '</div>';
    }
    if (prog.eventLog && prog.eventLog.length) {
      var last = prog.eventLog[prog.eventLog.length - 1];
      html += '<div class="buff-chip quiet" title="' + T('仅显示最近一条行军事件') + '"><span class="buff-k">' + T('行军') + '</span>' +
        last.name + '·' + last.choice + '</div>';
    }
    el.innerHTML = html;
  }

  function openLore(stage) {
    pendingStage = stage;
    $('#lore-chapter').textContent = stage.chapter;
    $('#lore-title').textContent = stage.name;
    $('#lore-year').textContent = stage.year + ' · ' + stage.subtitle;
    $('#lore-text').textContent = stage.lore;
    $('#lore-rule').textContent = T('本关目标：') + stage.goalText;
    /* 关卡场景横幅作背景（sc_<stageId>.png），缺图自动回退纯色 */
    var lore = $('#lore-screen');
    if (Data.UI_ART && Data.UI_ART.scenes[stage.id]) {
      lore.classList.add('lore-art');
      lore.style.backgroundImage = 'url(\'assets/cards/sc_' + stage.id + '.png\')';
    } else {
      lore.classList.remove('lore-art');
      lore.style.backgroundImage = '';
    }
    hideAllScreens();
    $('#lore-screen').classList.remove('hidden');
  }

  function launchStage(stage) {
    var prog = Campaign.load();
    var heroId = (prog && prog.hero) || 'liubang';
    var faction = Data.HEROES[heroId].faction;
    var deck = (prog && prog.deck && prog.deck.length >= 20) ? prog.deck : Data.DECKS[faction].slice();
    campaignRun = { stage: stage };
    startBattle({
      heroId: heroId,
      enemyHeroId: stage.enemy.heroId,
      aiLevel: stage.aiLevel,
      deck: deck,
      rules: Campaign.engineRules(stage, prog),   /* 带上军师被动与行军事件加成 */
      enemyMeta: stage.enemy.meta
    });
  }

  function backToCampaign() {
    campaignRun = null;
    pendingRewards = [];
    hideAllScreens();
    $('#campaign-screen').classList.remove('hidden');
    renderCampaignMap(Campaign.load());
    setMusic('map');
  }

  /* 对局中的目标提示条（战役模式下显示） */
  function renderGoalBanner() {
    var el = $('#goal-banner');
    if (!el) return;
    var rules = state && state.rules;
    if (!campaignRun || !rules || !rules.goal) { el.classList.add('hidden'); return; }
    el.classList.remove('hidden');
    if (rules.goal === 'survive') {
      var done = Math.min(state.players.p1.turnsTaken, rules.goalTurns);
      el.textContent = T('目标：存活 {n} 回合 · 已完成 {d} / {t}', { n: rules.goalTurns, d: done, t: rules.goalTurns });
    } else {
      el.textContent = T('目标：击破 {n}（{h} 血）', { n: state.players.p2.name, h: state.players.p2.hp });
    }
  }

  /* 战后三选一 */
  function cardTileHTML(id, hint) {
    var c = Data.CARDS[id];
    if (!c) return '';
    return '<div class="reward-card" data-id="' + id + '">' +
      '<div class="card' + (c.type === 'spell' ? ' spell-card' : '') + (artOf(id) ? ' has-art' : '') + '">' +
      '<div class="cost">' + c.cost + '</div>' +
      artOrGlyph(c) +
      '<div class="cname">' + c.name + '</div>' +
      '<div class="cdesc">' + Tut.markKeywords(c.desc) + '</div>' +
      (c.type === 'piece' ? '<div class="atk">' + c.atk + '</div><div class="hpu">' + c.hp + '</div>' : '') +
      '</div>' + (hint ? '<div class="rc-hint">' + hint + '</div>' : '') + '</div>';
  }

  function openReward(stage, heroFaction) {
    var prog = Campaign.load();
    pendingRewards = Campaign.rollRewards(stage, heroFaction, 3, prog);
    $('#reward-desc').textContent = T('「{s}」已破。选一张牌收入牌组。', { s: stage.name });
    $('#reward-cards').innerHTML = pendingRewards.map(function (id) {
      return cardTileHTML(id, T('选 它'));
    }).join('');
    hideAllScreens();
    $('#reward-screen').classList.remove('hidden');
  }

  function applyReward(cardId) {
    var stage = campaignRun && campaignRun.stage;
    if (!stage) { backToCampaign(); return; }
    var prog = Campaign.load();
    Campaign.clearStage(prog, stage.id, cardId || null);
    Campaign.consumeBoosts(prog);       /* 一次性加成只作用于刚打完的这一战 */
    noteAchievements(Codex.recordClear(stage.id, Campaign.stageIndex(stage.id),
      prog.deck.length, Campaign.STAGES.length).unlocked);
    SFX.play('win');
    /* 后面还有关卡 → 进入行军事件；最后一关 → 直接收兵回地图 */
    if (Campaign.needsEvent(prog, stage)) {
      campaignRun = null;
      pendingRewards = [];
      openEvent(Campaign.pickEvent(prog));
      return;
    }
    backToCampaign();
  }

  /* ---------- 行军事件 ---------- */

  var pendingEvent = null;

  function openEvent(ev) {
    if (!ev) { backToCampaign(); return; }
    pendingEvent = ev;
    $('#ev-title').textContent = ev.name;
    var evGlyph = $('#ev-glyph');
    evGlyph.textContent = ev.glyph;
    if (Data.UI_ART && Data.UI_ART.events[ev.id]) {
      evGlyph.classList.add('has-art');
      evGlyph.style.backgroundImage = 'url(\'assets/cards/ev_' + ev.id + '.png\')';
    } else {
      evGlyph.classList.remove('has-art');
      evGlyph.style.backgroundImage = '';
    }
    $('#ev-text').textContent = ev.text;
    $('#ev-options').innerHTML = ev.options.map(function (o, i) {
      return '<button class="ev-opt" data-i="' + i + '">' +
        '<span class="ev-opt-label">' + o.label + '</span>' +
        '<span class="ev-opt-hint">' + o.hint + '</span></button>';
    }).join('');
    hideAllScreens();
    $('#event-screen').classList.remove('hidden');
  }

  function chooseEventOption(idx) {
    if (!pendingEvent) return;
    var ev = pendingEvent;
    var prog = Campaign.load();
    var res = Campaign.applyEvent(prog, ev.id, idx);
    pendingEvent = null;
    if (!res.ok) { showToast(res.reason ? I18N.trReason(res.reason) : T('事件结算失败')); backToCampaign(); return; }
    SFX.play('click');
    noteAchievements(Codex.recordEvent(ev.id).unlocked);
    var fx = res.fx || {};

    /* 得牌：开三选一；删牌：开牌组选择 */
    if (fx.card) {
      var faction = Data.HEROES[prog.hero || 'liubang'].faction;
      var stage = { id: '_event', rewards: [], tier: 3 };
      var opts = { kind: fx.card === 'any' ? null : fx.card };
      var cards = Campaign.rollRewards(stage, faction, (fx.cardCount || 1) * 3, prog, opts);
      if (!cards.length) { showToast(T('囊中无可用之牌')); backToCampaign(); return; }
      showCardPick({
        title: T('得 牌'),
        desc: '「' + ev.name + '」· ' + res.option.label,
        cards: cards,
        deck: prog.deck,
        mode: 'add',
        count: fx.cardCount || 1
      });
      return;
    }
    if (fx.remove) {
      showCardPick({
        title: T('精 简 行 装'),
        desc: T('从牌组中移除 {n} 张牌', { n: fx.remove }),
        cards: prog.deck.slice(),
        deck: prog.deck,
        mode: 'remove',
        count: fx.remove
      });
      return;
    }
    backToCampaign();
  }

  /* ---------- 通用选牌（事件得牌 / 删牌） ---------- */

  var pickCfg = null;

  function showCardPick(cfg) {
    pickCfg = cfg;
    pickCfg.picked = 0;
    $('#pick-title').textContent = cfg.title;
    $('#pick-desc').textContent = cfg.desc + (cfg.count > 1 ? T('（还需 {n} 张）', { n: cfg.count }) : '');
    renderPickCards();
    hideAllScreens();
    $('#pick-screen').classList.remove('hidden');
  }

  function renderPickCards() {
    if (!pickCfg) return;
    var hint = pickCfg.mode === 'add' ? T('收 入') : T('移 除');
    $('#pick-cards').innerHTML = pickCfg.cards.map(function (id) {
      return cardTileHTML(id, hint);
    }).join('');
    $('#pick-desc').textContent = pickCfg.desc +
      (pickCfg.count > pickCfg.picked ? T('（还需 {n} 张）', { n: pickCfg.count - pickCfg.picked }) : '');
  }

  function pickCard(cardId) {
    if (!pickCfg) return;
    var prog = Campaign.load();
    if (!prog) { backToCampaign(); return; }
    var i = pickCfg.cards.indexOf(cardId);
    if (i < 0) return;
    if (pickCfg.mode === 'add') {
      prog.deck.push(cardId);
      pickCfg.cards.splice(i, 1);           /* 同一张不重复给 */
    } else {
      var di = prog.deck.indexOf(cardId);
      if (di < 0) { showToast(T('牌组里没有这张')); return; }
      prog.deck.splice(di, 1);
      pickCfg.cards.splice(i, 1);
    }
    Campaign.save(prog);
    pickCfg.picked++;
    SFX.play('click');
    if (pickCfg.picked >= pickCfg.count) { closePick(); return; }
    renderPickCards();
  }

  function closePick() {
    pickCfg = null;
    backToCampaign();
  }

  /* ---------- 存档位 ---------- */

  var SLOT_CN = ['壹', '贰', '叁'];
  function slotNo(i) { return T(SLOT_CN[i]); }

  function fmtSlotTime(ts) {
    if (!ts) return '';
    var d = new Date(ts);
    function p2(n) { return (n < 10 ? '0' : '') + n; }
    return d.getFullYear() + '-' + p2(d.getMonth() + 1) + '-' + p2(d.getDate()) +
      ' ' + p2(d.getHours()) + ':' + p2(d.getMinutes());
  }

  function slotRowHTML(s) {
    var active = s.active ? ' active' : '';
    var badge = s.active ? '<span class="slot-badge">' + T('当前') + '</span>' : '';
    if (s.empty) {
      return '<div class="slot-row empty' + active + '" data-i="' + s.index + '">' +
        '<div class="slot-no">' + SLOT_CN[s.index] + '</div>' +
        '<div class="slot-body">' +
          '<div class="slot-title">' + T('存档位 {n}', { n: slotNo(s.index) }) + badge + '</div>' +
          '<div class="slot-info">' + T('空存档位') + '</div>' +
          '<div class="slot-meta">' + T('进入即从「沛县起兵」开一局新战役') + '</div>' +
        '</div>' +
        '<div class="slot-actions"><button class="slot-btn primary" data-act="new">' + T('新建战役') + '</button></div>' +
      '</div>';
    }
    var hero = Data.HEROES[s.hero] || Data.HEROES.liubang;
    var adv = s.advisor ? Campaign.advisorById(s.advisor) : null;
    var next = s.nextStageId ? Campaign.stageById(s.nextStageId) : null;
    var prog = T('已通关 {a} / {b}', { a: s.cleared, b: s.total }) +
      (s.finished ? ' · ' + T('已问鼎') : (next ? ' · ' + T('下一关：{n}', { n: next.name }) : ''));
    var meta = T('牌组 {n} 张', { n: s.deckSize });
    if (adv) meta += ' · ' + T('军师 {n}', { n: adv.name });
    if (s.hpBonus) meta += ' · ' + T('生命上限 {v}', { v: (s.hpBonus > 0 ? '+' : '') + s.hpBonus });
    if (s.updatedAt) meta += ' · ' + fmtSlotTime(s.updatedAt);
    return '<div class="slot-row' + active + '" data-i="' + s.index + '">' +
      '<div class="slot-no">' + SLOT_CN[s.index] + '</div>' +
      '<div class="slot-body">' +
        '<div class="slot-title">' + T('存档位 {n}', { n: slotNo(s.index) }) + badge + '</div>' +
        '<div class="slot-info">' + hero.name + ' · ' + prog + '</div>' +
        '<div class="slot-meta">' + meta + '</div>' +
      '</div>' +
      '<div class="slot-actions">' +
        '<button class="slot-btn primary" data-act="enter">' + T('进入') + '</button>' +
        '<button class="slot-btn" data-act="clear">' + T('清空') + '</button>' +
      '</div>' +
    '</div>';
  }

  function renderSlots() {
    var list = Campaign.slots();
    $('#slot-list').innerHTML = list.map(slotRowHTML).join('');
  }

  function openSlots() {
    hideAllScreens();
    renderSlots();
    $('#slots-screen').classList.remove('hidden');
    setMusic('map');
  }

  function newCampaignInSlot(i) {
    Campaign.useSlot(i);
    Campaign.clearSlot(i);
    var prog = Campaign.start('liubang', Data.DECKS.han.slice());
    showToast(T('存档位 {n} 开新局：请择一军师', { n: slotNo(i) }));
    openAdvisor(prog);
  }

  function enterSlot(i) {
    Campaign.useSlot(i);
    var prog = Campaign.load();
    if (!prog || !prog.hero) { newCampaignInSlot(i); return; }
    openCampaign();
  }

  function handleSlotAction(ev) {
    var btn = ev.target.closest && ev.target.closest('[data-act]');
    if (!btn) return;
    var row = btn.closest('.slot-row');
    if (!row) return;
    var i = parseInt(row.getAttribute('data-i'), 10);
    var act = btn.getAttribute('data-act');
    if (act === 'enter') enterSlot(i);
    else if (act === 'new') newCampaignInSlot(i);
    else if (act === 'clear') {
      if (!confirm(T('清空存档位 {n}？该位的关卡进度、军师与牌组都会消失（成就业绩保留）。', { n: slotNo(i) }))) return;
      Campaign.clearSlot(i);
      if (i === Campaign.activeSlot()) Campaign.useSlot(i);
      renderSlots();
      showToast(T('存档位 {n} 已清空', { n: slotNo(i) }));
    }
  }

  if ($('#slot-list')) $('#slot-list').addEventListener('click', handleSlotAction);
  if ($('#btn-slots-back')) $('#btn-slots-back').addEventListener('click', function () {
    SFX.play('click');
    if (Campaign.load()) backToCampaign(); else {
      hideAllScreens();
      $('#start-screen').classList.remove('hidden');
      setMusic('title');
    }
  });

  /* ---------- 战役事件绑定 ---------- */

  $('#btn-campaign').addEventListener('click', function () {
    SFX.play('click');
    openCampaign();
  });

  $('#btn-camp-back').addEventListener('click', function () {
    hideAllScreens();
    $('#start-screen').classList.remove('hidden');
    setMusic('title');
  });

  $('#btn-camp-slots').addEventListener('click', function () { SFX.play('click'); openSlots(); });

  $('#camp-stages').addEventListener('click', function (ev) {
    var node = ev.target.closest && ev.target.closest('.stage-node');
    if (!node) return;
    var id = node.getAttribute('data-id');
    try {
      var prog = Campaign.load();
      if (!prog) prog = Campaign.start('liubang', Data.DECKS.han.slice());  /* 存档丢失时自愈 */
      if (Campaign.statusOf(prog, id) === 'locked') {
        showToast(T('先打赢前一关，才能走到这里'));
        return;
      }
      var stage = Campaign.stageById(id);
      if (!stage) { showToast(T('关卡数据异常：') + id); return; }
      openLore(stage);
      SFX.play('click');
    } catch (e) {
      showToast(T('打开关卡出错：') + e.message);
    }
  });

  /* 军师三选一 */
  $('#advisor-cards').addEventListener('click', function (ev) {
    var el = ev.target.closest('.adv-card');
    if (!el) return;
    chooseAdvisor(el.getAttribute('data-id'));
  });

  /* 地图上的「尚未择师」快捷入口 */
  $('#camp-buffs').addEventListener('click', function (ev) {
    if (!ev.target.closest('#chip-choose-adv')) return;
    openAdvisor(Campaign.load());
  });

  /* 行军事件选项 */
  $('#ev-options').addEventListener('click', function (ev) {
    var btn = ev.target.closest('.ev-opt');
    if (!btn) return;
    chooseEventOption(parseInt(btn.getAttribute('data-i'), 10));
  });

  /* 通用选牌 */
  $('#pick-cards').addEventListener('click', function (ev) {
    var el = ev.target.closest('.reward-card');
    if (!el) return;
    pickCard(el.getAttribute('data-id'));
  });

  $('#btn-pick-skip').addEventListener('click', function () {
    closePick();
  });

  $('#btn-lore-back').addEventListener('click', function () {
    pendingStage = null;
    backToCampaign();
  });

  $('#btn-lore-fight').addEventListener('click', function () {
    if (!pendingStage) return;
    var stage = pendingStage;
    pendingStage = null;
    SFX.play('click');
    launchStage(stage);
  });

  $('#reward-cards').addEventListener('click', function (ev) {
    var el = ev.target.closest('.reward-card');
    if (!el) return;
    applyReward(el.getAttribute('data-id'));
  });

  $('#btn-reward-skip').addEventListener('click', function () {
    applyReward(null);
  });

  $('#btn-over-back').addEventListener('click', function () {
    backToCampaign();
  });

  $('#btn-camp-reset').addEventListener('click', function () {
    if (!confirm(T('重开战役会清空通关进度、军师和已获得的牌组，确定要重开吗？'))) return;
    Campaign.reset();
    var fresh = Campaign.start('liubang', Data.DECKS.han.slice());
    openAdvisor(fresh);      /* 新的一局，重新择师 */
    showToast(T('战役已重置，请重新择师'));
  });

  /* ---------- 渲染 ---------- */

  var curFx = { enter: {}, hit: {}, floats: {} };

  function unitHTML(u, side, rank) {
    var tags = '';
    if (u.taunt) tags += '<span>' + T('守御') + '</span>';
    if (u.flank) tags += '<span>' + T('迂回') + '</span>';
    if (u.ranged) tags += '<span>' + T('远程') + '</span>';
    if (u.charge) tags += '<span>' + T('冲锋') + '</span>';
    if (u.deathrattle) tags += '<span>' + T('死战') + '</span>';
    if (u.combo) tags += '<span>' + T('连击') + '</span>';
    var cls = 'unit';
    if (u.taunt) cls += ' taunt';
    if (side === 'player' && u.canAttack && u.atk > 0 && isPlayerTurn()) cls += ' can-attack';
    if (selectedUid === u.uid) cls += ' selected';
    if (targetableUids.indexOf(u.uid) >= 0) cls += ' targetable';
    if (curFx.enter[u.uid]) cls += ' enter';
    if (curFx.hit[u.uid]) cls += ' hit';
    var fl = curFx.floats[u.uid];
    var float = fl ? '<div class="float-dmg ' + fl.cls + '">' + fl.text + '</div>' : '';
    return '<div class="' + cls + '" data-uid="' + u.uid + '" data-side="' + side + '" data-rank="' + rank + '">' +
      '<div class="tags">' + tags + '</div>' +
      float +
      '<div class="glyph">' + I18N.glyph(u.glyph) + '</div>' +
      '<div class="uname">' + u.name + '</div>' +
      '<div class="atk">' + u.atk + '</div>' +
      '<div class="hpu' + (u.hp < u.maxHp ? ' hurt' : '') + '">' + u.hp + '</div>' +
      '</div>';
  }

  function cardHTML(c, idx) {
    var playable = isPlayerTurn() && Engine.canPlay(state, 'p1', c);
    var cls = 'card' + (c.type === 'spell' ? ' spell-card' : '') + (playable ? '' : ' unplayable') + (artOf(c.id) ? ' has-art' : '');
    var body = '';
    if (c.type === 'piece') {
      body = artOrGlyph(c) +
        '<div class="cname">' + c.name + '</div>' +
        '<div class="cdesc">' + Tut.markKeywords(c.desc) + '</div>' +
        '<div class="atk">' + c.atk + '</div><div class="hpu">' + c.hp + '</div>';
    } else {
      body = artOrGlyph(c) +
        '<div class="cname">' + c.name + '</div>' +
        '<div class="cdesc">' + Tut.markKeywords(c.desc) + '</div>';
    }
    return '<div class="' + cls + '" data-idx="' + idx + '">' +
      '<div class="cost">' + c.cost + '</div>' + body + '</div>';
  }

  var targetableUids = [];

  /* 对局界面自然高度约 1030px，窗口不够高时按比例缩放整个战场，
     保证手牌区永远在屏幕内（否则窄屏下点不到手牌） */
  function fitBattlefield() {
    var bf = document.querySelector('.battlefield');
    if (!bf) return;
    bf.style.zoom = '';
    var avail = window.innerHeight - 6;
    var h = bf.getBoundingClientRect().height;
    if (!h || h <= avail) return;
    var z = Math.max(0.6, avail / h);
    bf.style.zoom = z.toFixed(3);
  }

  window.addEventListener('resize', fitBattlefield);

  function render() {
    if (!state) return;
    hidePreview();   /* render 会重建手牌/战场 DOM，旧预览必须收起，否则会悬空挡住界面 */
    var me = state.players.p1, foe = state.players.p2;

    /* 快照 diff：受击 / 入场 / 浮动数字 */
    var prev = lastSnap;
    var cur = computeSnap(state);
    lastSnap = cur;
    curFx = { enter: {}, hit: {}, floats: {} };
    if (prev) {
      var anyUnitDmg = false;
      Object.keys(cur.units).forEach(function (uidStr) {
        var uid = Number(uidStr);
        var c = cur.units[uidStr], o = prev.units[uidStr];
        if (!o) { curFx.enter[uid] = true; return; }
        if (c.hp < o.hp) {
          curFx.hit[uid] = true;
          curFx.floats[uid] = { text: '-' + (o.hp - c.hp), cls: '' };
          anyUnitDmg = true;
        } else if (c.atk > o.atk) {
          curFx.floats[uid] = { text: '+' + (c.atk - o.atk), cls: 'buff' };
        }
      });
      var heroHit = false;
      ['p1', 'p2'].forEach(function (pid) {
        if (cur.heroes[pid] < prev.heroes[pid]) {
          heroHit = true;
          var el = $(pid === 'p1' ? '#player-avatar' : '#enemy-avatar');
          el.classList.remove('hit');
          void el.offsetWidth;
          el.classList.add('hit');
          spawnFloat(el, '-' + (prev.heroes[pid] - cur.heroes[pid]), '');
        }
        if (cur.heroes[pid] > prev.heroes[pid]) {
          var el2 = $(pid === 'p1' ? '#player-avatar' : '#enemy-avatar');
          spawnFloat(el2, '+' + (cur.heroes[pid] - prev.heroes[pid]), 'heal');
        }
      });
      /* 攻击动作已有撞击音，免得「攻击+受击」两层声音叠在一起 */
      if ((heroHit || anyUnitDmg) && !(pendingFx && pendingFx.attack)) SFX.play('hurt');
      if (heroHit) {
        var bf = document.querySelector('.battlefield');
        if (bf) {
          bf.classList.remove('shake');
          void bf.offsetWidth;
          bf.classList.add('shake');
        }
      }
      if (cur.hands.p1 > prev.hands.p1) SFX.play('draw');
    }

    /* 英雄栏 */
    setHeroArt($('#player-avatar'), me.heroId);
    setHeroArt($('#enemy-avatar'), foe.heroId, foe.art);

    /* 音乐张力：任一方血量跌破 55% 起，曲子变快、鼓更密 */
    if (SFX.tension) {
      var minRatio = Math.min(me.hp / Math.max(1, me.maxHp), foe.hp / Math.max(1, foe.maxHp));
      SFX.tension(Math.max(0, Math.min(1, (0.55 - minRatio) / 0.45)));
    }
    /* 主将濒危：血量 ≤30% 时头像红边呼吸 */
    $('#player-avatar').classList.toggle('danger', me.hp > 0 && me.hp <= me.maxHp * 0.3);
    $('#enemy-avatar').classList.toggle('danger', foe.hp > 0 && foe.hp <= foe.maxHp * 0.3);
    $('#player-avatar').textContent = me.glyph;
    $('#player-name').textContent = me.name;
    $('#player-title').textContent = me.title;
    $('#player-hp').textContent = '❤ ' + me.hp;
    $('#player-mana').textContent = T('粮 {a}/{b}', { a: me.mana, b: me.maxMana });
    $('#player-deck').textContent = T('牌库 {n}', { n: me.deck.length });
    $('#enemy-avatar').textContent = foe.glyph;
    $('#enemy-name').textContent = foe.name;
    $('#enemy-title').textContent = foe.title;
    $('#enemy-hp').textContent = '❤ ' + foe.hp;
    $('#enemy-mana').textContent = T('粮 {a}/{b}', { a: foe.mana, b: foe.maxMana });
    $('#enemy-deck').textContent = T('牌库 {n}', { n: foe.deck.length });
    $('#enemy-hand').textContent = T('手牌 {n}', { n: foe.hand.length });

    /* 技能与结束按钮 */
    var skillBtn = $('#btn-skill');
    var canSk = Engine.canSkill(state, 'p1') && isPlayerTurn();
    skillBtn.disabled = !canSk;
    skillBtn.classList.toggle('active', canSk);
    skillBtn.textContent = T('{n}（{c} 粮）', { n: me.skill.name, c: me.skill.cost });
    var endBtn = $('#btn-end');
    endBtn.disabled = !isPlayerTurn();
    endBtn.classList.toggle('waiting', busy);

    /* 目标高亮 */
    targetableUids = [];
    var selUnit = selectedUid ? findUnit(me, selectedUid) : null;
    if (selUnit) {
      var info = Engine.getAttackTargets(state, 'p1', selUnit);
      if (info.heroOk) $('#enemy-avatar').classList.add('targetable');
      info.units.forEach(function (x) { targetableUids.push(x.unit.uid); });
    }

    /* 战场 */
    $all('.rank-row').forEach(function (row) {
      var side = row.getAttribute('data-side');
      var rank = row.getAttribute('data-rank');
      var p = side === 'player' ? me : foe;
      var html = '';
      p.board[rank].forEach(function (u) { html += unitHTML(u, side, rank); });
      var slots = Data.COLUMN_LIMIT - p.board[rank].length;
      for (var i = 0; i < slots; i++) {
        html += '<div class="unit empty-slot" style="border-style:dashed;opacity:.35"></div>';
      }
      row.innerHTML = html;
    });
    $('#enemy-avatar').classList.toggle('targetable',
      !!selUnit && Engine.getAttackTargets(state, 'p1', selUnit).heroOk);

    /* 攻击者突进特效（用完即清） */
    if (pendingFx && pendingFx.attacker) {
      var la = document.querySelector('[data-uid="' + pendingFx.attacker + '"]');
      if (la) la.classList.add('lunge');
    }
    pendingFx = null;

    /* 手牌 */
    var hh = '';
    me.hand.forEach(function (c, idx) { hh += cardHTML(c, idx); });
    $('#hand').innerHTML = hh;

    /* 日志（取最后 7 条） */
    $('#log').innerHTML = state.log.slice(-7).map(function (l) {
      return I18N.trLog(l).replace(/&/g, '&amp;').replace(/</g, '&lt;');
    }).join('<br>');

    /* 新战报 → 屏幕中上方文字条（回合分割行由横幅负责，不重复） */
    var tail = state.log[state.log.length - 1] || '';
    if (tail && tail !== lastLogTail && tail.indexOf('—— 第') !== 0) showCallout(I18N.trLog(tail));
    lastLogTail = tail;

    renderGoalBanner();
    fitBattlefield();
    if (Tut.active()) Tut.reposition();

    if (state.over) showOver();
  }

  function findUnit(p, uid) {
    var found = null;
    RANKS.forEach(function (r) {
      p.board[r].forEach(function (u) { if (u.uid === uid) found = u; });
    });
    return found;
  }

  /* 战后战绩：引擎在 state.stats 里累计，这里只做呈现 */
  function statsHTML(win) {
    var s = state.stats || { p1: {}, p2: {} };
    var me = s.p1 || {}, foe = s.p2 || {};
    var rows = [
      [T('剩余血量'), state.players.p1.hp + ' / ' + state.players.p1.maxHp,
        state.players.p2.hp + ' / ' + state.players.p2.maxHp],
      [T('造成伤害'), me.dmg || 0, foe.dmg || 0],
      [T('出兵'), me.units || 0, foe.units || 0],
      [T('用计'), me.spells || 0, foe.spells || 0]
    ];
    if (me.heal || foe.heal) rows.push([T('回血'), me.heal || 0, foe.heal || 0]);

    var html = '<div class="ovs-row ovs-head"><span>' + T('战 绩') + '</span><span>' +
      T('我方') + '</span><span>' + T('敌方') + '</span></div>';
    rows.forEach(function (r, i) {
      html += '<div class="ovs-row' + (i === 0 && win ? ' win' : '') + '">' +
        '<span>' + r[0] + '</span><span>' + r[1] + '</span><span>' + r[2] + '</span></div>';
    });
    var badge = (me.heroDmg || 0) >= 20
      ? '<span class="ovs-badge">' + T('直取主将 {n} 伤', { n: me.heroDmg }) + '</span>' : '';
    html += '<div class="ovs-foot">' +
      T('{n} 个回合 · 牌库余 {d} 张', { n: state.turnNo, d: state.players.p1.deck.length }) +
      badge + '</div>';
    return html;
  }

  function showOver() {
    var win = state.winner === 'p1';
    SFX.play(win ? 'win' : 'lose');
    setMusic('map');
    $('#over-stats').innerHTML = statsHTML(win);
    renderOverAchievements(recordBattleResult(win));

    /* 战役模式：胜利走三选一奖励，失败走重试 */
    if (campaignRun && campaignRun.stage) {
      var stage = campaignRun.stage;
      var prog = Campaign.load();
      var faction = Data.HEROES[(prog && prog.hero) || 'liubang'].faction;
      setTimeout(function () {
        $('#game-screen').classList.add('hidden');
        if (win) {
          /* 已通关的关卡重复挑战：不再发奖励，避免牌组无限膨胀 */
          if (prog && prog.cleared.indexOf(stage.id) >= 0) {
            showToast(T('这一关已经打过，奖励只能领一次'));
            backToCampaign();
            return;
          }
          openReward(stage, faction);
        } else {
          $('#over-title').textContent = T('兵 败 如 山 倒');
          $('#over-title').classList.add('lose');
          $('#over-desc').textContent = T('第 {n} 回合，功亏一篑。「{s}」还需再战。',
            { n: state.turnNo, s: stage.name });
          $('#btn-again').textContent = T('重 试 本 关');
          $('#btn-over-back').classList.remove('hidden');
          $('#over-screen').classList.remove('hidden');
        }
      }, 800);
      return;
    }

    /* 标准模式 */
    $('#over-title').textContent = win ? T('大 获 全 胜') : T('兵 败 如 山 倒');
    $('#over-title').classList.toggle('lose', !win);
    $('#over-desc').textContent = win
      ? T('历经 {n} 个回合，问鼎中原！', { n: state.turnNo })
      : T('鏖战 {n} 个回合，卷土重来未可知。', { n: state.turnNo });
    $('#btn-again').textContent = T('再 战 一 局');
    $('#btn-over-back').classList.add('hidden');
    setTimeout(function () {
      $('#game-screen').classList.add('hidden');
      $('#over-screen').classList.remove('hidden');
    }, 800);
  }

  /* ---------- 操作 ---------- */

  $('#hand').addEventListener('click', function (ev) {
    var el = ev.target.closest('.card');
    if (!el || !isPlayerTurn()) return;
    var card = state.players.p1.hand[parseInt(el.getAttribute('data-idx'), 10)];
    if (!card) return;
    var res = Engine.playCard(state, 'p1', card.uid);
    if (!res.ok) { showToast(I18N.trReason(res.reason)); hintFor(res.reason); }
    else {
      selectedUid = null;
      if (card.type === 'spell') { SFX.play('spell'); flash(); }
      else SFX.play('card');
    }
    render();
  });

  $('#btn-skill').addEventListener('click', function () {
    if (!isPlayerTurn()) return;
    var res = Engine.useSkill(state, 'p1');
    if (!res.ok) showToast(I18N.trReason(res.reason));
    else SFX.play('skill');
    render();
  });

  /* 结束回合前检查：还有没出的牌 / 没打的兵，防误点 */
  var endConfirmUntil = 0;

  function pendingHint() {
    var me = state.players.p1;
    var playable = me.hand.some(function (c) { return c.cost > 0 && Engine.canPlay(state, 'p1', c); });
    if (playable) return T('还有能出的牌');
    var canAtk = false;
    RANKS.forEach(function (r) {
      me.board[r].forEach(function (u) { if (u.canAttack && u.atk > 0) canAtk = true; });
    });
    if (canAtk) return T('还有能攻击的部队');
    return null;
  }

  $('#btn-end').addEventListener('click', function () {
    if (!isPlayerTurn()) return;
    if (Date.now() >= endConfirmUntil) {
      var hint = pendingHint();
      if (hint) {
        showToast(hint + T('，再点一次结束回合'));
        endConfirmUntil = Date.now() + 2500;
        return;
      }
    }
    endConfirmUntil = 0;
    selectedUid = null;
    Engine.endTurn(state);
    render();
    showBanner(T('敌 方 回 合'));
    SFX.play('turn');
    if (!state.over) scheduleAI();
  });

  /* 右键或 ESC 取消已选中的攻击单位 */
  document.addEventListener('contextmenu', function (ev) {
    if (selectedUid) {
      ev.preventDefault();
      selectedUid = null;
      render();
    }
  });
  document.addEventListener('keydown', function (ev) {
    if (ev.key === 'Escape' && selectedUid) {
      selectedUid = null;
      render();
    }
  });

  /* 战场点击：选攻击单位 / 选攻击目标 */
  $('.battlefield').addEventListener('click', function (ev) {
    var unitEl = ev.target.closest('.unit:not(.empty-slot)');
    var heroEl = ev.target.closest('.hero-avatar.small');
    if (!isPlayerTurn()) return;

    /* 点敌方英雄 = 攻击英雄 */
    if (heroEl && heroEl.id === 'enemy-avatar' && selectedUid) {
      var res = Engine.attack(state, 'p1', selectedUid, { kind: 'hero' });
      if (!res.ok) { showToast(I18N.trReason(res.reason)); hintFor(res.reason); }
      else { pendingFx = { attacker: selectedUid, attack: true }; SFX.play('attack'); }
      selectedUid = null;
      render();
      return;
    }
    if (!unitEl) return;
    var uid = parseInt(unitEl.getAttribute('data-uid'), 10);
    var side = unitEl.getAttribute('data-side');

    if (side === 'enemy') {
      if (selectedUid && targetableUids.indexOf(uid) >= 0) {
        var r2 = Engine.attack(state, 'p1', selectedUid, { kind: 'unit', uid: uid });
        if (!r2.ok) { showToast(I18N.trReason(r2.reason)); hintFor(r2.reason); }
        else { pendingFx = { attacker: selectedUid, attack: true }; SFX.play('attack'); }
        selectedUid = null;
        render();
      }
      return;
    }

    /* 我方单位：选中 / 取消 */
    var u = findUnit(state.players.p1, uid);
    if (u && u.canAttack && u.atk > 0) {
      selectedUid = (selectedUid === uid) ? null : uid;
      render();
    } else if (u) {
      /* 点了却毫无反应最容易让人困惑，这里解释一句（只说第一次） */
      Tut.hint(u.atk <= 0 ? 'noAtk' : 'sick', u.atk <= 0
        ? T('「{n}」没有攻击力，它的价值在于守御挡路，不能用来打人。', { n: u.name })
        : T('「{n}」这一回合还不能攻击：刚登场，或者已经出手过了。', { n: u.name }));
    }
  });

  /* ---------- 图鉴 · 成就 · 战绩 ---------- */

  var codexTab = 'cards';
  var codexFilter = { faction: 'all', type: 'all' };

  function openCodex(tab) {
    hideAllScreens();
    $('#codex-screen').classList.remove('hidden');
    switchCodexTab(tab || 'cards');
    SFX.play('click');
  }

  function closeCodex() {
    hideAllScreens();
    $('#start-screen').classList.remove('hidden');
    setMusic('title');
  }

  function switchCodexTab(tab) {
    codexTab = tab;
    $all('.codex-tab').forEach(function (b) {
      b.classList.toggle('selected', b.getAttribute('data-tab') === tab);
    });
    ['cards', 'ach', 'career'].forEach(function (k) {
      var el = $('#codex-' + k);
      if (el) el.classList.toggle('hidden', k !== tab);
    });
    if (tab === 'cards') renderCodexCards();
    else if (tab === 'ach') renderAchievements();
    else renderCareer();
    try { $('#codex-screen').scrollTop = 0; } catch (e) {}
  }

  /* 战役牌组里的同名张数（图鉴里标出来，方便构筑时查） */
  function deckCopies() {
    var prog = Campaign.load();
    var out = {};
    if (!prog || !prog.deck) return out;
    prog.deck.forEach(function (id) { out[id] = (out[id] || 0) + 1; });
    return out;
  }

  function codexCardHTML(id, copies) {
    var c = Data.CARDS[id];
    var f = Data.factionOf(id);
    var facLabel = f === 'han' ? T('汉') : (f === 'chu' ? T('楚') : '');
    return '<div class="codex-card" data-id="' + id + '">' +
      '<div class="card' + (c.type === 'spell' ? ' spell-card' : '') + (artOf(id) ? ' has-art' : '') + '">' +
      '<div class="cost">' + c.cost + '</div>' +
      artOrGlyph(c) +
      '<div class="cname">' + c.name + '</div>' +
      '<div class="cdesc">' + Tut.markKeywords(c.desc) + '</div>' +
      (c.type === 'piece' ? '<div class="atk">' + c.atk + '</div><div class="hpu">' + c.hp + '</div>' : '') +
      '</div>' +
      (facLabel ? '<span class="cx-fac ' + f + '">' + facLabel + '</span>' : '') +
      (copies ? '<span class="cx-own">' + T('牌组 ×{n}', { n: copies }) + '</span>' : '') +
      '</div>';
  }

  function renderCodexCards() {
    var ids = Codex.filterCards(Data, codexFilter);
    var copies = deckCopies();
    var stats = Codex.cardStats(Data);
    var prog = Campaign.load();
    $('#codex-sub').textContent = T('卡池 {a} 张 · 中立 {b} / 汉 {c} / 楚 {d} · 兵种 {e} / 计谋 {f}',
      { a: stats.total, b: stats.byFaction.neutral, c: stats.byFaction.han, d: stats.byFaction.chu,
        e: stats.byType.piece, f: stats.byType.spell }) +
      (prog && prog.deck.length ? T('　·　当前战役牌组 {n} 张', { n: prog.deck.length }) : '');
    $('#codex-grid').innerHTML = ids.length
      ? ids.map(function (id) { return codexCardHTML(id, copies[id] || 0); }).join('')
      : '<div class="codex-empty">' + T('这个筛选下暂时没有牌') + '</div>';
  }

  function renderAchievements() {
    var c = Codex.current();
    var total = Codex.ACHIEVEMENTS.length;
    var got = Codex.unlockedCount(c);
    $('#codex-sub').textContent = T('已解锁 {a} / {b}　·　成就只增不减，重开战役、清空进度都不影响',
      { a: got, b: total });

    var groups = ['battle', 'campaign', 'career'];
    $('#codex-ach').innerHTML = groups.map(function (g) {
      var list = Codex.ACHIEVEMENTS.filter(function (a) { return a.group === g; });
      if (!list.length) return '';
      var cards = list.map(function (a) {
        var on = !!c.ach[a.id];
        return '<div class="ach-card ' + (on ? 'on' : 'locked') + '" data-id="' + a.id + '">' +
          '<div class="ach-glyph">' + a.glyph + '</div>' +
          '<div class="ach-body"><div class="ach-name">' + a.name +
          (on ? '<span class="ach-tag">' + T('已达成') + '</span>' : '') + '</div>' +
          '<div class="ach-desc">' + a.desc + '</div></div></div>';
      }).join('');
      return '<div class="ach-group"><div class="ach-group-title">' +
        Codex.GROUP_NAMES[g] + '</div><div class="ach-grid">' + cards + '</div></div>';
    }).join('');
  }

  function renderCareer() {
    var s = Codex.summary();
    var lvlName = { jianxi: T('见习'), bijiang: T('裨将'), mingjiang: T('名将') };
    var stageName = s.maxStageId ? (Campaign.stageById(s.maxStageId) || {}).name : null;
    var chapters = Campaign.STAGES.length;

    $('#codex-sub').textContent = s.battles
      ? T('累计 {a} 场战斗 · 胜率 {b}%', { a: s.battles, b: s.winRate })
      : T('还没有开过战。打一局，这里就开始记事了。');

    var cells = [
      [s.battles, T('总 场 次')],
      [s.wins, T('胜 场')],
      [s.winRate + '<small>%</small>', T('胜 率')],
      [s.bestStreak, T('最 长 连 胜')],
      [s.clearedCount + '<small>/' + chapters + '</small>', T('战 役 进 度')],
      [s.dmg, T('累 计 伤 害')]
    ];
    var html = '<div class="career-grid">' + cells.map(function (x) {
      return '<div class="career-cell"><div class="career-num">' + x[0] +
        '</div><div class="career-label">' + x[1] + '</div></div>';
    }).join('') + '</div>';

    /* 战役 */
    var heroWin = Object.keys(s.heroes).filter(function (k) { return s.heroes[k] > 0; });
    var stageDisp = stageName
      ? (I18N.isEN() ? T('第{n}关 · {s}', { n: s.maxStage + 1, s: stageName })
                     : '第' + '〇一二三四五六七八'[s.maxStage + 1] + '关 · ' + stageName)
      : T('尚未出征');
    html += '<div class="career-block"><h3>' + T('战 役') + '</h3>' +
      '<div class="career-row"><span>' + T('最远抵达') + '</span><b>' + stageDisp + '</b></div>' +
      '<div class="career-row"><span>' + T('通关关卡') + '</span><b>' + s.clearedCount + ' / ' + chapters + '</b></div>' +
      '<div class="career-row"><span>' + T('最大牌组') + '</span><b>' + (s.maxDeck || 20) + T('张') + '</b></div>' +
      '<div class="career-row"><span>' + T('用过军师') + '</span><b>' + s.advisors + '</b></div>' +
      '<div class="career-row"><span>' + T('行军事件') + '</span><b>' + s.events + '</b></div>' +
      '</div>';

    /* 战阵 */
    var lvlRow = Object.keys(s.levels).filter(function (k) { return s.levels[k] > 0; })
      .map(function (k) { return (lvlName[k] || k) + ' ' + T('{n} 胜', { n: s.levels[k] }); }).join('　');
    html += '<div class="career-block"><h3>' + T('战 阵') + '</h3>' +
      '<div class="career-row"><span>' + T('单局最速取胜') + '</span><b>' +
      (s.fastestWin === null ? '—' : T('{n} 回合', { n: s.fastestWin })) + '</b></div>' +
      '<div class="career-row"><span>' + T('最凶险的胜仗') + '</span><b>' +
      (s.bestHpWin === null ? '—' : T('剩 {n} 血', { n: s.bestHpWin })) + '</b></div>' +
      '<div class="career-row"><span>' + T('累计出兵 / 用计') + '</span><b>' +
      T('{a} 员 / {b} 张', { a: s.units, b: s.spells }) + '</b></div>' +
      '<div class="career-row"><span>' + T('对主将造成伤害') + '</span><b>' + s.heroDmg + '</b></div>' +
      '<div class="career-row"><span>' + T('各难度胜场') + '</span><b>' + (lvlRow || '—') + '</b></div>' +
      '<div class="career-note">' + T('用过的英雄：') +
      (heroWin.length ? heroWin.map(function (k) { return Data.HEROES[k] ? Data.HEROES[k].name : k; }).join(', ') : '—') +
      '</div></div>';

    $('#codex-career').innerHTML = html;
  }

  /* 结算页：把本次新解锁的成就列出来 */
  function renderOverAchievements(list) {
    var el = $('#over-ach');
    if (!el) return;
    if (!list || !list.length) { el.innerHTML = ''; return; }
    el.innerHTML = '<div class="ov-ach-title">' + T('成 就 解 锁') + '</div><div class="ov-ach-row">' +
      list.map(function (a) {
        return '<span class="ov-ach"><i>' + a.glyph + '</i>' + a.name + '</span>';
      }).join('') + '</div>';
  }

  /* 非战斗场景解锁的成就，用一条提示报出来 */
  function noteAchievements(list) {
    if (!list || !list.length) return;
    showToast(T('成就解锁 · ') + list.map(function (a) { return a.name; }).join(', '));
  }

  /* 一场战斗结束：记战绩 + 记成就 */
  function recordBattleResult(win) {
    if (!state) return [];
    var me = (state.stats || {}).p1 || {};
    var res = Codex.recordBattle({
      win: !!win,
      turns: state.turnNo,
      hp: state.players.p1.hp,
      maxHp: state.players.p1.maxHp,
      heroId: (Campaign.load() || {}).hero || pickedHero || 'liubang',
      level: campaignRun ? 'bijiang' : aiLevel,
      dmg: me.dmg || 0,
      heroDmg: me.heroDmg || 0,
      units: me.units || 0,
      spells: me.spells || 0
    });
    return res.unlocked || [];
  }

  $all('.codex-tab').forEach(function (btn) {
    btn.addEventListener('click', function () {
      switchCodexTab(btn.getAttribute('data-tab'));
      SFX.play('click');
    });
  });
  ['faction', 'type'].forEach(function (key) {
    var box = $('#codex-' + key);
    if (!box) return;
    box.addEventListener('click', function (ev) {
      var b = ev.target.closest('.filter-btn');
      if (!b) return;
      codexFilter[key] = b.getAttribute('data-v');
      $all('#codex-' + key + ' .filter-btn').forEach(function (x) {
        x.classList.toggle('selected', x === b);
      });
      renderCodexCards();
      SFX.play('click');
    });
  });
  $('#btn-codex-back').addEventListener('click', closeCodex);

  /* ---------- AI 行动循环 ---------- */

  function scheduleAI() {
    if (!state || state.over || state.current !== 'p2') { busy = false; render(); return; }
    busy = true;
    render();
    setTimeout(function () {
      if (!state || state.over) { busy = false; render(); return; }
      var action = AI.aiNextAction(state, 'p2');
      /* AI 动作音效与攻击特效 */
      if (action.type === 'play') {
        var pc = null;
        state.players.p2.hand.forEach(function (x) { if (x.uid === action.uid) pc = x; });
        if (pc && pc.type === 'spell') { SFX.play('spell'); flash(); }
        else SFX.play('card');
      } else if (action.type === 'skill') {
        SFX.play('skill');
      } else if (action.type === 'attack') {
        pendingFx = { attacker: action.attacker, attack: true };
        SFX.play('attack');
      }
      AI.applyAction(state, 'p2', action);
      render();
      if (state.over) { busy = false; return; }
      if (action.type === 'end') {
        busy = false;
        showBanner(T('我 方 回 合'));
        SFX.play('turn');
        render();
        maybeIntro();
      } else {
        scheduleAI();
      }
    }, 800);
  }

  render();
  setMusic('title');   /* 主菜单用更慢的曲；浏览器未解锁音频时会等首次点击 */

  /* 自动化测试用的调试入口（不参与玩法，也不在界面上暴露） */
  window.__ui = {
    openEvent: openEvent,
    showCardPick: showCardPick,
    openAdvisor: openAdvisor,
    campaignProgress: function () { return Campaign.load(); },
    tutorial: function () { return window.Tutorial; },
    introSteps: introSteps,
    startIntro: function () { maybeIntro(); return !!(window.Tutorial && window.Tutorial.active()); },
    gameState: function () { return state; },
    render: render,
    campaignRun: function () { return campaignRun; },
    openCodex: openCodex,
    openLore: openLore,
    openSettings: openSettings,
    closeSettings: closeSettings,
    settingsState: function () {
      var v = SFX.volume ? SFX.volume() : { bgm: 0, sfx: 0 };
      return {
        motion: settings.motion, bgm: v.bgm, sfx: v.sfx, muted: SFX.muted(),
        music: SFX.musicScene ? SFX.musicScene() : null,
        tension: SFX.tension ? SFX.tension() : 0,
        settingsOpen: !$('#settings-screen').classList.contains('hidden')
      };
    },
    codexTab: function () { return codexTab; },
    codexFilter: function () { return codexFilter; },
    codex: function () { return window.Codex; },
    /* 测试用：直接判出胜负，检查结算面板与音乐切换 */
    simulateOver: function (win) {
      if (!state) return false;
      state.players[win ? 'p2' : 'p1'].hp = 0;
      state.over = true;
      state.winner = win ? 'p1' : 'p2';
      render();
      return true;
    }
  };
})();
