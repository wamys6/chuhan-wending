#!/usr/bin/env node
/*
 * 把 Web 版英文包（js/lang-en.js）导出成 Godot 用的 JSON。
 *
 * 为什么这么做：英文文案已经在 Web 版被人工审过一遍，Godot 端不该重写一份，
 * 否则两版会出现「同一个技能两种说法」这种最难查的不一致。
 * 这里只做格式转换 + 完整性检查，不改文字。
 *
 *   node tools/export-i18n.js
 *   → godot/data/lang-en.json
 */
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'js', 'lang-en.js');
const OUT = path.join(ROOT, 'godot', 'data', 'lang-en.json');

const src = fs.readFileSync(SRC, 'utf8');
let captured = null;
new Function('I18N', src)({
  load(o) { captured = o; },
});

if (!captured) {
  console.error('导出失败：lang-en.js 没有调用 I18N.load');
  process.exit(1);
}

/* 只取 Godot 端用得上的段。logPatterns 是 JS 正则表，Godot 用结构化 key 渲染，
   对应英文模板写在 godot/core/log_text.gd 里，这里不导。 */
const keep = [
  'ui', 'cards', 'heroes', 'ranks', 'stages', 'advisors',
  'events', 'ascension', 'tianshi', 'unlocks',
  'achievements', 'groups', 'keywords', 'keywordList', 'glyphs', 'reasons',
];

const out = { generatedFrom: 'js/lang-en.js', lang: 'en' };
for (const k of keep) {
  if (captured[k] == null) {
    console.error('缺少段：' + k);
    process.exit(1);
  }
  out[k] = captured[k];
}

/* ---------- 完整性检查：漏一条玩家就会看到中文夹在英文里 ---------- */

const data = JSON.parse(fs.readFileSync(path.join(ROOT, 'godot', 'data', 'game.json'), 'utf8'));
const problems = [];

for (const id of Object.keys(data.cards)) {
  const en = out.cards[id];
  if (!en) problems.push('卡牌缺英文：' + id);
  else if (!en.name || !en.desc) problems.push('卡牌缺 name/desc：' + id);
}
for (const id of Object.keys(data.heroes)) {
  const en = out.heroes[id];
  if (!en) problems.push('英雄缺英文：' + id);
  else if (!en.name || !en.title || !en.skill) problems.push('英雄缺字段：' + id);
  else if (!en.skill.name || !en.skill.desc) problems.push('英雄技能缺英文：' + id);
}
for (const s of data.stages) {
  const en = out.stages[s.id];
  if (!en) problems.push('关卡缺英文：' + s.id);
  else if (!en.name || !en.goalText || !en.lore) problems.push('关卡缺字段：' + s.id);
}
for (const a of data.advisors) {
  if (!out.advisors[a.id]) problems.push('军师缺英文：' + a.id);
}
for (let i = 0; i < data.ascension.length; i++) {
  const en = out.ascension[i];
  if (!en) problems.push('心魔缺英文：第 ' + (i + 1) + ' 级');
  else if (!en.name || !en.desc) problems.push('心魔缺字段：第 ' + (i + 1) + ' 级');
}
for (const t of data.tianshi) {
  const en = out.tianshi[t.id];
  if (!en) problems.push('天时缺英文：' + t.id);
  else if (!en.name || !en.desc) problems.push('天时缺字段：' + t.id);
}
for (const e of data.events) {
  const en = out.events[e.id];
  if (!en) problems.push('事件缺英文：' + e.id);
  else if (!en.options || en.options.length !== e.options.length) {
    problems.push('事件选项数不一致：' + e.id);
  }
}

/* 英文里不该残留汉字（全角标点允许，但汉字一定是漏译） */
const CJK = /[\u4e00-\u9fff]/;
function walk(node, at) {
  if (typeof node === 'string') {
    if (CJK.test(node)) problems.push('英文串里还有汉字：' + at + ' → ' + node.slice(0, 40));
  } else if (Array.isArray(node)) {
    node.forEach((v, i) => walk(v, at + '[' + i + ']'));
  } else if (node && typeof node === 'object') {
    for (const k of Object.keys(node)) walk(node[k], at + '.' + k);
  }
}
walk({ cards: out.cards, heroes: out.heroes, ranks: out.ranks, stages: out.stages,
  advisors: out.advisors, events: out.events, achievements: out.achievements,
  keywords: out.keywords, reasons: out.reasons }, 'en');

if (problems.length) {
  console.error('发现 ' + problems.length + ' 个问题：');
  for (const p of problems.slice(0, 30)) console.error('  · ' + p);
  process.exit(1);
}

fs.writeFileSync(OUT, JSON.stringify(out, null, 2) + '\n', 'utf8');
const size = fs.statSync(OUT).size;
console.log('已导出 ' + path.relative(ROOT, OUT) + '  ' + (size / 1024).toFixed(1) + ' KB');
console.log('  卡牌 ' + Object.keys(out.cards).length +
  ' / 关卡 ' + Object.keys(out.stages).length +
  ' / 军师 ' + Object.keys(out.advisors).length +
  ' / 事件 ' + Object.keys(out.events).length +
  ' / 成就 ' + Object.keys(out.achievements).length +
  ' / UI 文案 ' + Object.keys(out.ui).length);
