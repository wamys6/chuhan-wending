/* 《楚汉·问鼎》规则引擎（纯逻辑，可在浏览器与 Node 中运行） */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.Engine = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var D = (typeof self !== 'undefined' ? self : globalThis).Data;
  var RANKS = ['front', 'mid', 'back'];
  var uidSeq = 0;

  /* 军师被动数值：调参脚本可以改写（战役平衡用），Godot 侧
     godot/core/rules_engine.gd 顶部的同名常量必须保持一致。
     改动这里等于改规则，必须重跑 tools/trace.js 再跑等价性测试。 */
  var ADV = {
    xiaoheHp: 5,        /* 萧何：开战生命上限 +N */
    xiaoheDraw: 1,      /* 萧何：起手多摸 N 张 */
    chenpingDraw: 1,    /* 陈平：起手多摸 N 张 */
    chenpingAoe: 1,     /* 陈平：敌军已列阵时全体受 N 点伤害 */
    hanxinAtk: 1,       /* 韩信：中军兵种攻击力 +N */
    hanxinCount: 1,     /* 韩信：每场战斗受益的兵种数上限（2 时中军人人 +1，等于全局光环，实测 37%） */
    fankuaiAtk: 0,      /* 樊哙：本场第一个兵种 +N 攻（实测攻击力太贵，只留血） */
    xiangyingCap: 2,    /* 夏侯婴：每场战斗死战额外发动的次数上限（1 次太弱、3 次等于没限，见 build-lines 11.1） */
    zhouboBuff: 1,      /* 周勃：每回合给最高攻兵种 +N/+N（慢热成长） */
    zhouboCap: 1,       /* 周勃：每场战斗成长次数上限（2 次实测 31% 超带，砍到 1 次） */
    liyijiDown: 1,      /* 郦食其：每轮削敌方最高攻兵种 -N 攻（控场） */
    liyijiCap: 1,       /* 郦食其：每场战斗削减次数上限（3 次 45%、2 次 30%，只有 1 次才进带） */
    fankuaiHp: 1,       /* 樊哙：本场第一个兵种 +N 血 */
    zhangliangRefund: 0 /* 张良：每回合首张计谋返还 N 军粮（实测过强已归零，文案由常量生成） */
  };

  function other(pid) { return pid === 'p1' ? 'p2' : 'p1'; }

  function newInstance(baseId) {
    var c = D.CARDS[baseId];
    return {
      uid: ++uidSeq, baseId: baseId, name: c.name, type: c.type, cost: c.cost,
      col: c.col || null, atk: c.atk || 0, hp: c.hp || 0, maxHp: c.hp || 0,
      taunt: !!c.taunt, flank: !!c.flank, ranged: !!c.ranged,
      charge: !!c.charge, deathrattle: c.deathrattle || null, combo: c.combo || null,
      glyph: c.glyph || '牌', desc: c.desc || '', effect: c.effect || null,
      battlecry: c.battlecry || null, canAttack: false
    };
  }

  function shuffle(arr) {
    for (var i = arr.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var t = arr[i]; arr[i] = arr[j]; arr[j] = t;
    }
    return arr;
  }

  /* meta 可选：覆盖主将显示信息（战役里复用英雄技能、换个身份出场） */
  function makePlayer(pid, heroId, customDeck, meta) {
    var hero = D.HEROES[heroId];
    var ids = (customDeck && customDeck.length > 0) ? customDeck.slice() : D.DECKS[hero.faction].slice();
    var deckIds = shuffle(ids);
    var name = (meta && meta.name) || hero.name;
    var title = (meta && meta.title) || hero.title;
    var glyph = (meta && meta.glyph) || hero.glyph;
    var hp = (meta && typeof meta.hp === 'number') ? meta.hp : hero.hp;
    return {
      id: pid, heroId: heroId, name: name, title: title,
      glyph: glyph, skill: hero.skill,
      art: (meta && meta.art) || null,
      hp: hp, maxHp: hp,
      mana: 0, maxMana: 0, fatigue: 0, skillUsed: false, turnsTaken: 0,
      cardsPlayed: 0,
      deck: deckIds.map(newInstance), hand: [],
      board: { front: [], mid: [], back: [] }
    };
  }

  function log(state, text) {
    state.log.push(text);
    state.logTotal = (state.logTotal || 0) + 1;
    if (state.log.length > 60) state.log.shift();
  }

  /* ---------- 开局 ---------- */

  /* opts 可选，战役模式用：
       opts.rules            关卡规则（handLimit / goal / goalTurns / playerStartMana /
                             enemyStartMana / enemyOpeningUnits / enemyDeck）
       opts.p1Meta / p2Meta  覆盖双方主将的显示信息 */
  function newGame(playerHeroId, aiHeroId, firstPid, aiLevel, customDecks, opts) {
    uidSeq = 0;
    customDecks = customDecks || {};
    opts = opts || {};
    var rules = opts.rules || {};
    /* 关卡规则：敌方使用专门编排的牌组（每关打法不同） */
    if (rules.enemyDeck && rules.enemyDeck.length) customDecks.p2 = rules.enemyDeck.slice();
    var state = {
      turnNo: 0, current: firstPid, over: false, winner: null, log: [], rules: rules,
      levels: { p1: 'player', p2: aiLevel || 'bijiang' },
      /* 战绩统计（结算面板用）：造成的伤害 / 直击主将 / 出兵 / 计谋 / 治疗 */
      stats: {
        p1: { dmg: 0, heroDmg: 0, units: 0, spells: 0, heal: 0 },
        p2: { dmg: 0, heroDmg: 0, units: 0, spells: 0, heal: 0 }
      },
      players: {
        p1: makePlayer('p1', playerHeroId, customDecks.p1, opts.p1Meta),
        p2: makePlayer('p2', aiHeroId, customDecks.p2, opts.p2Meta)
      }
    };
    /* 关卡规则：玩家起始血量（鸿门宴这类"命悬一线"的关卡用） */
    if (rules.playerHp) {
      state.players.p1.hp = rules.playerHp;
      state.players.p1.maxHp = rules.playerHp;
    }
    /* 军师「萧何·镇国抚民」：每场战斗开局生命上限 +ADV.xiaoheHp */
    if (rules.advisor === 'xiaohe') {
      state.players.p1.hp += ADV.xiaoheHp;
      state.players.p1.maxHp += ADV.xiaoheHp;
      log(state, '军师萧何镇抚后方，我军生命上限 +' + ADV.xiaoheHp);
    }
    /* 行军积累的生命上限加成（事件「流民归附」等） */
    if (rules.playerHpBonus) {
      state.players.p1.hp += rules.playerHpBonus;
      state.players.p1.maxHp += rules.playerHpBonus;
      log(state, '沿途休整，我军生命上限 +' + rules.playerHpBonus);
    }
    /* 关卡规则：敌方开局已有部队在场 */
    if (rules.enemyOpeningUnits && rules.enemyOpeningUnits.length) {
      rules.enemyOpeningUnits.forEach(function (spec) {
        var u = newInstance(spec.baseId);
        u.canAttack = false;
        var rank = spec.rank || 'front';
        state.players.p2.board[rank].push(u);
        log(state, '敌军 ' + u.name + ' 已在' + D.RANK_NAMES[rank] + '列列阵');
      });
    }
    /* 军师「陈平·六出奇计」：开战先摸一张牌；敌军若已列阵，再全体受 1 点伤害 */
    if (rules.advisor === 'chenping') {
      var hit = 0;
      RANKS.forEach(function (r) {
        state.players.p2.board[r].slice().forEach(function (u) {
          hit++;
          damageUnit(state, 'p2', u, ADV.chenpingAoe, r);
        });
      });
      log(state, hit ? '军师陈平出奇计，敌军 ' + hit + ' 支部队各受 ' + ADV.chenpingAoe + ' 点伤害'
        : '军师陈平出奇计，先机在握');
    }
    var i;
    /* 起手张数：先手 3 张、后手 4 张；openingDraw 为负（心魔「起手少摸」）时
       直接从基础张数里扣——以前负数只被 extraDraw 的循环吞掉，等于没效果 */
    var negDraw = Math.min(0, rules.openingDraw || 0);
    var firstDraw = 3 + (firstPid === 'p1' ? negDraw : 0);
    var second = other(firstPid);
    var secondDraw = 4 + (second === 'p1' ? negDraw : 0);
    for (i = 0; i < firstDraw; i++) drawCard(state, firstPid, true);
    for (i = 0; i < secondDraw; i++) drawCard(state, second, true);
    state.players[second].hand.push(newInstance('s_xianji'));
    /* 起手额外摸牌：关卡/事件规则（樵夫指路）+ 军师（萧何/陈平各 1 张） */
    var advDraw = (rules.advisor === 'xiaohe' ? ADV.xiaoheDraw : 0)
      + (rules.advisor === 'chenping' ? ADV.chenpingDraw : 0);
    var bonusDraw = Math.max(0, rules.openingDraw || 0);
    var extraDraw = bonusDraw + advDraw;
    if (extraDraw) {
      for (i = 0; i < extraDraw; i++) drawCard(state, 'p1', true);
      if (bonusDraw) log(state, '轻装疾行，我军起手多摸 ' + bonusDraw + ' 张牌');
      if (advDraw) log(state, '军师献策，我军起手多摸 ' + advDraw + ' 张牌');
    }
    log(state, (firstPid === 'p1' ? '我方' : '敌方') + '抢得先机，率先出手');
    /* 进入开局换牌阶段：双方调手牌后由 beginGame 正式开局 */
    state.phase = 'mulligan';
    state.mulliganDone = { p1: false, p2: false };
    return state;
  }

  /* ---------- 开局换牌（mulligan） ---------- */

  /* 把选中的起手牌洗回牌库并抽回等量新牌；先机虎符不可换 */
  function doMulligan(state, pid, uids) {
    if (!state || state.phase !== 'mulligan' || state.mulliganDone[pid]) return { ok: false };
    var p = state.players[pid];
    var set = {};
    (uids || []).forEach(function (u) { set[u] = true; });
    var keep = [], replace = [];
    p.hand.forEach(function (c) { (set[c.uid] && c.baseId !== 's_xianji' ? replace : keep).push(c); });
    replace.forEach(function (c) { p.deck.push(c); });
    p.hand = keep;
    shuffle(p.deck);
    for (var i = 0; i < replace.length; i++) drawCard(state, pid, true);
    state.mulliganDone[pid] = true;
    if (replace.length > 0) log(state, (pid === 'p1' ? '我方' : '敌方') + '换掉 ' + replace.length + ' 张起手牌');
    return { ok: true, swapped: replace.length };
  }

  /* 双方换牌完毕，正式开始第一回合 */
  function beginGame(state) {
    if (!state || state.phase !== 'mulligan') return;
    state.phase = 'play';
    startTurn(state, state.current);
  }

  /* ---------- 回合 ---------- */

  function startTurn(state, pid) {
    if (state.over) return;
    var p = state.players[pid];
    var rules = state.rules || {};
    state.turnNo++;
    p.turnsTaken = (p.turnsTaken || 0) + 1;
    p.maxMana = Math.min(D.MAX_MANA, p.maxMana + 1);
    p.mana = p.maxMana;
    /* 关卡规则：玩家首回合额外军粮（彭城之战的补偿） */
    if (rules.playerStartMana && pid === 'p1' && p.turnsTaken === 1) p.mana += rules.playerStartMana;
    /* 关卡规则：敌方首回合额外军粮（垓下决战的霸王起手） */
    if (rules.enemyStartMana && pid === 'p2' && p.turnsTaken === 1) p.mana += rules.enemyStartMana;
    p.skillUsed = false;
    p.cardsPlayed = 0;
    p.spellPlayed = 0;
    RANKS.forEach(function (r) {
      p.board[r].forEach(function (u) { u.canAttack = u.atk > 0; });
    });
    /* 军师「周勃·安刘定倾」：每个我方回合开始，最高攻兵种 +N/+N（每场至多 CAP 次）
       慢热成长：要先把部队站住，收益在第 3 回合后才显出来——与韩信（登场即 +1）错位 */
    if (pid === 'p1' && rules.advisor === 'zhoubo'
        && (p.zbBuffs || 0) < ADV.zhouboCap) {
      var zbBest = null;
      RANKS.forEach(function (r) {
        p.board[r].forEach(function (u) {
          if (!zbBest || u.atk > zbBest.atk) zbBest = u;
        });
      });
      if (zbBest) {
        zbBest.atk += ADV.zhouboBuff;
        zbBest.hp += ADV.zhouboBuff;
        zbBest.maxHp += ADV.zhouboBuff;
        p.zbBuffs = (p.zbBuffs || 0) + 1;
        zbBest.canAttack = zbBest.atk > 0;
        log(state, '军师周勃安刘定倾：' + zbBest.name + ' +'
          + ADV.zhouboBuff + '/+' + ADV.zhouboBuff);
      }
    }
    /* 军师「郦食其·舌下齐城」：每个敌方回合开始，敌方最高攻兵种攻击力 -N（每场至多 CAP 次）
       只削一个、且削不到负数：控的是「对方的大哥」，不是全军 */
    if (pid === 'p2' && rules.advisor === 'liyiji'
        && (state.players.p2.lyCuts || 0) < ADV.liyijiCap) {
      var lyP = state.players.p2, lyBest = null;
      RANKS.forEach(function (r) {
        lyP.board[r].forEach(function (u) {
          if (!lyBest || u.atk > lyBest.atk) lyBest = u;
        });
      });
      if (lyBest && lyBest.atk > 0) {
        lyBest.atk = Math.max(0, lyBest.atk - ADV.liyijiDown);
        lyP.lyCuts = (lyP.lyCuts || 0) + 1;
        lyBest.canAttack = lyBest.atk > 0;
        log(state, '军师郦食其舌下齐城：' + lyBest.name + ' 攻击力 -' + ADV.liyijiDown);
      }
    }
    log(state, '—— 第 ' + state.turnNo + ' 回合 · ' + (pid === 'p1' ? '我方' : '敌方'));
    drawCard(state, pid);
  }

  function endTurn(state) {
    if (state.over) return;
    var rules = state.rules || {};
    /* 关卡规则：存活型目标——玩家数满回合数即获胜 */
    if (rules.goal === 'survive' && state.current === 'p1') {
      var me = state.players.p1;
      if (me.turnsTaken >= rules.goalTurns) {
        state.over = true;
        state.winner = 'p1';
        log(state, '你熬过了 ' + rules.goalTurns + ' 个回合，全身而退！');
        return;
      }
    }
    state.current = other(state.current);
    startTurn(state, state.current);
  }

  /* ---------- 抽牌与疲劳 ---------- */

  /* ignoreLimit：起手抽牌阶段用，不受关卡手牌上限限制 */
  function drawCard(state, pid, ignoreLimit) {
    if (state.over) return;
    var p = state.players[pid];
    if (p.deck.length === 0) {
      p.fatigue++;
      log(state, (pid === 'p1' ? '我方' : '敌方') + '粮草耗尽，疲劳受 ' + p.fatigue + ' 点伤害');
      damageHero(state, pid, p.fatigue);
      return;
    }
    var card = p.deck.shift();
    var handLimit = ignoreLimit ? D.HAND_LIMIT
      : ((state.rules && state.rules.handLimit) || D.HAND_LIMIT);
    if (p.hand.length >= handLimit) {
      log(state, (pid === 'p1' ? '我方' : '敌方') + '手牌已满，' + card.name + ' 被烧毁');
      return;
    }
    p.hand.push(card);
  }

  /* ---------- 目标合法性 ---------- */

  /* 可达规则：默认只能攻击敌方最靠前的有兵之列；马（迂回）可打前锋/中军；炮（远程）可打任意列；
     敌方全军覆没时才能攻击敌方英雄。可达目标中若有守御单位，必须先攻击守御。 */
  function getAttackTargets(state, pid, unit) {
    var e = state.players[other(pid)];
    var occupied = RANKS.filter(function (r) { return e.board[r].length > 0; });
    if (occupied.length === 0) return { heroOk: true, units: [], mustTaunt: false };
    var ranks;
    if (unit.ranged) ranks = occupied;
    else if (unit.flank) ranks = occupied.filter(function (r) { return r === 'front' || r === 'mid'; });
    else ranks = [occupied[0]];
    var units = [];
    ranks.forEach(function (r) {
      e.board[r].forEach(function (u) { units.push({ unit: u, rank: r }); });
    });
    var taunts = units.filter(function (x) { return x.unit.taunt; });
    if (taunts.length > 0) units = taunts;
    return { heroOk: false, units: units, mustTaunt: taunts.length > 0 };
  }

  /* ---------- 伤害 ---------- */

  function removeDead(state, pid, rank, unit) {
    var row = state.players[pid].board[rank];
    var idx = row.indexOf(unit);
    if (idx >= 0) {
      row.splice(idx, 1);
      log(state, (pid === 'p1' ? '我方' : '敌方') + '的 ' + unit.name + ' 阵亡');
    }
  }

  function damageUnit(state, ownerPid, unit, amount, rank) {
    if (amount <= 0 || state.over) return;
    var real = Math.min(amount, unit.hp);            /* 溢出伤害不计入战绩 */
    state.stats[other(ownerPid)].dmg += real;
    unit.hp -= amount;
    if (unit.hp <= 0) {
      removeDead(state, ownerPid, rank, unit);
      /* 死战：阵亡时触发一次效果（先移除，避免效果再次处理自己） */
      if (unit.deathrattle) {
        log(state, (ownerPid === 'p1' ? '我方' : '敌方') + unit.name + ' 死战发动');
        resolveEffect(state, ownerPid, unit.deathrattle, null, { lastStand: true });
        /* 夏侯婴·滕公：守御兵种阵亡时死战额外发动一次。
           taunt 是确定性字段，锁步联机安全；summon 类亡语第二次会受列满限制自然截断 */
        /* 夏侯婴：死战额外发动一次，每场战斗有次数上限。
           不限守御（限定守御实测只值 +1pp，带亡语的守御卡太少）；但完全不限次实测 +29pp，
           而每场 3 次把收益压回区间内——它奖励"多带死战卡"，不是白送强度。 */
        var xyOwner = state.players[ownerPid];
        if (ownerPid === 'p1' && state.rules.advisor === 'xiangying'
            && (xyOwner.xyDoubles || 0) < ADV.xiangyingCap + (xyOwner.xyCapBonus || 0)) {
          xyOwner.xyDoubles = (xyOwner.xyDoubles || 0) + 1;
          log(state, '军师夏侯婴护军有方：' + unit.name + ' 死战再发');
          resolveEffect(state, ownerPid, unit.deathrattle, null, { lastStand: true });
        }
      }
    }
  }

  function damageHero(state, pid, amount) {
    if (amount <= 0 || state.over) return;
    var p = state.players[pid];
    var real = Math.min(amount, p.hp);
    state.stats[other(pid)].dmg += real;
    state.stats[other(pid)].heroDmg += real;
    p.hp -= amount;
    if (p.hp <= 0) {
      p.hp = 0;
      state.over = true;
      state.winner = other(pid);
      log(state, (pid === 'p1' ? '我方' : '敌方') + '主将被击倒！');
    }
  }

  /* ---------- 出牌 ---------- */

  function canPlay(state, pid, card) {
    var p = state.players[pid];
    if (card.cost > p.mana) return false;
    if (card.type === 'piece' && p.board[card.col].length >= D.COLUMN_LIMIT) return false;
    return true;
  }

  function playCard(state, pid, uid) {
    var p = state.players[pid];
    var idx = -1, card = null;
    for (var i = 0; i < p.hand.length; i++) {
      if (p.hand[i].uid === uid) { idx = i; card = p.hand[i]; break; }
    }
    if (!card) return { ok: false, reason: '手里没有这张牌' };
    if (card.cost > p.mana) return { ok: false, reason: '军粮不足' };
    if (card.type === 'piece' && p.board[card.col].length >= D.COLUMN_LIMIT) {
      return { ok: false, reason: D.RANK_NAMES[card.col] + '列已满（每列最多 ' + D.COLUMN_LIMIT + ' 员）' };
    }
    /* 连击：本回合此前已经出过牌才触发 */
    var comboActive = (p.cardsPlayed || 0) > 0;
    p.mana -= card.cost;
    p.hand.splice(idx, 1);
    p.cardsPlayed = (p.cardsPlayed || 0) + 1;
    if (card.type === 'piece') {
      /* 军师被动：韩信（前锋 +1 攻）/ 樊哙（本场第一个出场的兵种 +2/+1） */
      if (pid === 'p1') {
        var advAtk = 0;
        if (state.rules.advisor === 'hanxin' && card.col === 'mid'
            && (p.hxCount || 0) < ADV.hanxinCount) {
          advAtk += ADV.hanxinAtk;
          p.hxCount = (p.hxCount || 0) + 1;
        }
        if (state.rules.advisor === 'fankuai' && !p.firstDeployDone) {
          advAtk += ADV.fankuaiAtk;
          card.hp += ADV.fankuaiHp;
          card.maxHp += ADV.fankuaiHp;
          p.firstDeployDone = true;
          var fkDesc = [];
          if (ADV.fankuaiAtk) fkDesc.push('攻击力 +' + ADV.fankuaiAtk);
          if (ADV.fankuaiHp) fkDesc.push('生命 +' + ADV.fankuaiHp);
          log(state, '军师樊哙先登陷阵：' + card.name + ' ' + fkDesc.join('、'));
        }
        if (advAtk) {
          card.atk += advAtk;
          if (state.rules.advisor === 'hanxin') {
            log(state, '军师韩信多多益善：' + card.name + ' 攻击力 +' + ADV.hanxinAtk);
          }
        }
      }
      /* 冲锋：登场当回合即可攻击 */
      card.canAttack = !!card.charge && card.atk > 0;
      p.board[card.col].push(card);
      state.stats[pid].units++;
      log(state, (pid === 'p1' ? '我方' : '敌方') + '派出 ' + card.name + ' → ' + D.RANK_NAMES[card.col]);
      if (card.battlecry) resolveBattlecry(state, pid, card.battlecry);
    } else {
      state.stats[pid].spells++;
      log(state, (pid === 'p1' ? '我方' : '敌方') + '使用计谋「' + card.name + '」');
      resolveEffect(state, pid, card.effect, card);
      /* 军师被动：张良——每回合第一张计谋牌额外抽一张（原先还返还 1 军粮，实测过强已去掉） */
      if (pid === 'p1' && state.rules.advisor === 'zhangliang' && !p.spellPlayed) {
        p.spellPlayed = 1;
        log(state, '军师张良运筹，锦囊既出，再添一策');
        drawCard(state, pid);
        /* 返还力实测过强，已归零；保留常量是为了让文案能跟着数值走（踩坑：文案写返还、实现已删） */
        if (ADV.zhangliangRefund > 0) p.mana += ADV.zhangliangRefund;
      }
    }
    if (comboActive && card.combo) {
      log(state, (pid === 'p1' ? '我方' : '敌方') + '「' + card.name + '」连击发动');
      resolveEffect(state, pid, card.combo, card);
    }
    return { ok: true };
  }

  function resolveBattlecry(state, pid, bc) {
    var p = state.players[pid];
    if (bc.tokens) {
      for (var j = 0; j < bc.tokens; j++) {
        if (p.board.front.length >= D.COLUMN_LIMIT) break;
        var t = newInstance('n_bing1');
        t.name = '兵·新卒（韩信所点）';
        t.canAttack = false;
        p.board.front.push(t);
      }
      log(state, (pid === 'p1' ? '我方' : '敌方') + '点兵 ' + j + ' 员，进入前锋列');
    }
    /* tokens 是点兵专属；其余字段一律交给 resolveEffect——战吼与亡语共用同一套效果词汇，
       否则每加一种战吼都要在引擎里复制一遍分支（拒马加攻、瓮城回血都会撞上）。 */
    var rest = {};
    Object.keys(bc).forEach(function (k) { if (k !== 'tokens') rest[k] = bc[k]; });
    if (Object.keys(rest).length) resolveEffect(state, pid, rest);
  }

  /* 统一的卡牌效果执行器。self 是触发效果的牌本身（连击里的自我强化要用） */
  function resolveEffect(state, pid, effect, self, ctx) {
    if (!effect) return;
    var p = state.players[pid], e = state.players[other(pid)];
    if (effect.draw) { for (var i = 0; i < effect.draw; i++) drawCard(state, pid); }
    if (effect.mana) { p.mana += effect.mana; }
    if (effect.dmgCol) {
      var targets = e.board[effect.dmgCol].slice();
      targets.forEach(function (u) { damageUnit(state, other(pid), u, effect.amount, effect.dmgCol); });
    }
    if (effect.dmgLowest) {
      var lowest = null;
      RANKS.forEach(function (r) {
        e.board[r].forEach(function (u) {
          if (!lowest || u.hp < lowest.unit.hp) lowest = { unit: u, rank: r };
        });
      });
      if (lowest) damageUnit(state, other(pid), lowest.unit, effect.dmgLowest, lowest.rank);
    }
    /* 反间：狙击敌方攻击力最高的兵种 */
    if (effect.dmgHighest) {
      var highest = null;
      RANKS.forEach(function (r) {
        e.board[r].forEach(function (u) {
          if (!highest || u.atk > highest.unit.atk) highest = { unit: u, rank: r };
        });
      });
      if (highest) damageUnit(state, other(pid), highest.unit, effect.dmgHighest, highest.rank);
    }
    /* 军师主动技（P6）：给我方/敌方「攻击力最高」的兵种加/削。不走 damageUnit，
       所以没有溢出伤害与亡语结算；攻击力削到 0 时同步收回攻击权（否则 0 攻还能出击） */
    if (effect.buffHighest) {
      var bh = null;
      RANKS.forEach(function (r) {
        p.board[r].forEach(function (u) { if (!bh || u.atk > bh.unit.atk) bh = { unit: u, rank: r }; });
      });
      if (bh) {
        var ba = effect.buffHighest.atk || 0, bhp = effect.buffHighest.hp || 0;
        bh.unit.atk += ba;
        bh.unit.hp += bhp;
        bh.unit.maxHp += bhp;
        bh.unit.canAttack = bh.unit.atk > 0;
        log(state, '我军 ' + bh.unit.name + ' +' + ba + '/+' + bhp);
      }
    }
    if (effect.debuffHighest) {
      var dh = null;
      RANKS.forEach(function (r) {
        e.board[r].forEach(function (u) { if (!dh || u.atk > dh.unit.atk) dh = { unit: u, rank: r }; });
      });
      if (dh && dh.unit.atk > 0) {
        var da = effect.debuffHighest.atk || 0;
        dh.unit.atk = Math.max(0, dh.unit.atk - da);
        dh.unit.canAttack = dh.unit.atk > 0;
        log(state, '敌军 ' + dh.unit.name + ' 攻击力 -' + da);
      }
    }
    /* 直取主将 / 恢复主将 */
    if (effect.dmgHero) {      log(state, (pid === 'p1' ? '我方' : '敌方') + '计策直击敌将 ' + effect.dmgHero + ' 点');
      damageHero(state, other(pid), effect.dmgHero);
    }
    if (effect.healHero) {
      var before = p.hp;
      p.hp = Math.min(p.maxHp, p.hp + effect.healHero);
      if (p.hp > before) {
        state.stats[pid].heal += p.hp - before;
        log(state, (pid === 'p1' ? '我方' : '敌方') + '主将恢复 ' + (p.hp - before) + ' 点血量');
      }
    }
    /* 全场伤害 / 全场增减攻 */
    if (effect.dmgAll) {
      RANKS.forEach(function (r) {
        e.board[r].slice().forEach(function (u) { damageUnit(state, other(pid), u, effect.dmgAll, r); });
      });
    }
    if (effect.buffCol) {
      p.board[effect.buffCol].forEach(function (u) { u.atk += effect.atk; });
    }
    if (effect.buffAll) {
      RANKS.forEach(function (r) { p.board[r].forEach(function (u) { u.atk += effect.buffAll; }); });
    }
    /* 全体加血（周勃·整军）：上限与当前血量一起加，不触发亡语/溢出 */
    if (effect.buffAllHp) {
      RANKS.forEach(function (r) {
        p.board[r].forEach(function (u) {
          u.hp += effect.buffAllHp;
          u.maxHp += effect.buffAllHp;
        });
      });
      log(state, '我军全体 +' + effect.buffAllHp + ' 生命');
    }
    if (effect.debuffAll) {
      RANKS.forEach(function (r) {
        e.board[r].forEach(function (u) { u.atk = Math.max(0, u.atk - effect.debuffAll); });
      });
    }
    /* 召唤援军（列满则止） */
    if (effect.summon) {
      var rank = effect.summon.rank || 'front';
      var n = effect.summon.count || 1;
      /* 死战专精：牌组里死战牌够多时，死战唤来的援军更硬（见 campaign.lastStandTier）。
         只对「死战触发的召唤」生效——战吼召唤（征发之类）不吃，否则等于全体加强 */
      var lsOn = ctx && ctx.lastStand && pid === 'p1';
      var ba = lsOn ? (state.rules.lastStandAtk || 0) : 0;
      var bh = lsOn ? (state.rules.lastStandHp || 0) : 0;
      for (var k = 0; k < n; k++) {
        if (p.board[rank].length >= D.COLUMN_LIMIT) break;
        if (!D.CARDS[effect.summon.baseId]) break;
        var t = newInstance(effect.summon.baseId);
        t.canAttack = false;
        if (ba > 0 || bh > 0) { t.atk += ba; t.hp += bh; t.maxHp += bh; }
        p.board[rank].push(t);
      }
      log(state, (pid === 'p1' ? '我方' : '敌方') + '增援抵达' + D.RANK_NAMES[rank] + '列'
        + (ba > 0 || bh > 0 ? '（死战专精 +' + ba + '/+' + bh + '）' : ''));
    }
    /* 只作用于牌本身（连击自我强化） */
    if (effect.selfAtk && self) { self.atk += effect.selfAtk; }
  }

  /* ---------- 军师主动技（每场战斗 1 次） ---------- */

  /* 主动技定义由战役侧通过 rules.advisorActive 注入：引擎不反向依赖 campaign。
     只对 p1 生效（军师是玩家的），每场一次，用 p.advUsed 记。 */
  function advisorActive(state) {
    var rules = state.rules || {};
    var a = rules.advisorActive;
    if (!rules.advisor || !a || !a.fx) return null;
    return a;
  }

  function canAdvisorActive(state, pid) {
    if (!state || state.over) return false;
    if (pid !== 'p1') return false;
    var a = advisorActive(state);
    if (!a) return false;
    var p = state.players.p1;
    if (p.advUsed) return false;
    return p.mana >= (a.cost || 0);
  }

  function useAdvisorActive(state, pid) {
    if (!canAdvisorActive(state, pid)) return { ok: false, reason: '军师技现在用不了' };
    var a = advisorActive(state);
    var p = state.players.p1;
    p.mana -= (a.cost || 0);
    p.advUsed = true;
    log(state, '军师出手「' + (a.name || '献策') + '」');
    /* xyCap 不是通用效果词，是夏侯婴专属：本场死战额外发动的次数上限 +N */
    var fx = {};
    Object.keys(a.fx).forEach(function (k) { if (k !== 'xyCap') fx[k] = a.fx[k]; });
    if (Object.keys(fx).length) resolveEffect(state, 'p1', fx, null);
    if (a.fx.xyCap) p.xyCapBonus = (p.xyCapBonus || 0) + a.fx.xyCap;
    return { ok: true };
  }

  /* ---------- 英雄技能 ---------- */

  function canSkill(state, pid) {
    var p = state.players[pid], e = state.players[other(pid)];
    if (p.skillUsed || p.mana < p.skill.cost || state.over) return false;
    if (p.heroId === 'xiangyu') return true;
    if (p.heroId === 'liubang') {
      if (p.hp < p.maxHp) return true;
      var any = RANKS.some(function (r) { return p.board[r].length > 0; });
      return any;
    }
    return false;
  }

  function useSkill(state, pid) {
    if (!canSkill(state, pid)) return { ok: false, reason: '技能现在用不了' };
    var p = state.players[pid], e = state.players[other(pid)];
    p.mana -= p.skill.cost;
    p.skillUsed = true;
    if (p.heroId === 'xiangyu') {
      if (e.board.front.length > 0) {
        e.board.front.slice().forEach(function (u) { damageUnit(state, other(pid), u, 1, 'front'); });
        log(state, (pid === 'p1' ? '我方' : '敌方') + '发动「破釜沉舟」，扫射敌方前锋');
      } else {
        log(state, (pid === 'p1' ? '我方' : '敌方') + '发动「破釜沉舟」，直击敌将 1 点');
        damageHero(state, other(pid), 1);
      }
    } else {
      if (p.hp < p.maxHp) {
        var hb = p.hp;
        p.hp = Math.min(p.maxHp, p.hp + 2);
        state.stats[pid].heal += p.hp - hb;
        log(state, (pid === 'p1' ? '我方' : '敌方') + '发动「约法三章」，恢复 2 点血量');
      } else {
        var cands = [];
        RANKS.forEach(function (r) { p.board[r].forEach(function (u) { cands.push(u); }); });
        var u = cands[Math.floor(Math.random() * cands.length)];
        if (u) {
          u.atk += 1;
          log(state, (pid === 'p1' ? '我方' : '敌方') + '发动「约法三章」，' + u.name + ' +1 攻');
        }
      }
    }
    return { ok: true };
  }

  /* ---------- 攻击 ---------- */

  function attack(state, pid, attackerUid, target) {
    var p = state.players[pid], e = state.players[other(pid)];
    var attacker = null, arank = null;
    RANKS.forEach(function (r) {
      p.board[r].forEach(function (u) { if (u.uid === attackerUid) { attacker = u; arank = r; } });
    });
    if (!attacker) return { ok: false, reason: '找不到攻击单位' };
    if (!attacker.canAttack || attacker.atk <= 0) return { ok: false, reason: '该单位本回合不能攻击' };
    var info = getAttackTargets(state, pid, attacker);
    if (target.kind === 'hero') {
      if (!info.heroOk) return { ok: false, reason: '敌方还有兵种挡路' };
      attacker.canAttack = false;
      log(state, (pid === 'p1' ? '我方' : '敌方') + attacker.name + ' 直取敌将，造成 ' + attacker.atk + ' 点伤害');
      damageHero(state, other(pid), attacker.atk);
      return { ok: true };
    }
    var t = null, trank = null;
    for (var i = 0; i < info.units.length; i++) {
      if (info.units[i].unit.uid === target.uid) { t = info.units[i].unit; trank = info.units[i].rank; break; }
    }
    if (!t) return { ok: false, reason: '不能攻击这个目标' };
    attacker.canAttack = false;
    log(state, (pid === 'p1' ? '我方' : '敌方') + attacker.name + ' 攻击 ' + t.name +
      '（' + attacker.atk + ' vs ' + t.atk + '）');
    damageUnit(state, other(pid), t, attacker.atk, trank);
    damageUnit(state, pid, attacker, t.atk, arank);
    return { ok: true };
  }

  /* ---------- 敌方意图预告（只读，不改状态） ----------
     以当前战场为准回答两个问题：
     1. 我方哪些部队会被现有敌军击杀？——围杀口径：够得着它的敌军总攻 ≥ 其生命
     2. 我方主将是否处于斩杀线？——我方全场无兵时主将才暴露（可达规则）
     只覆盖「当前在场敌军」：计谋直伤与当回合新下的冲锋牌预告不了（探针实测
     约覆盖一半的实际死亡），语义是「可能被击杀」，不是「必死」。 */
  function threatPreview(state, pid) {
    var out = { kill: {}, hero: false };
    if (!state || state.over || state.phase !== 'play') return out;
    var me = state.players[pid], foe = state.players[other(pid)];
    var foePid = other(pid);
    var reach = {}, foeAtk = 0;
    RANKS.forEach(function (r) {
      foe.board[r].forEach(function (a) {
        if (a.atk <= 0) return;
        foeAtk += a.atk;
        getAttackTargets(state, foePid, a).units.forEach(function (t) {
          reach[t.unit.uid] = (reach[t.unit.uid] || 0) + a.atk;
        });
      });
    });
    Object.keys(reach).forEach(function (uid) {
      var hp = 0;
      RANKS.some(function (r) {
        return me.board[r].some(function (u) {
          if (String(u.uid) === uid) { hp = u.hp; return true; }
          return false;
        });
      });
      if (hp > 0 && reach[uid] >= hp) out.kill[uid] = true;
    });
    /* 主将：全场无兵才暴露；项羽技能在前锋空时能直击主将，算进斩杀线 */
    var anyMine = RANKS.some(function (r) { return me.board[r].length > 0; });
    if (!anyMine) {
      var dmg = foeAtk;
      if (!foe.skillUsed && foe.mana >= foe.skill.cost && foe.heroId === 'xiangyu') dmg += 1;
      if (dmg >= me.hp) out.hero = true;
    }
    return out;
  }

  return {
    RANKS: RANKS,
    tuning: ADV,
    other: other,
    newInstance: newInstance,
    newGame: newGame,
    doMulligan: doMulligan,
    beginGame: beginGame,
    startTurn: startTurn,
    endTurn: endTurn,
    drawCard: drawCard,
    getAttackTargets: getAttackTargets,
    canPlay: canPlay,
    playCard: playCard,
    advisorActive: advisorActive,
    canAdvisorActive: canAdvisorActive,
    useAdvisorActive: useAdvisorActive,
    canSkill: canSkill,
    useSkill: useSkill,
    attack: attack,
    threatPreview: threatPreview
  };
});
