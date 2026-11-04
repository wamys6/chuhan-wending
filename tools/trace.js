/* 跨语言等价性测试的「录制端」
 *
 * 思路：同一个随机种子下，让 JS 版把一整局的动作全录下来（出牌/攻击/结束回合），
 * 并把每回合结束时的状态指纹一并存盘。然后由 GDScript 版重放这份动作表——
 * 只要两边每一步的状态指纹完全一致，就证明移植没有走样。
 *
 * 为什么值得这么麻烦：规则引擎有 551 行、几十个分支（守御/迂回/远程/冲锋/死战/
 * 连击/七种效果/军师被动），靠人眼 review 很难保证等价。有了这个测试，
 * 后面任何一次改规则都能立刻发现「只有一边改了」。
 *
 * 用法：node tools/trace.js
 * 产物：godot/tests/fixtures/trace.json
 */
'use strict';
var fs = require('fs');
var path = require('path');

var ROOT = path.resolve(__dirname, '..');

/* ---- 确定性随机数：必须与 godot/core/rng.gd 的 xorshift32 完全一致 ---- */
function makeRng(seed) {
  var s = (seed >>> 0) || 1;
  return function () {
    var x = s;
    x = (x ^ (x << 13)) >>> 0;
    x = (x ^ (x >>> 17)) >>> 0;
    x = (x ^ (x << 5)) >>> 0;
    s = x;
    return x / 4294967296;
  };
}

/* 用确定性 RNG 顶掉 Math.random（引擎内部只用它做洗牌与技能随机选人） */
function installRng(seed) {
  var r = makeRng(seed);
  Math.random = function () { return r(); };
}

var D = require(path.join(ROOT, 'js/data.js'));
var C = require(path.join(ROOT, 'js/campaign.js'));
/* engine.js 从全局取数据源（浏览器里是 self.Data），Node 下需手动挂上 */
globalThis.Data = D;
globalThis.Campaign = C;
var E = require(path.join(ROOT, 'js/engine.js'));

/* ---- 状态指纹：格式必须与 rules_engine.gd 的 fingerprint() 逐字一致 ---- */
function rowSig(row) {
  return row.map(function (u) {
    return u.baseId + '/' + u.atk + '/' + u.hp + '/' + (u.canAttack ? 1 : 0);
  }).join(',');
}
function handSig(hand) {
  return hand.map(function (c) { return c.baseId; }).join(',');
}
function fingerprint(state) {
  var parts = [];
  parts.push('t' + state.turnNo + ':' + state.current + ':' + (state.over ? 1 : 0) + ':' +
    (state.winner === null || state.winner === undefined ? '-' : state.winner));
  ['p1', 'p2'].forEach(function (pid) {
    var p = state.players[pid];
    var s = pid + ' hp' + p.hp + '/' + p.maxHp + ' m' + p.mana + '/' + p.maxMana +
      ' f' + p.fatigue + ' sk' + (p.skillUsed ? 1 : 0) +
      ' h[' + handSig(p.hand) + '] d' + p.deck.length + ' b{';
    ['front', 'mid', 'back'].forEach(function (r) {
      s += r + ':' + rowSig(p.board[r]) + ';';
    });
    s += '}';
    parts.push(s);
  });
  return parts.join(' | ');
}

/* ---- 确定性策略：有牌就出（手牌顺序），能打就打（首个合法目标），否则结束回合 ---- */
function playOneTurn(state, trace, pid) {
  var guard = 0;
  while (!state.over && guard++ < 80) {
    var p = state.players[pid];
    var played = false;

    for (var i = 0; i < p.hand.length; i++) {
      var card = p.hand[i];
      if (E.canPlay(state, pid, card)) {
        var r = E.playCard(state, pid, card.uid);
        if (r.ok) {
          trace.push({ a: 'play', uid: card.uid });
          played = true;
          break;
        }
      }
    }
    if (played) continue;

    if (E.canSkill(state, pid)) {
      var rs = E.useSkill(state, pid);
      if (rs.ok) { trace.push({ a: 'skill' }); continue; }
    }

    var attacked = false;
    for (var ri = 0; ri < E.RANKS.length && !attacked; ri++) {
      var row = p.board[E.RANKS[ri]].slice();
      for (var ui = 0; ui < row.length; ui++) {
        var u = row[ui];
        if (!u.canAttack || u.atk <= 0) continue;
        var info = E.getAttackTargets(state, pid, u);
        if (info.heroOk) {
          if (E.attack(state, pid, u.uid, { kind: 'hero' }).ok) {
            trace.push({ a: 'attack', uid: u.uid, target: { kind: 'hero' } });
            attacked = true;
            break;
          }
        } else if (info.units.length > 0) {
          var t = info.units[0];
          if (E.attack(state, pid, u.uid, { kind: 'unit', uid: t.unit.uid }).ok) {
            trace.push({ a: 'attack', uid: u.uid, target: { kind: 'unit', uid: t.unit.uid } });
            attacked = true;
            break;
          }
        }
      }
    }
    if (attacked) continue;

    trace.push({ a: 'end' });
    E.endTurn(state);
    return;
  }
  trace.push({ a: 'end' });
  if (!state.over) E.endTurn(state);
}

function runScenario(cfg) {
  installRng(cfg.seed);
  var state = E.newGame(cfg.hero, cfg.foe, cfg.first, 'bijiang', cfg.decks || {}, cfg.opts || {});
  var trace = [{ a: 'mull', p1: [], p2: [] }];
  E.doMulligan(state, 'p1', []);
  E.doMulligan(state, 'p2', []);
  E.beginGame(state);

  var marks = [];           /* 每回合结束时的指纹 */
  var rounds = 0;
  while (!state.over && rounds < 40) {
    var pid = state.current;
    playOneTurn(state, trace, pid);
    marks.push(fingerprint(state));
    rounds++;
  }
  return {
    name: cfg.name,
    seed: cfg.seed,
    hero: cfg.hero,
    foe: cfg.foe,
    first: cfg.first,
    opts: cfg.opts || {},
    decks: cfg.decks || {},
    trace: trace,
    marks: marks,
    final: fingerprint(state),
    log: state.log,
    logTotal: state.logTotal || 0
  };
}

/* ---- 场景表：覆盖两位主将、先后手、5 位军师、关卡规则、存活目标 ---- */
var jingxing = D && C.stageById('jingxing');
var jxEnemyDeck = (C.stageById('jingxing').rules.enemyDeck || []).slice();

var scenarios = [
  { name: 'standard-p1', seed: 1, hero: 'liubang', foe: 'xiangyu', first: 'p1' },
  { name: 'standard-p2', seed: 7, hero: 'xiangyu', foe: 'liubang', first: 'p2' },
  { name: 'advisor-hanxin', seed: 11, hero: 'liubang', foe: 'xiangyu', first: 'p1', opts: { rules: { advisor: 'hanxin' } } },
  { name: 'advisor-fankuai', seed: 13, hero: 'liubang', foe: 'xiangyu', first: 'p1', opts: { rules: { advisor: 'fankuai' } } },
  { name: 'advisor-zhangliang', seed: 17, hero: 'liubang', foe: 'xiangyu', first: 'p1', opts: { rules: { advisor: 'zhangliang' } } },
  { name: 'advisor-chenping', seed: 19, hero: 'liubang', foe: 'xiangyu', first: 'p1', opts: { rules: { advisor: 'chenping' } } },
  { name: 'advisor-xiaohe', seed: 23, hero: 'liubang', foe: 'xiangyu', first: 'p1', opts: { rules: { advisor: 'xiaohe' } } },
  /* 陈平的群伤只在「敌军已列阵」时触发，默认场景里永远走不到那一支，
     单靠 advisor-chenping 覆盖不到 chenping_hit 战报与伤害结算，这里补一个预置部队局 */
  {
    name: 'advisor-chenping-preset', seed: 41, hero: 'liubang', foe: 'xiangyu', first: 'p2',
    opts: {
      rules: {
        advisor: 'chenping',
        enemyOpeningUnits: [
          { baseId: 'n_bing1', rank: 'front' },
          { baseId: 'n_shi1', rank: 'mid' },
          { baseId: 'n_ma2', rank: 'back' }
        ]
      }
    }
  },
  {
    name: 'stage-pengcheng', seed: 43, hero: 'liubang', foe: 'xiangyu', first: 'p1',
    opts: { rules: C.stageById('pengcheng').rules, p2Meta: C.stageById('pengcheng').enemy.meta }
  },
  {
    name: 'stage-jingxing', seed: 29, hero: 'liubang', foe: 'xiangyu', first: 'p2',
    opts: {
      rules: C.stageById('jingxing').rules,
      p2Meta: C.stageById('jingxing').enemy.meta
    }
  },
  {
    name: 'stage-xingyang', seed: 31, hero: 'liubang', foe: 'xiangyu', first: 'p1',
    opts: { rules: C.stageById('xingyang').rules, p2Meta: C.stageById('xingyang').enemy.meta }
  },
  {
    name: 'goal-survive', seed: 37, hero: 'liubang', foe: 'xiangyu', first: 'p1',
    opts: { rules: { goal: 'survive', goalTurns: 5, playerHp: 12 } }
  },
  /* 心魔「起手少摸一张」：openingDraw 为负会直接从基础起手张数里扣，
     这是两边引擎都要走到的分支，正手/后手各录一局 */
  {
    name: 'asc-draw-p1', seed: 47, hero: 'liubang', foe: 'xiangyu', first: 'p1',
    opts: { rules: { openingDraw: -1 } }
  },
  {
    name: 'asc-draw-p2', seed: 53, hero: 'liubang', foe: 'xiangyu', first: 'p2',
    opts: { rules: { openingDraw: -1, goal: 'survive', goalTurns: 6 } }
  },
  /* 1.1 扩容卡的四个新分支：亡语召唤（刑徒/死士队）、单列加攻（断后/骸骨/偏将）、
     全体伤害（死士将，dmgAll 此前全池零覆盖）、最低血点杀（死囚）+ 守御战吼加攻（拒马）。
     这批卡不走这些场景，等价性测试会"看着全绿，实际没验到新路径"。 */
  {
    name: 'build-death-deck', seed: 59, hero: 'liubang', foe: 'xiangyu', first: 'p1',
    decks: {
      p1: ['n_bing5', 'n_bing5', 'n_bing6', 'n_bing6', 'n_bing7', 'n_bing7', 'n_bing9', 'n_bing10',
        'n_che4', 'n_jiang2', 'n_shi4', 'n_shi5', 'n_yi1', 'n_shi7', 'n_cheng2', 'n_cheng4',
        'n_dun1', 'n_lei1', 'n_cheng3', 'n_huogong'],
      p2: (D.DECKS.chu || []).slice()
    }
  },
  {
    name: 'advisor-xiangying', seed: 61, hero: 'liubang', foe: 'xiangyu', first: 'p1',
    decks: {
      p1: ['n_bing5', 'n_bing5', 'n_bing6', 'n_bing6', 'n_bing7', 'n_bing7', 'n_bing9', 'n_bing10',
        'n_che4', 'n_jiang2', 'n_shi4', 'n_shi5', 'n_yi1', 'n_shi7', 'n_cheng2', 'n_cheng4',
        'n_dun1', 'n_lei1', 'n_cheng3', 'n_huogong'],
      p2: (D.DECKS.chu || []).slice()
    },
    opts: { rules: { advisor: 'xiangying' } }
  },
  /* 死战专精（1.2）：死战召唤的援军吃 rules.lastStandAtk/Hp 的加成。
     档位由 campaign.lastStandTier 算、引擎只认这两个数字——分开测，改动互相不牵连。
     牌组里同时放征发（战吼召唤），用来卡住「只有死战触发的召唤才吃加成」这条边界。 */
  {
    name: 'laststand-tier', seed: 71, hero: 'liubang', foe: 'xiangyu', first: 'p1',
    decks: {
      p1: ['n_bing5', 'n_bing5', 'n_bing6', 'n_bing6', 'n_bing7', 'n_bing7', 'n_bing9', 'n_bing10',
        'n_che4', 'n_jiang2', 'n_shi4', 'n_shi5', 'n_yi1', 'n_shi7', 'n_cheng2', 'n_cheng4',
        'n_dun1', 'n_lei1', 'n_zhengfa', 'n_huogong'],
      p2: (D.DECKS.chu || []).slice()
    },
    opts: { rules: { lastStandAtk: 1, lastStandHp: 1, lastStandTier: 2 } }
  },
  /* 战吼统一走 resolveEffect 之后的补充场景：抽牌（持盾卒）+ 加攻（拒马）+ 回血（瓮城） */
  {
    name: 'battlecry-taunt', seed: 67, hero: 'liubang', foe: 'xiangyu', first: 'p2',
    decks: {
      p1: ['n_dun1', 'n_dun1', 'n_lei1', 'n_lei1', 'n_cheng3', 'n_cheng3', 'n_cheng2', 'n_cheng1',
        'n_shi7', 'n_xiangyong', 'n_xiangyong', 'n_zhengfa', 'n_zhengfa', 'n_xuanshang',
        'n_bing5', 'n_bing6', 'n_shi4', 'n_shi5', 'n_jiang1', 'n_huogong'],
      p2: (D.DECKS.chu || []).slice()
    }
  }
];

var out = { version: 1, engine: 'js', scenarios: [] };
scenarios.forEach(function (cfg) {
  out.scenarios.push(runScenario(cfg));
});

var dest = path.join(ROOT, 'godot/tests/fixtures/trace.json');
fs.mkdirSync(path.dirname(dest), { recursive: true });
fs.writeFileSync(dest, JSON.stringify(out), 'utf8');

out.scenarios.forEach(function (s) {
  console.log('  ' + s.name.padEnd(20) + ' 回合 ' + s.marks.length +
    ' 动作 ' + s.trace.length + ' 终局 ' + (s.final.indexOf(':1:') > 0 ? '有胜者' : '未完'));
});
console.log('写出 ' + dest + '  ' + (fs.statSync(dest).size / 1024).toFixed(1) + ' KB');
