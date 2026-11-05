/* 《楚汉·问鼎》卡牌与英雄数据（M1） */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.Data = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var HEROES = {
    liubang: {
      id: 'liubang', name: '刘邦', title: '汉王', hp: 30, glyph: '刘', faction: 'han',
      intro: '30 血续航型。英雄技能擅长回血与 Buff，越拖越稳。',
      skill: { name: '约法三章', cost: 2, desc: '恢复 2 点血量；若已满血，则随机一名友军 +1 攻。' }
    },
    xiangyu: {
      id: 'xiangyu', name: '项羽', title: '西楚霸王', hp: 26, glyph: '项', faction: 'chu',
      intro: '26 血强攻型。英雄技能清扫敌方前锋，节奏激进。',
      skill: { name: '破釜沉舟', cost: 1, desc: '对敌方前锋列全体造成 1 点伤害；若该列无兵，则对敌方主将造成 1 点伤害。' }
    }
  };

  /* 兵种牌字段：col 固定站位列；taunt 守御；flank 迂回（可打前锋/中军）；ranged 远程（可打任意列） */
  var CARDS = {
    /* ---- 中立 · 兵种 ---- */
    n_bing1: { id: 'n_bing1', name: '兵·新卒', type: 'piece', cost: 1, col: 'front', atk: 1, hp: 2, glyph: '兵', desc: '廉价的填线卒子，过河不回头。' },
    n_bing2: { id: 'n_bing2', name: '兵·锐士', type: 'piece', cost: 2, col: 'front', atk: 2, hp: 3, glyph: '兵', desc: '百战余生的老兵。' },
    n_ma1:   { id: 'n_ma1', name: '马·轻骑', type: 'piece', cost: 3, col: 'mid', atk: 3, hp: 2, glyph: '马', flank: true, desc: '迂回：可直接攻击中军。' },
    n_ma2:   { id: 'n_ma2', name: '马·骠骑', type: 'piece', cost: 4, col: 'mid', atk: 4, hp: 3, glyph: '马', flank: true, desc: '迂回：可直接攻击中军。' },
    n_che1:  { id: 'n_che1', name: '车·戎车', type: 'piece', cost: 5, col: 'mid', atk: 5, hp: 5, glyph: '车', desc: '横冲直撞的中军主力。' },
    n_che2:  { id: 'n_che2', name: '车·武刚车', type: 'piece', cost: 7, col: 'mid', atk: 7, hp: 6, glyph: '车', desc: '后期无解的钢铁洪流。' },
    n_pao1:  { id: 'n_pao1', name: '炮·飞石', type: 'piece', cost: 3, col: 'back', atk: 2, hp: 4, glyph: '炮', ranged: true, desc: '远程：可攻击任意一列。' },
    n_pao2:  { id: 'n_pao2', name: '炮·连弩', type: 'piece', cost: 4, col: 'back', atk: 3, hp: 3, glyph: '炮', ranged: true, desc: '远程：可攻击任意一列。' },
    n_shi1:  { id: 'n_shi1', name: '士·持戟卫', type: 'piece', cost: 2, col: 'mid', atk: 1, hp: 4, glyph: '士', taunt: true, desc: '守御：敌人必须先攻击它。' },
    n_shi2:  { id: 'n_shi2', name: '士·郎中骑', type: 'piece', cost: 3, col: 'mid', atk: 2, hp: 4, glyph: '士', taunt: true, desc: '守御：敌人必须先攻击它。' },
    n_xiang1:{ id: 'n_xiang1', name: '象·护军象', type: 'piece', cost: 4, col: 'mid', atk: 2, hp: 6, glyph: '象', taunt: true, desc: '守御：厚实的护军巨象。' },
    n_xiang2:{ id: 'n_xiang2', name: '象·安国象', type: 'piece', cost: 5, col: 'mid', atk: 3, hp: 5, glyph: '象', taunt: true, desc: '守御：威慑中军的大家伙。' },
    /* ---- 中立 · 兵种（扩充档位） ---- */
    n_bing4: { id: 'n_bing4', name: '兵·戍卒', type: 'piece', cost: 1, col: 'front', atk: 1, hp: 4, glyph: '兵', taunt: true, desc: '守御：守边的老卒，不争先，但守得住门。' },
    n_bing3: { id: 'n_bing3', name: '兵·死士', type: 'piece', cost: 2, col: 'front', atk: 3, hp: 1, glyph: '兵', deathrattle: { dmgHero: 2 }, desc: '死战：阵亡时对敌方主将造成 2 点伤害。' },
    n_shi3:  { id: 'n_shi3', name: '士·死士卫', type: 'piece', cost: 3, col: 'mid', atk: 2, hp: 5, glyph: '士', taunt: true, deathrattle: { buffAll: 1 }, desc: '守御。死战：友军全体 +1 攻。' },
    n_ma3:   { id: 'n_ma3', name: '马·铁骑', type: 'piece', cost: 5, col: 'mid', atk: 4, hp: 4, glyph: '马', flank: true, charge: true, desc: '冲锋、迂回：落地即可踹中军。' },
    n_che3:  { id: 'n_che3', name: '车·冲车', type: 'piece', cost: 6, col: 'mid', atk: 6, hp: 4, glyph: '车', charge: true, desc: '冲锋：撞开城门的那一辆。' },
    n_pao3:  { id: 'n_pao3', name: '炮·霹雳车', type: 'piece', cost: 6, col: 'back', atk: 4, hp: 4, glyph: '炮', ranged: true, deathrattle: { dmgCol: 'front', amount: 2 }, desc: '远程。死战：对敌方前锋列造成 2 点伤害。' },
    n_xiang3:{ id: 'n_xiang3', name: '象·战象', type: 'piece', cost: 6, col: 'mid', atk: 5, hp: 7, glyph: '象', taunt: true, desc: '守御：披甲上阵的巨兽。' },
    /* ---- 中立 · 死战铺场（1.1 卡池扩容，设计依据 docs/build-lines.md）----
       定价规则：死战溢价 -1.0 属性，守御溢价 +1.0（atk≤1 放宽到 +2）。
       summon 的 token 统一用 n_bing1（新卒 1/2）：不加"无亡语 token"机制，
       复用现有卡最省事，图鉴/奖励池也不会冒出重复牌。 */
    n_bing5: { id: 'n_bing5', name: '兵·刑徒', type: 'piece', cost: 1, col: 'front', atk: 2, hp: 2, glyph: '兵', deathrattle: { summon: { baseId: 'n_bing1', count: 1, rank: 'front' } }, desc: '死战：阵亡时前锋列补一名 1/2 新卒。骊山刑徒，豁命换人。' },
    n_bing6: { id: 'n_bing6', name: '兵·戍兵', type: 'piece', cost: 2, col: 'front', atk: 1, hp: 4, glyph: '兵', taunt: true, deathrattle: { summon: { baseId: 'n_bing1', count: 1, rank: 'front' } }, desc: '守御。死战：阵亡时前锋列补一名 1/2 新卒。' },
    n_bing7: { id: 'n_bing7', name: '兵·死士队', type: 'piece', cost: 4, col: 'mid', atk: 3, hp: 4, glyph: '兵', deathrattle: { summon: { baseId: 'n_bing1', count: 1, rank: 'front' } }, desc: '死战：阵亡时前锋列补一名 1/2 新卒。敢死之队，前仆后继。' },
    n_bing8: { id: 'n_bing8', name: '兵·降卒', type: 'piece', cost: 1, col: 'front', atk: 2, hp: 2, glyph: '兵', deathrattle: { draw: 1 }, desc: '死战：阵亡时抽一张牌。降者不死，留个后手。' },
    n_shi4:  { id: 'n_shi4', name: '士·断后', type: 'piece', cost: 3, col: 'front', atk: 2, hp: 5, glyph: '士', taunt: true, deathrattle: { buffCol: 'front', atk: 1 }, desc: '守御。死战：前锋列全体 +1 攻。断后者，以身饲阵。' },
    n_shi5:  { id: 'n_shi5', name: '士·骸骨', type: 'piece', cost: 4, col: 'mid', atk: 3, hp: 4, glyph: '士', deathrattle: { buffCol: 'mid', atk: 1 }, desc: '死战：阵亡时中军列全体 +1 攻。埋骨之地，反成刀锋。' },
    n_shi6:  { id: 'n_shi6', name: '士·门客', type: 'piece', cost: 3, col: 'mid', atk: 3, hp: 4, glyph: '士', deathrattle: { draw: 1 }, desc: '死战：阵亡时抽一张牌。士为知己者死。' },
    n_jiang1:{ id: 'n_jiang1', name: '将·偏将', type: 'piece', cost: 4, col: 'mid', atk: 4, hp: 3, glyph: '将', deathrattle: { buffCol: 'mid', atk: 1 }, desc: '死战：阵亡时中军列全体 +1 攻。偏将虽末，号令犹在。' },
    /* ---- 1.1 扩容 · 守御 6 张：全部带进攻性，纯墙只留土垣一张给新手 ---- */
    n_dun1:  { id: 'n_dun1', name: '盾·持盾卒', type: 'piece', cost: 1, col: 'front', atk: 1, hp: 3, glyph: '盾', taunt: true, battlecry: { draw: 1 }, desc: '守御。登场：抽一张牌。' },
    n_lei1:  { id: 'n_lei1', name: '垒·拒马', type: 'piece', cost: 2, col: 'front', atk: 1, hp: 4, glyph: '垒', taunt: true, battlecry: { buffCol: 'front', atk: 1 }, desc: '守御。登场：前锋列全体 +1 攻。' },
    n_cheng1:{ id: 'n_cheng1', name: '城·土垣', type: 'piece', cost: 3, col: 'mid', atk: 1, hp: 6, glyph: '城', taunt: true, desc: '守御：夯土为垣，最省人的一堵墙。' },
    n_cheng2:{ id: 'n_cheng2', name: '城·女墙', type: 'piece', cost: 4, col: 'mid', atk: 2, hp: 6, glyph: '城', taunt: true, deathrattle: { buffCol: 'mid', atk: 1 }, desc: '守御。死战：中军列全体 +1 攻。' },
    n_cheng3:{ id: 'n_cheng3', name: '城·瓮城', type: 'piece', cost: 5, col: 'mid', atk: 2, hp: 7, glyph: '城', taunt: true, battlecry: { healHero: 2 }, desc: '守御。登场：主将恢复 2 点血。' },
    n_cheng4:{ id: 'n_cheng4', name: '城·坚壁', type: 'piece', cost: 6, col: 'mid', atk: 3, hp: 8, glyph: '城', taunt: true, deathrattle: { buffAll: 1 }, desc: '守御。死战：己方全体 +1 攻。' },
    /* ---- 1.1 扩容 · 死战 · 续航 2 张（断牌/血线保险） ---- */
    n_yi1:   { id: 'n_yi1', name: '医·随军医', type: 'piece', cost: 2, col: 'mid', atk: 1, hp: 3, glyph: '医', deathrattle: { healHero: 2 }, desc: '死战：阵亡时主将恢复 2 点血。' },
    n_shi7:  { id: 'n_shi7', name: '士·死节', type: 'piece', cost: 5, col: 'front', atk: 3, hp: 6, glyph: '士', taunt: true, deathrattle: { healHero: 3 }, desc: '守御。死战：阵亡时主将恢复 3 点血。' },
    /* ---- 1.1 扩容 · 死战 · 直伤 4 张（把尸体变成伤害） ---- */
    n_bing9: { id: 'n_bing9', name: '兵·斥候', type: 'piece', cost: 2, col: 'front', atk: 2, hp: 2, glyph: '兵', deathrattle: { dmgCol: 'front', amount: 1 }, desc: '死战：阵亡时对敌方前锋列造成 1 点伤害。' },
    n_bing10:{ id: 'n_bing10', name: '兵·死囚', type: 'piece', cost: 3, col: 'front', atk: 4, hp: 2, glyph: '兵', deathrattle: { dmgLowest: 3 }, desc: '死战：阵亡时对敌方血量最低的兵种造成 3 点伤害。' },
    n_che4:  { id: 'n_che4', name: '车·决死车', type: 'piece', cost: 5, col: 'mid', atk: 4, hp: 4, glyph: '车', charge: true, deathrattle: { dmgCol: 'front', amount: 2 }, desc: '冲锋。死战：阵亡时对敌方前锋列造成 2 点伤害。' },
    n_jiang2:{ id: 'n_jiang2', name: '将·死士将', type: 'piece', cost: 6, col: 'mid', atk: 5, hp: 4, glyph: '将', deathrattle: { dmgAll: 2 }, desc: '死战：阵亡时对敌方全体造成 2 点伤害。' },
    /* ---- 1.1 扩容 · 中立 4 张：补 1 费曲线与过牌 ---- */
    n_zhengfa:{ id: 'n_zhengfa', name: '令·征发', type: 'spell', cost: 1, glyph: '征', effect: { summon: { baseId: 'n_bing1', count: 1, rank: 'front' } }, desc: '召唤一名 1/2 新卒到前锋列。' },
    n_xiangyong:{ id: 'n_xiangyong', name: '兵·乡勇', type: 'piece', cost: 1, col: 'front', atk: 1, hp: 3, glyph: '兵', desc: '临时征召的乡里青壮，聊胜于无。' },
    n_xuanshang:{ id: 'n_xuanshang', name: '令·悬赏', type: 'spell', cost: 2, glyph: '赏', effect: { draw: 1, healHero: 2 }, desc: '抽一张牌，主将恢复 2 点血。' },
    n_huogong:{ id: 'n_huogong', name: '令·火攻', type: 'spell', cost: 3, glyph: '火', effect: { dmgCol: 'mid', amount: 3 }, desc: '对敌方中军列造成 3 点伤害。焚其辎重，先断中坚。' },
    n_zengyuan:{ id: 'n_zengyuan', name: '军令·增援', type: 'spell', cost: 3, glyph: '援', effect: { summon: { baseId: 'n_bing1', count: 2, rank: 'front' } }, desc: '召唤两个 1/2 新卒到前锋列。' },
    /* ---- 中立 · 人物（传奇兵种牌） ---- */
    n_hanxin:{ id: 'n_hanxin', name: '韩信·点兵', type: 'piece', cost: 6, col: 'mid', atk: 5, hp: 5, glyph: '韩', battlecry: { tokens: 1 }, desc: '登场：召唤一个 1/1 兵到前锋列。多多益善！' },
    n_pengyue:{ id: 'n_pengyue', name: '彭越·游击', type: 'piece', cost: 4, col: 'mid', atk: 3, hp: 4, glyph: '彭', flank: true, desc: '迂回：游击战大师，可直接攻击中军。' },
    n_yingbu:{ id: 'n_yingbu', name: '英布·枭将', type: 'piece', cost: 4, col: 'mid', atk: 4, hp: 4, glyph: '英', desc: '先楚后汉的悍将，两边都好使。' },
    n_lizuo: { id: 'n_lizuo', name: '李左车·献策', type: 'piece', cost: 5, col: 'mid', atk: 3, hp: 5, glyph: '李', battlecry: { draw: 1 }, desc: '登场：抽一张牌。' },
    /* ---- 汉 · 牌 ---- */
    s_xiaohe:{ id: 's_xiaohe', name: '萧何·运粮', type: 'spell', cost: 2, glyph: '粮', effect: { draw: 2 }, desc: '抽两张牌。镇国家，抚百姓，给馈饷。' },
    s_jinang:{ id: 's_jinang', name: '张良·锦囊', type: 'spell', cost: 3, glyph: '锦', effect: { dmgCol: 'front', amount: 1 }, desc: '敌方前锋列全体受 1 点伤害。运筹帷幄之中。' },
    h_caocan:{ id: 'h_caocan', name: '曹参·陷阵', type: 'piece', cost: 3, col: 'mid', atk: 3, hp: 4, glyph: '曹', desc: '攻必取、战必胜的陷阵之将。' },
    h_zhoub: { id: 'h_zhoub', name: '周勃·安刘', type: 'piece', cost: 4, col: 'mid', atk: 2, hp: 6, glyph: '周', taunt: true, desc: '守御：厚重少文，安刘氏者必勃也。' },
    h_fankuai:{ id: 'h_fankuai', name: '樊哙·闯帐', type: 'piece', cost: 4, col: 'mid', atk: 4, hp: 3, glyph: '樊', charge: true, desc: '冲锋：鸿门宴上闯帐护主，生啖彘肩。' },
    h_guanying:{ id: 'h_guanying', name: '灌婴·骑将', type: 'piece', cost: 5, col: 'mid', atk: 4, hp: 5, glyph: '灌', flank: true, desc: '迂回：汉军骑将，专掠楚军粮道。' },
    h_jixin: { id: 'h_jixin', name: '纪信·代王', type: 'piece', cost: 3, col: 'mid', atk: 3, hp: 4, glyph: '纪', deathrattle: { healHero: 3 }, desc: '死战：阵亡时主将恢复 3 点血。荥阳城头的替身。' },
    h_chenping:{ id: 'h_chenping', name: '陈平·反间', type: 'spell', cost: 3, glyph: '间', effect: { dmgHighest: 3, draw: 1 }, desc: '对敌方攻击力最高的兵种造成 3 点伤害，并抽一张牌。' },
    h_luyi:  { id: 'h_luyi', name: '郦食其·说客', type: 'spell', cost: 3, glyph: '说', effect: { debuffAll: 1, draw: 1 }, desc: '敌方全军 -1 攻，抽一张牌。三寸之舌退百万师。' },
    s_simian:{ id: 's_simian', name: '四面楚歌', type: 'spell', cost: 5, glyph: '歌', effect: { debuffAll: 2 }, desc: '敌方全军 -2 攻。楚歌声起，军心自散。' },
    /* ---- P2 · 连击 6 张（汉）
       为什么成套补：全池原本只有 1 张连击卡（项庄，楚阵营），PvE 奖励池只给汉+中立，
       玩家一辈子拿不到第二张连击牌——关键词等于不存在。
       设计原则：全部用现有效果字段（零引擎改动），费用压在 1~3 费。
       连击是"本回合已出过牌"，所以它天然是节奏流：便宜的牌铺路，后手牌吃加成。
       两张兼有关键词的（叠阵/接武）负责和守御、死战咬合，不做纯数值变体。 */
    h_zhiji:{ id: 'h_zhiji', name: '兵·执戟郎', type: 'piece', cost: 1, col: 'front', atk: 1, hp: 3, glyph: '戟', combo: { selfAtk: 1 }, desc: '连击：本回合已出过牌则自身 +1 攻。执戟守门，进退有节。' },
    s_liannu:{ id: 's_liannu', name: '令·连弩齐发', type: 'spell', cost: 1, glyph: '弩', effect: { dmgCol: 'front', amount: 1 }, combo: { dmgCol: 'front', amount: 1 }, desc: '敌方前锋列受 1 点伤害；连击：再受 1 点。弩矢连发，不绝如雨。' },
    s_lianhuan:{ id: 's_lianhuan', name: '计·连环', type: 'spell', cost: 1, glyph: '环', effect: { draw: 1 }, combo: { draw: 1 }, desc: '抽一张牌；连击：再抽一张。环环相扣，计出不穷。' },
    h_qimen:{ id: 'h_qimen', name: '士·期门郎', type: 'piece', cost: 2, col: 'mid', atk: 2, hp: 3, glyph: '期', combo: { draw: 1 }, desc: '连击：本回合已出过牌则抽一张牌。期门宿卫，闻鼓即至。' },
    h_diezhen:{ id: 'h_diezhen', name: '垒·叠阵', type: 'piece', cost: 3, col: 'front', atk: 2, hp: 5, glyph: '叠', taunt: true, combo: { buffCol: 'front', atk: 1 }, desc: '守御。连击：前锋列全体 +1 攻。叠阵而前，盾如山积。' },
    h_jiewu:{ id: 'h_jiewu', name: '兵·接武', type: 'piece', cost: 3, col: 'mid', atk: 3, hp: 3, glyph: '接', deathrattle: { buffCol: 'mid', atk: 1 }, combo: { selfAtk: 2 }, desc: '死战：中军列 +1 攻。连击：自身 +2 攻。前武既接，后劲不绝。' },
    /* 后段两张：上面 6 张最贵 3 费，第 5 关后抽到 1/2 小兵等于废牌（实测连击流 12%，与随机无异）。
       补两张 5 费，让"连击"在后半程也有牌可打。 */
    h_xiandeng:{ id: 'h_xiandeng', name: '将·先登', type: 'piece', cost: 5, col: 'front', atk: 5, hp: 5, glyph: '登', combo: { selfAtk: 2 }, desc: '连击：本回合已出过牌则自身 +2 攻。先登者赏，怯者斩。' },
    s_lianying:{ id: 's_lianying', name: '计·连营', type: 'spell', cost: 4, glyph: '营', effect: { dmgCol: 'mid', amount: 2 }, combo: { dmgAll: 1 }, desc: '敌方中军 2 伤；连击：敌方全体 1 伤。连营百里，一炬皆惊。' },
    /* ---- 楚 · 牌 ---- */
    s_fanzeng:{ id: 's_fanzeng', name: '范增·毒计', type: 'spell', cost: 2, glyph: '毒', effect: { dmgLowest: 3 }, desc: '对敌方血量最低的兵种造成 3 点伤害。竖子不足与谋！' },
    s_bawang:{ id: 's_bawang', name: '霸王枪法', type: 'spell', cost: 4, glyph: '枪', effect: { buffCol: 'front', atk: 3 }, desc: '己方前锋列全体 +3 攻。力拔山兮气盖世！' },
    c_longqie:{ id: 'c_longqie', name: '龙且·江东子弟', type: 'piece', cost: 3, col: 'mid', atk: 4, hp: 4, glyph: '龙', desc: '跟随霸王起兵的江东健儿。' },
    c_jibu:  { id: 'c_jibu', name: '季布·一诺', type: 'piece', cost: 2, col: 'mid', atk: 3, hp: 3, glyph: '季', flank: true, desc: '迂回：得黄金百斤，不如得季布一诺。' },
    c_huanchu:{ id: 'c_huanchu', name: '桓楚·先锋', type: 'piece', cost: 2, col: 'front', atk: 2, hp: 3, glyph: '桓', charge: true, desc: '冲锋：霸王麾下第一个冲阵的人。' },
    c_xiangzhuang:{ id: 'c_xiangzhuang', name: '项庄·舞剑', type: 'piece', cost: 3, col: 'mid', atk: 3, hp: 3, glyph: '庄', combo: { selfAtk: 2 }, desc: '连击：本回合已出过牌则自身 +2 攻。项庄舞剑，意在沛公。' },
    c_zhuiqi:{ id: 'c_zhuiqi', name: '楚骑·追风', type: 'piece', cost: 4, col: 'mid', atk: 3, hp: 4, glyph: '骑', charge: true, desc: '冲锋：三万里追风，半日破五十六万。' },
    c_zhongli:{ id: 'c_zhongli', name: '钟离眜·骨鲠', type: 'piece', cost: 4, col: 'mid', atk: 4, hp: 5, glyph: '钟', taunt: true, desc: '守御：楚之骨鲠之臣，宁可死战不退。' },
    c_yuji:  { id: 'c_yuji', name: '虞姬·和歌', type: 'spell', cost: 3, glyph: '虞', effect: { healHero: 3, draw: 1 }, desc: '主将恢复 3 点血，抽一张牌。汉兵已略地，四面楚歌声。' },
    s_pozhen:{ id: 's_pozhen', name: '破阵', type: 'spell', cost: 4, glyph: '阵', effect: { dmgCol: 'front', amount: 2 }, desc: '敌方前锋列全体受 2 点伤害。' },
    s_juding:{ id: 's_juding', name: '霸王举鼎', type: 'spell', cost: 6, glyph: '鼎', effect: { buffAll: 2 }, desc: '己方全体 +2 攻。鼎可举，天不可逆。' },
    /* ---- 特殊 ---- */
    s_xianji:{ id: 's_xianji', name: '先机', type: 'spell', cost: 0, glyph: '机', effect: { mana: 1 }, desc: '本回合 +1 军粮。虎符在手，先发制人。' }
  };

  /* 官方预组牌库（各 20 张，同名牌最多 2 张） */
  var DECKS = {
    han: [
      'n_bing1', 'n_bing1', 'n_bing4', 'n_bing4', 'n_bing5', 'n_bing5',
      'n_shi1', 'n_shi1', 'n_pao1', 'n_pao1', 'n_ma1', 'n_ma1',
      'n_che1', 'h_caocan', 's_xiaohe', 's_xiaohe', 's_jinang', 'n_hanxin',
      'h_jixin', 'h_fankuai'
    ],
    chu: [
      'n_bing1', 'n_bing1', 'n_bing3', 'n_bing3', 'n_bing2', 'n_bing2',
      'n_shi1', 'n_shi1', 'n_pao1', 'n_pao1', 'n_ma1', 'n_ma1',
      'n_che1', 'c_huanchu', 's_fanzeng', 's_fanzeng', 's_bawang', 'c_longqie',
      'c_jibu', 'c_zhuiqi'
    ]
  };

  var RANK_NAMES = { front: '前锋', mid: '中军', back: '后军' };
  var HAND_LIMIT = 10;
  var COLUMN_LIMIT = 3;
  var MAX_MANA = 10;

  /* 阵营归属（未列出的均为中立牌） */
  var CARD_FACTION = {
    s_xiaohe: 'han', s_jinang: 'han', h_caocan: 'han', h_zhoub: 'han',
    h_fankuai: 'han', h_guanying: 'han', h_jixin: 'han',
    h_chenping: 'han', h_luyi: 'han', s_simian: 'han',
    h_zhiji: 'han', h_qimen: 'han', h_diezhen: 'han', h_jiewu: 'han',
    s_liannu: 'han', s_lianhuan: 'han', h_xiandeng: 'han', s_lianying: 'han',
    s_fanzeng: 'chu', s_bawang: 'chu', c_longqie: 'chu', c_jibu: 'chu',
    c_huanchu: 'chu', c_xiangzhuang: 'chu', c_zhuiqi: 'chu', c_zhongli: 'chu',
    c_yuji: 'chu', s_pozhen: 'chu', s_juding: 'chu'
  };

  function factionOf(cardId) { return CARD_FACTION[cardId] || 'neutral'; }

  /* 已有水墨立绘的卡（对应 assets/cards/<id>.png）；没有的卡自动回退文字占位 */
  var ART = {
    n_bing1: true, n_bing2: true, n_bing3: true, n_bing4: true,
    n_ma1: true, n_ma2: true, n_ma3: true,
    n_che1: true, n_che2: true, n_che3: true,
    n_pao1: true, n_pao2: true, n_pao3: true,
    n_shi1: true, n_shi2: true, n_shi3: true,
    n_xiang1: true, n_xiang2: true, n_xiang3: true,
    n_zengyuan: true, n_hanxin: true, n_pengyue: true, n_yingbu: true, n_lizuo: true,
    s_xiaohe: true, s_jinang: true, h_caocan: true, h_zhoub: true,
    h_fankuai: true, h_guanying: true, h_jixin: true, h_chenping: true, h_luyi: true,
    s_simian: true, s_fanzeng: true, s_bawang: true, s_pozhen: true, s_juding: true, s_xianji: true,
    c_longqie: true, c_jibu: true, c_huanchu: true, c_xiangzhuang: true,
    c_zhuiqi: true, c_zhongli: true, c_yuji: true
  };
  /* 已有立绘的英雄（assets/cards/<heroId>.png） */
  var HERO_ART = { xiangyu: true, liubang: true };

  /* 界面素材登记（assets/cards/ 下）：
     军师 ad_<id>.png / 行军事件 ev_<id>.png / 关卡场景 sc_<stageId>.png / 敌将头像 <art>.png
     未登记的项自动回退文字 glyph，不会出现破图 */
  var UI_ART = {
    advisors: { zhangliang: true, xiaohe: true, hanxin: true, fankuai: true, chenping: true },
    events: { liumin: true, liangdao: true, qishu: true, jiangjiang: true, yiqing: true,
              laozu: true, jisi: true, qiaofu: true, pofu: true, chuge: true },
    scenes: { peixian: true, hongmen: true, pengcheng: true, xingyang: true,
              jingxing: true, weishui: true, guling: true, gaixia: true },
    heroes: { liubang: true, xiangyu: true, h_sishui: true, h_chenyu: true, h_longqie2: true }
  };

  return {
    HEROES: HEROES,
    CARDS: CARDS,
    DECKS: DECKS,
    RANK_NAMES: RANK_NAMES,
    HAND_LIMIT: HAND_LIMIT,
    COLUMN_LIMIT: COLUMN_LIMIT,
    MAX_MANA: MAX_MANA,
    factionOf: factionOf,
    ART: ART,
    HERO_ART: HERO_ART,
    UI_ART: UI_ART
  };
});
