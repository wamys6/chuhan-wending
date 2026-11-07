## 图鉴数据 · 成就 · 战绩（与 Web 版 js/codex.js 口径一致）
##
## 三件事放在一个模块里，因为它们共享同一份「生涯存档」：
##   图鉴 —— 卡池筛选与统计（纯函数，不落盘）
##   成就 —— 18 项，达成即永久记录，判定基于已累加的战绩
##   战绩 —— 总场次/胜率/连胜/最深关卡/累计伤害等长期数据
## 存档：user://chuhan_career.json，与战役存档分开（换存档位不清成就）
class_name Codex
extends RefCounted

const PATH := "user://chuhan_career.json"

## 成就定义。cond 是声明式条件，由 _meets() 统一判定——
## 不用 lambda 是为了让成就表能被 JSON 序列化、也方便将来做在线成就同步。
const ACHIEVEMENTS := [
	# ---- 战阵：单场表现 ----
	{"id": "first_win", "group": "battle", "glyph": "捷", "name": "首战告捷",
		"desc": "赢下第一场战斗。", "cond": {"t": "battle_win", "min_wins": 1}},
	{"id": "flawless", "group": "battle", "glyph": "全", "name": "全师而归",
		"desc": "一兵未折，以满血取胜。", "cond": {"t": "flawless"}},
	{"id": "last_stand", "group": "battle", "glyph": "险", "name": "背水一战",
		"desc": "只剩 5 点血时反败为胜。", "cond": {"t": "low_hp_win", "hp": 5}},
	{"id": "swift", "group": "battle", "glyph": "速", "name": "速战速决",
		"desc": "12 个回合内结束战斗。", "cond": {"t": "fast_win", "turns": 12}},
	{"id": "decapitate", "group": "battle", "glyph": "斩", "name": "直取黄龙",
		"desc": "单场对敌方主将造成 20 点以上伤害。", "cond": {"t": "hero_dmg", "min": 20}},
	{"id": "army", "group": "battle", "glyph": "军", "name": "兵强马壮",
		"desc": "单场派出 10 员兵将。", "cond": {"t": "units", "min": 10}},
	{"id": "strategist", "group": "battle", "glyph": "谋", "name": "运筹帷幄",
		"desc": "单场使用 6 张计谋牌。", "cond": {"t": "spells", "min": 6}},
	{"id": "mingjiang", "group": "battle", "glyph": "名", "name": "力敌名将",
		"desc": "在「名将」智力下取胜。", "cond": {"t": "level_win", "level": "mingjiang"}},

	# ---- 战役：推进进度 ----
	{"id": "stage_1", "group": "campaign", "glyph": "沛", "name": "沛县起兵",
		"desc": "通关第壹关「沛县起兵」。", "cond": {"t": "cleared", "min": 1}},
	{"id": "stage_4", "group": "campaign", "glyph": "荥", "name": "挺进中原",
		"desc": "通关第肆关「荥阳对峙」。", "cond": {"t": "cleared", "min": 4}},
	{"id": "stage_all", "group": "campaign", "glyph": "鼎", "name": "问鼎中原",
		"desc": "通关全部 8 关，走到垓下。", "cond": {"t": "finished"}},
	{"id": "deck_26", "group": "campaign", "glyph": "众", "name": "兵多将广",
		"desc": "把战役牌组养到 26 张。", "cond": {"t": "max_deck", "min": 26}},
	{"id": "two_heroes", "group": "campaign", "glyph": "楚", "name": "楚河汉界",
		"desc": "刘邦与项羽各取胜一场。", "cond": {"t": "heroes_won", "ids": ["liubang", "xiangyu"]}},

	# ---- 阅历：长期积累 ----
	{"id": "veteran", "group": "career", "glyph": "百", "name": "百战之将",
		"desc": "累计进行 20 场战斗。", "cond": {"t": "battles", "min": 20}},
	{"id": "legend", "group": "career", "glyph": "五", "name": "五十战",
		"desc": "累计进行 50 场战斗。", "cond": {"t": "battles", "min": 50}},
	{"id": "streak_5", "group": "career", "glyph": "连", "name": "五连捷",
		"desc": "连胜 5 场。", "cond": {"t": "best_streak", "min": 5}},
	{"id": "advisors_3", "group": "career", "glyph": "师", "name": "三军之师",
		"desc": "用过 3 位不同的军师。", "cond": {"t": "advisors", "min": 3}},
	{"id": "events_6", "group": "career", "glyph": "行", "name": "阅尽行军",
		"desc": "经历 6 个不同的行军事件。", "cond": {"t": "events", "min": 6}},
	{"id": "damage_500", "group": "career", "glyph": "伤", "name": "千里杀将",
		"desc": "累计造成 500 点伤害。", "cond": {"t": "dmg", "min": 500}},
]

const GROUP_NAMES := {"battle": "战阵", "campaign": "战役", "career": "阅历"}

## 成就的显示文案：英文模式下按 id 取英文，中文模式取表里的原文
static func ach_name(a: Dictionary) -> String:
	return I18n.achievement_field(str(a.get("id", "")), "name", str(a.get("name", "")))

static func ach_desc(a: Dictionary) -> String:
	return I18n.achievement_field(str(a.get("id", "")), "desc", str(a.get("desc", "")))

## 分组名（战阵 / 战役 / 阅历）
static func group_name(g: String) -> String:
	return I18n.achievement_group(g, str(GROUP_NAMES.get(g, g)))

static var _career: Dictionary = {}
static var _loaded := false

# ---------------- 存档 ----------------

static func empty_career() -> Dictionary:
	return {
		"version": 1,
		"battles": 0, "wins": 0, "losses": 0,
		"pvpWins": 0, "pvpLosses": 0,
		"streak": 0, "bestStreak": 0,
		"turns": 0, "dmg": 0, "heroDmg": 0, "units": 0, "spells": 0,
		"bestHpWin": -1, "fastestWin": -1,
		"levels": {}, "heroes": {}, "advisors": {}, "events": {},
		"clearedStages": {}, "clearedCount": 0,
		"chubenClears": 0,
		"maxStage": -1, "maxStageId": "", "maxDeck": 0,
		"finished": false,
		# 已通关的最高心魔等级（0 = 只通过常规）。解锁上限 = 本值 + 1
		"ascensionBest": 0,
		# 整轮通关次数（解锁式 meta 的梯级货币：军师/事件分批解锁靠它）
		"runWins": 0,
		"ach": {},
		"firstPlayed": 0, "lastPlayed": 0,
	}

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_career = empty_career()
	if not FileAccess.file_exists(PATH):
		return
	var d: Dictionary = SafeFile.read_dict(PATH)
	if d.is_empty():
		return
	# 用空档补齐缺字段，老存档也能安全读
	var num_types := [TYPE_INT, TYPE_FLOAT]
	for k in _career.keys():
		if not d.has(k):
			continue
		var v = d[k]
		var tv := typeof(v)
		var tk := typeof(_career[k])
		# 类型不符（手改档 / 旧版本）就丢弃该字段——把 Array 塞进 Dictionary 字段，
		# 后面 .has() 会直接运行时报错。数字之间允许互通。
		if tv != tk and not (tv in num_types and tk in num_types):
			push_warning("Codex: 字段 %s 类型异常，已忽略" % k)
			continue
		_career[k] = v
	_career["version"] = 1
	# 老存档迁移：通关过但没记过次数 → 按 1 次算（解锁状态只多不少）
	if bool(_career.get("finished", false)) and int(_career.get("runWins", 0)) == 0:
		_career["runWins"] = 1

static func save() -> void:
	ensure_loaded()
	if not SafeFile.write(PATH, JSON.stringify(_career, "\t")):
		push_warning("Codex: 存档写入失败 %s" % PATH)

static func current() -> Dictionary:
	ensure_loaded()
	return _career

static func reset() -> void:
	_career = empty_career()
	_loaded = true
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

# ---------------- 成就判定 ----------------

## 判定一项成就。b 为空表示「非战斗触发」（通关/军师/事件等）
static func _meets(cond: Dictionary, c: Dictionary, b: Dictionary) -> bool:
	var kind := str(cond.get("t", ""))
	var has_b := not b.is_empty()
	match kind:
		"battle_win":
			return has_b and bool(b.get("win", false)) and int(c["wins"]) >= int(cond.get("min_wins", 1))
		"flawless":
			return has_b and bool(b.get("win", false)) and int(b.get("hp", 0)) >= int(b.get("maxHp", 1))
		"low_hp_win":
			return has_b and bool(b.get("win", false)) and int(b.get("hp", 999)) <= int(cond["hp"])
		"fast_win":
			return has_b and bool(b.get("win", false)) and int(b.get("turns", 999)) <= int(cond["turns"])
		"hero_dmg":
			return has_b and int(b.get("heroDmg", 0)) >= int(cond["min"])
		"units":
			return has_b and int(b.get("units", 0)) >= int(cond["min"])
		"spells":
			return has_b and int(b.get("spells", 0)) >= int(cond["min"])
		"level_win":
			return has_b and bool(b.get("win", false)) and str(b.get("level", "")) == str(cond["level"])
		"cleared":
			return int(c["clearedCount"]) >= int(cond["min"])
		"finished":
			return bool(c["finished"])
		"max_deck":
			return int(c["maxDeck"]) >= int(cond["min"])
		"heroes_won":
			var won: Dictionary = c["heroes"]
			for hid in (cond["ids"] as Array):
				if int(won.get(str(hid), 0)) <= 0:
					return false
			return true
		"battles":
			return int(c["battles"]) >= int(cond["min"])
		"best_streak":
			return int(c["bestStreak"]) >= int(cond["min"])
		"advisors":
			return (c["advisors"] as Dictionary).size() >= int(cond["min"])
		"events":
			return (c["events"] as Dictionary).size() >= int(cond["min"])
		"dmg":
			return int(c["dmg"]) >= int(cond["min"])
	return false

## 检查全部成就，返回本次新解锁的成就定义数组
static func check_all(b: Dictionary = {}) -> Array:
	ensure_loaded()
	var out: Array = []
	var ach: Dictionary = _career["ach"]
	for a in ACHIEVEMENTS:
		if ach.has(str(a["id"])):
			continue
		if _meets(a["cond"], _career, b):
			ach[str(a["id"])] = int(Time.get_unix_time_from_system())
			out.append(a)
	return out

static func unlocked_count() -> int:
	ensure_loaded()
	return (_career["ach"] as Dictionary).size()

static func is_unlocked(id: String) -> bool:
	ensure_loaded()
	return (_career["ach"] as Dictionary).has(id)

# ---------------- 记录入口 ----------------

## 一场战斗结束。b: {win, turns, hp, maxHp, heroId, level, dmg, heroDmg, units, spells}
static func record_battle(b: Dictionary) -> Array:
	ensure_loaded()
	var now := int(Time.get_unix_time_from_system())
	if int(_career["firstPlayed"]) == 0:
		_career["firstPlayed"] = now
	_career["lastPlayed"] = now

	_career["battles"] = int(_career["battles"]) + 1
	_career["turns"] = int(_career["turns"]) + int(b.get("turns", 0))
	_career["dmg"] = int(_career["dmg"]) + int(b.get("dmg", 0))
	_career["heroDmg"] = int(_career["heroDmg"]) + int(b.get("heroDmg", 0))
	_career["units"] = int(_career["units"]) + int(b.get("units", 0))
	_career["spells"] = int(_career["spells"]) + int(b.get("spells", 0))

	if bool(b.get("win", false)):
		_career["wins"] = int(_career["wins"]) + 1
		_career["streak"] = int(_career["streak"]) + 1
		if int(_career["streak"]) > int(_career["bestStreak"]):
			_career["bestStreak"] = int(_career["streak"])
		var heroes: Dictionary = _career["heroes"]
		var hid := str(b.get("heroId", ""))
		if hid != "":
			heroes[hid] = int(heroes.get(hid, 0)) + 1
		var levels: Dictionary = _career["levels"]
		var lv := str(b.get("level", ""))
		if lv != "":
			levels[lv] = int(levels.get(lv, 0)) + 1
		var hp := int(b.get("hp", 0))
		if int(_career["bestHpWin"]) < 0 or hp < int(_career["bestHpWin"]):
			_career["bestHpWin"] = hp
		var turns := int(b.get("turns", 0))
		if int(_career["fastestWin"]) < 0 or turns < int(_career["fastestWin"]):
			_career["fastestWin"] = turns
	else:
		_career["losses"] = int(_career["losses"]) + 1
		_career["streak"] = 0

	var unlocked := check_all(b)
	save()
	return unlocked

## 一场 PvP 切磋结束：只记胜负场次，不影响单机战绩与成就
static func record_pvp(win: bool) -> void:
	ensure_loaded()
	var now := int(Time.get_unix_time_from_system())
	if int(_career["firstPlayed"]) == 0:
		_career["firstPlayed"] = now
	_career["lastPlayed"] = now
	if win:
		_career["pvpWins"] = int(_career.get("pvpWins", 0)) + 1
	else:
		_career["pvpLosses"] = int(_career.get("pvpLosses", 0)) + 1
	save()

## 首次通关某关。idx 从 0 起，total 为关卡总数
## mode 为难度档位（"chuben" = 初阵），初阵首次通关单独计数
static func record_clear(stage_id: String, idx: int, deck_size: int, total: int,
		ascension_level: int = 0, mode: String = "") -> Array:
	ensure_loaded()
	var cleared: Dictionary = _career["clearedStages"]
	if not cleared.has(stage_id):
		cleared[stage_id] = int(Time.get_unix_time_from_system())
		_career["clearedCount"] = cleared.size()
		if mode == "chuben":
			_career["chubenClears"] = int(_career.get("chubenClears", 0)) + 1
		if idx > int(_career["maxStage"]):
			_career["maxStage"] = idx
			_career["maxStageId"] = stage_id
	# 整轮通关的成绩每次都记：心魔解锁靠它。这段不能塞进上面的「首次通关」分支——
	# 通过一次之后 8 关全在 clearedStages 里，再打心魔就永远进不来。
	if total > 0 and cleared.size() >= total:
		_career["finished"] = true
		_career["runWins"] = int(_career.get("runWins", 0)) + 1
		if ascension_level > int(_career.get("ascensionBest", 0)):
			_career["ascensionBest"] = ascension_level
	if deck_size > int(_career["maxDeck"]):
		_career["maxDeck"] = deck_size
	var unlocked := check_all()
	save()
	return unlocked

static func record_advisor(advisor_id: String) -> Array:
	if advisor_id == "":
		return []
	ensure_loaded()
	var advs: Dictionary = _career["advisors"]
	advs[advisor_id] = int(advs.get(advisor_id, 0)) + 1
	var unlocked := check_all()
	save()
	return unlocked

static func record_event(event_id: String) -> Array:
	if event_id == "":
		return []
	ensure_loaded()
	var evs: Dictionary = _career["events"]
	evs[event_id] = int(evs.get(event_id, 0)) + 1
	var unlocked := check_all()
	save()
	return unlocked

# ---------------- 心魔解锁 ----------------

static func ascension_best() -> int:
	ensure_loaded()
	return int(_career.get("ascensionBest", 0))

## 可选的心魔上限：还没通关过 → 只有常规；通过常规 → 1 级；通过心魔 N → N+1 级
static func ascension_unlocked() -> int:
	ensure_loaded()
	if not bool(_career.get("finished", false)):
		return 0
	return clampi(ascension_best() + 1, 0, Campaign.ascension_max())

# ---------------- 解锁式 meta ----------------

static func run_wins() -> int:
	ensure_loaded()
	return int(_career.get("runWins", 0))

## 当前解锁状态（advisors/events = 已解锁 id 表，level = 已达梯级）
static func unlock_state() -> Dictionary:
	ensure_loaded()
	return Campaign.unlock_state({
		"runWins": int(_career.get("runWins", 0)),
		"ascensionBest": int(_career.get("ascensionBest", 0)),
	})

# ---------------- 摘要 ----------------

static func summary() -> Dictionary:
	ensure_loaded()
	var battles := int(_career["battles"])
	return {
		"battles": battles,
		"wins": int(_career["wins"]),
		"losses": int(_career["losses"]),
		"pvpWins": int(_career.get("pvpWins", 0)),
		"pvpLosses": int(_career.get("pvpLosses", 0)),
		"winRate": roundi(float(_career["wins"]) / float(battles) * 100.0) if battles > 0 else 0,
		"streak": int(_career["streak"]),
		"bestStreak": int(_career["bestStreak"]),
		"turns": int(_career["turns"]),
		"dmg": int(_career["dmg"]),
		"heroDmg": int(_career["heroDmg"]),
		"units": int(_career["units"]),
		"spells": int(_career["spells"]),
		"bestHpWin": int(_career["bestHpWin"]),
		"fastestWin": int(_career["fastestWin"]),
		"clearedCount": int(_career["clearedCount"]),
		"chubenClears": int(_career.get("chubenClears", 0)),
		"maxStage": int(_career["maxStage"]),
		"maxDeck": int(_career["maxDeck"]),
		"finished": bool(_career["finished"]),
		"advisors": (_career["advisors"] as Dictionary).size(),
		"events": (_career["events"] as Dictionary).size(),
		"ach": unlocked_count(),
	}

# ---------------- 图鉴 ----------------

## 筛选卡牌。opts: {faction: all|neutral|han|chu, type: all|piece|spell}
## 排序口径与 Web 版一致：先按费用，兵种在计谋前，再按名称
static func filter_cards(opts: Dictionary = {}) -> Array:
	GameData.ensure_loaded()
	var fac := str(opts.get("faction", "all"))
	var typ := str(opts.get("type", "all"))
	var out: Array = []
	for id in GameData.cards.keys():
		var cid := str(id)
		if cid == "s_xianji":
			continue                                  # 先机虎符不算构筑卡
		var c: Dictionary = GameData.cards[id]
		if typ != "all" and str(c.get("type", "")) != typ:
			continue
		if fac != "all" and GameData.faction_of(cid) != fac:
			continue
		out.append(cid)
	out.sort_custom(func (a: String, b: String) -> bool:
		var ca: Dictionary = GameData.cards[a]
		var cb: Dictionary = GameData.cards[b]
		if int(ca["cost"]) != int(cb["cost"]):
			return int(ca["cost"]) < int(cb["cost"])
		if str(ca["type"]) != str(cb["type"]):
			return str(ca["type"]) == "piece"
		return str(ca["name"]) < str(cb["name"]))
	return out

static func card_stats() -> Dictionary:
	var all := filter_cards()
	var by_faction := {"neutral": 0, "han": 0, "chu": 0}
	var by_type := {"piece": 0, "spell": 0}
	for cid in all:
		var f := GameData.faction_of(str(cid))
		by_faction[f] = int(by_faction.get(f, 0)) + 1
		var t := str(GameData.card(str(cid)).get("type", "piece"))
		by_type[t] = int(by_type.get(t, 0)) + 1
	return {"total": all.size(), "byFaction": by_faction, "byType": by_type}

## 测试用：清空内存态（不删档）
static func _reset_memory() -> void:
	_career = {}
	_loaded = false
