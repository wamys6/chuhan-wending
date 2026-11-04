/* 《楚汉·问鼎》音频离线渲染（Node 生成 WAV，零三方依赖）
 *
 * 为什么离线渲染而不是用 Godot 的 AudioStreamGenerator：
 *   实时合成要每帧喂 PCM，GL Compatibility 下容易爆音；离线渲染一次跑完，
 *   运行时只剩「播放 + 调音量」，CPU 占用为零，也方便将来整首换成真人录音。
 *
 * 音色与 Web 版 js/audio.js 完全同源：D 宫五声音阶、三角波拨弦 + 泛音、
 * 正弦箫 + 颤音、低频战鼓、双持续低音。
 *
 * 循环无缝的三个关键：
 *   1) 循环长度取整数拍；
 *   2) 越过结尾的尾音「绕回」开头叠加，接缝两端的和相等；
 *   3) 持续低音的频率微调到 L 的整数分之一，避免接缝处相位跳变产生咔哒声。
 *
 * 用法：node tools/make-audio.js
 */
'use strict';

const fs = require('fs');
const path = require('path');

const SR = 44100;                      // Godot 导入时会压成 QOA，体积约为 PCM 的 1/5，这里给足采样率换音质
const OUT_DIR = path.join(__dirname, '..', 'godot', 'assets', 'audio');

/* 确定性随机：同一种子每次生成的曲子一模一样，便于回归比对 */
function xorshift(seed) {
  let s = seed >>> 0 || 1;
  return function () {
    s ^= s << 13; s >>>= 0;
    s ^= s >>> 17;
    s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
}

/* D 宫 · 五声音阶（与 Web 版同表） */
const SCALE = [146.83, 164.81, 185.00, 220.00, 246.94, 293.66, 329.63];

function wave(type, ph) {
  switch (type) {
    case 'sine': return Math.sin(ph);
    case 'tri': {
      const x = ph / (2 * Math.PI);
      const f = x - Math.floor(x + 0.5);       // [-0.5, 0.5)
      return 4 * Math.abs(f) - 1;
    }
    case 'saw': {
      const x = ph / (2 * Math.PI);
      const f = x - Math.floor(x + 0.5);
      return 2 * f;
    }
    case 'square': return Math.sin(ph) >= 0 ? 1 : -1;
    default: return Math.sin(ph);
  }
}

/* 叠加一个音符（自动绕回循环开头，保证无缝） */
function addNote(buf, frames, t0, dur, f0, f1, amp, type, opt) {
  opt = opt || {};
  const start = Math.round(t0 * SR);
  const n = Math.min(Math.round(dur * SR), frames);
  const harmAmp = opt.harmAmp || 0;
  const harmRatio = opt.harmRatio || 2.005;
  const vibHz = opt.vib || 0;
  const vibDepth = opt.vibDepth || 0;
  const envKind = opt.env || 'pluck';
  const k = Math.log(amp / 0.0001) / Math.max(0.05, dur);
  let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    let env;
    if (envKind === 'flute') {
      env = t < 0.35 ? amp * (t / 0.35)
        : amp * Math.max(0, 1 - (t - 0.35) / Math.max(0.01, dur - 0.35));
    } else if (envKind === 'drum') {
      env = amp * Math.exp(-t * 11);
    } else {
      env = t < 0.012 ? amp * (t / 0.012) : amp * Math.exp(-k * (t - 0.012));
    }
    const p = t / dur;
    let f = f0;
    if (f1) f = f0 * Math.pow(f1 / f0, Math.min(1, p));   // 指数滑音
    if (vibHz) f *= 1 + vibDepth * Math.sin(2 * Math.PI * vibHz * t);
    ph += 2 * Math.PI * f / SR;
    let s = wave(type, ph);
    if (harmAmp) s += harmAmp * Math.sin(ph * harmRatio);
    buf[(start + i) % frames] += s * env;
  }
}

/* 持续低音：频率取 L 的整数分之一，循环处相位归零 */
function addDrone(buf, frames, L, baseF, amp, cyclesPerLoop, phases) {
  const f = Math.round(baseF * L) / L;
  const lfo = (2 * Math.PI * cyclesPerLoop) / L;
  for (let i = 0; i < frames; i++) {
    const t = i / SR;
    buf[i] += Math.sin(2 * Math.PI * f * t) * amp * (0.75 + 0.25 * Math.sin(lfo * t));
  }
}

/* 一阶低通：削掉合成波的毛刺感，听感接近 Web 版的 biquad */
function lowpass(buf, fc) {
  const a = 1 - Math.exp(-2 * Math.PI * fc / SR);
  let y = 0;
  for (let i = 0; i < buf.length; i++) {
    y += a * (buf[i] - y);
    buf[i] = y;
  }
}

function normalize(buf, peak) {
  let max = 0;
  for (let i = 0; i < buf.length; i++) if (Math.abs(buf[i]) > max) max = Math.abs(buf[i]);
  if (max < 1e-9) return;
  const g = peak / max;
  for (let i = 0; i < buf.length; i++) buf[i] *= g;
}

/* 写 16bit 单声道 WAV */
function writeWav(file, buf) {
  const dataLen = buf.length * 2;
  const h = Buffer.alloc(44);
  h.write('RIFF', 0);
  h.writeUInt32LE(36 + dataLen, 4);
  h.write('WAVE', 8);
  h.write('fmt ', 12);
  h.writeUInt32LE(16, 16);
  h.writeUInt16LE(1, 20);            // PCM
  h.writeUInt16LE(1, 22);            // mono
  h.writeUInt32LE(SR, 24);
  h.writeUInt32LE(SR * 2, 28);
  h.writeUInt16LE(2, 32);
  h.writeUInt16LE(16, 34);
  h.write('data', 36);
  h.writeUInt32LE(dataLen, 40);
  const pcm = Buffer.alloc(dataLen);
  for (let i = 0; i < buf.length; i++) {
    let v = Math.max(-1, Math.min(1, buf[i]));
    pcm.writeInt16LE(Math.round(v * 32767), i * 2);
  }
  fs.writeFileSync(file, Buffer.concat([h, pcm]));
  return { bytes: 44 + dataLen, secs: buf.length / SR };
}

/* ---------------- 三首背景音乐 ---------------- */
const BGM = {
  title:  { bpm: 44, bars: 32, density: 0.46, flute: 0.30, drum: 0,    vol: 0.80, seed: 1001, peak: 0.62 },
  map:    { bpm: 52, bars: 32, density: 0.62, flute: 0.16, drum: 0,    vol: 0.90, seed: 2002, peak: 0.62 },
  battle: { bpm: 84, bars: 48, density: 0.88, flute: 0.06, drum: 0.55, vol: 1.00, seed: 3003, peak: 0.70 }
};

function buildBgm(cfg) {
  const beat = 60 / cfg.bpm;
  const L = beat * cfg.bars;
  const frames = Math.round(L * SR);
  const buf = new Float32Array(frames);

  // 低音底座：两个纯五度持续音，慢速呼吸（周期整除循环长度）
  addDrone(buf, frames, L, 73.42, 0.040, 2);
  addDrone(buf, frames, L, 110.00, 0.028, 3);

  const rnd = xorshift(cfg.seed);
  let idx = 3;
  for (let b = 0; b < cfg.bars; b++) {
    const t = b * beat;
    // 拨弦旋律：小步游走，像有人随手抚琴
    if (rnd() < cfg.density) {
      const step = (rnd() < 0.5 ? -1 : 1) * (rnd() < 0.7 ? 1 : 2);
      idx = Math.max(0, Math.min(SCALE.length - 1, idx + step));
      let f = SCALE[idx];
      if (rnd() < 0.18) f *= 2;
      addNote(buf, frames, t, 1.9, f, f * 0.994, 0.10 * cfg.vol, 'tri',
        { harmRatio: 2.005, harmAmp: 0.22 });
    }
    // 长音：箫/埙的味道
    if (rnd() < cfg.flute) {
      const f = SCALE[Math.floor(rnd() * 4)] * 2;
      addNote(buf, frames, t + 0.1, 2.2, f, f, 0.05, 'sine',
        { env: 'flute', vib: 4.6, vibDepth: 0.006 });
    }
    // 战鼓：只在对局曲出现
    if (cfg.drum && rnd() < cfg.drum) {
      addNote(buf, frames, t, 0.3, 96, 48, 0.16, 'sine', { env: 'drum' });
    }
    // 每四拍一个低音根音，撑住和声
    if (b % 4 === 0) {
      const f = (b % 8 === 0 ? SCALE[0] : SCALE[2]) * 0.5;
      addNote(buf, frames, t, 3.0, f, f, 0.055 * cfg.vol, 'tri',
        { harmRatio: 2, harmAmp: 0.15 });
    }
  }

  lowpass(buf, 3500);
  normalize(buf, cfg.peak);
  return buf;
}

/* ---------------- 音效 ---------------- */
function noiseBuf(dur, freq, highpass, vol) {
  const n = Math.round(dur * SR);
  const buf = new Float32Array(n);
  const rnd = xorshift(7777);
  for (let i = 0; i < n; i++) buf[i] = (rnd() * 2 - 1) * (1 - i / n);
  const a = 1 - Math.exp(-2 * Math.PI * freq / SR);
  let y = 0;
  for (let i = 0; i < n; i++) {
    y += a * (buf[i] - y);
    buf[i] = (highpass ? buf[i] - y : y) * vol;
  }
  return buf;
}

function mixInto(dst, src, offset) {
  const off = Math.round(offset * SR);
  for (let i = 0; i < src.length; i++) {
    if (off + i < dst.length) dst[off + i] += src[i];
  }
}

function buildSfx(name) {
  // 每条目：{n:[时值参数块...], noise:[...]}，时间单位秒
  const defs = {
    card: () => {
      const b = new Float32Array(Math.round(0.30 * SR));
      addNote(b, b.length, 0, 0.14, 520, 260, 0.45, 'tri');
      return b;
    },
    spell: () => {
      const b = new Float32Array(Math.round(0.45 * SR));
      addNote(b, b.length, 0, 0.25, 300, 700, 0.22, 'saw');
      addNote(b, b.length, 0, 0.30, 150, 90, 0.36, 'sine');
      return b;
    },
    attack: () => {
      const b = new Float32Array(Math.round(0.40 * SR));
      mixInto(b, noiseBuf(0.14, 700, false, 0.55), 0);
      addNote(b, b.length, 0, 0.16, 140, 70, 0.6, 'sine');
      return b;
    },
    hurt: () => {
      const b = new Float32Array(Math.round(0.30 * SR));
      addNote(b, b.length, 0, 0.18, 220, 110, 0.22, 'square');
      return b;
    },
    skill: () => {
      const b = new Float32Array(Math.round(0.36 * SR));
      addNote(b, b.length, 0, 0.22, 440, 660, 0.32, 'sine');
      addNote(b, b.length, 0, 0.26, 660, 660, 0.12, 'tri');
      return b;
    },
    turn: () => {
      const b = new Float32Array(Math.round(0.90 * SR));
      addNote(b, b.length, 0, 0.50, 392, 392, 0.38, 'sine');
      addNote(b, b.length, 0, 0.70, 523, 523, 0.16, 'sine');
      return b;
    },
    click: () => {
      const b = new Float32Array(Math.round(0.14 * SR));
      addNote(b, b.length, 0, 0.07, 660, 660, 0.26, 'sine');
      return b;
    },
    tick: () => {
      const b = new Float32Array(Math.round(0.10 * SR));
      addNote(b, b.length, 0, 0.04, 880, 880, 0.10, 'sine');
      return b;
    },
    draw: () => {
      const b = new Float32Array(Math.round(0.16 * SR));
      mixInto(b, noiseBuf(0.06, 2400, true, 0.22), 0);
      return b;
    },
    win: () => {
      const b = new Float32Array(Math.round(1.10 * SR));
      [523, 659, 784, 1046].forEach((f, i) => {
        addNote(b, b.length, i * 0.14, 0.35, f, f, 0.38, 'tri', { harmRatio: 2, harmAmp: 0.18 });
      });
      return b;
    },
    lose: () => {
      const b = new Float32Array(Math.round(1.30 * SR));
      [330, 262, 196].forEach((f, i) => {
        addNote(b, b.length, i * 0.18, 0.40, f, f, 0.38, 'tri', { harmRatio: 2, harmAmp: 0.18 });
      });
      return b;
    },
    /* 印章盖下：纸面拍击 + 木质闷响 + 印泥余韵。心魔定级时用 */
    seal: () => {
      const b = new Float32Array(Math.round(0.42 * SR));
      mixInto(b, noiseBuf(0.05, 1800, true, 0.34), 0);
      addNote(b, b.length, 0, 0.20, 150, 62, 0.72, 'sine');
      addNote(b, b.length, 0.02, 0.34, 92, 70, 0.22, 'tri');
      return b;
    },
    /* 签筒摇动：竹签相击的几记脆响，节奏故意不匀（匀了就成节拍器） */
    lottery: () => {
      const b = new Float32Array(Math.round(0.70 * SR));
      [0, 0.11, 0.19, 0.30, 0.36].forEach((t, i) => {
        mixInto(b, noiseBuf(0.035, 2600 + i * 180, true, 0.30 - i * 0.035), t);
      });
      [0, 0.12, 0.31].forEach((t) => addNote(b, b.length, t, 0.06, 1250, 900, 0.16, 'tri'));
      addNote(b, b.length, 0.02, 0.28, 180, 140, 0.15, 'sine');
      return b;
    },
    /* 天时落定：一声铜锣。基频偏低 + 非谐泛音，长衰减，收尾靠尾淡出 */
    omen: () => {
      const b = new Float32Array(Math.round(1.40 * SR));
      mixInto(b, noiseBuf(0.09, 3800, true, 0.28), 0);
      addNote(b, b.length, 0, 1.30, 196, 188, 0.32, 'sine', { harmRatio: 2.76, harmAmp: 0.15 });
      addNote(b, b.length, 0.01, 1.10, 294, 286, 0.16, 'sine', { harmRatio: 1.5, harmAmp: 0.10 });
      addNote(b, b.length, 0.02, 0.90, 441, 430, 0.09, 'tri');
      return b;
    }
  };
  if (!defs[name]) throw new Error('未知音效: ' + name);
  const buf = defs[name]();
  lowpass(buf, 5000);
  // 尾部 10ms 淡出，杜绝播放截断的爆音
  const tail = Math.min(buf.length, Math.round(0.010 * SR));
  for (let i = 0; i < tail; i++) buf[buf.length - tail + i] *= 1 - i / tail;
  return buf;
}

/* ---------------- 主流程 ---------------- */
function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  let total = 0;
  const report = [];
  for (const name of Object.keys(BGM)) {
    const buf = buildBgm(BGM[name]);
    const info = writeWav(path.join(OUT_DIR, 'bgm_' + name + '.wav'), buf);
    total += info.bytes;
    report.push(`  bgm_${name}.wav`.padEnd(24) + info.secs.toFixed(1).padStart(6) + ' s');
  }
  const SFX = ['card', 'spell', 'attack', 'hurt', 'skill', 'turn', 'click', 'tick', 'draw', 'win', 'lose',
    'seal', 'lottery', 'omen'];
  for (const name of SFX) {
    const buf = buildSfx(name);
    const info = writeWav(path.join(OUT_DIR, 'sfx_' + name + '.wav'), buf);
    total += info.bytes;
    report.push(`  sfx_${name}.wav`.padEnd(24) + info.secs.toFixed(2).padStart(6) + ' s');
  }
  console.log('[audio] 生成完毕：');
  console.log(report.join('\n'));
  console.log('[audio] 合计 ' + (total / 1048576).toFixed(1) + ' MB → ' + OUT_DIR);
}

main();
