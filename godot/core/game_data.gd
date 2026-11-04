## 静态数据层：读取 data/game.json（由 tools/export-data.js 从 JS 版导出）
##
## 迁移期这套 JSON 与 JS 版共用同一份数值来源，避免手抄 46 张卡把平衡搞坏。
## 后期若改用 Godot 的 Resource（.tres）编辑，只需换掉这里的读取实现。
class_name GameData
extends RefCounted

const DATA_PATH := "res://data/game.json"

static var cards: Dictionary = {}
static var heroes: Dictionary = {}
static var decks: Dictionary = {}
static var stages: Array = []
static var advisors: Array = []
static var events: Array = []
static var ascension: Array = []
static var tianshi: Array = []
static var constants: Dictionary = {}
static var art: Dictionary = {}
static var faction: Dictionary = {}

static var _loaded := false

static func ensure_loaded() -> void:
	if _loaded:
		return
	var text := ""
	if FileAccess.file_exists(DATA_PATH):
		text = FileAccess.get_file_as_string(DATA_PATH)
	if text == "":
		push_error("GameData: 读不到 %s，请先运行 node tools/export-data.js" % DATA_PATH)
		return
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameData: game.json 解析失败")
		return
	cards = parsed["cards"]
	heroes = parsed["heroes"]
	decks = parsed["decks"]
	stages = parsed["stages"]
	advisors = parsed["advisors"]
	events = parsed["events"]
	ascension = parsed.get("ascension", [])
	tianshi = parsed.get("tianshi", [])
	constants = parsed["constants"]
	art = parsed.get("art", {})
	faction = parsed.get("faction", {})
	_loaded = true

static func hand_limit() -> int:
	ensure_loaded()
	return int(constants["HAND_LIMIT"])

static func column_limit() -> int:
	ensure_loaded()
	return int(constants["COLUMN_LIMIT"])

static func max_mana() -> int:
	ensure_loaded()
	return int(constants["MAX_MANA"])

static func rank_name(rank: String) -> String:
	ensure_loaded()
	return str(constants["RANK_NAMES"].get(rank, rank))

static func card(base_id: String) -> Dictionary:
	ensure_loaded()
	return cards.get(base_id, {})

static func has_card(base_id: String) -> bool:
	ensure_loaded()
	return cards.has(base_id)

static func hero(hero_id: String) -> Dictionary:
	ensure_loaded()
	return heroes.get(hero_id, {})

static func stage_by_id(stage_id: String) -> Dictionary:
	ensure_loaded()
	for s in stages:
		if s["id"] == stage_id:
			return s
	return {}

static func advisor_by_id(advisor_id: String) -> Dictionary:
	ensure_loaded()
	for a in advisors:
		if a["id"] == advisor_id:
			return a
	return {}

static func event_by_id(event_id: String) -> Dictionary:
	ensure_loaded()
	for e in events:
		if e["id"] == event_id:
			return e
	return {}

## 卡牌阵营归属（未登记的视为中立）
static func faction_of(card_id: String) -> String:
	ensure_loaded()
	return str(faction.get(card_id, "neutral"))
