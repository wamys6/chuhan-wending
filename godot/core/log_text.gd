## 战报文案（结构化 key + 参数）
##
## 引擎只产出 {k, a} 结构，不拼字符串。好处：
##   1. 文案集中在此，改文案不碰规则代码；
##   2. 以后加语言只是加一列，不需要像 Web 版那样用正则反解中文；
##   3. 测试可以断言 key 与参数，比断言整句中文稳。
class_name LogText
extends RefCounted

const ZH := {
	"advisor_xiaohe": "军师萧何镇抚后方，我军生命上限 +{n}",
	"rest_hp": "沿途休整，我军生命上限 +{n}",
	"enemy_preplaced": "敌军 {name} 已在{rank}列列阵",
	"chenping_hit": "军师陈平出奇计，敌军 {n} 支部队各受 {d} 点伤害",
	"chenping_none": "军师陈平出奇计，先机在握",
	"first": "{side}抢得先机，率先出手",
	"opening_draw": "轻装疾行，我军起手多摸 {n} 张牌",
	"adv_draw": "军师献策，我军起手多摸 {n} 张牌",
	"mulligan": "{side}换掉 {n} 张起手牌",
	"turn": "—— 第 {n} 回合：{side}（军粮 {m}/{mm}）",
	"survive_win": "你熬过了 {n} 个回合，全身而退！",
	"fatigue": "{side}粮草耗尽，疲劳受 {n} 点伤害",
	"hand_full": "{side}手牌已满，{name} 被烧毁",
	"death": "{side}的 {name} 阵亡",
	"deathrattle": "{side}{name} 死战发动",
	"xy_double": "军师夏侯婴护军有方：{name} 死战再发",
	"hero_down": "{side}主将被击倒！",
	"deploy": "{side}派出 {name} → {rank}",
	"spell": "{side}使用计谋「{name}」",
	"adv_fankuai": "军师樊哙先登陷阵：{name} 生命 +{h}",
	"adv_hanxin": "军师韩信多多益善：{name} 攻击力 +{a}",
	"adv_zhangliang": "军师张良运筹，锦囊既出，再添一策",
	"combo": "{side}「{name}」连击发动",
	"tokens": "{side}点兵 {n} 员，进入前锋列",
	"spell_hero_dmg": "{side}计策直击敌将 {n} 点",
	"heal_hero": "{side}主将恢复 {n} 点血量",
	"summon": "{side}增援抵达{rank}列",
	"summon_bonus": "{side}增援抵达{rank}列（死战专精 +{a}/+{h}）",
	"skill_sweep": "{side}发动「破釜沉舟」，扫射敌方前锋",
	"skill_hero_hit": "{side}发动「破釜沉舟」，直击敌将 1 点",
	"skill_heal": "{side}发动「约法三章」，恢复 2 点血量",
	"skill_buff": "{side}发动「约法三章」，{name} +1 攻",
	"attack_hero": "{side}{name} 直取敌将，造成 {n} 点伤害",
	"attack_unit": "{side}{name} 攻击 {target}（{a} vs {d}）",
}

const SIDE_ZH := {"p1": "我方", "p2": "敌方"}
const SIDE_EN := {"p1": "Your army", "p2": "The enemy"}

## 英文文案：与 ZH 一一对应（缺键会退回 key，测试会全键扫一遍）
const EN := {
	"advisor_xiaohe": "Advisor Xiao He holds the rear: max Health +{n}",
	"rest_hp": "Rest along the way: max Health +{n}",
	"enemy_preplaced": "Enemy {name} is already arrayed in the {rank}",
	"chenping_hit": "Advisor Chen Ping's stratagem: {n} enemy units take {d} damage each",
	"chenping_none": "Advisor Chen Ping's stratagem: you seize the first move",
	"first": "{side} seize the first move",
	"opening_draw": "Light marching: draw {n} extra cards",
	"adv_draw": "Advisor's counsel: draw {n} extra cards",
	"mulligan": "{side} mulligan {n} cards",
	"turn": "—— Turn {n}: {side} (Provision {m}/{mm})",
	"survive_win": "You held out for {n} turns and withdrew intact!",
	"fatigue": "{side} run out of supplies: {n} fatigue damage",
	"hand_full": "{side} hand is full: {name} is burned",
	"death": "{side} {name} falls",
	"deathrattle": "{side} {name} triggers Last Stand",
	"xy_double": "Xiahou Ying holds the line: {name} triggers Last Stand again",
	"hero_down": "{side} commander is slain!",
	"deploy": "{side} deploy {name} → {rank}",
	"spell": "{side} play the stratagem “{name}”",
	"adv_fankuai": "Advisor Fan Kuai leads the charge: {name} +{h} Health",
	"adv_hanxin": "Advisor Han Xin, the more the better: {name} +{a} Attack",
	"adv_zhangliang": "Zhang Liang's counsel: one more stratagem",
	"combo": "{side} “{name}” Combo triggers",
	"tokens": "{side} muster {n} tokens into the Vanguard",
	"spell_hero_dmg": "{side} stratagem strikes the commander for {n}",
	"heal_hero": "{side} commander restores {n} Health",
	"summon": "{side} reinforcements arrive in the {rank}",
	"summon_bonus": "{side} reinforcements arrive in the {rank} (Last Stand mastery +{a}/+{h})",
	"skill_sweep": "{side} use “Break the Kettles”: sweep the enemy Vanguard",
	"skill_hero_hit": "{side} use “Break the Kettles”: 1 damage to the commander",
	"skill_heal": "{side} use “Three Articles”: restore 2 Health",
	"skill_buff": "{side} use “Three Articles”: {name} +1 Attack",
	"attack_hero": "{side} {name} strikes the commander for {n}",
	"attack_unit": "{side} {name} attacks {target} ({a} vs {d})",
}

## 把 {k, a} 渲染成中文（迁移期用于与 JS 版逐字比对）
static func zh(key: String, args: Dictionary) -> String:
	return _render_with(ZH, SIDE_ZH, key, args)

## 英文渲染（战报随界面语言切换）
static func en(key: String, args: Dictionary) -> String:
	return _render_with(EN, SIDE_EN, key, args)

static func _render_with(table: Dictionary, sides: Dictionary, key: String, args: Dictionary) -> String:
	var tpl: String = table.get(key, key)
	var out: String = tpl
	var a: Dictionary = args.duplicate()
	if a.has("side"):
		a["side"] = sides.get(a["side"], a["side"])
	# 列名与卡名在数据层换语言时已本地化，这里只负责套模板
	for k in a.keys():
		out = out.replace("{" + str(k) + "}", str(a[k]))
	return out

static func render(entry: Dictionary) -> String:
	var key := str(entry["k"])
	var args: Dictionary = entry["a"]
	if I18n.is_en():
		return en(key, args)
	return zh(key, args)
