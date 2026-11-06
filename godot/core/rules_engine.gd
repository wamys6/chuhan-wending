## 《楚汉·问鼎》规则引擎（GDScript 版，逐条移植自 js/engine.js）
##
## 设计取舍：
##   * 状态用 Dictionary，而不是自定义类 —— 迁移期需要与 JS 版逐字段比对，
##     Dictionary 的语义（引用传递）与 JS 对象一致，等价性测试才可信。
##   * 引擎是纯逻辑，不碰任何 Node/UI，因此可以在 --headless 下跑测试与模拟。
##   * 战报只产出 {k, a} 结构（见 LogText），不拼中文。
class_name RulesEngine
extends RefCounted

const RANKS: Array = ["front", "mid", "back"]

## 军师被动数值：必须与 js/engine.js 顶部的 ADV 对象逐项一致。
## 改动这里等于改规则 —— 要重跑 node tools/trace.js 再跑等价性测试。
const ADV_XIAOHE_HP := 5        ## 萧何：开战生命上限 +N
const ADV_XIAOHE_DRAW := 1      ## 萧何：起手多摸 N 张
const ADV_CHENPING_DRAW := 1    ## 陈平：起手多摸 N 张
const ADV_CHENPING_AOE := 1     ## 陈平：敌军已列阵时全体受 N 点伤害
const ADV_HANXIN_ATK := 1       ## 韩信：中军兵种攻击力 +N
const ADV_HANXIN_COUNT := 1     ## 韩信：每场战斗受益的兵种数上限（2 = 中军人人都吃，等于全局光环）
const ADV_FANKUAI_ATK := 0      ## 樊哙：本场第一个兵种 +N 攻（实测攻击力太贵，只留血）
const ADV_FANKUAI_HP := 1       ## 樊哙：本场第一个兵种 +N 血
const ADV_XIANGYING_CAP := 2    ## 夏侯婴：每场战斗死战额外发动的次数上限
const ADV_ZHOUBO_BUFF := 1      ## 周勃：每回合给最高攻兵种 +N/+N（慢热成长）
const ADV_ZHOUBO_CAP := 1       ## 周勃：每场战斗成长次数上限（2 次实测 31% 超带）
const ADV_LIYIJI_DOWN := 1      ## 郦食其：每轮削敌方最高攻兵种 -N 攻（控场）
const ADV_LIYIJI_CAP := 1       ## 郦食其：每场战斗削减次数上限（3 次 45%、2 次 30%）
const ADV_ZHANGLIANG_REFUND := 0 ## 张良：每回合首张计谋返还 N 军粮（实测过强已归零；文案由常量生成）

## 全局实例号：每局从 0 开始（与 JS 版一致，保证 uid 序列相同）
static var uid_seq: int = 0
## 外部注入的确定性随机源（迁移期比对用），为空则用 randf()
static var rng: Object = null

static func _r() -> float:
	if rng != null:
		return rng.next_float()
	return randf()


static func other(pid: String) -> String:
	return "p2" if pid == "p1" else "p1"


static func _side(pid: String) -> String:
	return pid


## 由卡牌定义造一张战场实例
static func new_instance(base_id: String) -> Dictionary:
	GameData.ensure_loaded()
	var c: Dictionary = GameData.cards[base_id]
	uid_seq += 1
	return {
		"uid": uid_seq,
		"baseId": base_id,
		"name": c["name"],
		"type": c["type"],
		"cost": int(c["cost"]),
		"col": c.get("col", null),
		"atk": int(c.get("atk", 0)),
		"hp": int(c.get("hp", 0)),
		"maxHp": int(c.get("hp", 0)),
		"taunt": bool(c.get("taunt", false)),
		"flank": bool(c.get("flank", false)),
		"ranged": bool(c.get("ranged", false)),
		"charge": bool(c.get("charge", false)),
		"deathrattle": c.get("deathrattle", null),
		"combo": c.get("combo", null),
		"glyph": c.get("glyph", "牌"),
		"desc": c.get("desc", ""),
		"effect": c.get("effect", null),
		"battlecry": c.get("battlecry", null),
		"canAttack": false,
	}


static func shuffle(arr: Array) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := int(floor(_r() * float(i + 1)))
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
	return arr


static func _log(state: Dictionary, key: String, args: Dictionary = {}) -> void:
	state["log"].append({"k": key, "a": args})
	state["logTotal"] = int(state.get("logTotal", 0)) + 1
	if state["log"].size() > 60:
		state["log"].pop_front()


## meta 可选：覆盖主将显示信息（战役里复用英雄技能、换个身份出场）
static func make_player(pid: String, hero_id: String, custom_deck = null, meta = null) -> Dictionary:
	GameData.ensure_loaded()
	var hero: Dictionary = GameData.heroes[hero_id]
	var ids: Array = []
	if custom_deck != null and custom_deck.size() > 0:
		ids = custom_deck.duplicate()
	else:
		ids = GameData.decks[hero["faction"]].duplicate()
	var deck_ids := shuffle(ids)

	var pname: String = hero["name"]
	var ptitle: String = hero["title"]
	var pglyph: String = hero["glyph"]
	var php: int = int(hero["hp"])
	var part = null
	if meta != null:
		if meta.has("name"):
			pname = str(meta["name"])
		if meta.has("title"):
			ptitle = str(meta["title"])
		if meta.has("glyph"):
			pglyph = str(meta["glyph"])
		if meta.has("hp"):
			php = int(meta["hp"])
		part = meta.get("art", null)

	var deck: Array = []
	for cid in deck_ids:
		deck.append(new_instance(str(cid)))

	return {
		"id": pid,
		"heroId": hero_id,
		"name": pname,
		"title": ptitle,
		"glyph": pglyph,
		"skill": hero["skill"],
		"art": part,
		"hp": php,
		"maxHp": php,
		"mana": 0,
		"maxMana": 0,
		"fatigue": 0,
		"skillUsed": false,
		"turnsTaken": 0,
		"cardsPlayed": 0,
		"spellPlayed": 0,
		"firstDeployDone": false,
		"deck": deck,
		"hand": [],
		"board": {"front": [], "mid": [], "back": []},
	}


## opts 可选，战役模式用：
##   opts.rules            关卡规则（handLimit / goal / goalTurns / playerStartMana /
##                         enemyStartMana / enemyOpeningUnits / enemyDeck / advisor ...）
##   opts.p1Meta / p2Meta  覆盖双方主将的显示信息
static func new_game(player_hero_id: String, ai_hero_id: String, first_pid: String = "p1",
		ai_level: String = "bijiang", custom_decks = null, opts = null) -> Dictionary:
	GameData.ensure_loaded()
	uid_seq = 0
	var decks_in: Dictionary = custom_decks.duplicate(true) if custom_decks != null else {}
	var o: Dictionary = opts.duplicate(true) if opts != null else {}
	var rules: Dictionary = o.get("rules", {})
	rules = rules.duplicate(true)

	# 关卡规则：敌方使用专门编排的牌组（每关打法不同）
	if rules.has("enemyDeck") and rules["enemyDeck"] is Array and rules["enemyDeck"].size() > 0:
		decks_in["p2"] = rules["enemyDeck"].duplicate()

	var state := {
		"turnNo": 0,
		"current": first_pid,
		"over": false,
		"winner": null,
		"log": [],
		"rules": rules,
		"levels": {"p1": "player", "p2": ai_level},
		"stats": {
			"p1": {"dmg": 0, "heroDmg": 0, "units": 0, "spells": 0, "heal": 0},
			"p2": {"dmg": 0, "heroDmg": 0, "units": 0, "spells": 0, "heal": 0},
		},
		"players": {
			"p1": make_player("p1", player_hero_id, decks_in.get("p1", null), o.get("p1Meta", null)),
			"p2": make_player("p2", ai_hero_id, decks_in.get("p2", null), o.get("p2Meta", null)),
		},
	}

	# 关卡规则：玩家起始血量（鸿门宴这类「命悬一线」的关卡用）
	if rules.has("playerHp") and int(rules["playerHp"]) != 0:
		state["players"]["p1"]["hp"] = int(rules["playerHp"])
		state["players"]["p1"]["maxHp"] = int(rules["playerHp"])

	# 军师「萧何·镇国抚民」：每场战斗开局生命上限 +ADV_XIAOHE_HP
	if str(rules.get("advisor", "")) == "xiaohe":
		state["players"]["p1"]["hp"] += ADV_XIAOHE_HP
		state["players"]["p1"]["maxHp"] += ADV_XIAOHE_HP
		_log(state, "advisor_xiaohe", {"n": ADV_XIAOHE_HP})

	# 行军积累的生命上限加成（事件「流民归附」等）
	if int(rules.get("playerHpBonus", 0)) != 0:
		state["players"]["p1"]["hp"] += int(rules["playerHpBonus"])
		state["players"]["p1"]["maxHp"] += int(rules["playerHpBonus"])
		_log(state, "rest_hp", {"n": int(rules["playerHpBonus"])})

	# 关卡规则：敌方开局已有部队在场
	if rules.has("enemyOpeningUnits") and rules["enemyOpeningUnits"] is Array:
		for spec in rules["enemyOpeningUnits"]:
			var u := new_instance(str(spec["baseId"]))
			u["canAttack"] = false
			var rank: String = str(spec.get("rank", "front"))
			state["players"]["p2"]["board"][rank].append(u)
			_log(state, "enemy_preplaced", {"name": u["name"], "rank": GameData.rank_name(rank)})

	# 军师「陈平·六出奇计」：开战先摸牌；敌军若已列阵，再全体受 ADV_CHENPING_AOE 点伤害
	if str(rules.get("advisor", "")) == "chenping":
		var hit := 0
		for r in RANKS:
			for u in state["players"]["p2"]["board"][r].duplicate():
				hit += 1
				damage_unit(state, "p2", u, ADV_CHENPING_AOE, r)
		if hit > 0:
			_log(state, "chenping_hit", {"n": hit, "d": ADV_CHENPING_AOE})
		else:
			_log(state, "chenping_none")

	# 起手张数：先手 3 张、后手 4 张；openingDraw 为负（心魔「起手少摸」）时
	# 直接从基础张数里扣——以前负数只被 extra_draw 的循环吞掉，等于没效果
	var neg_draw := mini(0, int(rules.get("openingDraw", 0)))
	var first_draw := 3 + (neg_draw if first_pid == "p1" else 0)
	var second := other(first_pid)
	var second_draw := 4 + (neg_draw if second == "p1" else 0)
	for i in maxi(0, first_draw):
		draw_card(state, first_pid, true)
	for i in maxi(0, second_draw):
		draw_card(state, second, true)
	state["players"][second]["hand"].append(new_instance("s_xianji"))

	# 起手额外摸牌：关卡/事件规则（樵夫指路）+ 军师（萧何/陈平各按常量取）
	var adv_draw := 0
	if str(rules.get("advisor", "")) == "xiaohe":
		adv_draw += ADV_XIAOHE_DRAW
	if str(rules.get("advisor", "")) == "chenping":
		adv_draw += ADV_CHENPING_DRAW
	var bonus_draw := maxi(0, int(rules.get("openingDraw", 0)))
	var extra_draw := bonus_draw + adv_draw
	if extra_draw > 0:
		for i in extra_draw:
			draw_card(state, "p1", true)
		if bonus_draw != 0:
			_log(state, "opening_draw", {"n": bonus_draw})
		if adv_draw > 0:
			_log(state, "adv_draw", {"n": adv_draw})

	_log(state, "first", {"side": first_pid})

	# 进入开局换牌阶段
	state["phase"] = "mulligan"
	state["mulliganDone"] = {"p1": false, "p2": false}
	return state


# ---------- 开局换牌（mulligan） ----------

## 把选中的起手牌洗回牌库并抽回等量新牌；先机虎符不可换
static func do_mulligan(state: Dictionary, pid: String, uids: Array) -> Dictionary:
	if state.is_empty() or state.get("phase", "") != "mulligan" or state["mulliganDone"][pid]:
		return {"ok": false}
	var p: Dictionary = state["players"][pid]
	var picked := {}
	for u in uids:
		picked[u] = true
	var keep: Array = []
	var replace: Array = []
	for c in p["hand"]:
		if picked.has(c["uid"]) and c["baseId"] != "s_xianji":
			replace.append(c)
		else:
			keep.append(c)
	for c in replace:
		p["deck"].append(c)
	p["hand"] = keep
	shuffle(p["deck"])
	for i in replace.size():
		draw_card(state, pid, true)
	state["mulliganDone"][pid] = true
	if replace.size() > 0:
		_log(state, "mulligan", {"side": pid, "n": replace.size()})
	return {"ok": true, "swapped": replace.size()}


## 双方换牌完毕，正式开始第一回合
static func begin_game(state: Dictionary) -> void:
	if state.is_empty() or state.get("phase", "") != "mulligan":
		return
	state["phase"] = "play"
	start_turn(state, str(state["current"]))


# ---------- 回合 ----------

static func start_turn(state: Dictionary, pid: String) -> void:
	if state["over"]:
		return
	var p: Dictionary = state["players"][pid]
	var rules: Dictionary = state.get("rules", {})
	state["turnNo"] = int(state["turnNo"]) + 1
	p["turnsTaken"] = int(p["turnsTaken"]) + 1
	p["maxMana"] = mini(GameData.max_mana(), int(p["maxMana"]) + 1)
	p["mana"] = int(p["maxMana"])

	# 关卡规则：玩家/敌方首回合额外军粮
	if int(rules.get("playerStartMana", 0)) != 0 and pid == "p1" and int(p["turnsTaken"]) == 1:
		p["mana"] = int(p["mana"]) + int(rules["playerStartMana"])
	if int(rules.get("enemyStartMana", 0)) != 0 and pid == "p2" and int(p["turnsTaken"]) == 1:
		p["mana"] = int(p["mana"]) + int(rules["enemyStartMana"])

	p["skillUsed"] = false
	p["cardsPlayed"] = 0
	p["spellPlayed"] = 0
	for r in RANKS:
		for u in p["board"][r]:
			u["canAttack"] = int(u["atk"]) > 0

	# 军师「周勃·安刘定倾」：每个我方回合开始，最高攻兵种 +N/+N（每场至多 CAP 次）
	# 慢热成长：得先把部队站住，收益在第 3 回合后才显出来——与韩信（登场即 +1）错位
	if pid == "p1" and str(rules.get("advisor", "")) == "zhoubo" \
			and int(p.get("zbBuffs", 0)) < ADV_ZHOUBO_CAP:
		var best = null
		for r in RANKS:
			for u in p["board"][r]:
				if best == null or int(u["atk"]) > int(best["atk"]):
					best = u
		if best != null:
			best["atk"] = int(best["atk"]) + ADV_ZHOUBO_BUFF
			best["hp"] = int(best["hp"]) + ADV_ZHOUBO_BUFF
			best["maxHp"] = int(best["maxHp"]) + ADV_ZHOUBO_BUFF
			best["canAttack"] = int(best["atk"]) > 0
			p["zbBuffs"] = int(p.get("zbBuffs", 0)) + 1
			_log(state, "adv_zhoubo", {"name": best["name"],
				"a": ADV_ZHOUBO_BUFF, "h": ADV_ZHOUBO_BUFF})

	# 军师「郦食其·舌下齐城」：每个敌方回合开始，敌方最高攻兵种 -N 攻（每场至多 CAP 次）
	# 只削一个、且削不到负数：控的是「对方的大哥」，不是全军
	if pid == "p2" and str(rules.get("advisor", "")) == "liyiji" \
			and int(p.get("lyCuts", 0)) < ADV_LIYIJI_CAP:
		var ly_best = null
		for r in RANKS:
			for u in p["board"][r]:
				if ly_best == null or int(u["atk"]) > int(ly_best["atk"]):
					ly_best = u
		if ly_best != null and int(ly_best["atk"]) > 0:
			ly_best["atk"] = maxi(0, int(ly_best["atk"]) - ADV_LIYIJI_DOWN)
			ly_best["canAttack"] = int(ly_best["atk"]) > 0
			p["lyCuts"] = int(p.get("lyCuts", 0)) + 1
			_log(state, "adv_liyiji", {"name": ly_best["name"], "d": ADV_LIYIJI_DOWN})

	_log(state, "turn", {"n": int(state["turnNo"]), "side": pid,
		"m": int(p["mana"]), "mm": int(p["maxMana"])})
	draw_card(state, pid)


static func end_turn(state: Dictionary) -> void:
	if state["over"]:
		return
	var rules: Dictionary = state.get("rules", {})
	# 关卡规则：存活型目标——玩家数满回合数即获胜
	if str(rules.get("goal", "")) == "survive" and str(state["current"]) == "p1":
		var me: Dictionary = state["players"]["p1"]
		if int(me["turnsTaken"]) >= int(rules.get("goalTurns", 0)):
			state["over"] = true
			state["winner"] = "p1"
			_log(state, "survive_win", {"n": int(rules["goalTurns"])})
			return
	state["current"] = other(str(state["current"]))
	start_turn(state, str(state["current"]))


# ---------- 抽牌与疲劳 ----------

## ignore_limit：起手抽牌阶段用，不受关卡手牌上限限制
static func draw_card(state: Dictionary, pid: String, ignore_limit: bool = false) -> void:
	if state["over"]:
		return
	var p: Dictionary = state["players"][pid]
	if p["deck"].size() == 0:
		p["fatigue"] = int(p["fatigue"]) + 1
		_log(state, "fatigue", {"side": pid, "n": int(p["fatigue"])})
		damage_hero(state, pid, int(p["fatigue"]))
		return
	var card: Dictionary = p["deck"].pop_front()
	var hand_limit := GameData.hand_limit()
	if not ignore_limit:
		var r: Dictionary = state.get("rules", {})
		if int(r.get("handLimit", 0)) != 0:
			hand_limit = int(r["handLimit"])
	if p["hand"].size() >= hand_limit:
		_log(state, "hand_full", {"side": pid, "name": card["name"]})
		return
	p["hand"].append(card)


# ---------- 目标合法性 ----------

## 可达规则：默认只能攻击敌方最靠前的有兵之列；马（迂回）可打前锋/中军；
## 炮（远程）可打任意列；敌方全军覆没时才能攻击敌方英雄。
## 可达目标中若有守御单位，必须先攻击守御。
static func get_attack_targets(state: Dictionary, pid: String, unit: Dictionary) -> Dictionary:
	var e: Dictionary = state["players"][other(pid)]
	var occupied: Array = []
	for r in RANKS:
		if e["board"][r].size() > 0:
			occupied.append(r)
	if occupied.is_empty():
		return {"heroOk": true, "units": [], "mustTaunt": false}

	var ranks: Array = []
	if unit["ranged"]:
		ranks = occupied
	elif unit["flank"]:
		for r in occupied:
			if r == "front" or r == "mid":
				ranks.append(r)
	else:
		ranks = [occupied[0]]

	var units: Array = []
	for r in ranks:
		for u in e["board"][r]:
			units.append({"unit": u, "rank": r})

	var taunts: Array = []
	for x in units:
		if x["unit"]["taunt"]:
			taunts.append(x)
	if taunts.size() > 0:
		units = taunts
	return {"heroOk": false, "units": units, "mustTaunt": taunts.size() > 0}


# ---------- 伤害 ----------

static func remove_dead(state: Dictionary, pid: String, rank: String, unit: Dictionary) -> void:
	var row: Array = state["players"][pid]["board"][rank]
	for i in row.size():
		if row[i]["uid"] == unit["uid"]:
			row.remove_at(i)
			_log(state, "death", {"side": pid, "name": unit["name"]})
			return


static func damage_unit(state: Dictionary, owner_pid: String, unit: Dictionary, amount: int, rank: String) -> void:
	if amount <= 0 or state["over"]:
		return
	var real := mini(amount, int(unit["hp"]))     # 溢出伤害不计入战绩
	state["stats"][other(owner_pid)]["dmg"] += real
	unit["hp"] = int(unit["hp"]) - amount
	if int(unit["hp"]) <= 0:
		remove_dead(state, owner_pid, rank, unit)
		# 死战：阵亡时触发一次效果（先移除，避免效果再次处理自己）
		if unit["deathrattle"] != null:
			_log(state, "deathrattle", {"side": owner_pid, "name": unit["name"]})
			resolve_effect(state, owner_pid, unit["deathrattle"], null, {"lastStand": true})
			# 夏侯婴：死战额外发动一次，每场战斗有次数上限（不限次实测 +29pp，太强）
			var owner: Dictionary = state["players"][owner_pid]
			if owner_pid == "p1" and str(state["rules"].get("advisor", "")) == "xiangying" \
					and int(owner.get("xyDoubles", 0)) < ADV_XIANGYING_CAP + int(owner.get("xyCapBonus", 0)):
				owner["xyDoubles"] = int(owner.get("xyDoubles", 0)) + 1
				_log(state, "xy_double", {"name": unit["name"]})
				resolve_effect(state, owner_pid, unit["deathrattle"], null, {"lastStand": true})


static func damage_hero(state: Dictionary, pid: String, amount: int) -> void:
	if amount <= 0 or state["over"]:
		return
	var p: Dictionary = state["players"][pid]
	var real := mini(amount, int(p["hp"]))
	state["stats"][other(pid)]["dmg"] += real
	state["stats"][other(pid)]["heroDmg"] += real
	p["hp"] = int(p["hp"]) - amount
	if int(p["hp"]) <= 0:
		p["hp"] = 0
		state["over"] = true
		state["winner"] = other(pid)
		_log(state, "hero_down", {"side": pid})


# ---------- 出牌 ----------

static func can_play(state: Dictionary, pid: String, card: Dictionary) -> bool:
	var p: Dictionary = state["players"][pid]
	if int(card["cost"]) > int(p["mana"]):
		return false
	if card["type"] == "piece" and p["board"][card["col"]].size() >= GameData.column_limit():
		return false
	return true


static func play_card(state: Dictionary, pid: String, uid: int) -> Dictionary:
	var p: Dictionary = state["players"][pid]
	var idx := -1
	var card: Dictionary = {}
	for i in p["hand"].size():
		if int(p["hand"][i]["uid"]) == uid:
			idx = i
			card = p["hand"][i]
			break
	if card.is_empty():
		return {"ok": false, "reason": "手里没有这张牌"}
	if int(card["cost"]) > int(p["mana"]):
		return {"ok": false, "reason": "军粮不足"}
	if card["type"] == "piece" and p["board"][card["col"]].size() >= GameData.column_limit():
		return {"ok": false, "reason": "%s列已满（每列最多 %d 员）"
			% [GameData.rank_name(str(card["col"])), GameData.column_limit()]}

	# 连击：本回合此前已经出过牌才触发
	var combo_active := int(p["cardsPlayed"]) > 0
	p["mana"] = int(p["mana"]) - int(card["cost"])
	p["hand"].remove_at(idx)
	p["cardsPlayed"] = int(p["cardsPlayed"]) + 1

	var rules: Dictionary = state.get("rules", {})
	if card["type"] == "piece":
		# 军师被动：韩信（前锋 +ADV_HANXIN_ATK 攻）/ 樊哙（本场第一个出场的兵种 +N/+N）
		if pid == "p1":
			var adv_atk := 0
			if str(rules.get("advisor", "")) == "hanxin" and str(card["col"]) == "mid" \
					and int(p.get("hxCount", 0)) < ADV_HANXIN_COUNT:
				adv_atk += ADV_HANXIN_ATK
				p["hxCount"] = int(p.get("hxCount", 0)) + 1
			if str(rules.get("advisor", "")) == "fankuai" and not bool(p["firstDeployDone"]):
				adv_atk += ADV_FANKUAI_ATK
				card["hp"] = int(card["hp"]) + ADV_FANKUAI_HP
				card["maxHp"] = int(card["maxHp"]) + ADV_FANKUAI_HP
				p["firstDeployDone"] = true
				_log(state, "adv_fankuai", {"name": card["name"],
					"a": ADV_FANKUAI_ATK, "h": ADV_FANKUAI_HP})
			if adv_atk != 0:
				card["atk"] = int(card["atk"]) + adv_atk
				if str(rules.get("advisor", "")) == "hanxin":
					_log(state, "adv_hanxin", {"name": card["name"], "a": ADV_HANXIN_ATK})

		# 冲锋：登场当回合即可攻击
		card["canAttack"] = bool(card["charge"]) and int(card["atk"]) > 0
		p["board"][card["col"]].append(card)
		state["stats"][pid]["units"] += 1
		_log(state, "deploy", {"side": pid, "name": card["name"], "rank": GameData.rank_name(str(card["col"]))})
		if card["battlecry"] != null:
			resolve_battlecry(state, pid, card["battlecry"])
	else:
		state["stats"][pid]["spells"] += 1
		_log(state, "spell", {"side": pid, "name": card["name"]})
		resolve_effect(state, pid, card["effect"], card)
		# 军师被动：张良——每回合第一张计谋牌额外抽一张（返还力实测过强，已归零）
		if pid == "p1" and str(rules.get("advisor", "")) == "zhangliang" and int(p["spellPlayed"]) == 0:
			p["spellPlayed"] = 1
			_log(state, "adv_zhangliang")
			draw_card(state, pid)
			if ADV_ZHANGLIANG_REFUND > 0:
				p["mana"] += ADV_ZHANGLIANG_REFUND

	if combo_active and card["combo"] != null:
		_log(state, "combo", {"side": pid, "name": card["name"]})
		resolve_effect(state, pid, card["combo"], card)
	return {"ok": true}


static func resolve_battlecry(state: Dictionary, pid: String, bc: Dictionary) -> void:
	var p: Dictionary = state["players"][pid]
	if int(bc.get("tokens", 0)) != 0:
		var j := 0
		for k in int(bc["tokens"]):
			if p["board"]["front"].size() >= GameData.column_limit():
				break
			var t := new_instance("n_bing1")
			t["name"] = "兵·新卒（韩信所点）"
			t["canAttack"] = false
			p["board"]["front"].append(t)
			j += 1
		_log(state, "tokens", {"side": pid, "n": j})
	# tokens 是点兵专属；其余字段一律交给 resolve_effect —— 战吼与亡语共用同一套效果词汇，
	# 否则每加一种战吼都要在引擎里复制一遍分支（与 js/engine.js 一致）
	var rest: Dictionary = bc.duplicate()
	rest.erase("tokens")
	if not rest.is_empty():
		resolve_effect(state, pid, rest)


## 统一的卡牌效果执行器。self 是触发效果的牌本身（连击里的自我强化要用）
## ctx：调用方的上下文。目前只有 lastStand——死战触发的效果才吃「死战专精」的援军加成，
## 战吼召唤（征发之类）不能吃，否则等于全体加强。
static func resolve_effect(state: Dictionary, pid: String, effect, self_card = null, ctx: Dictionary = {}) -> void:
	if effect == null:
		return
	var p: Dictionary = state["players"][pid]
	var e: Dictionary = state["players"][other(pid)]

	if int(effect.get("draw", 0)) != 0:
		for i in int(effect["draw"]):
			draw_card(state, pid)
	if int(effect.get("mana", 0)) != 0:
		p["mana"] = int(p["mana"]) + int(effect["mana"])

	if effect.has("dmgCol"):
		var col: String = str(effect["dmgCol"])
		for u in e["board"][col].duplicate():
			damage_unit(state, other(pid), u, int(effect.get("amount", 0)), col)

	if effect.has("dmgLowest"):
		var lowest = null
		for r in RANKS:
			for u in e["board"][r]:
				if lowest == null or int(u["hp"]) < int(lowest["unit"]["hp"]):
					lowest = {"unit": u, "rank": r}
		if lowest != null:
			damage_unit(state, other(pid), lowest["unit"], int(effect["dmgLowest"]), lowest["rank"])

	# 反间：狙击敌方攻击力最高的兵种
	if effect.has("dmgHighest"):
		var highest = null
		for r in RANKS:
			for u in e["board"][r]:
				if highest == null or int(u["atk"]) > int(highest["unit"]["atk"]):
					highest = {"unit": u, "rank": r}
		if highest != null:
			damage_unit(state, other(pid), highest["unit"], int(effect["dmgHighest"]), highest["rank"])

	# 军师主动技（P6）：给我方/敌方「攻击力最高」的兵种加/削。
	# 不走 damage_unit，所以没有溢出伤害与亡语结算；攻击力削到 0 时同步收回攻击权
	if effect.has("buffHighest"):
		var bh = null
		for r in RANKS:
			for u in p["board"][r]:
				if bh == null or int(u["atk"]) > int(bh["unit"]["atk"]):
					bh = {"unit": u, "rank": r}
		if bh != null:
			var ba := int(effect["buffHighest"].get("atk", 0))
			var bhp := int(effect["buffHighest"].get("hp", 0))
			bh["unit"]["atk"] = int(bh["unit"]["atk"]) + ba
			bh["unit"]["hp"] = int(bh["unit"]["hp"]) + bhp
			bh["unit"]["maxHp"] = int(bh["unit"]["maxHp"]) + bhp
			bh["unit"]["canAttack"] = int(bh["unit"]["atk"]) > 0
			_log(state, "buff_highest", {"name": str(bh["unit"]["name"]), "atk": ba, "hp": bhp})

	if effect.has("debuffHighest"):
		var dh = null
		for r in RANKS:
			for u in e["board"][r]:
				if dh == null or int(u["atk"]) > int(dh["unit"]["atk"]):
					dh = {"unit": u, "rank": r}
		if dh != null and int(dh["unit"]["atk"]) > 0:
			var da := int(effect["debuffHighest"].get("atk", 0))
			dh["unit"]["atk"] = maxi(0, int(dh["unit"]["atk"]) - da)
			dh["unit"]["canAttack"] = int(dh["unit"]["atk"]) > 0
			_log(state, "debuff_highest", {"name": str(dh["unit"]["name"]), "n": da})

	# 直取主将 / 恢复主将
	if int(effect.get("dmgHero", 0)) != 0:
		_log(state, "spell_hero_dmg", {"side": pid, "n": int(effect["dmgHero"])})
		damage_hero(state, other(pid), int(effect["dmgHero"]))

	if int(effect.get("healHero", 0)) != 0:
		var before := int(p["hp"])
		p["hp"] = mini(int(p["maxHp"]), int(p["hp"]) + int(effect["healHero"]))
		if int(p["hp"]) > before:
			state["stats"][pid]["heal"] += int(p["hp"]) - before
			_log(state, "heal_hero", {"side": pid, "n": int(p["hp"]) - before})

	# 全场伤害 / 全场增减攻
	if int(effect.get("dmgAll", 0)) != 0:
		for r in RANKS:
			for u in e["board"][r].duplicate():
				damage_unit(state, other(pid), u, int(effect["dmgAll"]), r)

	if effect.has("buffCol"):
		var bcol: String = str(effect["buffCol"])
		for u in p["board"][bcol]:
			u["atk"] = int(u["atk"]) + int(effect.get("atk", 0))

	if int(effect.get("buffAll", 0)) != 0:
		for r in RANKS:
			for u in p["board"][r]:
				u["atk"] = int(u["atk"]) + int(effect["buffAll"])

	# 全体加血（周勃·整军）：上限与当前血量一起加
	if int(effect.get("buffAllHp", 0)) != 0:
		var bhp := int(effect["buffAllHp"])
		for r in RANKS:
			for u in p["board"][r]:
				u["hp"] = int(u["hp"]) + bhp
				u["maxHp"] = int(u["maxHp"]) + bhp
		_log(state, "buff_all_hp", {"n": bhp})

	if int(effect.get("debuffAll", 0)) != 0:
		for r in RANKS:
			for u in e["board"][r]:
				u["atk"] = maxi(0, int(u["atk"]) - int(effect["debuffAll"]))

	# 召唤援军（列满则止）
	if effect.has("summon"):
		var s: Dictionary = effect["summon"]
		var rank: String = str(s.get("rank", "front"))
		var n := int(s.get("count", 1))
		if not GameData.has_card(str(s.get("baseId", ""))):
			n = 0
		# 死战专精：牌组里死战牌够多时，死战唤来的援军更硬（见 campaign.gd last_stand_tier）
		var ls_on := bool(ctx.get("lastStand", false)) and pid == "p1"
		var ba := int(state["rules"].get("lastStandAtk", 0)) if ls_on else 0
		var bh := int(state["rules"].get("lastStandHp", 0)) if ls_on else 0
		var bonus := ba if ba > 0 or bh > 0 else 0
		for k in n:
			if p["board"][rank].size() >= GameData.column_limit():
				break
			var t := new_instance(str(s["baseId"]))
			t["canAttack"] = false
			if ba > 0 or bh > 0:
				t["atk"] = int(t["atk"]) + ba
				t["hp"] = int(t["hp"]) + bh
				t["maxHp"] = int(t["maxHp"]) + bh
			p["board"][rank].append(t)
		if bonus > 0:
			_log(state, "summon_bonus",
				{"side": pid, "rank": GameData.rank_name(rank), "a": ba, "h": bh})
		else:
			_log(state, "summon", {"side": pid, "rank": GameData.rank_name(rank)})

	# 只作用于牌本身（连击自我强化）
	if int(effect.get("selfAtk", 0)) != 0 and self_card != null:
		self_card["atk"] = int(self_card["atk"]) + int(effect["selfAtk"])


# ---------- 军师主动技（每场战斗 1 次，P6） ----------
# 定义由战役侧通过 rules["advisorActive"] 注入，引擎不反向依赖 campaign.gd。
# 只对 p1 生效（军师是玩家的），每场一次，用 p["advUsed"] 记。

static func advisor_active(state: Dictionary) -> Dictionary:
	var rules: Dictionary = state.get("rules", {})
	if str(rules.get("advisor", "")) == "":
		return {}
	var a = rules.get("advisorActive", null)
	if a == null or not (a is Dictionary) or not a.has("fx"):
		return {}
	return a


static func can_advisor_active(state: Dictionary, pid: String) -> bool:
	if state.is_empty() or bool(state["over"]) or pid != "p1":
		return false
	var a := advisor_active(state)
	if a.is_empty():
		return false
	var p: Dictionary = state["players"]["p1"]
	if bool(p.get("advUsed", false)):
		return false
	return int(p["mana"]) >= int(a.get("cost", 0))


static func use_advisor_active(state: Dictionary, pid: String) -> Dictionary:
	if not can_advisor_active(state, pid):
		return {"ok": false, "reason": "军师技现在用不了"}
	var a := advisor_active(state)
	var p: Dictionary = state["players"]["p1"]
	p["mana"] = int(p["mana"]) - int(a.get("cost", 0))
	p["advUsed"] = true
	_log(state, "adv_active", {"name": str(a.get("name", "献策"))})
	var fx: Dictionary = (a["fx"] as Dictionary).duplicate()
	# xyCap 不是通用效果词，是夏侯婴专属：本场死战额外发动的次数上限 +N
	var xy := int(fx.get("xyCap", 0))
	fx.erase("xyCap")
	if not fx.is_empty():
		resolve_effect(state, "p1", fx)
	if xy != 0:
		p["xyCapBonus"] = int(p.get("xyCapBonus", 0)) + xy
	return {"ok": true}


# ---------- 英雄技能 ----------

static func can_skill(state: Dictionary, pid: String) -> bool:
	var p: Dictionary = state["players"][pid]
	if bool(p["skillUsed"]) or int(p["mana"]) < int(p["skill"]["cost"]) or state["over"]:
		return false
	if str(p["heroId"]) == "xiangyu":
		return true
	if str(p["heroId"]) == "liubang":
		if int(p["hp"]) < int(p["maxHp"]):
			return true
		for r in RANKS:
			if p["board"][r].size() > 0:
				return true
		return false
	return false


static func use_skill(state: Dictionary, pid: String) -> Dictionary:
	if not can_skill(state, pid):
		return {"ok": false, "reason": "技能现在用不了"}
	var p: Dictionary = state["players"][pid]
	var e: Dictionary = state["players"][other(pid)]
	p["mana"] = int(p["mana"]) - int(p["skill"]["cost"])
	p["skillUsed"] = true

	if str(p["heroId"]) == "xiangyu":
		if e["board"]["front"].size() > 0:
			for u in e["board"]["front"].duplicate():
				damage_unit(state, other(pid), u, 1, "front")
			_log(state, "skill_sweep", {"side": pid})
		else:
			_log(state, "skill_hero_hit", {"side": pid})
			damage_hero(state, other(pid), 1)
	else:
		if int(p["hp"]) < int(p["maxHp"]):
			var hb := int(p["hp"])
			p["hp"] = mini(int(p["maxHp"]), int(p["hp"]) + 2)
			state["stats"][pid]["heal"] += int(p["hp"]) - hb
			_log(state, "skill_heal", {"side": pid})
		else:
			var cands: Array = []
			for r in RANKS:
				for u in p["board"][r]:
					cands.append(u)
			if cands.size() > 0:
				var u2: Dictionary = cands[int(floor(_r() * float(cands.size())))]
				u2["atk"] = int(u2["atk"]) + 1
				_log(state, "skill_buff", {"side": pid, "name": u2["name"]})
	return {"ok": true}


# ---------- 攻击 ----------

static func attack(state: Dictionary, pid: String, attacker_uid: int, target: Dictionary) -> Dictionary:
	var p: Dictionary = state["players"][pid]
	var attacker = null
	var arank := ""
	for r in RANKS:
		for u in p["board"][r]:
			if int(u["uid"]) == attacker_uid:
				attacker = u
				arank = r
	if attacker == null:
		return {"ok": false, "reason": "找不到攻击单位"}
	if not bool(attacker["canAttack"]) or int(attacker["atk"]) <= 0:
		return {"ok": false, "reason": "该单位本回合不能攻击"}

	var info := get_attack_targets(state, pid, attacker)
	if str(target.get("kind", "")) == "hero":
		if not bool(info["heroOk"]):
			return {"ok": false, "reason": "敌方还有兵种挡路"}
		attacker["canAttack"] = false
		_log(state, "attack_hero", {"side": pid, "name": attacker["name"], "n": int(attacker["atk"])})
		damage_hero(state, other(pid), int(attacker["atk"]))
		return {"ok": true}

	var t = null
	var trank := ""
	for x in info["units"]:
		if int(x["unit"]["uid"]) == int(target.get("uid", -1)):
			t = x["unit"]
			trank = str(x["rank"])
			break
	if t == null:
		return {"ok": false, "reason": "不能攻击这个目标"}

	attacker["canAttack"] = false
	_log(state, "attack_unit", {"side": pid, "name": attacker["name"], "target": t["name"],
		"a": int(attacker["atk"]), "d": int(t["atk"])})
	damage_unit(state, other(pid), t, int(attacker["atk"]), trank)
	damage_unit(state, pid, attacker, int(t["atk"]), arank)
	return {"ok": true}


# ---------- 状态指纹（测试与存档校验用） ----------

## 把一局状态压成稳定的字符串，用于跨语言等价性比对
static func fingerprint(state: Dictionary) -> String:
	var parts: Array = []
	parts.append("t%d:%s:%s:%s" % [int(state["turnNo"]), str(state["current"]),
		"1" if state["over"] else "0", "-" if state["winner"] == null else str(state["winner"])])
	for pid in ["p1", "p2"]:
		var p: Dictionary = state["players"][pid]
		var s := "%s hp%d/%d m%d/%d f%d sk%d av%d h[%s] d%d b{" % [
			pid, int(p["hp"]), int(p["maxHp"]), int(p["mana"]), int(p["maxMana"]),
			int(p["fatigue"]), 1 if p["skillUsed"] else 0, 1 if p.get("advUsed", false) else 0,
			_hand_sig(p["hand"]), p["deck"].size()]
		for r in RANKS:
			s += r + ":" + _row_sig(p["board"][r]) + ";"
		s += "}"
		parts.append(s)
	return " | ".join(parts)


static func _row_sig(row: Array) -> String:
	var out: Array = []
	for u in row:
		out.append("%s/%d/%d/%d" % [u["baseId"], int(u["atk"]), int(u["hp"]), 1 if u["canAttack"] else 0])
	return ",".join(out)


static func _hand_sig(hand: Array) -> String:
	var out: Array = []
	for c in hand:
		out.append(str(c["baseId"]))
	return ",".join(out)
