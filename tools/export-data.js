/* 从 JS 版导出数据到 Godot 工程（单一数据源：迁移期两边共用同一份数值）
   用法：node tools/export-data.js
   产物：godot/data/game.json */
'use strict';
var fs = require('fs');
var path = require('path');

var ROOT = path.resolve(__dirname, '..');
var D = require(path.join(ROOT, 'js/data.js'));
var C = require(path.join(ROOT, 'js/campaign.js'));

function strip(v) {
  /* 只保留纯数据，丢掉函数引用（JSON.stringify 会自动丢，这里显式防 undefined） */
  return JSON.parse(JSON.stringify(v));
}

var out = {
  version: 1,
  constants: {
    HAND_LIMIT: D.HAND_LIMIT,
    COLUMN_LIMIT: D.COLUMN_LIMIT,
    MAX_MANA: D.MAX_MANA,
    RANK_NAMES: D.RANK_NAMES
  },
  heroes: strip(D.HEROES),
  cards: strip(D.CARDS),
  decks: strip(D.DECKS),
  art: { cards: strip(D.ART), heroes: strip(D.HERO_ART), ui: strip(D.UI_ART) },
  stages: strip(C.STAGES),
  advisors: strip(C.ADVISORS),
  events: strip(C.EVENTS),
  ascension: strip(C.ASCENSION),
  tianshi: strip(C.TIANSHI)
};

var dest = path.join(ROOT, 'godot/data/game.json');
fs.mkdirSync(path.dirname(dest), { recursive: true });
fs.writeFileSync(dest, JSON.stringify(out, null, 1), 'utf8');

var stat = fs.statSync(dest);
console.log('写出 ' + dest + '  ' + (stat.size / 1024).toFixed(1) + ' KB');
console.log('  卡牌 ' + Object.keys(out.cards).length +
  ' / 英雄 ' + Object.keys(out.heroes).length +
  ' / 牌组 ' + Object.keys(out.decks).length +
  ' / 关卡 ' + out.stages.length +
  ' / 军师 ' + Object.keys(out.advisors).length +
  ' / 事件 ' + Object.keys(out.events).length +
  ' / 心魔 ' + out.ascension.length +
  ' / 天时 ' + out.tianshi.length);
