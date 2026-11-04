/* 《楚汉·问鼎》程序化音效（Web Audio API 合成，零素材依赖）
   用法：SFX.play('card' | 'spell' | 'attack' | 'hurt' | 'turn' | 'click' | 'draw' | 'skill' | 'win' | 'lose') */
(function (root) {
  'use strict';

  var ctx = null;
  var muted = false;
  try { muted = localStorage.getItem('chuhan_mute') === '1'; } catch (e) {}

  /* 音量分层：音乐与音效各一条总线，独立调节（设置面板用） */
  var volBgm = 0.6, volSfx = 0.8;
  try {
    var savedVol = JSON.parse(localStorage.getItem('chuhan_vol') || '{}');
    if (typeof savedVol.bgm === 'number') volBgm = Math.max(0, Math.min(1, savedVol.bgm));
    if (typeof savedVol.sfx === 'number') volSfx = Math.max(0, Math.min(1, savedVol.sfx));
  } catch (e) {}

  var sfxBus = null;

  function ensureSfxBus() {
    var c = ac(); if (!c) return null;
    if (!sfxBus) {
      sfxBus = c.createGain();
      sfxBus.gain.value = volSfx;
      sfxBus.connect(c.destination);
    }
    return sfxBus;
  }

  function ac() {
    try {
      if (!ctx) {
        var AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) return null;
        ctx = new AC();
      }
      if (ctx.state === 'suspended') ctx.resume();
      return ctx;
    } catch (e) { return null; }   /* 音频不可用也不能影响游戏流程 */
  }

  /* 单音：频率滑音 + 衰减包络 */
  function tone(opt) {
    var c = ac(); if (!c) return;
    var dur = opt.dur || 0.2;
    var o = c.createOscillator(), g = c.createGain();
    o.type = opt.type || 'sine';
    o.frequency.setValueAtTime(opt.f0, c.currentTime);
    if (opt.f1) o.frequency.exponentialRampToValueAtTime(opt.f1, c.currentTime + dur);
    g.gain.setValueAtTime(opt.vol || 0.15, c.currentTime);
    g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + dur);
    o.connect(g); g.connect(ensureSfxBus() || c.destination);
    o.start(); o.stop(c.currentTime + dur + 0.05);
  }

  /* 噪声爆音：打击感（攻防碰撞、抽牌沙沙） */
  function noise(opt) {
    var c = ac(); if (!c) return;
    var dur = opt.dur || 0.15;
    var len = Math.floor(c.sampleRate * dur);
    var buf = c.createBuffer(1, len, c.sampleRate);
    var d = buf.getChannelData(0);
    for (var i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len);
    var src = c.createBufferSource(); src.buffer = buf;
    var f = c.createBiquadFilter();
    f.type = opt.filter || 'lowpass';
    f.frequency.value = opt.freq || 800;
    var g = c.createGain(); g.gain.value = opt.vol || 0.12;
    src.connect(f); f.connect(g); g.connect(ensureSfxBus() || c.destination);
    src.start();
  }

  var SFXAPI = {
    muted: function () { return muted; },
    toggle: function () {
      muted = !muted;
      try { localStorage.setItem('chuhan_mute', muted ? '1' : '0'); } catch (e) {}
      applyMusic();          /* 静音时立刻掐掉音乐，取消静音时接回来 */
      return muted;
    },
    play: function (name) {
      if (muted) return;
      try {
        playSound(name);
      } catch (e) { /* 音效失败静默忽略，绝不阻塞界面操作 */ }
    },
    /* 背景音乐场景：'title'（主菜单）| 'map'（地图/过场）| 'battle'（对局）| null（停止） */
    music: function (scene) {
      if (scene === wantScene) return;
      wantScene = scene || null;
      lastIdx = 3;
      applyMusic();
    },
    musicScene: function () { return wantScene; },
    /* 音量：kind = 'bgm' | 'sfx'，0-1；返回当前音量表 */
    volume: function () { return { bgm: volBgm, sfx: volSfx }; },
    setVolume: function (kind, v) {
      v = Math.max(0, Math.min(1, Number(v) || 0));
      if (kind === 'bgm') {
        volBgm = v;
        var c = ctx;
        if (master && c) {
          master.gain.cancelScheduledValues(c.currentTime);
          master.gain.setValueAtTime(master.gain.value, c.currentTime);
          master.gain.linearRampToValueAtTime(muted ? 0 : v, c.currentTime + 0.15);
        }
      } else if (kind === 'sfx') {
        volSfx = v;
        var bus = ensureSfxBus();
        if (bus && ctx) bus.gain.setValueAtTime(v, ctx.currentTime);
      }
      try {
        localStorage.setItem('chuhan_vol', JSON.stringify({ bgm: volBgm, sfx: volSfx }));
      } catch (e) {}
      return { bgm: volBgm, sfx: volSfx };
    },
    /* 战斗紧张度 0-1：血量越低，曲子越快、鼓点越密；不传参则读取当前值 */
    tension: function (v) {
      if (v === undefined) return tensionVal;
      var t = Math.max(0, Math.min(1, Number(v) || 0));
      if (Math.abs(t - tensionVal) < 0.08) return tensionVal;
      tensionVal = t;
      return tensionVal;
    }
  };

  /* ------------------------------------------------------------------
     背景音乐：五声音阶程序化生成，古琴拨弦 + 箫 + 低音持续
     —— 零素材，切换场景时淡出淡入，静音开关统一管理
  ------------------------------------------------------------------ */
  var SCALE = [146.83, 164.81, 185.00, 220.00, 246.94, 293.66, 329.63];  /* D 宫 · 五声 */
  var SCENES = {
    title:  { bpm: 44, density: 0.46, drum: 0,    flute: 0.30, vol: 0.8 },
    map:    { bpm: 52, density: 0.62, drum: 0,    flute: 0.16, vol: 0.9 },
    battle: { bpm: 84, density: 0.88, drum: 0.55, flute: 0.06, vol: 1.0 }
  };
  var wantScene = null, master = null, timer = 0, drone = [], lastIdx = 3, fadeT = 0;
  var tensionVal = 0;

  function ensureMaster() {
    var c = ac(); if (!c) return null;
    if (!master) {
      master = c.createGain();
      master.gain.value = volBgm;
      master.connect(c.destination);
    }
    return master;
  }

  /* 拨弦：三角波 + 泛音，快速起音长衰减，带一点下滑音 */
  function pluck(f, vol) {
    var c = ac(); var m = ensureMaster(); if (!c || !m) return;
    var t0 = c.currentTime + 0.01;
    var g = c.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(vol, t0 + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 1.9);
    var o1 = c.createOscillator(); o1.type = 'triangle';
    o1.frequency.setValueAtTime(f, t0);
    o1.frequency.linearRampToValueAtTime(f * 0.994, t0 + 1.2);
    var o2 = c.createOscillator(); o2.type = 'sine';
    o2.frequency.setValueAtTime(f * 2.005, t0);
    var g2 = c.createGain(); g2.gain.value = 0.22;
    o1.connect(g); o2.connect(g2); g2.connect(g);
    g.connect(m);
    o1.start(t0); o2.start(t0);
    o1.stop(t0 + 2.0); o2.stop(t0 + 2.0);
  }

  /* 箫：慢起音 + 颤音，长音 */
  function flute(f, vol) {
    var c = ac(); var m = ensureMaster(); if (!c || !m) return;
    var t0 = c.currentTime + 0.01, dur = 2.2;
    var g = c.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.linearRampToValueAtTime(vol, t0 + 0.35);
    g.gain.linearRampToValueAtTime(0.0001, t0 + dur);
    var o = c.createOscillator(); o.type = 'sine';
    o.frequency.setValueAtTime(f, t0);
    var lfo = c.createOscillator(); lfo.frequency.value = 4.6;
    var lg = c.createGain(); lg.gain.value = f * 0.006;
    lfo.connect(lg); lg.connect(o.frequency);
    o.connect(g); g.connect(m);
    o.start(t0); lfo.start(t0);
    o.stop(t0 + dur + 0.1); lfo.stop(t0 + dur + 0.1);
  }

  /* 鼓：低频闷击，只在对局场景出现 */
  function drum(vol) {
    var c = ac(); var m = ensureMaster(); if (!c || !m) return;
    var t0 = c.currentTime + 0.01;
    var o = c.createOscillator(); o.type = 'sine';
    o.frequency.setValueAtTime(96, t0);
    o.frequency.exponentialRampToValueAtTime(48, t0 + 0.22);
    var g = c.createGain();
    g.gain.setValueAtTime(vol, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.28);
    o.connect(g); g.connect(m);
    o.start(t0); o.stop(t0 + 0.3);
  }

  function startDrone() {
    var c = ac(); var m = ensureMaster(); if (!c || !m) return;
    stopDrone();
    [73.42, 110.00].forEach(function (f, i) {
      var o = c.createOscillator(); o.type = 'sine'; o.frequency.value = f;
      var g = c.createGain(); g.gain.value = 0.0001;
      g.gain.linearRampToValueAtTime(i ? 0.028 : 0.04, c.currentTime + 3);
      o.connect(g); g.connect(m); o.start();
      drone.push({ o: o, g: g });
    });
  }

  function stopDrone() {
    var c = ctx;
    drone.forEach(function (d) {
      try {
        if (c) {
          d.g.gain.cancelScheduledValues(c.currentTime);
          d.g.gain.setValueAtTime(d.g.gain.value, c.currentTime);
          d.g.gain.linearRampToValueAtTime(0.0001, c.currentTime + 0.5);
        }
        d.o.stop((c ? c.currentTime : 0) + 0.6);
      } catch (e) {}
    });
    drone = [];
  }

  function step() {
    var cfg = SCENES[wantScene];
    var c = ac();
    if (!cfg || !c) return;
    /* 浏览器未解锁音频时先等着，等首次交互后再起 */
    if (c.state !== 'running') { timer = setTimeout(step, 700); return; }

    /* 紧张度让曲子变快、鼓更密（只在对局场景生效） */
    var tense = wantScene === 'battle' ? tensionVal : 0;
    var beat = (60 / (cfg.bpm * (1 + tense * 0.28))) * 1000;
    if (Math.random() < cfg.density + tense * 0.08) {
      /* 旋律做小步游走，比纯随机更像"曲子" */
      var idx = lastIdx + (Math.random() < 0.5 ? -1 : 1) * (Math.random() < 0.7 ? 1 : 2);
      idx = Math.max(0, Math.min(SCALE.length - 1, idx));
      lastIdx = idx;
      var f = SCALE[idx];
      if (Math.random() < 0.18) f *= 2;
      pluck(f, 0.10 * cfg.vol);
    }
    if (Math.random() < cfg.flute) flute(SCALE[Math.floor(Math.random() * 4)] * 2, 0.05);
    if (cfg.drum && Math.random() < cfg.drum + tense * 0.3) drum(0.16);

    timer = setTimeout(step, beat * (1.1 + Math.random() * 2.2));
  }

  function applyMusic() {
    clearTimeout(timer);
    clearTimeout(fadeT);
    var c = ctx;
    if (master && c) {
      /* 先淡出，再换曲，避免切换时"咔"一声 */
      master.gain.cancelScheduledValues(c.currentTime);
      master.gain.setValueAtTime(master.gain.value, c.currentTime);
      master.gain.linearRampToValueAtTime(0.0001, c.currentTime + 0.3);
    }
    fadeT = setTimeout(function () {
      stopDrone();
      if (muted || !wantScene) { if (master) master.gain.value = 0; return; }
      ensureMaster();
      if (master) {
        master.gain.cancelScheduledValues(ctx.currentTime);
        master.gain.setValueAtTime(0.0001, ctx.currentTime);
        master.gain.linearRampToValueAtTime(volBgm, ctx.currentTime + 0.8);
      }
      startDrone();
      step();
    }, 320);
  }

  /* 首次交互解锁音频（浏览器自动播放策略） */
  if (typeof document !== 'undefined') (function () {
    function unlock() {
      var c = ac();
      if (c && wantScene && !muted) { clearTimeout(timer); step(); }
      ['click', 'keydown', 'touchstart'].forEach(function (ev) {
        document.removeEventListener(ev, unlock, true);
      });
    }
    ['click', 'keydown', 'touchstart'].forEach(function (ev) {
      document.addEventListener(ev, unlock, true);
    });
  })();


  function playSound(name) {
    switch (name) {
        case 'card':    /* 出兵：短促落子 */
          tone({ type: 'triangle', f0: 520, f1: 260, dur: 0.14, vol: 0.14 });
          break;
        case 'spell':   /* 计谋：上扬丝鸣 + 低鸣 */
          tone({ type: 'sawtooth', f0: 300, f1: 700, dur: 0.25, vol: 0.07 });
          tone({ type: 'sine', f0: 150, f1: 90, dur: 0.3, vol: 0.12 });
          break;
        case 'attack':  /* 攻击：钝器碰撞 */
          noise({ dur: 0.14, freq: 700, vol: 0.18 });
          tone({ type: 'sine', f0: 140, f1: 70, dur: 0.16, vol: 0.2 });
          break;
        case 'hurt':    /* 受击：闷哼 */
          tone({ type: 'square', f0: 220, f1: 110, dur: 0.18, vol: 0.07 });
          break;
        case 'skill':   /* 英雄技能：号角 */
          tone({ type: 'sine', f0: 440, f1: 660, dur: 0.22, vol: 0.1 });
          break;
        case 'turn':    /* 回合钟声 */
          tone({ type: 'sine', f0: 392, dur: 0.5, vol: 0.12 });
          tone({ type: 'sine', f0: 523, dur: 0.7, vol: 0.05 });
          break;
        case 'click':   /* 点选 */
          tone({ type: 'sine', f0: 660, dur: 0.07, vol: 0.08 });
          break;
        case 'tick':    /* 通用轻点（任意可点元素的底层反馈，很轻） */
          tone({ type: 'sine', f0: 880, dur: 0.04, vol: 0.028 });
          break;
        case 'draw':    /* 抽牌沙沙 */
          noise({ dur: 0.06, freq: 2400, filter: 'highpass', vol: 0.06 });
          break;
        case 'win':     /* 胜利：上行琶音 */
          [523, 659, 784, 1046].forEach(function (f, i) {
            setTimeout(function () { tone({ type: 'triangle', f0: f, dur: 0.35, vol: 0.12 }); }, i * 140);
          });
          break;
        case 'lose':    /* 失败：下行三音 */
          [330, 262, 196].forEach(function (f, i) {
            setTimeout(function () { tone({ type: 'triangle', f0: f, dur: 0.4, vol: 0.12 }); }, i * 180);
          });
          break;
    }
  }

  root.SFX = SFXAPI;
})(typeof self !== 'undefined' ? self : this);
