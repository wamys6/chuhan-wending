/* 《楚汉·问鼎》英文文案库
   通过 I18N.load({...}) 注入，结构：
   ui          UI 字典：中文（trim 后）→ 英文；{a}/{b} 为占位符
   cards       卡牌 id → { name, desc }
   heroes      英雄 id → { name, title, intro, skill:{name,desc} }
   ranks       三列名 { front, mid, back }
   stages      关卡 id → { chapter, name, year, subtitle, lore, goalText, enemy:{name,title} }
   advisors    军师 id → { name, title, desc, flavor }
   events      事件 id → { name, text, options:[{label,hint}] }
   achievements成就 id → { name, desc }；groups 三组成名
   keywords    关键词释义（EN 键）；keywordList 牌面标注顺序
   logPatterns 战报翻译：[正则, 替换函数]（卡名/列名/人名已先被数据层本地化） */
(function () {
  'use strict';
  var SIDE = { '我方': 'Your army', '敌方': 'The enemy' };

  I18N.load({
    ui: {
      '楚汉': 'CHU–HAN',
      '问鼎': 'BATTLE FOR THE THRONE',
      '刘邦': 'Liu Bang', '汉王': 'King of Han',
      '项羽': 'Xiang Yu', '西楚霸王': 'Hegemon-King of Chu',
      '技能「约法三章」（2 军粮）': 'Power \u201CThree Articles\u201D (2 Prov)',
      '恢复 2 点血；满血时随机友军 +1 攻': 'Restore 2 Health; at full Health, a random friendly unit gains +1 Attack.',
      '技能「破釜沉舟」（1 军粮）': 'Power \u201CBreak the Kettles\u201D (1 Prov)',
      '扫射敌方前锋列（1 伤）；无兵时直击主将': 'Sweep the enemy Vanguard (1 damage); if the column is empty, hit the commander.',
      '为刘邦组建牌库': 'Build a deck for Liu Bang',
      '楚河汉界 · 兵车对垒 · 逐鹿中原': 'Chu River, Han Border · Chariots and Spears · The Contest for the Realm',
      '选择你的主将（对手将执掌另一方）': 'Choose your commander (your rival takes the other)',
      '血量 30': 'Health 30',
      '血量 26': 'Health 26',
      '30 血续航型，越拖越稳': '30 Health, attrition style—steadier the longer it lasts',
      '26 血强攻型，节奏激进': '26 Health, aggression style—relentless tempo',
      '敌将智力：': 'Enemy general AI:',
      '见习': 'Recruit', '裨将': 'Captain', '名将': 'General',
      '楚 汉 战 役': 'CHU–HAN CAMPAIGN',
      '快 速 开 战': 'QUICK BATTLE',
      '组 建 牌 库': 'BUILD DECK',
      '玩法说明': 'How to Play',
      '图鉴 · 成就': 'Codex · Achievements',
      '存档位': 'Save Slots',
      '重看新手引导': 'Replay Tutorial',
      '战役：从沛县起兵打到垓下决战（8 关） · 快速开战：单局对战 AI · 卡池 45 张 · 打倒对方主将即胜':
        'Campaign: eight stages from Pei County to Gaixia · Quick Battle: one match vs AI · 45-card pool · Reduce the enemy commander to 0 to win',
      '为{h}组建牌库': 'Build a deck for {h}',
      '已选 ': 'Picked ', ' / 20': ' / 20',
      '返回': 'Back',
      '每张牌最多带 2 张；汉将可用「中立 + 汉」牌，楚将可用「中立 + 楚」牌。点卡片加入，再点移出。': 'Up to 2 copies per card; Han uses Neutral + Han cards, Chu uses Neutral + Chu cards. Click a card to add it, click again to remove.',
      '全部': 'All', '中立': 'Neutral', '本阵营': 'Your Faction', '汉': 'Han', '楚': 'Chu',
      '兵种': 'Units', '计谋': 'Stratagems',
      '保存牌库': 'Save Deck', '以此阵 出 战': 'MARCH WITH THIS DECK',
      '自沛县起兵，至垓下决战': 'From Pei County to the final field at Gaixia',
      '重开战役': 'Restart Campaign',
      '存 档 位': 'SAVE SLOTS',
      '三个存档位各存一局楚汉战役，互不干扰；成就业绩是全局记录，不受存档位影响。': 'Three save slots, each holding its own campaign. Achievements and career stats are global and unaffected by slots.',
      '当前使用的存档位会高亮显示；进入空存档位会从沛县起兵开新局。': 'Your active slot is highlighted; entering an empty slot starts a fresh campaign from Pei County.',
      '退 回 地 图': 'BACK TO MAP', '出 战': 'TO BATTLE',
      '大 获 全 胜': 'A RESOUNDING VICTORY', '兵 败 如 山 倒': 'A CRUSHING DEFEAT',
      '选一张牌，收入你的牌组': 'Pick one card to add to your deck',
      '都 不 要': 'TAKE NOTHING',
      '楚 汉 战 役 · 择 师': 'CHU–HAN CAMPAIGN · CHOOSE A STRATEGIST',
      '择 一 军 师': 'CHOOSE YOUR STRATEGIST',
      '心 魔': 'INNER DEMON',
      '常 规': 'NORMAL',
      '心魔 1': 'Demon 1', '心魔 2': 'Demon 2', '心魔 3': 'Demon 3',
      '常规难度': 'Normal difficulty',
      '常规难度：不作任何额外限制': 'Normal difficulty: no extra restrictions',
      '先通关前一等级才解锁': 'Clear the previous tier to unlock',
      '已解锁下一级心魔 —— 下次择师时可选，难度更高': 'Next Inner Demon unlocked — pick it the next time you choose a strategist',
      '军师随你走完这一趟楚汉路。他的谋略贯穿每一场战斗，也决定了这一局的打法。': 'Your strategist walks the whole road with you. His counsel shapes every battle—and the way this run plays.',
      '军师选定后整局不变；想换人就在地图上「重开战役」。': 'Your strategist stays for the whole run; to change, restart the campaign from the map.',
      '行 军 途 中': 'ON THE MARCH',
      '得 牌': 'GAIN A CARD', '精 简 行 装': 'TRIM THE BAGGAGE',
      '跳 过': 'SKIP',
      '粮 0/0': 'Prov 0/0',
      '牌库 20': 'Deck 20', '手牌 4': 'Hand 4',
      '技能': 'Power', '结束回合': 'End Turn',
      '楚 河': 'CHU RIVER', '汉 界': 'HAN BORDER',
      '设 置': 'SETTINGS',
      '背景音乐': 'Music', '音 效': 'Sound', '静 音': 'Mute', '动画特效': 'Effects', '全 屏': 'Fullscreen',
      '开': 'On', '关': 'Off',
      '语言': 'Language',
      '语 言': 'Language', '中文': '中文', 'English': 'English',
      '设置自动保存，下次打开仍然生效。': 'Settings are saved automatically.',
      '返 回': 'CLOSE',
      '音效开关': 'Toggle sound', '设置': 'Settings',
      '卡牌图鉴': 'Card Codex', '成 就': 'ACHIEVEMENTS', '战 绩': 'CAREER',
      '这个筛选下暂时没有牌': 'No cards under this filter',
      '目标': 'Goal',
      '调 兵 遣 将': 'MUSTER YOUR TROOPS',
      '这是你的起手牌。点选不想要的牌（可多选），确认后洗回牌库换成新牌；也可以全部保留。': 'Your opening hand. Click cards you dislike (any number), then confirm to shuffle them back and draw replacements—or keep them all.',
      '全部保留': 'KEEP ALL', '确 认 出 战': 'CONFIRM & FIGHT',
      '再 战 一 局': 'BATTLE AGAIN', '重 试 本 关': 'RETRY THIS STAGE', '返 回 地 图': 'BACK TO MAP',
      '我 方 回 合': 'YOUR TURN', '敌 方 回 合': 'ENEMY TURN',
      '明 白 了': 'GOT IT',
      /* 玩法说明（逐段） */
      '：打倒对方主将即获胜。主将就是你开局选的人物（刘邦 30 血 / 项羽 26 血）。': ': reduce the enemy commander to 0. Your commander is the hero you picked at the start (Liu Bang 30 / Xiang Yu 26 Health).',
      '调兵遣将': 'Muster',
      '：开局先看起手牌，不满意的可以点选换掉（先机虎符不可换），也可全部保留——这是唯一一次换手牌的机会。': ': look at your opening hand; click any cards to swap (except First Mover), or keep all—this is your one chance to mulligan.',
      '军粮': 'Provisions',
      '：出牌要花军粮。第 1 回合 1 点、第 2 回合 2 点……每回合上限 +1（最多 10），每回合回满。': ': cards cost Provisions. Turn 1 gives 1, turn 2 gives 2, +1 each turn (max 10), refilled every turn.',
      '三列军阵': 'Three Battle Columns',
      '：战场分前锋、中军、后军三列，每列最多站 3 员。兵只能进前锋，车、马、士、象进中军，炮进后军。': ': the field has Vanguard, Center and Rear columns, 3 units each. Infantry deploy only to the Vanguard; Chariots, Cavalry, Guards and Elephants to the Center; Catapults to the Rear.',
      '攻击规则': 'Attack Rules',
      '：默认只能攻击敌方最靠前且有兵的一列——前锋空了才能打中军，中军空了才能打后军；全军覆没时才能直取主将。单位登场当回合不能攻击。': ': you may normally attack only the foremost enemy column with units—the Center opens up once the Vanguard is empty, the Rear once the Center is empty; reach the commander only when the field is cleared. Units cannot attack the turn they arrive.',
      '兵种关键字': 'Unit Keywords',
      '（士、象）：敌人必须先攻击它；': ' (Guards, Elephants): enemies must attack it first; ',
      '（马）：可直接攻击前锋或中军；': ' (Cavalry): may strike the Vanguard or Center directly; ',
      '（炮）：可攻击任意一列。': ' (Catapults): may attack any column.',
      '守御': 'Taunt', '迂回': 'Flank', '远程': 'Ranged', '冲锋': 'Charge', '死战': 'Last Stand', '连击': 'Combo',
      '交锋关键字': 'Combat Keywords',
      '：登场当回合即可攻击；': ': may attack the very turn it arrives; ',
      '：阵亡时触发一次效果；': ': triggers an effect once when it dies; ',
      '：本回合此前已出过别的牌才会触发。': ': only triggers if you played another card earlier this turn.',
      '楚汉战役': 'Chu–Han Campaign',
      '：8 关历史路线，每关有专属规则与敌军牌组；每胜一关，从三张牌里选一张永久加入你的战役牌组。': ': an 8-stage historical road, each with its own rules and enemy deck; after each victory, pick one of three cards to keep permanently in your campaign deck.',
      '择一军师': 'Choose a Strategist',
      '：每局战役开局从三名军师里选一位，他的被动贯穿所有战斗（如韩信：前锋兵种 +1 攻）。想换人就在地图上「重开战役」。': ': at the start of each campaign run, pick one of three strategists whose passive spans every battle (e.g. Han Xin: Vanguard units +1 Attack). To change, restart the campaign from the map.',
      '行军事件': 'March Events',
      '：每关打完、进入下一关之前，会随机遇到一个行军事件——开仓赈济、粮道被断、破釜沉舟……每个选择都有代价与收获，生命上限会累计到之后的每场战斗。': ': after each stage and before the next, a random march event appears—open the granaries, severed supply lines, burning the kettles… every choice trades a cost for a gain, and max Health carries into later battles.',
      '奖励随机': 'Random Rewards',
      '：每次三选一的候选牌从全局卡池随机抽取，越靠后的关能抽到越强的牌；同名牌最多带 2 张。': ': each three-card pick is drawn from the global pool; later stages offer stronger cards. Max 2 copies per card.',
      '计谋牌': 'Stratagems',
      '：使用后立即生效并弃置，如「萧何·运粮」抽两张牌、「范增·毒计」狙击残血兵种。': ': take effect immediately and are discarded—Grain Convoy draws two cards; Venom snipes a wounded unit.',
      '疲劳': 'Fatigue',
      '：牌库抽完后，每次该抽牌改为受到递增伤害（1、2、3……），对局必有胜负。': ': once your deck runs dry, each draw becomes rising damage (1, 2, 3…)—every battle must end.',
      '先机': 'First Mover',
      '：后手玩家开局多 1 张牌和一张 0 费「先机」，使用后本回合 +1 军粮。': ': the player who moves second starts with 1 extra card and a free First Mover—play it for +1 Provision this turn.',
      '操作': 'Controls',
      '：点手牌即出牌（悬停可放大看牌）；点我方发绿光的单位，再点红色光圈的目标即攻击，右键或 ESC 取消选择；点「结束回合」交给对方（还有牌可出时会请你再确认一次）。': ': click a card in hand to play it (hover to enlarge); click a glowing green unit, then a red-ringed target, to attack—right-click or ESC cancels; End Turn passes play (you will be asked to confirm if you still have plays).',
      /* 动态串（ui.js） */
      '已重置，下一局开场会重新引导': 'Reset. The tutorial will run again at the start of your next battle.',
      '同名牌最多带 2 张': 'At most 2 copies of a card',
      '牌库已满 20 张': 'Deck is full at 20 cards',
      '需正好 20 张才能保存': 'A deck needs exactly 20 cards to save',
      '牌库已保存，以后「快速开战」将自动使用': 'Deck saved. Quick Battle will use it from now on.',
      '为 {h} 组建牌库': 'Build a deck for {h}',
      '军师「{n}」入帐': 'Strategist {n} joins your tent',
      '已 通 关': 'CLEARED', '待 战': 'TO BATTLE',
      '目标：': 'Goal: ',
      '本关目标：': 'Stage goal: ',
      '{h}视角 · 已通关 {a} / {b}': '{h}\u2019s road · cleared {a} / {b}',
      '当前牌组 {n} 张': 'Deck: {n} cards',
      '牌组 {n} 张': 'Deck: {n} cards',
      '军师': 'Strategist', '生命上限': 'Max Health', '下一战': 'Next Battle', '行军': 'March',
      '尚未择师（点击选择）': 'No strategist yet (click to choose)',
      '军粮 {v}': 'Provisions {v}',
      '起手 +{n} 牌': '+{n} opening cards',
      '敌方军粮 {v}': 'Enemy Provisions {v}',
      '仅显示最近一条行军事件': 'Shows the most recent march event',
      '目标：存活 {n} 回合 · 已完成 {d} / {t}': 'Goal: survive {n} turns · {d} / {t} done',
      '目标：击破 {n}（{h} 血）': 'Goal: defeat {n} ({h} Health)',
      '「{s}」已破。选一张牌收入牌组。': '{s} is taken. Pick one card for your deck.',
      '选 它': 'TAKE IT',
      /* Godot 版奖励页的次要选项：不取牌、改删一张（Web 版无此界面，仅供 Godot 用） */
      '不取此牌 · 改删一张': 'NO CARD · DROP ONE INSTEAD',
      '删掉一张废牌，比多拿一张更强 —— 但删太多会断了低费曲线':
        'Cutting a dead card beats taking a new one — but cut too deep and your low-cost curve breaks',
      '牌组已到下限': 'Deck is at the minimum size',
      '删 去 一 张': 'DROP ONE CARD',
      '点选要删的牌 · 同名只删一张': 'Click the card to cut · one copy per click',
      '取 消': 'CANCEL',
      '删 去 并 进 军': 'CUT IT AND MARCH',
      '事件结算失败': 'Event failed to resolve',
      '囊中无可用之牌': 'No eligible cards to remove',
      '从牌组中移除 {n} 张牌': 'Remove {n} cards from your deck',
      '（还需 {n} 张）': ' ({n} more to pick)',
      '收 入': 'TAKE', '移 除': 'REMOVE',
      '牌组里没有这张': 'That card is not in your deck',
      '存档位 {n}': 'Save Slot {n}',
      '壹': 'I', '贰': 'II', '叁': 'III', '肆': 'IV', '伍': 'V', '陆': 'VI', '柒': 'VII', '捌': 'VIII',
      '当前': 'ACTIVE',
      '空存档位': 'Empty slot',
      '初阵开局': 'Novice', '常规开局': 'Standard',
      '初阵：{d}': 'Novice: {d}',
      '主将 +{hp} 血、敌军首回合 -{mana} 军粮，适合新手':
        'commander +{hp} HP, enemy starts {mana} Provision short — for new players',
      '常规：标准难度': 'Standard: normal difficulty',
      '初阵档': 'Novice', '初阵通关': 'Novice clears',
      '进入': 'Enter', '清空': 'Clear',
      '已通关 {a} / {b}': 'cleared {a} / {b}',
      '已问鼎': 'Throne claimed',
      '下一关：{n}': 'Next: {n}',
      '军师 {n}': 'Strategist {n}',
      '生命上限 {v}': 'Max Health {v}',
      '存档位 {n} 开新局：请择一军师': 'Slot {n} starts fresh: choose a strategist',
      '清空存档位 {n}？该位的关卡进度、军师与牌组都会消失（成就业绩保留）。': 'Clear Slot {n}? Its stage progress, strategist and deck will be erased (achievements are kept).',
      '存档位 {n} 已清空': 'Slot {n} cleared',
      '先打赢前一关，才能走到这里': 'Win the previous stage first to reach here',
      '关卡数据异常：': 'Bad stage data: ',
      '打开关卡出错：': 'Error opening stage: ',
      '重开战役会清空通关进度、军师和已获得的牌组，确定要重开吗？': 'Restarting wipes this slot\u2019s progress, strategist and gained deck. Restart?',
      '战役已重置，请重新择师': 'Campaign restarted—choose a strategist',
      '粮 {a}/{b}': 'Prov {a}/{b}',
      '牌库 {n}': 'Deck {n}',
      '手牌 {n}': 'Hand {n}',
      '{n}（{c} 粮）': '{n} ({c} Prov)',
      '剩余血量': 'Health left', '造成伤害': 'Damage dealt', '出兵': 'Units deployed',
      '用计': 'Stratagems', '回血': 'Healing', '战 绩': 'BATTLE RECORD', '我方': 'You', '敌方': 'Foe',
      '直取主将 {n} 伤': '{n} damage to the commander',
      '{n} 个回合 · 牌库余 {d} 张': '{n} turns · {d} cards left in deck',
      '这一关已经打过，奖励只能领一次': 'This stage was already cleared; its reward can only be claimed once',
      '第 {n} 回合，功亏一篑。「{s}」还需再战。': 'Fell on turn {n}, so close. {s} must be fought again.',
      '历经 {n} 个回合，问鼎中原！': '{n} turns of war—and the throne is won!',
      '鏖战 {n} 个回合，卷土重来未可知。': '{n} hard turns. The comeback is still unwritten.',
      '还有能出的牌': 'You still have cards to play',
      '还有能攻击的部队': 'You still have units that can attack',
      '，再点一次结束回合': ' — click End Turn again to pass',
      '「{n}」没有攻击力，它的价值在于守御挡路，不能用来打人。': '{n} has no Attack—its worth is standing in the way, not striking.',
      '「{n}」这一回合还不能攻击：刚登场，或者已经出手过了。': '{n} cannot attack this turn: it just arrived, or has already struck.',
      '牌组 ×{n}': 'Deck ×{n}',
      '卡池 {a} 张 · 中立 {b} / 汉 {c} / 楚 {d} · 兵种 {e} / 计谋 {f}': 'Pool: {a} cards · Neutral {b} / Han {c} / Chu {d} · Units {e} / Stratagems {f}',
      '　·　当前战役牌组 {n} 张': ' · campaign deck: {n} cards',
      '已解锁 {a} / {b}　·　成就只增不减，重开战役、清空进度都不影响': 'Unlocked {a} / {b} · achievements are permanent—restarts and resets never remove them',
      '已达成': 'DONE',
      '还没有开过战。打一局，这里就开始记事了。': 'No battles yet. Fight one and the record begins.',
      '累计 {a} 场战斗 · 胜率 {b}%': '{a} battles so far · {b}% wins',
      '总 场 次': 'BATTLES', '胜 场': 'WINS', '胜 率': 'WIN RATE', '最 长 连 胜': 'BEST STREAK',
      '战 役 进 度': 'CAMPAIGN', '累 计 伤 害': 'TOTAL DAMAGE',
      '战 役': 'CAMPAIGN', '战 阵': 'BATTLEFIELD',
      '最远抵达': 'Furthest stage', '通关关卡': 'Stages cleared', '最大牌组': 'Largest deck',
      '用过军师': 'Strategists used', '行军事件': 'March events seen',
      '第{n}关 · {s}': 'Stage {n} · {s}',
      '尚未出征': 'Not yet taken the field',
      '张': ' cards', '{a} / {b}': '{a} / {b}', '{a} 员 / {b} 张': '{a} / {b}',
      '单局最速取胜': 'Fastest win', '最凶险的胜仗': 'Narrowest win',
      '{n} 回合': '{n} turns', '剩 {n} 血': '{n} Health left',
      '累计出兵 / 用计': 'Units / Stratagems', '对主将造成伤害': 'Damage to commanders',
      '各难度胜场': 'Wins by difficulty',
      '{n} 胜': '{n} wins',
      '用过的英雄：': 'Commanders played: ',
      '成 就 解 锁': 'ACHIEVEMENT UNLOCKED',
      '成就解锁 · ': 'Achievement · ',
      '小 提 示': 'TIP',
      /* 新手引导（六步） */
      '这就是你的对手': 'This is your opponent',
      '把敌方主将的血量打到 0 就赢了。反过来，你的主将一死，仗就打输了。': 'Bring the enemy commander to 0 Health to win. If your commander dies first, the battle is lost.',
      '军粮就是出牌的费用': 'Provisions are what cards cost',
      '第 1 回合 1 点，第 2 回合 2 点……每回合上限加 1（最多 10），开局回满。这里的「当前/上限」就是你现在有多少粮。': 'Turn 1 gives 1, turn 2 gives 2, and so on—the cap rises by 1 each turn (max 10) and refills every turn. \u201Ccurrent/cap\u201D here is what you have right now.',
      '点一张牌，它就下场': 'Click a card to deploy it',
      '亮着的牌现在就能出；灰掉的是军粮不够，或者那一列已经站满 3 员。点一张试试。': 'Bright cards can be played now; greyed-out ones lack Provisions, or their column already holds 3 units. Try clicking one.',
      '兵种下场要等一回合': 'New units wait a turn to attack',
      '刚登场的兵种当回合不能攻击（带「冲锋」的除外）。到你的下一回合，它会亮起绿光——点它，再点敌人，就是一次进攻。': 'A unit just deployed cannot attack this turn (unless it has Charge). On your next turn it glows green—click it, then click an enemy, to attack.',
      '别忘了主将技能': 'Don\u2019t forget your commander power',
      '每回合能用一次。刘邦「约法三章」回血续航，项羽「破釜沉舟」横扫敌方前锋——关键时刻能翻盘。': 'Usable once per turn. Liu Bang\u2019s Three Articles heals and holds; Xiang Yu\u2019s Break the Kettles sweeps the enemy Vanguard—it can flip a fight.',
      '打完就交给对面': 'Done? Hand play over',
      '手里还有能出的牌、或还有能攻击的部队时，会先提醒你一次，再点才真的结束回合。': 'If you still have plays or attacks available, you\u2019ll be asked once before the turn actually ends.',
      /* 引导一次性提示 */
      '军粮不够。每回合上限 +1，撑到下个回合就出得起了。': 'Not enough Provisions. The cap rises by 1 each turn—wait one turn and it will be affordable.',
      '它这一回合还不能攻击：刚登场，或者已经出手过了。': 'It cannot attack this turn: it just arrived, or has already struck.',
      '敌方最靠前的那一列还没清空，暂时打不到后面的部队。': 'The foremost enemy column isn\u2019t cleared yet, so the units behind it are out of reach.',
      '每列最多站 {n} 员。先打完这一列，或把牌出到别的列。': 'Each column holds at most {n} units. Clear this one first, or deploy into another column.',
      '跳 过': 'SKIP', '下 一 步': 'NEXT', '开 始 出 征': 'SET OUT',
      '暂 无': '—',
      '第 1 存档': 'Slot 1'
    },

    cards: {
      n_bing1: { name: 'Infantry · Recruit', desc: 'Cheap line-holders; once they cross the river they do not look back.' },
      n_bing2: { name: 'Infantry · Veteran', desc: 'Old soldiers who lived through a hundred fights.' },
      n_ma1: { name: 'Cavalry · Outrider', desc: 'Flank: may attack the Center directly.' },
      n_ma2: { name: 'Cavalry · Lancer', desc: 'Flank: may attack the Center directly.' },
      n_che1: { name: 'Chariot · War Chariot', desc: 'The brawling mainstay of the Center.' },
      n_che2: { name: 'Chariot · Ironclad', desc: 'A tide of steel no late game can answer.' },
      n_pao1: { name: 'Catapult · Stone Sling', desc: 'Ranged: may attack any column.' },
      n_pao2: { name: 'Catapult · Repeater', desc: 'Ranged: may attack any column.' },
      n_shi1: { name: 'Guard · Halberdier', desc: 'Taunt: enemies must attack it first.' },
      n_shi2: { name: 'Guard · Imperial Rider', desc: 'Taunt: enemies must attack it first.' },
      n_xiang1: { name: 'Elephant · Guardian', desc: 'Taunt: a thick-hided guardian beast.' },
      n_xiang2: { name: 'Elephant · Colossus', desc: 'Taunt: a towering deterrent in the Center.' },
      n_bing4: { name: 'Infantry · Borderer', desc: 'Taunt: an old border soldier—never first, but he holds the gate.' },
      n_bing3: { name: 'Infantry · Deathseeker', desc: 'Last Stand: deals 2 damage to the enemy commander when it dies.' },
      n_shi3: { name: 'Guard · Oathguard', desc: 'Taunt. Last Stand: all friendly units gain +1 Attack.' },
      n_ma3: { name: 'Cavalry · Ironhoof', desc: 'Charge, Flank: kicks the Center in the teeth the moment it lands.' },
      n_che3: { name: 'Chariot · Battering Ram', desc: 'Charge: the one that breaks the gate open.' },
      n_pao3: { name: 'Catapult · Thunderer', desc: 'Ranged. Last Stand: deals 2 damage to the whole enemy Vanguard.' },
      n_xiang3: { name: 'Elephant · Armored Titan', desc: 'Taunt: an armored giant on the field.' },
      n_bing5: { name: 'Infantry · Convict', desc: 'Last Stand: a 1/2 Recruit joins your Vanguard when it dies.' },
      n_bing6: { name: 'Infantry · Garrison', desc: 'Taunt. Last Stand: a 1/2 Recruit joins your Vanguard when it dies.' },
      n_bing7: { name: 'Infantry · Deathband', desc: 'Last Stand: a 1/2 Recruit joins your Vanguard when it dies.' },
      n_bing8: { name: 'Infantry · Defector', desc: 'Last Stand: draw a card when it dies.' },
      n_shi4: { name: 'Guard · Rearguard', desc: 'Taunt. Last Stand: your Vanguard gains +1 Attack.' },
      n_shi5: { name: 'Guard · Bonewall', desc: 'Last Stand: your Center gains +1 Attack.' },
      n_shi6: { name: 'Guard · Retainer', desc: 'Last Stand: draw a card when it dies.' },
      n_jiang1: { name: 'General · Deputy', desc: 'Last Stand: your Center gains +1 Attack.' },
      n_dun1: { name: 'Shield · Shieldbearer', desc: 'Taunt. Battlecry: draw a card.' },
      n_lei1: { name: 'Rampart · Caltrops', desc: 'Taunt. Battlecry: your Vanguard gains +1 Attack.' },
      n_cheng1: { name: 'Wall · Earthworks', desc: 'Taunt: packed earth, the cheapest wall a man can raise.' },
      n_cheng2: { name: 'Wall · Parapet', desc: 'Taunt. Last Stand: your Center gains +1 Attack.' },
      n_cheng3: { name: 'Wall · Barbican', desc: 'Taunt. Battlecry: restore 2 Health to your hero.' },
      n_cheng4: { name: 'Wall · Bulwark', desc: 'Taunt. Last Stand: all friendly units gain +1 Attack.' },
      n_yi1: { name: 'Medic · Field Surgeon', desc: 'Last Stand: restore 2 Health to your hero.' },
      n_shi7: { name: 'Guard · Death Vow', desc: 'Taunt. Last Stand: restore 3 Health to your hero.' },
      n_bing9: { name: 'Infantry · Scout', desc: 'Last Stand: deal 1 damage to the enemy Vanguard.' },
      n_bing10: { name: 'Infantry · Condemned', desc: 'Last Stand: deal 3 damage to the enemy unit with the lowest Health.' },
      n_che4: { name: 'Chariot · Doomed Charge', desc: 'Charge. Last Stand: deal 2 damage to the enemy Vanguard.' },
      n_jiang2: { name: 'General · Warlord of the Dead', desc: 'Last Stand: deal 2 damage to all enemy units.' },
      n_zhengfa: { name: 'Ordinance · Conscription', desc: 'Summon a 1/2 Recruit into your Vanguard.' },
      n_xiangyong: { name: 'Infantry · Militia', desc: 'Conscripted villagers. Better than nothing.' },
      n_xuanshang: { name: 'Ordinance · Bounty', desc: 'Draw a card and restore 2 Health to your hero.' },
      n_huogong: { name: 'Ordinance · Fire Attack', desc: 'Deal 3 damage to the enemy Center.' },
      n_zengyuan: { name: 'Ordinance · Reinforcements', desc: 'Summon two 1/2 Recruits into your Vanguard.' },
      n_hanxin: { name: 'Han Xin · Muster', desc: 'Battlecry: summon a 1/1 Recruit into your Vanguard. The more, the better!' },
      n_pengyue: { name: 'Peng Yue · Guerrilla', desc: 'Flank: a master of the raid, may strike the Center directly.' },
      n_yingbu: { name: 'Ying Bu · Warlord', desc: 'A beast of a general who served Chu first, then Han—deadly on either side.' },
      n_lizuo: { name: 'Li Zuoche · Counsel', desc: 'Battlecry: draw a card.' },
      s_xiaohe: { name: 'Xiao He · Grain Convoy', desc: 'Draw 2 cards. He steadied the state and never let the grain stop.' },
      s_jinang: { name: 'Zhang Liang · Silk Pouch', desc: 'Deal 1 damage to every enemy in the Vanguard. Victory is planned within the tent.' },
      h_caocan: { name: 'Cao Can · Assault', desc: 'The assault lord: what he besieged, he took; what he fought, he won.' },
      h_zhoub: { name: 'Zhou Bo · Dynastic Shield', desc: 'Taunt: plain of speech and heavy of hand—the man who secured the Han succession.' },
      h_fankuai: { name: 'Fan Kuai · Tentbreaker', desc: 'Charge: burst into the banquet at Hongmen and gnawed a raw pork shoulder.' },
      h_guanying: { name: 'Guan Ying · Horse Lord', desc: 'Flank: Han\u2019s cavalry commander, born to strip Chu\u2019s supply lines.' },
      h_jixin: { name: 'Ji Xin · Body Double', desc: 'Last Stand: restore 3 Health to your commander. The man who burned in the king\u2019s robes at Xingyang.' },
      h_chenping: { name: 'Chen Ping · Discord', desc: 'Deal 3 damage to the enemy\u2019s strongest unit, then draw a card.' },
      h_luyi: { name: 'Li Yiji · Envoy', desc: 'All enemy units lose 1 Attack; draw a card. A three-inch tongue undoes a million-man army.' },
      s_simian: { name: 'Songs of Chu', desc: 'All enemy units lose 2 Attack. When the songs of Chu rise on every side, the will to fight scatters.' },
      h_zhiji: { name: 'Halberdier', desc: 'Combo: if you played another card this turn, gain +1 Attack. Halberd at the gate, in step and in order.' },
      s_liannu: { name: 'Volley of Crossbows', desc: 'Deal 1 damage to the enemy Vanguard; Combo: deal 1 more. Bolt after bolt, like rain that will not stop.' },
      s_lianhuan: { name: 'Chain of Schemes', desc: 'Draw a card; Combo: draw another. Link upon link, scheme upon scheme.' },
      h_qimen: { name: 'Palace Guard', desc: 'Combo: if you played another card this turn, draw a card. Guards of the Qimen watch, answering the drum.' },
      h_diezhen: { name: 'Stacked Shields', desc: 'Taunt. Combo: your Vanguard gains +1 Attack. Shields stacked forward, a mountain of them.' },
      h_jiewu: { name: 'Successor in Arms', desc: 'Last Stand: your Center gains +1 Attack. Combo: gain +2 Attack. The old line ends, the new one presses on.' },
      h_xiandeng: { name: 'First Over the Wall', desc: 'Combo: if you played another card this turn, gain +2 Attack. First up the wall is rewarded; the timid are cut down.' },
      s_lianying: { name: 'Burning Camps', desc: 'Deal 2 damage to the enemy Center; Combo: deal 1 damage to all enemies. A hundred li of camps, one torch to wake them all.' },
      s_fanzeng: { name: 'Fan Zeng · Venom', desc: 'Deal 3 damage to the enemy\u2019s weakest unit. That brat is not worth planning with!' },
      s_bawang: { name: 'Hegemon\u2019s Spear', desc: 'Units in your Vanguard gain +3 Attack. I could uproot mountains and out-storm the world!' },
      c_longqie: { name: 'Long Ju · Jiangdong Elite', desc: 'A bold son of Jiangdong who marched out with the Hegemon.' },
      c_jibu: { name: 'Ji Bu · Given Word', desc: 'Flank: a hundred catties of gold are worth less than one promise from Ji Bu.' },
      c_huanchu: { name: 'Huan Chu · Vanguard', desc: 'Charge: the first man into the fray for the Hegemon.' },
      c_xiangzhuang: { name: 'Xiang Zhuang · Sword Dance', desc: 'Combo: if you played another card this turn, gain +2 Attack. The sword dance aims at the Lord of Pei.' },
      c_zhuiqi: { name: 'Chu Horse · Windchaser', desc: 'Charge: thirty thousand li of pursuit—half a day to rout 560,000.' },
      c_zhongli: { name: 'Zhongli Mo · Backbone', desc: 'Taunt: the backbone of Chu—he would die in place before giving a step.' },
      c_yuji: { name: 'Yu Ji · Last Refrain', desc: 'Restore 3 Health to your commander; draw a card. Han soldiers have taken the land—songs of Chu on every side.' },
      s_pozhen: { name: 'Shatter the Line', desc: 'Deal 2 damage to every enemy in the Vanguard.' },
      s_juding: { name: 'Lifting the Cauldron', desc: 'All your units gain +2 Attack. The cauldron he can lift; Heaven he cannot defy.' },
      s_xianji: { name: 'First Mover', desc: 'Gain 1 Provision this turn. The tiger tally in hand—strike first.' }
    },

    heroes: {
      liubang: {
        name: 'Liu Bang', title: 'King of Han',
        intro: '30 Health, attrition style. A power that heals and buffs—the longer it drags, the steadier it gets.',
        skill: { name: 'Three Articles', desc: 'Restore 2 Health; if already at full Health, a random friendly unit gains +1 Attack.' }
      },
      xiangyu: {
        name: 'Xiang Yu', title: 'Hegemon-King of Chu',
        intro: '26 Health, aggression style. A power that sweeps the enemy Vanguard—all tempo, no mercy.',
        skill: { name: 'Break the Kettles', desc: 'Deal 1 damage to every enemy in the Vanguard; if that column is empty, deal 1 damage to the enemy commander.' }
      }
    },

    ranks: { front: 'Vanguard', mid: 'Center', back: 'Rear' },

    stages: {
      peixian: {
        chapter: 'Chapter I', name: 'Rising at Pei County',
        year: 'First Year of Er Shi · 209 BC',
        subtitle: 'Slay the serpent, raise the banner',
        lore: 'Chen Sheng and Wu Guang rose at Dazexiang, and a world long ground under Qin\u2019s heel caught fire.\n\nThe elders of Pei County killed the magistrate, opened the gates and hailed you as \u201CLord of Pei.\u201D You have three thousand sons of the county—no more—and the Qin commandant is already marching on the city.\n\nThis is your first battle. Win it, and there is a Han at the end of the road.',
        goalText: 'Defeat the Qin commandant (the enemy has only 14 Health)',
        enemy: { name: 'Qin · Sishui Commandant', title: 'Qin Army Commandant' }
      },
      hongmen: {
        chapter: 'Chapter II', name: 'The Feast at Hongmen',
        year: 'First Year of Han · 206 BC',
        subtitle: 'They are the knife and block; we are the fish and meat',
        lore: 'You entered the Pass first and broke Xianyang. Xiang Yu brought four hundred thousand men to Hongmen; you have ten thousand.\n\nYou come to the feast. At table, Fan Zeng lifts his jade pendant three times; Xiang Yu sits silent. Xiang Zhuang rises to dance with his sword, and its edge grazes your seat again and again—Xiang Bo shields you with his body; Fan Kuai storms the tent, eyes blazing.\n\nThis battle is not for winning. Walk out of that tent alive, and you have won.',
        goalText: 'Survive 10 turns (you have 12 Health and a hand limit of 3)',
        enemy: { name: 'Xiang Yu', title: 'Hegemon-King of Chu' }
      },
      pengcheng: {
        chapter: 'Chapter III', name: 'The Battle of Pengcheng',
        year: 'Second Year of Han · 205 BC',
        subtitle: 'The Sui River could not flow for the dead',
        lore: 'While Xiang Yu marched north against Qi, you fell on Pengcheng with half a million allied troops and took it. You thought the matter settled, and feasted day after day.\n\nThen Xiang Yu came back with thirty thousand picked horse. In half a day, half a million men came apart. The Sui River could not flow for the dead.\n\nHis riders are drawn up in their ranks. You will get one chance, and only one.',
        goalText: 'Defeat Xiang Yu (1 enemy vanguard is already arrayed; you gain +2 Provisions turn 1)',
        enemy: { name: 'Xiang Yu', title: 'Hegemon-King of Chu' }
      },
      xingyang: {
        chapter: 'Chapter IV', name: 'The Standoff at Xingyang',
        year: 'Third Year of Han · 204 BC',
        subtitle: 'Ji Xin burns; the King slips out by night',
        lore: 'Xiang Yu walls you into Xingyang and cuts the grain road. The city is starving; the soldiers are spent.\n\nChen Ping\u2019s sowing of distrust drives Fan Zeng away. Ji Xin dresses in your robes and rides your chariot out the east gate, offering a false surrender—and burns for it. You cut your way out the west gate with a few dozen riders, under cover of dark.\n\nTo leave this city, first punch through Chu\u2019s iron wall.',
        goalText: 'Defeat Xiang Yu (22 Health; Chu holds the walls. You gain +2 Provisions turn 1)',
        enemy: { name: 'Xiang Yu', title: 'Hegemon-King of Chu' }
      },
      jingxing: {
        chapter: 'Chapter V', name: 'Backs to the River',
        year: 'Third Year of Han · 204 BC',
        subtitle: 'In desperate ground, rise again',
        lore: 'Han Xin leads twenty thousand raw recruits down the Jingxing defile; two hundred thousand Zhao men hold the mouth of the pass. He arrays them with their backs to the river—nowhere to run.\n\n\u201CThrow them into desperate ground and they rise; place them where all is lost and they survive.\u201D These recruits do not fight because they are brave. They fight because there is no road home.\n\nYou have sixteen Health. Break the line, or die on this riverbank.',
        goalText: 'Defeat the Zhao army (you have 16 Health, +2 Provisions turn 1; 1 enemy unit is already arrayed)',
        enemy: { name: 'Zhao · Lord Cheng\u2019an', title: 'Chen Yu, King of Dai' }
      },
      weishui: {
        chapter: 'Chapter VI', name: 'The Battle of Wei River',
        year: 'Fourth Year of Han · 203 BC',
        subtitle: 'Dam the water with sandbags; strike at mid-crossing',
        lore: 'Han Xin marches east against Qi; Long Ju brings two hundred thousand Chu men to break him. The armies face each other across the Wei.\n\nBy night, Han Xin\u2019s men dam the upper reaches with ten thousand sandbags. At dawn he feigns defeat and falls back across the river. Long Ju, delighted, fords in pursuit—and the bags are cut. Half the Chu army never makes it across.\n\nBefore the water returns, punch through all three of Long Ju\u2019s lines.',
        goalText: 'Defeat Long Ju (24 Health; 200,000 Chu troops at the gates. You gain +3 Provisions turn 1)',
        enemy: { name: 'Long Ju', title: 'Grand Marshal of Chu' }
      },
      guling: {
        chapter: 'Chapter VII', name: 'The Battle of Guling',
        year: 'Fifth Year of Han · 202 BC',
        subtitle: 'No relief comes; hold the line alone',
        lore: 'The Treaty of the Hong Canal is signed, and Xiang Yu marches east for home. You tear it up and follow on his heels, sending word for Han Xin and Peng Yue to join you at Guling.\n\nThe appointed day comes. Not one soldier of either relief army appears. Xiang Yu wheels about and smashes into you; you dig in behind high walls and deep ditches.\n\nIf no relief is coming, then hold this line yourself.',
        goalText: 'Defeat Xiang Yu (18 Health, hand limit 4, +2 Provisions turn 1; the enemy also gains +2 Provisions turn 1)',
        enemy: { name: 'Xiang Yu', title: 'Hegemon-King of Chu' }
      },
      gaixia: {
        chapter: 'Chapter VIII', name: 'The Final Battle at Gaixia',
        year: 'Fifth Year of Han · 202 BC',
        subtitle: 'Ambush on ten sides; songs of Chu on four',
        lore: 'Han Xin\u2019s three hundred thousand hold the center, Kong Xi on the left, Chen He on the right, Zhou Bo and Chai Wu behind—ambush upon ambush, ten deep, folding around the Chu army at Gaixia.\n\nAt midnight the Han camp sings songs of Chu on every side. Xiang Yu starts up in alarm: \u201CHas Han taken all of Chu? Why are there so many men of Chu over there!\u201D\n\nThis is the last battle. He is still the Hegemon who once lifted a cauldron.',
        goalText: 'Defeat Xiang Yu (30 Health; an enemy Lancer opens on the field and the enemy gains +2 Provisions turn 1; you gain +3 Provisions turn 1)',
        enemy: { name: 'Xiang Yu', title: 'Hegemon-King of Chu' }
      }
    },

    advisors: {
      zhangliang: {
        name: 'Zhang Liang', title: 'Grand Strategist',
        desc: 'The first Stratagem you play each turn draws a card and refunds 1 Provision.',
        flavor: 'Planning inside the tent; victory a thousand li away.'
      },
      xiaohe: {
        name: 'Xiao He', title: 'Keeper of the State',
        desc: 'At the start of each battle, your max Health +5 and you draw an extra card.',
        flavor: 'He steadied the state, settled the people, and the grain never stopped moving.'
      },
      hanxin: {
        name: 'Han Xin', title: 'The More the Better',
        desc: 'Units you deploy into the Vanguard gain +1 Attack.',
        flavor: 'Give me more troops—always more.'
      },
      fankuai: {
        name: 'Fan Kuai', title: 'First Through the Gate',
        desc: 'The first unit you deploy each battle gains +1 Attack and +1 Health.',
        flavor: 'Let me in—I will share his fate!'
      },
      chenping: {
        name: 'Chen Ping', title: 'Six Strange Stratagems',
        desc: 'Draw two extra cards at the start of each battle; if the enemy has units arrayed, deal 1 damage to each of them.',
        flavor: 'Six strange stratagems, six new fiefs.'
      },
      xiangying: {
        name: 'Xiahou Ying', title: 'Duke of Teng',
        desc: 'Every Last Stand of yours triggers one extra time (at most twice extra per battle).',
        flavor: 'The prince is in danger—yet he can be saved. Why abandon him?'
      },
      zhoubo: {
        name: 'Zhou Bo', title: 'Steadying the House of Liu',
        desc: 'At the start of each of your turns, your highest-Attack unit gains +1 Attack and +1 Health (at most once per battle).',
        flavor: 'Blunt and plain of speech—yet it is Bo who will keep the House of Liu standing.'
      },
      liyiji: {
        name: 'Li Yiji', title: 'Seventy Cities by Tongue',
        desc: 'At the start of each enemy turn, their highest-Attack unit loses 1 Attack (at most once per battle).',
        flavor: 'One scholar\'s argument, and seventy cities of Qi came over.'
      }
    },

    events: {
      liumin: {
        name: 'Refugees Join',
        text: 'Famine in Guanzhong; thousands of refugees, old and young, follow the army. The grain will hold only to next month, and the road ahead is long.',
        options: [
          { label: 'Open the granaries', hint: 'Max Health +3' },
          { label: 'Enlist them', hint: 'Gain a random Infantry card' },
          { label: 'Turn them away', hint: 'No complications' }
        ]
      },
      liangdao: {
        name: 'Supply Line Severed',
        text: 'Chu outriders have cut the grain road; nothing will come from Aocang for three days. Men have begun slaughtering the horses.',
        options: [
          { label: 'Escort the grain', hint: 'Gain a fine card; -1 Provision turn 1 next battle' },
          { label: 'Abandon it, travel light', hint: 'Max Health -2' },
          { label: 'Eat the horses', hint: 'Max Health -1, gain a random Infantry card' }
        ]
      },
      qishu: {
        name: 'A Chance Find',
        text: 'Digging along the march route, you uncover a bundle of bamboo slips—old military texts, most characters eaten away, a few strategies still legible.',
        options: [
          { label: 'Read by lamplight', hint: 'Pick 1 of 3 Stratagems' },
          { label: 'Burn them', hint: 'Max Health +2' }
        ]
      },
      jiangjiang: {
        name: 'A Defector\u2019s Oath',
        text: 'A Chu officer surrenders with his troops, saying his family are in Guanzhong. Your generals smell a ruse.',
        options: [
          { label: 'Take him in', hint: 'Gain a random card' },
          { label: 'Send him home', hint: 'Max Health +2' },
          { label: 'Execute him as warning', hint: 'Max Health -1, gain a fine card' }
        ]
      },
      yiqing: {
        name: 'Plague in Camp',
        text: 'The summer rains have not stopped for months, and sickness seeps through the camp. The physician says: cut off the arm to save the body, or spend everything you have.',
        options: [
          { label: 'Isolate the sick', hint: 'A random card is removed from your deck' },
          { label: 'Spare no cost', hint: 'Max Health -3, deck untouched' }
        ]
      },
      laozu: {
        name: 'An Old Soldier\u2019s Request',
        text: 'An old soldier who has followed you since Pei kneels before the tent. His legs are failing him, he says; he cannot march any farther.',
        options: [
          { label: 'Let him go home', hint: 'Remove a card from your deck (you choose)' },
          { label: 'Keep him in the ranks', hint: 'Max Health -2' },
          { label: 'Reward him richly, then release', hint: 'Max Health -1, remove two cards' }
        ]
      },
      jisi: {
        name: 'Sacrifice to the River',
        text: 'The army must cross. Old custom demands sinking a jade disc for the river god. The shamans say: the god is displeased, the boats must not launch.',
        options: [
          { label: 'Sink the jade', hint: '+2 Provisions turn 1 next battle' },
          { label: 'Skip the rite, save the jade', hint: 'Max Health +1' }
        ]
      },
      qiaofu: {
        name: 'The Woodcutter\u2019s Path',
        text: 'A woodcutter in the hills says there is a small path that loops behind the enemy—rugged going, and the baggage train may have to be abandoned.',
        options: [
          { label: 'Take the small path', hint: '+1 Provision and +1 opening card next battle' },
          { label: 'March the high road', hint: 'Safe and steady' }
        ]
      },
      pofu: {
        name: 'Break the Kettles',
        text: 'A strong enemy ahead, no retreat behind. Your generals ask: smash the cooking pots now, or keep them just in case?',
        options: [
          { label: 'Sink the boats, smash the pots', hint: 'Max Health -5, gain two cards' },
          { label: 'Keep the baggage train', hint: 'Steady, as planned' }
        ]
      },
      chuge: {
        name: 'Songs in the Night',
        text: 'At midnight, songs of Chu drift in from beyond the pickets—sweet and desolate to the bone. Soldiers rise all around the camp; some weep.',
        options: [
          { label: 'Teach the camp the songs', hint: 'Enemy -1 Provision turn 1 next battle' },
          { label: 'Flog the troublemakers', hint: 'Max Health -1, gain a random card' },
          { label: 'Comfort the soldiers', hint: 'Max Health +1' }
        ]
      },
      jieqi: {
        name: 'Borrowing from the People',
        text: 'Xingyang is encircled and the granaries are empty. The village elders gather outside the gate: they will lend thirty thousand bushels, if you remit their taxes for three years after the war.',
        options: [
          { label: 'Sign the bond', hint: '+3 Provision turn 1 next battle, Max Health -2' },
          { label: 'Requisition the grain', hint: 'Max Health -1, gain a random unit card' },
          { label: 'Split the army to farm', hint: 'Draw two extra opening cards next battle, Max Health -1' }
        ]
      },
      guren: {
        name: 'A Visitor in the Night',
        text: 'Near midnight someone knocks at the gate: Xiang Bo, the Hegemon\'s own uncle. Years ago at Xiapi you saved his life. He says the Hegemon will lead the iron cavalry himself tomorrow.',
        options: [
          { label: 'Send him off with gifts', hint: 'Enemy -2 Provision turn 1 next battle' },
          { label: 'Beg him to soften the blow', hint: 'Max Health +4, -1 Provision turn 1 next battle' },
          { label: 'Refuse him the gate', hint: 'Owe him nothing' }
        ]
      },
      shibing: {
        name: 'Homesick Men',
        text: 'Three years since you entered the pass. Every night someone hums a Pei County tune. The provost brings the muster roll and asks: give them an answer, or there will be trouble.',
        options: [
          { label: 'Promise them home', hint: 'Max Health +3, draw one fewer opening card next battle' },
          { label: 'Crack down on mutiny', hint: 'Gain two cards, Max Health -3' },
          { label: 'Rest in place', hint: 'Draw one extra opening card next battle' }
        ]
      },
      dujiang: {
        name: 'Crossing the River',
        text: 'The river has swollen and there are not enough boats. Your officers ask: lighten the baggage and force the crossing, or wait for the water to fall.',
        options: [
          { label: 'Lighten and cross', hint: '+2 Provision turn 1 next battle, lose a random card from your deck' },
          { label: 'Wait for the water', hint: 'Draw two extra opening cards next battle, Enemy +1 Provision turn 1' },
          { label: 'Follow the bank', hint: 'Max Health +2' }
        ]
      },
      qiufeng: {
        name: 'The False King',
        text: 'A messenger rides in from Qi: Han Xin has taken the kingdom and asks to be made its "acting king." For a moment no one in the tent speaks.',
        options: [
          { label: 'Make him king in truth', hint: 'Gain two cards, Max Health -2' },
          { label: 'Send an envoy to placate him', hint: 'Draw one extra opening card next battle' },
          { label: 'Rebuke his presumption', hint: 'Max Health +3' }
        ]
      },
      honggou: {
        name: 'The Hong Canal Truce',
        text: 'Xiang Yu returns your father and your wife, and proposes to divide the realm at the Hong Canal. Your officers all say: at last, we can rest.',
        options: [
          { label: 'Make the truce', hint: 'Max Health +5, draw one fewer opening card next battle' },
          { label: 'Pursue and strike', hint: 'Max Health -4, gain three cards' },
          { label: 'Feign agreement', hint: '+2 Provision turn 1 next battle' }
        ]
      }
    },

    /* 心魔：按序号对齐（第 1 项 = 第 1 级） */
    ascension: [
      { name: 'Inner Demon: First Stir', desc: 'Commander max Health -3' },
      { name: 'Inner Demon: Siege', desc: 'Draw one fewer opening card' },
      { name: 'Inner Demon: Last Stand', desc: 'Enemy +1 Provision on turn 1' }
    ],

    /* 天时：每局随机一个，八关全程生效 */
    tianshi: {
      qingfeng: { name: 'Fate: Fair Wind', desc: 'You gain +1 Provision on turn 1' },
      fengnian: { name: 'Fate: Fat Year', desc: 'You draw one extra opening card' },
      shuangjiang: { name: 'Fate: First Frost', desc: 'Enemy -1 Provision on turn 1' },
      kuhan: { name: 'Fate: Bitter Cold', desc: 'You -1 Provision on turn 1' },
      lihuo: { name: 'Fate: Scorching Fire', desc: 'Your max Health -4' },
      xingbian: { name: 'Fate: Omen Star', desc: 'Enemy +1 Provision on turn 1' }
    },

    achievements: {
      first_win: { name: 'First Blood', desc: 'Win your first battle.' },
      flawless: { name: 'Unscathed', desc: 'Win with every unit alive and full Health.' },
      last_stand: { name: 'Backs to the River', desc: 'Turn defeat into victory with 5 or fewer Health left.' },
      swift: { name: 'Swift Victory', desc: 'End a battle within 12 turns.' },
      decapitate: { name: 'Strike the Dragon', desc: 'Deal 20+ damage to the enemy commander in a single battle.' },
      army: { name: 'Grand Muster', desc: 'Deploy 10 units in one battle.' },
      strategist: { name: 'Master Planner', desc: 'Play 6 Stratagems in one battle.' },
      mingjiang: { name: 'Equal to a General', desc: 'Win a battle on General difficulty.' },
      stage_1: { name: 'Rising at Pei', desc: 'Clear Stage 1, \u201CRising at Pei County\u201D.' },
      stage_4: { name: 'Into the Heartland', desc: 'Clear Stage 4, \u201CThe Standoff at Xingyang\u201D.' },
      stage_all: { name: 'Throne of the Realm', desc: 'Clear all 8 stages, all the way to Gaixia.' },
      deck_26: { name: 'Growing Ranks', desc: 'Grow your campaign deck to 26 cards.' },
      two_heroes: { name: 'Chu River, Han Border', desc: 'Win at least once as each of Liu Bang and Xiang Yu.' },
      veteran: { name: 'Veteran of a Hundred', desc: 'Fight 20 battles in total.' },
      legend: { name: 'Fifty Battles', desc: 'Fight 50 battles in total.' },
      streak_5: { name: 'Five in a Row', desc: 'Win 5 battles in a row.' },
      advisors_3: { name: 'Council of Three', desc: 'Use 3 different strategists.' },
      events_6: { name: 'Road-Worn', desc: 'Experience 6 different march events.' },
      damage_500: { name: 'Killer of a Thousand Li', desc: 'Deal 500 total damage.' }
    },

    groups: { battle: 'Battlefield', campaign: 'Campaign', career: 'Career' },

    keywords: {
      'Taunt': 'Enemies must destroy it before they can reach the units behind it.',
      'Flank': 'May attack the enemy Vanguard or Center directly, without clearing the column ahead.',
      'Ranged': 'May attack any enemy column, ignoring column order.',
      'Charge': 'May attack the very turn it is deployed.',
      'Last Stand': 'Triggers an effect once when it dies.',
      'Combo': 'Triggers only if you already played another card this turn.',
      'Summoning Sickness': 'A unit cannot attack the turn it arrives (unless it has Charge).',
      'Provisions': 'The resource cards cost to play. The cap on turn N is N (max 10), refilled every turn.'
    },
    keywordList: ['Taunt', 'Flank', 'Ranged', 'Charge', 'Last Stand', 'Combo'],

    /* 单位面 / 地图节点的装饰字：EN 下用短拉丁缩写 */
    glyphs: {
      '兵': 'IN', '马': 'CV', '车': 'CH', '炮': 'CP', '士': 'GD', '象': 'EL',
      '韩': 'HX', '彭': 'PY', '英': 'YB', '李': 'LZ', '曹': 'CC', '周': 'ZB',
      '樊': 'FK', '灌': 'GY', '纪': 'JX', '龙': 'LJ', '季': 'JB', '桓': 'HC',
      '庄': 'XZ', '钟': 'ZM'
    },

    /* 战报：引擎保留中文输出，显示时按序匹配（卡名/列名/人名已被数据层本地化） */
    logPatterns: [
      [/^—— 第 (\d+) 回合：(.+)（军粮 (\d+)\/(\d+)）$/, function (m) {
        return '—— Turn ' + m[1] + ': ' + (SIDE[m[2]] || m[2]) + ' (Provisions ' + m[3] + '/' + m[4] + ')';
      }],
      [/^(我方|敌方)抢得先机，率先出手$/, function (m) { return SIDE[m[1]] + ' seize first mover and strike first.'; }],
      [/^(我方|敌方)换掉 (\d+) 张起手牌$/, function (m) { return SIDE[m[1]] + ' mulligan ' + m[2] + ' opening cards.'; }],
      [/^(我方|敌方)粮草耗尽，疲劳受 (\d+) 点伤害$/, function (m) { return SIDE[m[1]] + ' is out of cards—Fatigue deals ' + m[2] + ' damage.'; }],
      [/^(我方|敌方)手牌已满，(.+) 被烧毁$/, function (m) { return SIDE[m[1]] + '\u2019s hand is full; ' + m[2] + ' burns up.'; }],
      [/^(我方|敌方)的 (.+) 阵亡$/, function (m) { return SIDE[m[1]] + '\u2019s ' + m[2] + ' falls.'; }],
      [/^(我方|敌方)(.+) 死战发动$/, function (m) { return SIDE[m[1]] + ' ' + m[2] + ' triggers Last Stand.'; }],
      [/^(我方|敌方)主将被击倒！$/, function (m) { return SIDE[m[1]] + ' commander is struck down!'; }],
      [/^军师萧何镇抚后方，我军生命上限 \+(\d+)$/, function (m) { return 'Strategist Xiao He steadies the rear: your max Health +' + m[1] + '.'; }],
      [/^沿途休整，我军生命上限 \+(\d+)$/, function (m) { return 'Rest along the road: your max Health +' + m[1] + '.'; }],
      [/^敌军 (.+) 已在(.+)列列阵$/, function (m) { return 'Enemy ' + m[1] + ' already arrays in the ' + m[2] + ' column.'; }],
      [/^军师陈平出奇计，敌军 (\d+) 支部队各受 (\d+) 点伤害$/, function (m) { return 'Strategist Chen Ping\u2019s ruse: ' + m[1] + ' enemy units take ' + m[2] + ' damage each.'; }],
      [/^军师陈平出奇计，先机在握$/, function () { return 'Strategist Chen Ping\u2019s ruse—first mover in hand.'; }],
      [/^轻装疾行，我军起手多摸 (\d+) 张牌$/, function (m) { return 'Travel light: draw ' + m[1] + ' extra opening cards.'; }],
      [/^军师献策，我军起手多摸 (\d+) 张牌$/, function (m) { return 'Your strategist\u2019s counsel: draw ' + m[1] + ' extra opening cards.'; }],
      [/^军师樊哙先登陷阵：(.+) 攻击力 \+(\d+)、生命 \+(\d+)$/, function (m) { return 'Strategist Fan Kuai leads the charge: ' + m[1] + ' gets +' + m[2] + ' Attack, +' + m[3] + ' Health.'; }],
      [/^军师韩信多多益善：(.+) 攻击力 \+(\d+)$/, function (m) { return 'Strategist Han Xin, ever-hungry for more: ' + m[1] + ' gets +' + m[2] + ' Attack.'; }],
      [/^(我方|敌方)派出 (.+) → (.+)$/, function (m) { return SIDE[m[1]] + ' deploy ' + m[2] + ' to the ' + m[3] + ' column.'; }],
      [/^(我方|敌方)使用计谋「(.+)」$/, function (m) { return SIDE[m[1]] + ' play the Stratagem \u201C' + m[2] + '\u201D.'; }],
      [/^军师张良运筹，锦囊既出，再添一策（军粮 \+1）$/, function () { return 'Strategist Zhang Liang: one scheme earns another (+1 Provision).'; }],
      [/^(我方|敌方)「(.+)」连击发动$/, function (m) { return SIDE[m[1]] + ' ' + m[2] + ' triggers Combo.'; }],
      [/^(我方|敌方)点兵 (\d+) 员，进入前锋列$/, function (m) { return SIDE[m[1]] + ' muster ' + m[2] + ' into the Vanguard.'; }],
      [/^(我方|敌方)计策直击敌将 (\d+) 点$/, function (m) { return SIDE[m[1]] + ' scheme strikes the enemy commander for ' + m[2] + '.'; }],
      [/^(我方|敌方)主将恢复 (\d+) 点血量$/, function (m) { return SIDE[m[1]] + ' commander restores ' + m[2] + ' Health.'; }],
      [/^(我方|敌方)增援抵达(.+)列$/, function (m) { return SIDE[m[1]] + ' reinforcements arrive in the ' + m[2] + ' column.'; }],
      [/^(我方|敌方)发动「破釜沉舟」，扫射敌方前锋$/, function (m) { return SIDE[m[1]] + ' uses Break the Kettles, sweeping the enemy Vanguard.'; }],
      [/^(我方|敌方)发动「破釜沉舟」，直击敌将 1 点$/, function (m) { return SIDE[m[1]] + ' uses Break the Kettles, striking the enemy commander for 1.'; }],
      [/^(我方|敌方)发动「约法三章」，恢复 2 点血量$/, function (m) { return SIDE[m[1]] + ' uses Three Articles, restoring 2 Health.'; }],
      [/^(我方|敌方)发动「约法三章」，(.+) \+1 攻$/, function (m) { return SIDE[m[1]] + ' uses Three Articles: ' + m[2] + ' gains +1 Attack.'; }],
      [/^(我方|敌方)(.+) 直取敌将，造成 (\d+) 点伤害$/, function (m) { return SIDE[m[1]] + ' ' + m[2] + ' strikes home at the commander: ' + m[3] + ' damage.'; }],
      [/^(我方|敌方)(.+) 攻击 (.+)（(\d+) vs (\d+)）$/, function (m) {
        return SIDE[m[1]] + ' ' + m[2] + ' attacks ' + m[3] + ' (' + m[4] + ' vs ' + m[5] + ').';
      }]
    ],

    /* 引擎 reason（toast 显示） */
    reasons: [
      [/^(\S+)列已满（每列最多 (\d+) 员）$/, function (m) { return 'The ' + m[1] + ' column is full (' + m[2] + ' per column).'; }],
      [/^手里没有这张牌$/, function () { return 'That card is not in your hand.'; }],
      [/^军粮不足$/, function () { return 'Not enough Provisions.'; }],
      [/^技能现在用不了$/, function () { return 'The power cannot be used right now.'; }],
      [/^找不到攻击单位$/, function () { return 'No attacker selected.'; }],
      [/^该单位本回合不能攻击$/, function () { return 'That unit cannot attack this turn.'; }],
      [/^敌方还有兵种挡路$/, function () { return 'Enemy units still block the way.'; }],
      [/^不能攻击这个目标$/, function () { return 'Cannot attack that target.'; }]
    ]
  });
})();
