/* 《楚汉·问鼎》新手引导：聚光灯分步提示 + 关键词释义 + 首次触发提示 */
(function (root) {
  'use strict';

  var T = (typeof I18N !== 'undefined') ? I18N.t : function (x) { return x; };

  var STORE_KEY = 'chuhan_tutorial_v1';

  /* ------------------------------------------------------------------
     关键词释义（悬停任意关键词气泡显示）
  ------------------------------------------------------------------ */
  var KEYWORDS = {
    '守御': '敌人必须先打掉它，才能碰到它后面的部队。',
    '迂回': '可以直接攻击敌方前锋或中军，不用等前面的列清空。',
    '远程': '可以攻击敌方任意一列，不受排列顺序限制。',
    '冲锋': '登场当回合就能攻击，不用等一回合。',
    '死战': '阵亡时触发一次效果，比如让友军全体加攻。',
    '连击': '本回合此前已经打出过别的牌，才会触发。',
    '召唤失调': '兵种登场当回合不能攻击（带「冲锋」的除外）。',
    '军粮': '出牌要花的资源。第 N 回合上限为 N（最多 10），每回合回满。'
  };

  /* ------------------------------------------------------------------
     存档：localStorage 不可用时退回内存副本（同 campaign 的处理）
  ------------------------------------------------------------------ */
  var memory = { flags: {}, hints: {} };
  var loaded = false;

  function read() {
    if (loaded) return memory;
    loaded = true;
    try {
      var raw = root.localStorage && root.localStorage.getItem(STORE_KEY);
      if (raw) {
        var p = JSON.parse(raw);
        if (p && typeof p === 'object') {
          memory.flags = p.flags || {};
          memory.hints = p.hints || {};
        }
      }
    } catch (e) { /* 读不到就只用内存 */ }
    return memory;
  }

  function write() {
    try { root.localStorage.setItem(STORE_KEY, JSON.stringify(memory)); } catch (e) {}
  }

  /* 引导是否已完成（每段引导用各自的 flag） */
  function done(flag) {
    return !!read().flags[flag];
  }

  function markDone(flag) {
    read().flags[flag] = Date.now();
    write();
  }

  function reset() {
    memory = { flags: {}, hints: {} };
    loaded = true;
    try { root.localStorage.removeItem(STORE_KEY); } catch (e) {}
  }

  /* ------------------------------------------------------------------
     关键词标注：把牌面描述里的关键词包成可悬停的 <b>
     只标注真正的战斗关键词——「军粮」「召唤失调」这类解释性词条
     只出现在提示气泡里，不在牌面上画虚线下划线
  ------------------------------------------------------------------ */
  var KW_LIST_DEFAULT = ['守御', '迂回', '远程', '冲锋', '死战', '连击'];
  var kwList = null;    /* 语言切换时由 I18N 注入对应语言的列表 */

  function setKeywordList(list) { kwList = list || null; }

  function escapeHtml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function markKeywords(text) {
    var html = escapeHtml(text || '');
    (kwList || KW_LIST_DEFAULT).forEach(function (kw) {
      /* 已经包过的（含 class="kw"）不再重复包：用占位符规避二次替换 */
      html = html.split(kw).join('\u0001' + kw + '\u0002');
    });
    html = html.replace(/\u0001([^\u0002]+)\u0002/g, '<b class="kw" data-kw="$1">$1</b>');
    return html;
  }

  /* ------------------------------------------------------------------
     引导层 DOM（懒创建，避免污染 index.html）
  ------------------------------------------------------------------ */
  var layer = null, spot = null, box = null, stepEl = null,
    titleEl = null, textEl = null, nextBtn = null, skipBtn = null;
  var steps = [], cur = 0, active = false, opts = {};

  function build() {
    if (layer) return;
    layer = document.createElement('div');
    layer.id = 'coach-layer';
    layer.className = 'hidden';
    layer.innerHTML =
      '<div id="coach-spot"></div>' +
      '<div id="coach-box">' +
        '<div class="coach-step" id="coach-step"></div>' +
        '<h3 class="coach-title" id="coach-title"></h3>' +
        '<p class="coach-text" id="coach-text"></p>' +
        '<div class="coach-actions">' +
          '<button class="coach-skip" id="coach-skip">' + T('跳 过') + '</button>' +
          '<button class="coach-next" id="coach-next">' + T('下 一 步') + '</button>' +
        '</div>' +
      '</div>';
    document.body.appendChild(layer);
    spot = layer.querySelector('#coach-spot');
    box = layer.querySelector('#coach-box');
    stepEl = layer.querySelector('#coach-step');
    titleEl = layer.querySelector('#coach-title');
    textEl = layer.querySelector('#coach-text');
    nextBtn = layer.querySelector('#coach-next');
    skipBtn = layer.querySelector('#coach-skip');

    nextBtn.addEventListener('click', function (ev) {
      ev.stopPropagation();
      next();
    });
    skipBtn.addEventListener('click', function (ev) {
      ev.stopPropagation();
      finish(true);
    });

    /* 目标元素被点击时自动推进（比如"点一张牌试试"） */
    document.addEventListener('click', function (ev) {
      if (!active) return;
      var st = steps[cur];
      if (!st || !st.advanceOn) return;
      if (ev.target.closest && ev.target.closest(st.advanceOn)) advance();
    }, true);
  }

  function elOf(st) {
    if (!st) return null;
    if (typeof st.el === 'function') return st.el();
    return st.sel ? document.querySelector(st.sel) : null;
  }

  function place() {
    if (!active) return;
    var st = steps[cur];
    var el = elOf(st);
    var vw = root.innerWidth, vh = root.innerHeight;
    var pad = st && st.pad != null ? st.pad : 6;

    if (!el) {
      spot.style.display = 'none';
      box.style.left = Math.round((vw - 340) / 2) + 'px';
      box.style.top = Math.round(vh - 300) + 'px';
      return;
    }

    var r = el.getBoundingClientRect();
    if (!r.width && !r.height) {
      spot.style.display = 'none';
      box.style.left = Math.round((vw - 340) / 2) + 'px';
      box.style.top = Math.round(vh / 2) + 'px';
      return;
    }

    var x = Math.max(0, r.left - pad), y = Math.max(0, r.top - pad);
    var w = Math.min(vw - x, r.width + pad * 2), h = Math.min(vh - y, r.height + pad * 2);
    spot.style.display = 'block';
    spot.style.left = x + 'px';
    spot.style.top = y + 'px';
    spot.style.width = w + 'px';
    spot.style.height = h + 'px';

    /* 提示框：优先放在目标下方，放不下就放上方，都放不下就贴底 */
    var bw = 340, bh = box.offsetHeight || 170;
    var bx = Math.min(vw - bw - 14, Math.max(14, r.left + r.width / 2 - bw / 2));
    var below = r.bottom + 14;
    var above = r.top - bh - 14;
    var by;
    if (below + bh + 8 <= vh) by = below;
    else if (above >= 8) by = above;
    else by = Math.max(8, vh - bh - 14);

    box.style.left = Math.round(bx) + 'px';
    box.style.top = Math.round(by) + 'px';
  }

  function render() {
    var st = steps[cur];
    if (!st) return finish(false);
    build();
    stepEl.textContent = (cur + 1) + ' / ' + steps.length;
    titleEl.textContent = st.title || '';
    textEl.textContent = st.text || '';
    box.classList.toggle('no-target', !elOf(st));
    nextBtn.textContent = cur === steps.length - 1 ? T('开 始 出 征') : T('下 一 步');
    skipBtn.classList.toggle('hidden', !!st.noSkip);
    /* 有动作要求的那一步，把「下一步」弱化，引导玩家真的去点 */
    nextBtn.classList.toggle('ghost', !!st.advanceOn);
    place();
  }

  function advance() {
    if (!active) return;
    cur++;
    if (cur >= steps.length) { finish(false); return; }
    render();
  }

  /* 公开的 next：既给按钮用，也给外部（如完成动作后）调用 */
  function next() { advance(); }
  function prev() {
    if (!active || cur <= 0) return;
    cur--;
    render();
  }

  function finish(skipped) {
    active = false;
    if (layer) layer.classList.add('hidden');
    if (opts.onDone) opts.onDone(skipped);
    if (!skipped && opts.flag) markDone(opts.flag);
    steps = [];
    cur = 0;
    opts = {};
  }

  function start(list, o) {
    if (!list || !list.length) return;
    build();
    steps = list;
    cur = 0;
    opts = o || {};
    active = true;
    layer.classList.remove('hidden');
    render();
  }

  function stop() {
    if (!active) return;
    active = false;
    if (layer) layer.classList.add('hidden');
    steps = [];
    cur = 0;
    opts = {};
  }

  /* ------------------------------------------------------------------
     一次性提示（规则首次触发时）
  ------------------------------------------------------------------ */
  var tipEl = null, tipTimer = 0;

  function hint(id, text, o) {
    o = o || {};
    var store = read();
    if (!o.always && store.hints[id]) return false;
    if (!o.always) { store.hints[id] = 1; write(); }

    /* 无 DOM 环境（单元测试）只记录标记 */
    if (typeof document === 'undefined') return true;

    if (!tipEl) {
      tipEl = document.createElement('div');
      tipEl.id = 'coach-tip';
      document.body.appendChild(tipEl);
    }
    tipEl.innerHTML = '<b>' + T('小 提 示') + '</b>' + escapeHtml(text);
    tipEl.classList.add('show');
    clearTimeout(tipTimer);
    tipTimer = setTimeout(function () { tipEl.classList.remove('show'); }, o.ms || 4200);
    return true;
  }

  /* ------------------------------------------------------------------
     关键词悬停气泡
  ------------------------------------------------------------------ */
  var kwEl = null, kwTimer = 0;

  function hideKw() {
    if (kwEl) kwEl.classList.remove('show');
  }

  function ensureKw() {
    if (kwEl) return;
    kwEl = document.createElement('div');
    kwEl.id = 'kw-tip';
    document.body.appendChild(kwEl);
  }

  function bindKeywordTip() {
    document.addEventListener('mouseover', function (ev) {
      var t = ev.target;
      if (!t || !t.closest) return;
      var b = t.closest('.kw');
      if (!b) { hideKw(); return; }
      var kw = b.getAttribute('data-kw');
      var def = KEYWORDS[kw];
      if (!def) return;
      ensureKw();
      kwEl.innerHTML = '<b>' + escapeHtml(kw) + '</b>' + escapeHtml(def);
      kwEl.classList.add('show');
      var vw = root.innerWidth;
      var w = kwEl.offsetWidth || 240;
      var x = Math.min(vw - w - 10, Math.max(10, ev.clientX - w / 2));
      var y = ev.clientY - (kwEl.offsetHeight || 70) - 14;
      kwEl.style.left = Math.round(x) + 'px';
      kwEl.style.top = Math.round(Math.max(8, y)) + 'px';
      /* 悬停结束后 2.6 秒自动消失，避免切屏后气泡一直挂着 */
      clearTimeout(kwTimer);
      kwTimer = setTimeout(hideKw, 2600);
    });
    document.addEventListener('mouseout', function (ev) {
      if (!ev.target || !ev.target.closest) return;
      if (!ev.target.closest('.kw')) return;
      if (ev.relatedTarget && ev.relatedTarget.closest && ev.relatedTarget.closest('.kw')) return;
      hideKw();
    });
    root.addEventListener('scroll', hideKw, true);
  }

  if (typeof document !== 'undefined') bindKeywordTip();
  if (typeof document !== 'undefined') root.addEventListener('resize', place);

  root.Tutorial = {
    KEYWORDS: KEYWORDS,
    markKeywords: markKeywords,
    done: done,
    markDone: markDone,
    reset: reset,
    start: start,
    stop: stop,
    next: next,
    prev: prev,
    active: function () { return active; },
    step: function () { return active ? cur : -1; },
    total: function () { return steps.length; },
    hint: hint,
    setKeywordList: setKeywordList,
    reposition: place,
    /* 测试用 */
    _store: function () { return read(); }
  };
})(typeof self !== 'undefined' ? self : this);
