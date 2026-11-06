/* 《楚汉·问鼎》AI 决策（贪心核心 + 三档难度）
   见习 jianxi：50% 概率故意选次优动作；裨将 bijiang：标准贪心；
   名将 mingjiang：贪心 + 更重视斩杀与保护性交换。 */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.AI = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var Engine = (typeof self !== 'undefined' ? self : globalThis).Engine;

  function opp(pid) { return Engine.other(pid); }

  function levelOf(state, pid) {
    return (state.levels && state.levels[pid]) || 'bijiang';
  }

  /* 出牌评分 */
  function playScore(state, pid, card) {
    var p = state.players[pid], e = state.players[opp(pid)];
    if (card.type === 'piece') {
      var s = (card.atk + card.hp) / Math.max(1, card.cost) * 2 + 1;
      if (card.col === 'front' && p.board.front.length === 0) s += 0.8; /* 前锋不能空 */
      if (card.col === 'back' && p.board.back.length === 0 && e.board.front.length > 0) s += 0.5;
      if (card.taunt && p.board.mid.length === 0) s += 0.6;
      if (card.charge) s += card.atk * 0.35 + 0.5;                 /* 冲锋：当回合就能换血 */
      if (card.deathrattle) s += 0.7;                              /* 死战：死了还有收益 */
      if (card.combo && (p.cardsPlayed || 0) > 0) s += 0.9;
      return s;
    }
    var ef = card.effect || {};
    if (ef.draw) return 3 + ef.draw;
    if (ef.mana) {
      var followup = p.hand.some(function (c) {
        return c.uid !== card.uid && c.type === 'piece' && c.cost === p.mana + 1;
      });
      return followup ? 7 : 0.1;
    }
    if (ef.dmgLowest) {
      var any = Engine.RANKS.some(function (r) { return e.board[r].length > 0; });
      return any ? 2.5 + ef.dmgLowest * 0.3 : 0;
    }
    if (ef.dmgCol) {
      return e.board[ef.dmgCol].length * 1.4 + (e.board[ef.dmgCol].length ? 0.8 : 0);
    }
    if (ef.buffCol) {
      return p.board[ef.buffCol].length * 1.5 + (e.board.front.length ? 0.5 : 0);
    }
    /* ---- 扩充卡池新增的效果 ---- */
    if (ef.dmgHighest) {
      var hasUnit = Engine.RANKS.some(function (r) { return e.board[r].length > 0; });
      return (hasUnit ? 2.6 : 0) + (ef.draw ? ef.draw * 1.8 : 0);
    }
    if (ef.healHero) {
      var missing = Math.max(0, p.maxHp - p.hp);
      return Math.min(missing, ef.healHero) * 1.3 + (ef.draw ? ef.draw * 1.9 : 0);
    }
    if (ef.dmgAll) {
      var n = 0;
      Engine.RANKS.forEach(function (r) { n += e.board[r].length; });
      return n * (ef.dmgAll * 0.7 + 0.5);
    }
    if (ef.debuffAll) {
      var m = 0;
      Engine.RANKS.forEach(function (r) {
        e.board[r].forEach(function (u) { if (u.atk > 0) m++; });
      });
      return m * (ef.debuffAll * 0.9 + 0.5);
    }
    if (ef.summon) {
      var room = Math.max(0, 3 - p.board[ef.summon.rank || 'front'].length);
      return Math.min(room, ef.summon.count || 1) * 2.2;
    }
    if (ef.buffAll) {
      var own = 0;
      Engine.RANKS.forEach(function (r) {
        p.board[r].forEach(function (u) { if (u.atk > 0) own++; });
      });
      return own * ef.buffAll * 0.9;
    }
    return 0;
  }

  function skillUseful(state, pid) {
    var p = state.players[pid], e = state.players[opp(pid)];
    if (p.skillUsed || p.mana < p.skill.cost) return false;
    if (p.heroId === 'xiangyu') return true; /* 扫前锋或直击主将总有目标 */
    if (p.heroId === 'liubang') {
      if (p.hp <= p.maxHp - 2) return true;
      if (p.hp === p.maxHp) {
        return Engine.RANKS.some(function (r) { return p.board[r].length > 0; });
      }
      return false;
    }
    return false;
  }

  /* 攻击评分 */
  function attackScore(attacker, target, level) {
    var kills = attacker.atk >= target.unit.hp;
    var dies = target.unit.atk >= attacker.hp;
    /* 名将不做「没换到人还搭上自己」的送死攻击 */
    if (level === 'mingjiang' && dies && !kills) return -100;
    var s = 0;
    if (kills) s += 8 + target.unit.atk;
    if (!dies) s += 4; else s -= 2;
    if (target.unit.taunt && !kills) s += 2;
    s += target.unit.atk * 0.5 - target.unit.hp * 0.1;
    if (level === 'mingjiang' && !dies && kills) s += 1.5; /* 名将偏爱安全的好交换 */
    return s;
  }

  /* 斩杀计算：场上可攻击单位总攻（+项羽技能直伤）是否够打死敌方主将。
     敌人全军覆没（heroOk）时，所有攻击都能直取主将，总攻即斩杀线。 */
  function lethalPlan(state, pid) {
    var p = state.players[pid], e = state.players[opp(pid)];
    var total = 0, first = null;
    Engine.RANKS.forEach(function (r) {
      p.board[r].forEach(function (u) {
        if (!u.canAttack || u.atk <= 0) return;
        var info = Engine.getAttackTargets(state, pid, u);
        if (!info.heroOk) return;
        total += u.atk;
        if (!first) first = u;
      });
    });
    if (!first) return null;
    var skillDmg = 0;
    var skillReady = !p.skillUsed && p.mana >= p.skill.cost;
    if (skillReady && p.heroId === 'xiangyu' && e.board.front.length === 0) skillDmg = 1;
    if (total + skillDmg < e.hp) return null;
    if (total < e.hp) return { type: 'skill' }; /* 先用技能补上最后一点 */
    return { type: 'attack', attacker: first.uid, target: { kind: 'hero' }, score: 9999 };
  }

  /* 军师主动技（每场 1 次）：只在「确实有东西可用」时出手，别空放 */
  function advAction(state, pid) {
    if (!Engine.canAdvisorActive(state, pid)) return null;
    var a = Engine.advisorActive(state);
    if (!a || !a.fx) return null;
    var p = state.players[pid], e = state.players[opp(pid)];
    var fx = a.fx;
    var myUnits = 0, foeUnits = 0, myRattle = 0;
    Engine.RANKS.forEach(function (r) {
      myUnits += p.board[r].length;
      foeUnits += e.board[r].length;
      p.board[r].forEach(function (u) { if (u.deathrattle) myRattle++; });
    });
    if (fx.draw) return { type: 'adv' };
    if (fx.healHero) return p.hp <= p.maxHp - 2 ? { type: 'adv' } : null;
    if (fx.summon) {
      var rank = fx.summon.rank || 'front';
      return p.board[rank].length < 3 ? { type: 'adv' } : null;
    }
    /* buffCol 只加某一列：那一列没人就白花军粮（曾经漏了这个分支，
       韩信的「点兵」在 AI 手里一次都没放过，A/B 差值精确等于 0.0pp） */
    if (fx.buffCol) {
      var col = p.board[fx.buffCol] || [];
      return col.length > 0 ? { type: 'adv' } : null;
    }
    if (fx.buffAll || fx.buffAllHp || fx.buffHighest) return myUnits > 0 ? { type: 'adv' } : null;
    if (fx.dmgHighest || fx.debuffHighest) return foeUnits > 0 ? { type: 'adv' } : null;
    if (fx.xyCap) return myRattle > 0 ? { type: 'adv' } : null;
    return null;
  }

  /* 产生下一个动作：play / adv / skill / attack / end */
  function aiNextAction(state, pid) {
    if (state.over) return { type: 'end' };
    var p = state.players[pid], e = state.players[opp(pid)];
    var level = levelOf(state, pid);
    var randomize = (level === 'jianxi' && Math.random() < 0.5);

    /* 0. 名将先算斩杀：能一击定胜负就不铺垫 */
    if (level === 'mingjiang') {
      var lethal = lethalPlan(state, pid);
      if (lethal) return lethal;
    }

    /* 1. 出牌 */
    var plays = [];
    p.hand.forEach(function (card) {
      if (card.cost <= p.mana && Engine.canPlay(state, pid, card)) {
        plays.push({ type: 'play', uid: card.uid, score: playScore(state, pid, card) });
      }
    });
    if (plays.length > 0) {
      if (randomize) return plays[Math.floor(Math.random() * plays.length)];
      plays.sort(function (a, b) { return b.score - a.score; });
      if (plays[0].score > 0.5) return plays[0];
    }

    /* 1.5 军师主动技：放在出牌之后、攻击之前——加攻/减攻要赶在打人前 */
    var adv = advAction(state, pid);
    if (adv) return adv;

    /* 2. 英雄技能 */
    if (skillUseful(state, pid)) {
      var spare = p.mana - p.skill.cost;
      if (spare >= 2 || p.hand.every(function (c) { return c.cost > p.mana; }) || randomize === false) {
        return { type: 'skill' };
      }
    }

    /* 3. 攻击 */
    var attacks = [];
    Engine.RANKS.forEach(function (r) {
      p.board[r].forEach(function (u) {
        if (!u.canAttack || u.atk <= 0) return;
        var info = Engine.getAttackTargets(state, pid, u);
        if (info.heroOk) {
          attacks.push({ type: 'attack', attacker: u.uid, target: { kind: 'hero' },
            score: 100 + u.atk + (level === 'mingjiang' ? 10 : 0) });
        }
        info.units.forEach(function (t) {
          attacks.push({ type: 'attack', attacker: u.uid, target: { kind: 'unit', uid: t.unit.uid },
            score: attackScore(u, t, level) });
        });
      });
    });
    if (attacks.length > 0) {
      if (randomize) return attacks[Math.floor(Math.random() * attacks.length)];
      attacks.sort(function (a, b) { return b.score - a.score; });
      if (attacks[0].score > 0) return attacks[0];
    }

    return { type: 'end' };
  }

  /* 在真实状态上执行一个 AI 动作 */
  function applyAction(state, pid, action) {
    if (action.type === 'play') return Engine.playCard(state, pid, action.uid);
    if (action.type === 'adv') return Engine.useAdvisorActive(state, pid);
    if (action.type === 'skill') return Engine.useSkill(state, pid);
    if (action.type === 'attack') return Engine.attack(state, pid, action.attacker, action.target);
    if (action.type === 'end') { Engine.endTurn(state); return { ok: true }; }
    return { ok: false, reason: '未知动作' };
  }

  /* AI 开局换牌：换掉费用 >=5 的大牌（前期用不上） */
  function aiMulligan(state, pid) {
    var p = state.players[pid];
    return p.hand.filter(function (c) { return c.cost >= 5; }).map(function (c) { return c.uid; });
  }

  return { aiNextAction: aiNextAction, applyAction: applyAction, aiMulligan: aiMulligan };
});
