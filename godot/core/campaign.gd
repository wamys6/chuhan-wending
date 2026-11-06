## 战役层：进度 / 存档位 / 奖励池 / 军师 / 行军事件
##
## 移植自 Web 版 js/campaign.js，行为口径保持一致：
##   - 8 关线性推进，通关解锁下一关，首次通关发一张奖励牌
##   - 3 个存档位，进度存成 user:// 下的 JSON
##   - 军师 5 选 3 择 1，开局定终身（被动只对玩家生效，由引擎读取 rules.advisor）
##   - 关间随机行军事件，一次性加成在下一场战斗后清零
class_name Campaign
extends RefCounted

const SLOT_COUNT := 3
const SAVE_PATH := "user://chuhan_slots.json"
const PROGRESS_VERSION := 2
const HP_BONUS_FLOOR := -8
## 牌组下限：奖励页可以「不取牌、改删一张」，但不能把牌组删到转不动。
## 20 张起步、8 关最多删 8 次；15 张是「还能撑过 10 费局三轮循环」的底线
## （实测删 4 张已 -10pp，删到 15 以下会直接进疲劳，属于玩家自伤而非策略）
const MIN_DECK := 15

# ---------------- 关卡查询 ----------------

static func stages() -> Array:
	GameData.ensure_loaded()
	return GameData.stages

static func stage_by_id(stage_id: String) -> Dictionary:
	return GameData.stage_by_id(stage_id)

static func stage_index(stage_id: String) -> int:
	var list := stages()
	for i in list.size():
		if list[i]["id"] == stage_id:
			return i
	return -1

static func status_of(progress: Dictionary, stage_id: String) -> String:
	if progress.is_empty():
		return "locked"
	var idx := stage_index(stage_id)
	if idx < 0:
		return "locked"
	if stage_id in progress.get("cleared", []):
		return "cleared"
	if idx == 0:
		return "open"
	var prev_id: String = stages()[idx - 1]["id"]
	return "open" if prev_id in progress.get("cleared", []) else "locked"

static func next_stage(progress: Dictionary) -> Dictionary:
	for s in stages():
		if status_of(progress, s["id"]) == "open":
			return s
	return {}

static func is_finished(progress: Dictionary) -> bool:
	return not progress.is_empty() and progress.get("cleared", []).size() >= stages().size()

# ---------------- 进度对象 ----------------

static func empty_progress(hero_id: String) -> Dictionary:
	return {
		"version": PROGRESS_VERSION,
		"hero": hero_id,
		"deck": [],
		"cleared": [],
		"advisor": "",
		"hpBonus": 0,
		"manaBonus": 0,
		"drawBonus": 0,
		"enemyManaBonus": 0,
		"ascension": 0,
		"tianShi": "",
		"mode": "regular",
		"events": [],
		"eventLog": [],
		"retried": [],
		"startedAt": Time.get_unix_time_from_system(),
	}

static func normalize(p) -> Dictionary:
	if typeof(p) != TYPE_DICTIONARY:
		return {}
	if not (p.get("cleared", null) is Array) or not (p.get("deck", null) is Array):
		return {}
	var out: Dictionary = p
	out["version"] = int(out.get("version", 1))
	if out["version"] < PROGRESS_VERSION:
		out["version"] = PROGRESS_VERSION
	for key in ["hpBonus", "manaBonus", "drawBonus", "enemyManaBonus"]:
		if typeof(out.get(key, 0)) != TYPE_FLOAT and typeof(out.get(key, 0)) != TYPE_INT:
			out[key] = 0
	for key in ["events", "eventLog", "retried"]:
		if not (out.get(key, null) is Array):
			out[key] = []
	if typeof(out.get("advisor", "")) != TYPE_STRING:
		out["advisor"] = ""
	# 心魔 / 天时：老存档没有这两项，按「常规难度、无天时」处理
	out["ascension"] = clampi(int(out.get("ascension", 0)), 0, ascension_max())
	if not out.has("tianShi") or typeof(out["tianShi"]) != TYPE_STRING:
		out["tianShi"] = ""
	# 初阵档位（P3）：老存档没有 mode，一律按常规难度
	if str(out.get("mode", "")) != "chuben":
		out["mode"] = "regular"
	out["hero"] = str(out.get("hero", "liubang"))
	return out

## 开新战役：清空进度，牌组用该英雄的官方预组
## ascension 为心魔等级（0 = 常规），天时在开局时随机决定
## mode 为难度档位："regular"（常规，默认）| "chuben"（初阵宽容档），整条战役跟随存档
static func start_run(hero_id: String, preset_deck: Array, advisor_id: String = "",
		ascension_level: int = 0, mode: String = "regular") -> Dictionary:
	var p := empty_progress(hero_id)
	p["deck"] = preset_deck.duplicate()
	p["advisor"] = advisor_id
	p["ascension"] = clampi(ascension_level, 0, ascension_max())
	p["mode"] = "chuben" if mode == "chuben" else "regular"
	var ts := roll_tian_shi()
	p["tianShi"] = str(ts.get("id", ""))
	save_slot(active_slot(), p)
	return p

## 通关一关：记录进度 + 首次通关发奖励牌
static func clear_stage(progress: Dictionary, stage_id: String, reward_card_id: String = "") -> Dictionary:
	var first_clear: bool = not (stage_id in progress.get("cleared", []))
	if first_clear:
		progress["cleared"].append(stage_id)
		if reward_card_id != "":
			progress["deck"].append(reward_card_id)
	save_slot(active_slot(), progress)
	return progress

## 牌组还能不能再删一张（奖励页「不取牌、改删一张」用）
static func can_remove_card(progress: Dictionary) -> bool:
	return (progress.get("deck", []) as Array).size() > MIN_DECK

## 从牌组删掉一张指定牌。返回是否真的删了（牌组已到下限 / 牌不在牌组里 → false）
static func remove_card(progress: Dictionary, card_id: String) -> bool:
	var deck: Array = progress.get("deck", [])
	if deck.size() <= MIN_DECK:
		return false
	var idx := deck.find(card_id)
	if idx < 0:
		return false
	deck.remove_at(idx)
	progress["deck"] = deck
	save_slot(active_slot(), progress)
	return true

# ---------------- 心魔 / 天时 ----------------

## 心魔表（累计叠加：第 N 级 = 1..N 全部生效）
static func ascension_levels() -> Array:
	GameData.ensure_loaded()
	return GameData.ascension

static func ascension_max() -> int:
	return ascension_levels().size()

static func ascension_by_level(level: int) -> Dictionary:
	GameData.ensure_loaded()
	if level <= 0 or level > GameData.ascension.size():
		return {}
	return GameData.ascension[level - 1]

## 第 1..level 级的效果合计
static func ascension_mods(level: int) -> Dictionary:
	var out: Dictionary = {}
	var n: int = clampi(level, 0, ascension_max())
	for i in n:
		var mods: Dictionary = (ascension_levels()[i] as Dictionary).get("mods", {})
		for k in mods.keys():
			out[k] = int(out.get(k, 0)) + int(mods[k])
	return out

static func tian_shi_list() -> Array:
	GameData.ensure_loaded()
	return GameData.tianshi

static func tian_shi_by_id(id: String) -> Dictionary:
	if id == "":
		return {}
	for t in tian_shi_list():
		if str(t.get("id", "")) == id:
			return t
	return {}

static func roll_tian_shi() -> Dictionary:
	var list := tian_shi_list()
	if list.is_empty():
		return {}
	return list[randi() % list.size()]

## 累计效果的文字摘要（地图与过场用）：把 1..level 的说明串起来
static func ascension_summary(level: int) -> String:
	var parts: Array = []
	for i in clampi(level, 0, ascension_max()):
		var a: Dictionary = ascension_levels()[i]
		parts.append(str(a.get("desc", "")))
	return " · ".join(parts)

## 心魔 + 天时的效果合计（本局每关都生效）
static func run_mods(progress: Dictionary) -> Dictionary:
	var out: Dictionary = ascension_mods(int(progress.get("ascension", 0)))
	var ts := tian_shi_by_id(str(progress.get("tianShi", "")))
	var mods: Dictionary = ts.get("mods", {})
	for k in mods.keys():
		out[k] = int(out.get(k, 0)) + int(mods[k])
	return out

# ---------------- 关卡规则合并 ----------------

## 把关卡规则 + 战役累积加成 + 军师合成引擎能吃的 rules
## 全局难度旋钮（1.1 卡池扩容后的校准）：八关统一 +1 敌方开局军粮。
## 扩容把奖励池平均质量抬上去（新卡都是"标准属性 + 一条效果"），整轮通关率翻倍，
## 用这个把基线压回个位数。为什么不是预置部队：那是最强杠杆，一加就 0%（实测）。
const GLOBAL_ENEMY_MANA := 1

## 初阵档位（P3 难度宽容度）：新建战役时可选的宽容档，给不熟卡牌对战的玩家。
## 跟存档走（progress.mode），中途不变；与心魔/天时叠加；
## 敌方首回合军粮最低到 0（1 全局 - 1 初阵 - 1 霜降天时），不会为负。
const CHUBEN_HP := 6
const CHUBEN_ENEMY_MANA := -1

## 每关的重整机会（P5）：同一关兵败第二次即本局终结。
## 依据：无穷重试让「19% 通关率」对真人等于 100%，run 毫无风险；
## 给一次机会后理论上限 ≈ p×1.35（+5pp），不破坏难度曲线。
const RETRY_PER_STAGE := 1

# 死战专精（1.2）：牌组里死战牌的张数决定死战召唤物的强度增幅。
# 1.1 的结论是「死战路线靠卡堆起不来」；1.2 量出原因不是选不到（专精玩家已经
# 拿到 7.6 张、浓度 27%），而是每多一张只值 1~2 点属性、不产生质变。所以这里
# 改的不是发牌量，而是让「同类牌的张数」改变牌本身的效果强度。
# 死战专精：档位按「死战牌占牌组的比例」算，不按绝对张数。
# 为什么是比例——牌组从 20 张长到 28 张，绝对张数门槛会随规模漂移：早期 6 张是 30%，
# 晚期 6 张只有 21%，同一个门槛在不同关卡含义完全不同。
# 实测分布（test/diag-tier.js）：初始 3/20=15%，专精流第 8 关约 7.4/28=26%，
# 按质量选牌约 5.0/28=18%。20% 这条线正好夹在中间：专精流第 3~4 关开始吃到，
# 按质量选的普通玩家全程吃不到。
# 幅度「血先走、攻跟上」：首版每档 +1/+1 递增实测过猛（专精 28%、军师叠加 38%）。
const LAST_STAND_RATIO := [0.20, 0.25, 0.30]
const LAST_STAND_BONUS := [[0, 1], [1, 1], [2, 2]]

static func last_stand_bonus(deck: Array) -> Array:
	var tier := last_stand_tier(deck)
	return LAST_STAND_BONUS[tier - 1] if tier > 0 else [0, 0]


static func last_stand_tier(deck: Array) -> int:
	if deck.is_empty():
		return 0
	var n := 0
	for id in deck:
		var c := GameData.card(str(id))
		if not c.is_empty() and c.get("deathrattle", null) != null:
			n += 1
	var ratio := float(n) / float(deck.size())
	var tier := 0
	for i in LAST_STAND_RATIO.size():
		if ratio >= float(LAST_STAND_RATIO[i]):
			tier = i + 1
	return tier


static func engine_rules(stage: Dictionary, progress: Dictionary) -> Dictionary:
	var r: Dictionary = (stage.get("rules", {}) as Dictionary).duplicate(true)
	r["enemyStartMana"] = int(r.get("enemyStartMana", 0)) + GLOBAL_ENEMY_MANA
	if stage.has("goal"):
		r["goal"] = stage["goal"]
	if stage.has("goalTurns"):
		r["goalTurns"] = stage["goalTurns"]
	if not progress.is_empty():
		var adv := str(progress.get("advisor", ""))
		if adv != "":
			r["advisor"] = adv
		# 死战专精：只跟牌组，不跟军师。军师是「这一局怎么打」，专精是「我选了哪些牌」
		var lsb := last_stand_bonus(progress.get("deck", []))
		r["lastStandTier"] = last_stand_tier(progress.get("deck", []))
		r["lastStandAtk"] = int(lsb[0])
		r["lastStandHp"] = int(lsb[1])
		var hp_bonus := int(progress.get("hpBonus", 0))
		# 初阵档位：主将 +6 血、敌军首回合 -1 军粮，与心魔/天时叠加
		if str(progress.get("mode", "")) == "chuben":
			hp_bonus += CHUBEN_HP
			r["enemyStartMana"] = int(r.get("enemyStartMana", 0)) + CHUBEN_ENEMY_MANA
		var mana_bonus := int(progress.get("manaBonus", 0))
		if mana_bonus != 0:
			r["playerStartMana"] = int(r.get("playerStartMana", 0)) + mana_bonus
		var draw_bonus := int(progress.get("drawBonus", 0))
		if draw_bonus != 0:
			r["openingDraw"] = int(r.get("openingDraw", 0)) + draw_bonus
		var e_mana := int(progress.get("enemyManaBonus", 0))
		if e_mana != 0:
			r["enemyStartMana"] = int(r.get("enemyStartMana", 0)) + e_mana
		# 心魔（累计）+ 本局天时：只改军粮与生命上限
		var mods := run_mods(progress)
		if int(mods.get("playerStartMana", 0)) != 0:
			r["playerStartMana"] = int(r.get("playerStartMana", 0)) + int(mods["playerStartMana"])
		if int(mods.get("enemyStartMana", 0)) != 0:
			r["enemyStartMana"] = int(r.get("enemyStartMana", 0)) + int(mods["enemyStartMana"])
		if int(mods.get("openingDraw", 0)) != 0:
			r["openingDraw"] = int(r.get("openingDraw", 0)) + int(mods["openingDraw"])
		hp_bonus += int(mods.get("playerHpBonus", 0))
		if hp_bonus != 0:
			r["playerHpBonus"] = hp_bonus
	# 敌首回合加成钳到 ≥0：初阵(-1)与霜降天时(-1)叠加时把全局(+1)抵穿，按 0 算
	if r.has("enemyStartMana") and int(r["enemyStartMana"]) < 0:
		r["enemyStartMana"] = 0
	return r

## 一次性加成用完即清（每场战斗开打时调用）
static func consume_boosts(progress: Dictionary) -> void:
	if progress.is_empty():
		return
	progress["manaBonus"] = 0
	progress["drawBonus"] = 0
	progress["enemyManaBonus"] = 0
	save_slot(active_slot(), progress)

# ---------------- 奖励池 ----------------

## 稀有度按费用分档：1 普通（≤2 费）/ 2 精良（3-4 费）/ 3 史诗（≥5 费）
static func rarity_of(card: Dictionary) -> int:
	var cost := int(card.get("cost", 0))
	var r := 1 if cost <= 2 else (2 if cost <= 4 else 3)
	# 连击牌统一后置到第 4 关起（P2）。它们全是低成本牌，按费用分档会挤进早期三选一，
	# 把强牌稀释掉（实测随机玩家 -2pp）。后置后第 1~3 关池子不变，
	# 连击流从第 4 关成型——本来也是「先铺路再连击」的节奏。
	if card.get("combo", null) != null and r < 3:
		r = 3
	return r

## 关卡可给的稀有度上限：越靠后池子越深
static func tier_of(stage: Dictionary) -> int:
	if stage.has("tier"):
		return int(stage["tier"])
	var idx := stage_index(str(stage["id"]))
	if idx <= 0:
		return 1
	return 2 if idx <= 2 else 3

static func deck_count(deck: Array, card_id: String) -> int:
	var n := 0
	for id in deck:
		if str(id) == card_id:
			n += 1
	return n

## 全局可奖励卡池：按稀有度上限 + 阵营过滤 + 同名 ≤2 张；特色牌不受稀有度限制
static func reward_pool(stage: Dictionary, hero_faction: String, deck: Array) -> Array:
	var tier := tier_of(stage)
	var pool: Array = []
	for id in GameData.cards.keys():
		var c: Dictionary = GameData.cards[id]
		var fac := GameData.faction_of(str(id))
		# 汉营不出楚牌，楚营不出汉牌，中立通用
		if fac != "neutral" and fac != hero_faction:
			continue
		if rarity_of(c) > tier:
			continue
		if deck_count(deck, str(id)) >= 2:
			continue
		pool.append(str(id))
	for id in stage.get("rewards", []):
		var sid := str(id)
		if not GameData.has_card(sid):
			continue
		if deck_count(deck, sid) >= 2:
			continue
		if not (sid in pool):
			pool.append(sid)
	return pool

## 抽 n 张奖励候选：特色牌 45% 概率顶上一张
## opts.kind：只出这一类（"piece" / "spell"），事件「得一张兵种牌」靠它过滤
static func roll_rewards(stage: Dictionary, hero_faction: String, n: int, deck: Array,
		opts: Dictionary = {}) -> Array:
	var pool := reward_pool(stage, hero_faction, deck)
	var kind := str(opts.get("kind", ""))
	if kind != "":
		var filtered: Array = []
		for id in pool:
			if str((GameData.cards[id] as Dictionary).get("type", "")) == kind:
				filtered.append(id)
		pool = filtered
	if pool.is_empty():
		return []
	var featured: Array = []
	for id in stage.get("rewards", []):
		if str(id) in pool and not (str(id) in featured):
			featured.append(str(id))
	var copy: Array = pool.duplicate()
	var out: Array = []
	while out.size() < n and copy.size() > 0:
		var pick := ""
		if featured.size() > 0 and randf() < 0.45:
			var fi := randi() % featured.size()
			pick = str(featured[fi])
			featured.remove_at(fi)
			if not (pick in copy):
				continue
		else:
			pick = str(copy[randi() % copy.size()])
		out.append(pick)
		copy.erase(pick)
	# 构筑引导（P2 连击）：牌组里已有 2 张连击牌时，三选一有 45% 概率替换一张为连击牌。
	# 连击牌全池 8/77、三选一命中率约 25%，不引导的话八关只拿得到 1~2 张，
	# 浓度永远到不了能形成打法的程度（实测 combo 策略与随机无异）。
	# 只服务「已经在走这条路」的人：不足 2 张时不触发，其余玩家奖励不变。
	var combo_n := 0
	for id in deck:
		var dc: Dictionary = GameData.cards.get(str(id), {})
		if dc.get("combo", null) != null:
			combo_n += 1
	if combo_n >= 2 and out.size() > 0 and randf() < 0.30:
		var combo_pool: Array = []
		for id in pool:
			var c: Dictionary = GameData.cards.get(str(id), {})
			if c.get("combo", null) != null and not (str(id) in out):
				combo_pool.append(str(id))
		if combo_pool.size() > 0:
			out[randi() % out.size()] = str(combo_pool[randi() % combo_pool.size()])
	return out

# ---------------- 军师 ----------------

static func advisor_by_id(advisor_id: String) -> Dictionary:
	return GameData.advisor_by_id(advisor_id)

## 随机抽 n 个军师供玩家挑选
static func roll_advisors(n: int = 3) -> Array:
	var copy: Array = (GameData.advisors as Array).duplicate(true)
	var out: Array = []
	while out.size() < n and copy.size() > 0:
		out.append(copy.pop_at(randi() % copy.size()))
	return out

# ---------------- 行军事件 ----------------

static func event_by_id(event_id: String) -> Dictionary:
	return GameData.event_by_id(event_id)

## 抽一个本局还没触发过的事件；都触发完了就从头再来一圈
static func pick_event(progress: Dictionary) -> Dictionary:
	var used: Array = progress.get("events", [])
	var fresh: Array = []
	for e in GameData.events:
		if not (str(e["id"]) in used):
			fresh.append(e)
	var pool: Array = fresh if fresh.size() > 0 else (GameData.events as Array)
	return pool[randi() % pool.size()]

## 通关后、且后面还有关卡 → 需要一个事件节点
static func needs_event(progress: Dictionary, stage: Dictionary) -> bool:
	if progress.is_empty() or stage.is_empty():
		return false
	var idx := stage_index(str(stage["id"]))
	return idx >= 0 and idx < stages().size() - 1

## 结算事件选项：写进进度并返回 {ok, fx, option}
static func apply_event(progress: Dictionary, event_id: String, option_index: int) -> Dictionary:
	var ev := event_by_id(event_id)
	if progress.is_empty() or ev.is_empty():
		return {"ok": false, "reason": "事件不存在"}
	var options: Array = ev.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return {"ok": false, "reason": "选项不存在"}
	var opt: Dictionary = options[option_index]
	var fx: Dictionary = opt.get("fx", {})
	if fx.has("hp"):
		progress["hpBonus"] = maxi(HP_BONUS_FLOOR, int(progress.get("hpBonus", 0)) + int(fx["hp"]))
	if fx.has("mana"):
		progress["manaBonus"] = int(progress.get("manaBonus", 0)) + int(fx["mana"])
	if fx.has("draw"):
		progress["drawBonus"] = int(progress.get("drawBonus", 0)) + int(fx["draw"])
	if fx.has("enemyMana"):
		progress["enemyManaBonus"] = int(progress.get("enemyManaBonus", 0)) + int(fx["enemyMana"])
	if fx.has("removeRandom"):
		var deck: Array = progress.get("deck", [])
		for i in int(fx["removeRandom"]):
			if deck.is_empty():
				break
			deck.remove_at(randi() % deck.size())
	if not (str(ev["id"]) in progress.get("events", [])):
		progress["events"].append(str(ev["id"]))
	progress["eventLog"].append({"id": ev["id"], "name": ev["name"], "choice": str(opt["label"])})
	while progress["eventLog"].size() > 12:
		progress["eventLog"].pop_front()
	save_slot(active_slot(), progress)
	return {"ok": true, "fx": fx, "option": opt, "event": ev}

## 事件「得牌」的候选池：按 fx.card（牌类）与 fx.cardCount（几张）抽 张数×3 张供玩家挑。
## 与 Web 版 ui.js:1011 的 `(fx.cardCount || 1) * 3` 对齐——三倍是为了「三选一」的手感。
static func event_candidates(progress: Dictionary, fx: Dictionary) -> Array:
	var hero := GameData.hero(str(progress.get("hero", "liubang")))
	var kind := str(fx.get("card", "any"))
	var picks := maxi(1, int(fx.get("cardCount", 1)))
	var stage := {"id": "_event", "rewards": [], "tier": 3}
	var opts := {} if kind == "any" else {"kind": kind}
	return roll_rewards(stage, str(hero.get("faction", "han")), picks * 3,
		progress.get("deck", []), opts)

## 事件「得牌」落地：选了几张就调几次（选牌层只管展示与挑选）
static func add_card(progress: Dictionary, card_id: String) -> bool:
	if not GameData.has_card(card_id):
		return false
	var deck: Array = progress.get("deck", [])
	deck.append(card_id)
	progress["deck"] = deck
	save_slot(active_slot(), progress)
	return true

## 机会卡：抽一张随机兵种牌塞进牌组（事件「流民归附」用）
static func grant_random_piece(progress: Dictionary) -> String:
	var pool: Array = []
	for id in GameData.cards.keys():
		var c: Dictionary = GameData.cards[id]
		if str(c["type"]) == "piece" and GameData.faction_of(str(id)) != "chu":
			pool.append(str(id))
	if pool.is_empty():
		return ""
	var pick := str(pool[randi() % pool.size()])
	progress["deck"].append(pick)
	save_slot(active_slot(), progress)
	return pick

# ---------------- 存档位（user:// 下 JSON） ----------------

static func _empty_store() -> Dictionary:
	return {"version": 1, "active": 0, "slots": [null, null, null]}

static func _read_store() -> Dictionary:
	var store := _empty_store()
	if FileAccess.file_exists(SAVE_PATH):
		var text := FileAccess.get_file_as_string(SAVE_PATH)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			store = parsed
	var slots: Array = store.get("slots", [])
	while slots.size() < SLOT_COUNT:
		slots.append(null)
	store["slots"] = slots
	var active := int(store.get("active", 0))
	store["active"] = clampi(active, 0, SLOT_COUNT - 1)
	return store

static func _write_store(store: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Campaign: 存档写入失败 %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(store))
	f.close()

static func active_slot() -> int:
	return int(_read_store()["active"])

static func use_slot(index: int) -> void:
	var store := _read_store()
	store["active"] = clampi(index, 0, SLOT_COUNT - 1)
	_write_store(store)

static func load_slot(index: int) -> Dictionary:
	var store := _read_store()
	var entry = store["slots"][clampi(index, 0, SLOT_COUNT - 1)]
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	return normalize(entry.get("progress", null))

static func save_slot(index: int, progress: Dictionary) -> void:
	var store := _read_store()
	var i := clampi(index, 0, SLOT_COUNT - 1)
	store["slots"][i] = {"progress": progress, "updatedAt": Time.get_unix_time_from_system()}
	_write_store(store)

static func clear_slot(index: int) -> void:
	var store := _read_store()
	store["slots"][clampi(index, 0, SLOT_COUNT - 1)] = null
	_write_store(store)

## 存档位摘要（界面用）
# ---------------- 重整机会（P5） ----------------
# 每关 1 次：第一次兵败回地图可再战；同一关第二次兵败 → 本局终结。
# 放弃本局与兵败同等消耗（否则玩家会在必败时退出躲惩罚）。

static func retry_left(progress: Dictionary, stage_id: String) -> int:
	if progress.is_empty() or stage_id == "":
		return 0
	var used := 0
	for sid in (progress.get("retried", []) as Array):
		if str(sid) == stage_id:
			used += 1
	return maxi(0, RETRY_PER_STAGE - used)

static func can_retry(progress: Dictionary, stage_id: String) -> bool:
	return retry_left(progress, stage_id) > 0

## 消耗一次重整；返回 false 表示已用完（调用方应终结本局）
static func take_retry(progress: Dictionary, stage_id: String) -> bool:
	if not can_retry(progress, stage_id):
		return false
	var arr: Array = (progress.get("retried", []) as Array).duplicate()
	arr.append(stage_id)
	progress["retried"] = arr
	save_slot(active_slot(), progress)
	return true

## 本局终结：清空当前存档位（成就/生涯是独立存档，不受影响）
static func end_run() -> int:
	var i := int(active_slot())
	clear_slot(i)
	return i

static func slot_summary(index: int) -> Dictionary:
	var store := _read_store()
	var entry = store["slots"][index]
	var out := {"index": index, "empty": true, "active": int(store["active"]) == index, "updatedAt": 0}
	if typeof(entry) != TYPE_DICTIONARY:
		return out
	var p := normalize(entry.get("progress", null))
	if p.is_empty():
		return out
	var hero := GameData.hero(str(p["hero"]))
	var nxt := next_stage(p)
	out["empty"] = false
	out["updatedAt"] = int(entry.get("updatedAt", 0))
	out["hero"] = str(hero.get("name", p["hero"]))
	out["cleared"] = p["cleared"].size()
	out["total"] = stages().size()
	out["nextStage"] = str(nxt.get("name", "—"))
	out["deckSize"] = p["deck"].size()
	var adv := advisor_by_id(str(p.get("advisor", "")))
	out["advisor"] = str(adv.get("name", ""))
	out["hpBonus"] = int(p.get("hpBonus", 0))
	out["mode"] = str(p.get("mode", "regular"))
	out["retries"] = (p.get("retried", []) as Array).size()
	out["finished"] = is_finished(p)
	return out

static func slot_count() -> int:
	return SLOT_COUNT

## 测试用：清掉全部存档
static func _wipe_all() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
