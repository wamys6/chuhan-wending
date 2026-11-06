## AI 决策（移植自 js/ai.js：贪心核心 + 三档难度）
## 见习 jianxi：50% 概率故意选次优动作；裨将 bijiang：标准贪心；
## 名将 mingjiang：贪心 + 更重视斩杀与保护性交换。
class_name Ai
extends RefCounted

static func opp(pid: String) -> String:
	return RulesEngine.other(pid)

static func level_of(state: Dictionary, pid: String) -> String:
	return str(state.get("levels", {}).get(pid, "bijiang"))

## 出牌评分
static func play_score(state: Dictionary, pid: String, card: Dictionary) -> float:
	var p: Dictionary = state["players"][pid]
	var e: Dictionary = state["players"][opp(pid)]

	if card["type"] == "piece":
		var s: float = (int(card["atk"]) + int(card["hp"])) / float(maxi(1, int(card["cost"]))) * 2.0 + 1.0
		if str(card["col"]) == "front" and p["board"]["front"].is_empty():
			s += 0.8                                   # 前锋不能空
		if str(card["col"]) == "back" and p["board"]["back"].is_empty() and e["board"]["front"].size() > 0:
			s += 0.5
		if card["taunt"] and p["board"]["mid"].is_empty():
			s += 0.6
		if card["charge"]:
			s += int(card["atk"]) * 0.35 + 0.5         # 冲锋：当回合就能换血
		if card["deathrattle"] != null:
			s += 0.7                                   # 死战：死了还有收益
		if card["combo"] != null and int(p["cardsPlayed"]) > 0:
			s += 0.9
		return s

	var ef: Dictionary = card["effect"] if card["effect"] != null else {}
	if int(ef.get("draw", 0)) != 0:
		return 3.0 + int(ef["draw"])
	if int(ef.get("mana", 0)) != 0:
		var followup := false
		for c in p["hand"]:
			if int(c["uid"]) != int(card["uid"]) and c["type"] == "piece" \
					and int(c["cost"]) == int(p["mana"]) + 1:
				followup = true
				break
		return 7.0 if followup else 0.1
	if int(ef.get("dmgLowest", 0)) != 0:
		for r in RulesEngine.RANKS:
			if e["board"][r].size() > 0:
				return 2.5 + int(ef["dmgLowest"]) * 0.3
		return 0.0
	if ef.has("dmgCol"):
		var col: String = str(ef["dmgCol"])
		var n: int = e["board"][col].size()
		return n * 1.4 + (0.8 if n > 0 else 0.0)
	if ef.has("buffCol"):
		var bcol: String = str(ef["buffCol"])
		return p["board"][bcol].size() * 1.5 + (0.5 if e["board"]["front"].size() > 0 else 0.0)

	# ---- 扩充卡池新增的效果 ----
	if int(ef.get("dmgHighest", 0)) != 0:
		var has_unit := false
		for r in RulesEngine.RANKS:
			if e["board"][r].size() > 0:
				has_unit = true
		return (2.6 if has_unit else 0.0) + (int(ef["draw"]) * 1.8 if ef.has("draw") else 0.0)
	if int(ef.get("healHero", 0)) != 0:
		var missing := maxi(0, int(p["maxHp"]) - int(p["hp"]))
		return mini(missing, int(ef["healHero"])) * 1.3 + (int(ef["draw"]) * 1.9 if ef.has("draw") else 0.0)
	if int(ef.get("dmgAll", 0)) != 0:
		var n2 := 0
		for r in RulesEngine.RANKS:
			n2 += e["board"][r].size()
		return n2 * (int(ef["dmgAll"]) * 0.7 + 0.5)
	if int(ef.get("debuffAll", 0)) != 0:
		var m := 0
		for r in RulesEngine.RANKS:
			for u in e["board"][r]:
				if int(u["atk"]) > 0:
					m += 1
		return m * (int(ef["debuffAll"]) * 0.9 + 0.5)
	if ef.has("summon"):
		var sm: Dictionary = ef["summon"]
		var rank: String = str(sm.get("rank", "front"))
		var room: int = maxi(0, 3 - p["board"][rank].size())
		return mini(room, int(sm.get("count", 1))) * 2.2
	if int(ef.get("buffAll", 0)) != 0:
		var own := 0
		for r in RulesEngine.RANKS:
			for u in p["board"][r]:
				if int(u["atk"]) > 0:
					own += 1
		return own * int(ef["buffAll"]) * 0.9
	return 0.0

static func skill_useful(state: Dictionary, pid: String) -> bool:
	var p: Dictionary = state["players"][pid]
	if bool(p["skillUsed"]) or int(p["mana"]) < int(p["skill"]["cost"]):
		return false
	if str(p["heroId"]) == "xiangyu":
		return true                                    # 扫前锋或直击主将总有目标
	if str(p["heroId"]) == "liubang":
		if int(p["hp"]) <= int(p["maxHp"]) - 2:
			return true
		if int(p["hp"]) == int(p["maxHp"]):
			for r in RulesEngine.RANKS:
				if p["board"][r].size() > 0:
					return true
		return false
	return false

## 攻击评分
static func attack_score(attacker: Dictionary, target: Dictionary, level: String) -> float:
	var t: Dictionary = target["unit"]
	var kills: bool = int(attacker["atk"]) >= int(t["hp"])
	var dies: bool = int(t["atk"]) >= int(attacker["hp"])
	# 名将不做「没换到人还搭上自己」的送死攻击
	if level == "mingjiang" and dies and not kills:
		return -100.0
	var s := 0.0
	if kills:
		s += 8.0 + int(t["atk"])
	if not dies:
		s += 4.0
	else:
		s -= 2.0
	if bool(t["taunt"]) and not kills:
		s += 2.0
	s += int(t["atk"]) * 0.5 - int(t["hp"]) * 0.1
	if level == "mingjiang" and not dies and kills:
		s += 1.5                                       # 名将偏爱安全的好交换
	return s

## 斩杀计算：场上可攻击单位总攻（+项羽技能直伤）是否够打死敌方主将
static func lethal_plan(state: Dictionary, pid: String) -> Variant:
	var p: Dictionary = state["players"][pid]
	var e: Dictionary = state["players"][opp(pid)]
	var total := 0
	var first = null
	for r in RulesEngine.RANKS:
		for u in p["board"][r]:
			if not bool(u["canAttack"]) or int(u["atk"]) <= 0:
				continue
			var info := RulesEngine.get_attack_targets(state, pid, u)
			if not bool(info["heroOk"]):
				continue
			total += int(u["atk"])
			if first == null:
				first = u
	if first == null:
		return null
	var skill_dmg := 0
	var skill_ready: bool = (not bool(p["skillUsed"])) and int(p["mana"]) >= int(p["skill"]["cost"])
	if skill_ready and str(p["heroId"]) == "xiangyu" and e["board"]["front"].is_empty():
		skill_dmg = 1
	if total + skill_dmg < int(e["hp"]):
		return null
	if total < int(e["hp"]):
		return {"type": "skill"}                       # 先用技能补上最后一点
	return {"type": "attack", "attacker": int(first["uid"]),
		"target": {"kind": "hero"}, "score": 9999.0}

## 军师主动技（每场 1 次）：只在「确实有东西可用」时出手，别空放
static func adv_action(state: Dictionary, pid: String) -> Variant:
	if not RulesEngine.can_advisor_active(state, pid):
		return null
	var a: Dictionary = RulesEngine.advisor_active(state)
	if a.is_empty():
		return null
	var p: Dictionary = state["players"][pid]
	var e: Dictionary = state["players"][opp(pid)]
	var fx: Dictionary = a["fx"]
	var my_units := 0
	var foe_units := 0
	var my_rattle := 0
	for r in RulesEngine.RANKS:
		my_units += (p["board"][r] as Array).size()
		foe_units += (e["board"][r] as Array).size()
		for u in p["board"][r]:
			if u.get("deathrattle", null) != null:
				my_rattle += 1
	if fx.has("draw"):
		return {"type": "adv"}
	if fx.has("healHero"):
		return {"type": "adv"} if int(p["hp"]) <= int(p["maxHp"]) - 2 else null
	if fx.has("summon"):
		var rank: String = str((fx["summon"] as Dictionary).get("rank", "front"))
		return {"type": "adv"} if (p["board"][rank] as Array).size() < 3 else null
	# buffCol 只加某一列：那一列没人就白花军粮（JS 侧曾漏掉这个分支）
	if fx.has("buffCol"):
		var col: Array = p["board"].get(str(fx["buffCol"]), [])
		return {"type": "adv"} if col.size() > 0 else null
	if fx.has("buffAll") or fx.has("buffAllHp") or fx.has("buffHighest"):
		return {"type": "adv"} if my_units > 0 else null
	if fx.has("dmgHighest") or fx.has("debuffHighest"):
		return {"type": "adv"} if foe_units > 0 else null
	if fx.has("xyCap"):
		return {"type": "adv"} if my_rattle > 0 else null
	return null


## 产生下一个动作：play / adv / skill / attack / end
static func next_action(state: Dictionary, pid: String) -> Dictionary:
	if bool(state["over"]):
		return {"type": "end"}
	var p: Dictionary = state["players"][pid]
	var level := level_of(state, pid)
	var randomize: bool = level == "jianxi" and RulesEngine._r() < 0.5

	# 0. 名将先算斩杀
	if level == "mingjiang":
		var lethal = lethal_plan(state, pid)
		if lethal != null:
			return lethal

	# 1. 出牌
	var plays: Array = []
	for card in p["hand"]:
		if int(card["cost"]) <= int(p["mana"]) and RulesEngine.can_play(state, pid, card):
			plays.append({"type": "play", "uid": int(card["uid"]),
				"score": play_score(state, pid, card)})
	if plays.size() > 0:
		if randomize:
			return plays[int(floor(RulesEngine._r() * float(plays.size())))]
		plays.sort_custom(func (a, b): return a["score"] > b["score"])
		if float(plays[0]["score"]) > 0.5:
			return plays[0]

	# 1.5 军师主动技：出牌之后、攻击之前——加攻/减攻要赶在打人前
	var adv = adv_action(state, pid)
	if adv != null:
		return adv

	# 2. 英雄技能
	if skill_useful(state, pid):
		var spare: int = int(p["mana"]) - int(p["skill"]["cost"])
		var no_affordable := true
		for c in p["hand"]:
			if int(c["cost"]) <= int(p["mana"]):
				no_affordable = false
				break
		if spare >= 2 or no_affordable or not randomize:
			return {"type": "skill"}

	# 3. 攻击
	var attacks: Array = []
	for r in RulesEngine.RANKS:
		for u in p["board"][r]:
			if not bool(u["canAttack"]) or int(u["atk"]) <= 0:
				continue
			var info := RulesEngine.get_attack_targets(state, pid, u)
			if bool(info["heroOk"]):
				attacks.append({"type": "attack", "attacker": int(u["uid"]),
					"target": {"kind": "hero"},
					"score": 100.0 + int(u["atk"]) + (10.0 if level == "mingjiang" else 0.0)})
			for t in info["units"]:
				attacks.append({"type": "attack", "attacker": int(u["uid"]),
					"target": {"kind": "unit", "uid": int(t["unit"]["uid"])},
					"score": attack_score(u, t, level)})
	if attacks.size() > 0:
		if randomize:
			return attacks[int(floor(RulesEngine._r() * float(attacks.size())))]
		attacks.sort_custom(func (a, b): return a["score"] > b["score"])
		if float(attacks[0]["score"]) > 0.0:
			return attacks[0]

	return {"type": "end"}

## 在真实状态上执行一个 AI 动作
static func apply_action(state: Dictionary, pid: String, action: Dictionary) -> Dictionary:
	match str(action["type"]):
		"play":
			return RulesEngine.play_card(state, pid, int(action["uid"]))
		"adv":
			return RulesEngine.use_advisor_active(state, pid)
		"skill":
			return RulesEngine.use_skill(state, pid)
		"attack":
			return RulesEngine.attack(state, pid, int(action["attacker"]), action["target"])
		"end":
			RulesEngine.end_turn(state)
			return {"ok": true}
	return {"ok": false, "reason": "未知动作"}

## AI 开局换牌：换掉费用 >=5 的大牌（前期用不上）
static func mulligan_uids(state: Dictionary, pid: String) -> Array:
	var out: Array = []
	for c in state["players"][pid]["hand"]:
		if int(c["cost"]) >= 5:
			out.append(int(c["uid"]))
	return out
