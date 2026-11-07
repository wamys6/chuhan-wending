## 中英双语：文案查表 + 数据层换语言 + 战报/关键词按语言渲染
##
## 三条原则：
##   1. 英文内容只有一份来源——Web 版的 js/lang-en.js（已被人工审过），
##      由 tools/export-i18n.js 导成 data/lang-en.json；Godot 独有的界面文案
##      另放 data/lang-godot-en.json，两处合并成一张表。
##   2. 翻译收在渲染出口：UiTheme.label()/button() 是全部界面的唯一入口，
##      在那里统一过 T()，比给每句话手工包一遍可靠。动态拼出来的句子
##      （「血量 22 / 22」这类）由 RULES 里的模板规则处理。
##   3. 中文是数据源：切英文时把 GameData 里的 name/desc 就地改掉（不是换一份
##      数据），这样图鉴、地图、奖励这些「读 GameData 就画」的界面自动跟着变；
##      切回中文用 _zh 快照还原。
##
## 缺翻译不会崩——T() 原样返回中文，同时记进 missing 列表，测试会把它列出来。
class_name I18n
extends RefCounted

const ZH := "zh"
const EN := "en"

const EN_PATH := "res://data/lang-en.json"
## Godot 端独有的界面文案（Web 版没有的按钮/提示），手写维护
const EXTRA_PATH := "res://data/lang-godot-en.json"

## 数字嵌在句中的模板。{1}{2} 按正则分组顺序替换。
## 注意：模板里不要留中文，否则等于没翻译。
const RULES := [
	# —— 战场数值 ——
	["^血量 ([0-9]+) / ([0-9]+)$", "Health {1} / {2}"],
	# —— 战役地图的常驻加成 ——
	["^死战专精 \\+([0-9]+)/\\+([0-9]+)$", "Last Stand mastery +{1}/+{2}"],
	["^血量 ([0-9]+)$", "Health {1}"],
	["^军粮 ([0-9]+) / ([0-9]+)$", "Provision {1} / {2}"],
	["^军粮 ([0-9]+)$", "Provision {1}"],
	# —— 回合 ——
	["^第 ([0-9]+) 回合 · 我方行动$", "Turn {1} · Your move"],
	["^第 ([0-9]+) 回合 · 敌方行动$", "Turn {1} · Enemy move"],
	["^第 ([0-9]+) 回合 · 我方行动 · ([0-9]+) 秒$", "Turn {1} · Your move · {2}s"],
	["^第 ([0-9]+) 回合$", "Turn {1}"],
	["^([0-9]+) 回合$", "{1} turns"],
	# —— 出牌被拒 · 军阵列满 ——
	# 数字来自 COLUMN_LIMIT，不能写死；列名在英文模式下已是 Vanguard/Center/Rear
	# （apply_data 会把 RANK_NAMES 整表换掉），所以 {1} 直接复用即可。
	["^(.+)列已满（每列最多 ([0-9]+) 员）$", "The {1} column is full ({2} per column)"],
	["^每列最多站 ([0-9]+) 员。先打完这一列，或把牌出到别的列。$",
		"Each column holds at most {1} units. Clear this one first, or deploy into another column."],
	# —— 卡面 ——
	["^([0-9]+) 费$", "{1} Prov"],
	["^([0-9]+) 攻 / ([0-9]+) 血$", "{1} Atk / {2} HP"],
	["^([0-9]+) 攻 · ([0-9]+) 血$", "{1} Atk · {2} HP"],
	# —— 技能按钮的悬浮说明 ——
	["^(.+)（([0-9]+) 军粮）\\n(.+)$", "{1} ({2} Provisions)\n{3}"],
	# —— 军师主动技按钮（P6）——
	["^(.+)（([0-9]+) 军粮 · 每场一次）\\n(.+)$", "{1} ({2} Provisions · once per battle)\n{3}"],
	["^(.+) · 已用$", "{1} · used"],
	# —— 成就横幅 / 关卡名号 ——
	["^「(.+)」已 破$", "“{1}” Taken"],
	["^「(.+)」已破$", "“{1}” Taken"],
	["^「(.+)」(.+)$", "“{1}” {2}"],
	["^此战失利，可回师再战 · 目标：(.+)$", "Defeat — regroup and try again · Objective: {1}"],
	["^此战失利，尚可重整一次 · 目标：(.+)$", "Defeat — one rally left · Objective: {1}"],
	["^重整机会已尽，大军溃散 · 目标：(.+)$", "No rally left — the host scatters · Objective: {1}"],
	# —— 战绩数字 ——
	["^造成伤害 ([0-9]+)　直击主将 ([0-9]+)　出兵 ([0-9]+)　用计 ([0-9]+)$",
		"Damage {1}　Commander {2}　Deployed {3}　Spells {4}"],
	["^胜 ([0-9]+) · 负 ([0-9]+)$", "{1} W · {2} L"],
	["^共 ([0-9]+) 场$", "{1} battles"],
	["^最长 ([0-9]+) 连胜$", "Best {1} in a row"],
	["^其中直击主将 ([0-9]+)$", "{1} to commanders"],
	["^用计 ([0-9]+) 次$", "{1} spells"],
	["^共 ([0-9]+) 位$", "{1} total"],
	["^共 ([0-9]+) 个$", "{1} total"],
	["^([0-9]+) 点$", "{1} HP"],
	["^([0-9]+) 张$", "{1} cards"],
	# —— 选牌层：多选时提示还剩几张 ——
	["^（还需 ([0-9]+) 张）$", " ({1} more to pick)"],
	# —— 地图 / 存档位 ——
	["^进度　([0-9]+) / ([0-9]+)$", "Progress　{1} / {2}"],
	["^已通关 ([0-9]+) / ([0-9]+)$", "Cleared {1} / {2}"],
	["^生涯作战 ([0-9]+) 场 · 胜 ([0-9]+) 场$", "Career: {1} battles · {2} wins"],
	# —— PvP ——
	["^负 ([0-9]+) 场（好友对战）$", "{1} losses (friend battles)"],
	["^动作序列错位（本端 ([0-9]+) / 对端 ([0-9]+)）$", "Action desync (local {1} / remote {2})"],
	["^战役 ([0-9]+) 关 · 卡池 ([0-9]+) 张$", "Campaign of {1} stages · {2}-card pool"],
	["^战役已终 · ([0-9]+) 关全胜$", "Campaign complete · {1} stages taken"],
	["^下一关　(.+)$", "Next　{1}"],
	["^本局难度　(.+)$", "Difficulty　{1}"],
	["^难度　　初阵$", "Difficulty　　Novice"],
	# 初阵档位说明（数字由 Campaign.CHUBEN_* 生成，不写死）
	["^初阵：主将 \\+([0-9]+) 血、敌军首回合 -([0-9]+) 军粮，适合新手$",
		"Novice: commander +{1} HP, enemy starts {2} Provision short — for new players"],
	["^心魔 ([0-9]+)$", "Demon {1}"],
	["^牌组　　([0-9]+) 张$", "Deck　　{1} cards"],
	["^军师　　(.+)$", "Strategist　　{1}"],
	["^生命　　([+-][0-9]+)$", "Health　　{1}"],
	["^保存　　(.+)$", "Saved　　{1}"],
	# —— 图鉴 ——
	["^卡池 ([0-9]+) 张 · 成就 ([0-9]+) / ([0-9]+)$", "{1} cards · Achievements {2} / {3}"],
	["^中立 ([0-9]+) · 汉 ([0-9]+) · 楚 ([0-9]+)\\n兵种 ([0-9]+) · 计谋 ([0-9]+)$",
		"Neutral {1} · Han {2} · Chu {3}\nUnits {4} · Tactics {5}"],
	# 分组标题：「Battlefield　·　2 / 8」——分组名已英文，只有分隔与计数要处理
	["^(.+)　·　([0-9]+) / ([0-9]+)$", "{1}　·　{2} / {3}"],
	# 卡面元信息：「兵种 · 中军 · 1 攻 · 4 血」
	["^兵种 · (.+) · ([0-9]+) 攻 · ([0-9]+) 血$", "Unit · {1} · {2} Atk · {3} HP"],
	["^计谋 · ([0-9]+) 费$", "Stratagem · {1} Prov"],
	# 关卡目标条：「本关目标 · 击破秦军校尉」
	["^本关目标 · (.+)$", "Objective · {1}"],
	# 地图顶栏：「主将　刘邦」「军师　张良」
	["^主将　(.+)$", "Commander　{1}"],
	["^军师　(.+)$", "Strategist　{1}"],
	# 地图加成 chips：「生命 +3」「军粮 -1」「起手 +1」「敌粮 +2」
	["^生命 ([+-][0-9]+)$", "Health {1}"],
	["^军粮 ([+-][0-9]+)$", "Provision {1}"],
	["^起手 ([+-][0-9]+)$", "Opening draw {1}"],
	["^敌粮 ([+-][0-9]+)$", "Enemy prov {1}"],
	# 菜单主按钮：「继 续 战 役  ·  1 / 8」（去空白后匹配）
	["^继续战役·([0-9]+)/([0-9]+)$", "CONTINUE · {1} / {2}"],
	# 菜单页脚
	["^战役：([0-9]+) 关 · 卡池 ([0-9]+) 张 · (.+)$", "Campaign: {1} stages · {2} cards · {3}"],
	# 战斗血条：牌库余量与疲劳告警（疲劳 N = 下一跳伤害，N = 已跳数 + 1）
	["^牌库 ([0-9]+)$", "Deck {1}"],
	["^疲劳 ([0-9]+) 伤$", "Fatigue {1}"],
	# 兵败战报
	["^([0-9]+) 回合 · 造成 ([0-9]+) 伤 · 出兵 ([0-9]+) · 敌将余 ([0-9]+) 血$",
		"{1} turns · {2} damage dealt · {3} units played · enemy at {4} HP"],
]

## 当前语言（与应用启动时从 Settings 读入的值同步）
static var lang := ZH
## 缺翻译的原文（测试会打印；发布前应为空）
static var missing: Array = []

static var _loaded := false
static var _en: Dictionary = {}
static var _ui: Dictionary = {}          # 中文原文 → 英文
static var _ui_squash: Dictionary = {}   # 去空白后的键 → 英文（「战 报」与「战报」都能命中）
static var _regex: Array = []            # [{re, tpl}]
static var _zh: Dictionary = {}          # 中文数据快照
static var _snapshot_done := false

# ---------------- 装载 ----------------

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_en = _read_json(EN_PATH)
	var extra := _read_json(EXTRA_PATH)
	var ui: Dictionary = {}
	if _en.get("ui") is Dictionary:
		ui = (_en["ui"] as Dictionary).duplicate()
	if extra.get("ui") is Dictionary:
		for k in (extra["ui"] as Dictionary).keys():
			ui[k] = extra["ui"][k]
	_ui = ui
	for k in _ui.keys():
		_ui_squash[_squash(str(k))] = _ui[k]
	for r in RULES:
		var re := RegEx.new()
		if re.compile(str(r[0])) == OK:
			_regex.append({"re": re, "tpl": str(r[1])})
		else:
			push_warning("I18n: 规则编译失败 " + str(r[0]))

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(raw) != OK or not (j.data is Dictionary):
		push_warning("I18n: 解析失败 " + path)
		return {}
	return j.data

static func _squash(s: String) -> String:
	return s.replace(" ", "").replace("\u3000", "").replace("\n", "")

# ---------------- 语言切换 ----------------

static func is_en() -> bool:
	return lang == EN

## 玩家在设置面板里主动切语言：改内存 + 落盘
static func set_lang(l: String) -> void:
	_apply_lang(l)
	Settings.set_lang(lang)

## 只改运行期语言、不写盘。启动时读设置、命令行 --lang 覆盖、测试切语言都走
## 这个：免得「只是看一眼英文」就把玩家的语言偏好永久改掉
static func set_lang_soft(l: String) -> void:
	_apply_lang(l)

static func _apply_lang(l: String) -> void:
	lang = EN if l == EN else ZH
	apply_data()

## 启动时调用：语言取自设置，并把数据层摆到对应语言
static func init_from_settings() -> void:
	Settings.ensure_loaded()
	set_lang_soft(str(Settings.lang))

# ---------------- 文案 ----------------

## 翻译一段文案。中文模式下原样返回；英文模式按 精确 → 去空白 → 数字模板 依次尝试。
## 参数收 Variant，方便在赋值处直接包一层（数字/非字符串也不会炸）。
static func T(v) -> String:
	var s := str(v)
	if s == "":
		return s
	ensure_loaded()
	if lang != EN:
		return s
	# 本来就是英文（换语言后数据层已是英文）直接放行，不必查表也不必记缺
	if not has_cjk(s):
		return _clean(s)
	if _ui.has(s):
		return _clean(str(_ui[s]))
	var sq := _squash(s)
	if _ui_squash.has(sq):
		return _clean(str(_ui_squash[sq]))
	# 模板规则：先按原样匹配，再按去空白匹配（中文排版常插空格，如「继 续 战 役」）
	var hit := _apply_rules(s)
	if hit != "":
		return _clean(hit)
	hit = _apply_rules(sq)
	if hit != "":
		return _clean(hit)
	if not missing.has(s):
		missing.append(s)
	return s

## 英文排版收尾：中文排版用的全角空格在英文里很丑，统一成普通空格
static func _clean(s: String) -> String:
	return s.replace("\u3000", " ")

static func _apply_rules(s: String) -> String:
	for rule in _regex:
		var m: RegExMatch = (rule["re"] as RegEx).search(s)
		if m == null:
			continue
		var out: String = str(rule["tpl"])
		for i in range(1, 10):
			var ph := "{%d}" % i
			if out.contains(ph):
				out = out.replace(ph, m.get_string(i))
		return out
	return ""

## 是否含汉字（判断一段文案要不要翻译／有没有漏译）
static func has_cjk(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			return true
		# 中文标点也算「中文文案」：漏译时多半连着标点一起漏（全角空格除外）
		if c == 0x3000:
			continue
		if c >= 0x3001 and c <= 0x303F:
			return true
		if c >= 0xFF00 and c <= 0xFFEF:
			return true
	return false

static func has_text(key: String) -> bool:
	ensure_loaded()
	return _ui.has(key) or _ui_squash.has(_squash(key))

# ---------------- 数据取词 ----------------

static func card_en(id: String) -> Dictionary:
	ensure_loaded()
	var c = _en.get("cards", {}).get(id, {})
	return c if c is Dictionary else {}

static func card_name(id: String, fallback: String = "") -> String:
	if not is_en():
		return fallback if fallback != "" else str(GameData.card(id).get("name", id))
	var c := card_en(id)
	return str(c.get("name", fallback if fallback != "" else id))

static func card_desc(id: String, fallback: String = "") -> String:
	if not is_en():
		return fallback if fallback != "" else str(GameData.card(id).get("desc", ""))
	var c := card_en(id)
	return str(c.get("desc", fallback))

static func hero_field(id: String, field: String, fallback: String = "") -> String:
	ensure_loaded()
	if not is_en():
		return fallback
	var h = _en.get("heroes", {}).get(id, {})
	if not (h is Dictionary):
		return fallback
	return str(h.get(field, fallback))

static func skill_field(id: String, field: String, fallback: String = "") -> String:
	ensure_loaded()
	if not is_en():
		return fallback
	var h = _en.get("heroes", {}).get(id, {})
	if not (h is Dictionary) or not (h.get("skill") is Dictionary):
		return fallback
	return str((h["skill"] as Dictionary).get(field, fallback))

static func achievement_field(id: String, field: String, fallback: String = "") -> String:
	ensure_loaded()
	if not is_en():
		return fallback
	var a = _en.get("achievements", {}).get(id, {})
	if not (a is Dictionary):
		return fallback
	return str(a.get(field, fallback))

static func achievement_group(id: String, fallback: String = "") -> String:
	ensure_loaded()
	if not is_en():
		return fallback
	var g = _en.get("groups", {}).get(id, null)
	return str(g) if g != null else fallback

## 军师/事件这类「数组里找 id」的数据，英文模式直接按 id 取
static func advisor_field(id: String, field: String, fallback: String = "") -> String:
	ensure_loaded()
	if not is_en():
		return fallback
	var a = _en.get("advisors", {}).get(id, {})
	if not (a is Dictionary):
		return fallback
	return str(a.get(field, fallback))

static func event_field(id: String, field: String, fallback: String = "") -> String:
	ensure_loaded()
	if not is_en():
		return fallback
	var e = _en.get("events", {}).get(id, {})
	if not (e is Dictionary):
		return fallback
	return str(e.get(field, fallback))

static func event_option(id: String, index: int, field: String, fallback: String = "") -> String:
	ensure_loaded()
	if not is_en():
		return fallback
	var e = _en.get("events", {}).get(id, {})
	if not (e is Dictionary) or not (e.get("options") is Array):
		return fallback
	var opts: Array = e["options"]
	if index < 0 or index >= opts.size():
		return fallback
	var o = opts[index]
	if not (o is Dictionary):
		return fallback
	return str(o.get(field, fallback))

static func stage_field(id: String, field: String, fallback: String = "") -> String:
	ensure_loaded()
	if not is_en():
		return fallback
	var s = _en.get("stages", {}).get(id, {})
	if not (s is Dictionary):
		return fallback
	return str(s.get(field, fallback))

static func stage_enemy_field(id: String, field: String, fallback: String = "") -> String:
	ensure_loaded()
	if not is_en():
		return fallback
	var s = _en.get("stages", {}).get(id, {})
	if not (s is Dictionary) or not (s.get("enemy") is Dictionary):
		return fallback
	return str((s["enemy"] as Dictionary).get(field, fallback))

## 关键词：当前语言的「名称 → 释义」表
static func keyword_pairs() -> Array:
	ensure_loaded()
	var out: Array = []
	if not is_en():
		for k in Tutorial.KEYWORDS.keys():
			out.append({"name": str(k), "text": str(Tutorial.KEYWORDS[k])})
		return out
	var list: Array = _en.get("keywordList", [])
	var kw: Dictionary = _en.get("keywords", {})
	for name in list:
		var n := str(name)
		out.append({"name": n, "text": str(kw.get(n, ""))})
	# 解释性词条（不进牌面加粗，但浮层里要解释）
	for name in ["Summoning Sickness", "Provisions"]:
		if kw.has(name):
			out.append({"name": name, "text": str(kw[name])})
	return out

static func keyword_list() -> Array:
	ensure_loaded()
	if not is_en():
		return Tutorial.KEYWORD_LIST
	return (_en.get("keywordList", []) as Array).duplicate()

## 单位圆牌上的字形（中文是「兵」「马」，英文用两字母代号）
static func glyph(ch: String) -> String:
	ensure_loaded()
	if not is_en():
		return ch
	var g: Dictionary = _en.get("glyphs", {})
	return str(g.get(ch, ch))

# ---------------- 数据层换语言 ----------------

## 中文模式下的原始数据快照（只做一次）
static func _take_snapshot() -> void:
	if _snapshot_done:
		return
	_snapshot_done = true
	GameData.ensure_loaded()
	_zh = {
		"cards": GameData.cards.duplicate(true),
		"heroes": GameData.heroes.duplicate(true),
		"stages": GameData.stages.duplicate(true),
		"advisors": GameData.advisors.duplicate(true),
		"events": GameData.events.duplicate(true),
		"ascension": GameData.ascension.duplicate(true),
		"tianshi": GameData.tianshi.duplicate(true),
		"ranks": (GameData.constants.get("RANK_NAMES", {}) as Dictionary).duplicate(true),
	}

## 把 GameData 里的展示字段摆成当前语言。
## 就地改（不换容器），这样已经持有这些字典引用的界面也能立刻看到新文案。
static func apply_data() -> void:
	ensure_loaded()
	GameData.ensure_loaded()
	_take_snapshot()
	var en := is_en()
	var en_cards: Dictionary = _en.get("cards", {})
	var en_heroes: Dictionary = _en.get("heroes", {})
	var en_stages: Dictionary = _en.get("stages", {})
	var en_advisors: Dictionary = _en.get("advisors", {})
	var en_events: Dictionary = _en.get("events", {})
	var zh_cards: Dictionary = _zh["cards"]
	var zh_heroes: Dictionary = _zh["heroes"]

	for id in GameData.cards.keys():
		var c: Dictionary = GameData.cards[id]
		var zc: Dictionary = zh_cards.get(id, {})
		if en and en_cards.has(id):
			c["name"] = en_cards[id].get("name", c.get("name", ""))
			c["desc"] = en_cards[id].get("desc", c.get("desc", ""))
		else:
			c["name"] = zc.get("name", c.get("name", ""))
			c["desc"] = zc.get("desc", c.get("desc", ""))

	for id in GameData.heroes.keys():
		var h: Dictionary = GameData.heroes[id]
		var zh_h: Dictionary = zh_heroes.get(id, {})
		if en and en_heroes.has(id):
			var eh: Dictionary = en_heroes[id]
			h["name"] = eh.get("name", h.get("name", ""))
			h["title"] = eh.get("title", h.get("title", ""))
			h["intro"] = eh.get("intro", h.get("intro", ""))
			if h.get("skill") is Dictionary and eh.get("skill") is Dictionary:
				var hs: Dictionary = h["skill"]
				hs["name"] = eh["skill"].get("name", hs.get("name", ""))
				hs["desc"] = eh["skill"].get("desc", hs.get("desc", ""))
		else:
			h["name"] = zh_h.get("name", h.get("name", ""))
			h["title"] = zh_h.get("title", h.get("title", ""))
			h["intro"] = zh_h.get("intro", h.get("intro", ""))
			if h.get("skill") is Dictionary and zh_h.get("skill") is Dictionary:
				var hs2: Dictionary = h["skill"]
				var zs: Dictionary = zh_h["skill"]
				hs2["name"] = zs.get("name", hs2.get("name", ""))
				hs2["desc"] = zs.get("desc", hs2.get("desc", ""))

	for i in GameData.stages.size():
		var s: Dictionary = GameData.stages[i]
		var zs2: Dictionary = _find_by_id(_zh["stages"], str(s.get("id", "")))
		var es = en_stages.get(str(s.get("id", "")), null)
		for f in ["chapter", "name", "year", "subtitle", "lore", "goalText"]:
			if en and es != null and es is Dictionary and es.has(f):
				s[f] = es[f]
			elif zs2.has(f):
				s[f] = zs2[f]
		var meta: Dictionary = {}
		if s.get("enemy") is Dictionary and s["enemy"].get("meta") is Dictionary:
			meta = s["enemy"]["meta"]
		var zmeta: Dictionary = {}
		if zs2.get("enemy") is Dictionary and zs2["enemy"].get("meta") is Dictionary:
			zmeta = zs2["enemy"]["meta"]
		if en and es != null and es is Dictionary and es.get("enemy") is Dictionary:
			var ee: Dictionary = es["enemy"]
			if meta.has("name") and ee.has("name"):
				meta["name"] = ee["name"]
			if meta.has("title") and ee.has("title"):
				meta["title"] = ee["title"]
		else:
			if meta.has("name") and zmeta.has("name"):
				meta["name"] = zmeta["name"]
			if meta.has("title") and zmeta.has("title"):
				meta["title"] = zmeta["title"]

	for i in GameData.advisors.size():
		var a: Dictionary = GameData.advisors[i]
		var za: Dictionary = _find_by_id(_zh["advisors"], str(a.get("id", "")))
		var ea = en_advisors.get(str(a.get("id", "")), null)
		for f in ["name", "title", "desc", "flavor"]:
			if en and ea != null and ea is Dictionary and ea.has(f):
				a[f] = ea[f]
			elif za.has(f):
				a[f] = za[f]
		# 主动技（P6）是一个嵌套字典，主循环的浅字段覆盖管不到它
		var zact: Dictionary = (za.get("active", {}) as Dictionary) if za.has("active") else {}
		var eact: Dictionary = (ea.get("active", {}) as Dictionary) if (ea != null and ea is Dictionary and ea.has("active")) else {}
		if a.has("active") and a["active"] is Dictionary:
			for f in ["name", "desc"]:
				if en and eact.has(f):
					a["active"][f] = eact[f]
				elif zact.has(f):
					a["active"][f] = zact[f]

	for i in GameData.events.size():
		var e: Dictionary = GameData.events[i]
		var ze: Dictionary = _find_by_id(_zh["events"], str(e.get("id", "")))
		var ee2 = en_events.get(str(e.get("id", "")), null)
		for f in ["name", "text"]:
			if en and ee2 != null and ee2 is Dictionary and ee2.has(f):
				e[f] = ee2[f]
			elif ze.has(f):
				e[f] = ze[f]
		var zopts: Array = ze.get("options", [])
		var eopts: Array = (ee2.get("options", []) as Array) if (ee2 != null and ee2 is Dictionary) else []
		for oi in (e.get("options", []) as Array).size():
			var o: Dictionary = e["options"][oi]
			for f in ["label", "hint"]:
				if en and oi < eopts.size() and eopts[oi] is Dictionary and eopts[oi].has(f):
					o[f] = eopts[oi][f]
				elif oi < zopts.size() and zopts[oi] is Dictionary and zopts[oi].has(f):
					o[f] = zopts[oi][f]

	# 心魔表按序号对齐（表里没有 id，顺序即等级）
	var zh_asc: Array = _zh.get("ascension", [])
	var en_asc: Array = _en.get("ascension", [])
	for i in GameData.ascension.size():
		var a2: Dictionary = GameData.ascension[i]
		var za2: Dictionary = zh_asc[i] if i < zh_asc.size() else {}
		var ea2 = en_asc[i] if i < en_asc.size() else null
		for f in ["name", "desc"]:
			if en and ea2 != null and ea2 is Dictionary and ea2.has(f):
				a2[f] = ea2[f]
			elif za2.has(f):
				a2[f] = za2[f]

	# 解锁梯按序号对齐（表里没有 id，顺序即梯级）
	var zh_unl: Array = _zh.get("unlocks", [])
	var en_unl: Array = _en.get("unlocks", [])
	var unl_ladder: Array = GameData.unlocks.get("ladder", [])
	for i in unl_ladder.size():
		var u2: Dictionary = unl_ladder[i]
		var zu2: Dictionary = zh_unl[i] if i < zh_unl.size() else {}
		var eu2 = en_unl[i] if i < en_unl.size() else null
		for f in ["desc"]:
			if en and eu2 != null and eu2 is Dictionary and eu2.has(f):
				u2[f] = eu2[f]
			elif zu2.has(f):
				u2[f] = zu2[f]

	for i in GameData.tianshi.size():
		var t2: Dictionary = GameData.tianshi[i]
		var zt2: Dictionary = _find_by_id(_zh["tianshi"], str(t2.get("id", "")))
		var et2 = _en.get("tianshi", {}).get(str(t2.get("id", "")), null)
		for f in ["name", "desc"]:
			if en and et2 != null and et2 is Dictionary and et2.has(f):
				t2[f] = et2[f]
			elif zt2.has(f):
				t2[f] = zt2[f]

	var ranks: Dictionary = GameData.constants.get("RANK_NAMES", {})
	var zranks: Dictionary = _zh["ranks"]
	var eranks: Dictionary = _en.get("ranks", {})
	for r in ranks.keys():
		if en and eranks.has(r):
			ranks[r] = eranks[r]
		elif zranks.has(r):
			ranks[r] = zranks[r]

static func _find_by_id(list: Array, id: String) -> Dictionary:
	for it in list:
		if it is Dictionary and str(it.get("id", "")) == id:
			return it
	return {}

## 场上 state 里存的是卡牌副本，切语言要按 baseId 从（已换好语言的）GameData 重新取词
static func localize_state(state: Dictionary) -> void:
	if state.is_empty() or not (state.get("players") is Dictionary):
		return
	for pid in (state["players"] as Dictionary).keys():
		var p: Dictionary = state["players"][pid]
		for pool in ["hand", "deck"]:
			for c in (p.get(pool, []) as Array):
				if not (c is Dictionary) or not c.has("baseId"):
					continue
				var gd := GameData.card(str(c["baseId"]))
				if not gd.is_empty():
					c["name"] = str(gd.get("name", c.get("name", "")))
					c["desc"] = str(gd.get("desc", c.get("desc", "")))
		for rank in (p.get("board", {}) as Dictionary).keys():
			for u in (p["board"][rank] as Array):
				if not (u is Dictionary) or not u.has("baseId"):
					continue
				var gd2 := GameData.card(str(u["baseId"]))
				if not gd2.is_empty():
					u["name"] = str(gd2.get("name", u.get("name", "")))
					u["desc"] = str(gd2.get("desc", u.get("desc", "")))
		# 主将与技能名
		var hid := str(p.get("heroId", ""))
		if hid != "":
			var hd := GameData.hero(hid)
			if not hd.is_empty():
				p["name"] = str(hd.get("name", p.get("name", "")))
				p["title"] = str(hd.get("title", p.get("title", "")))
			if p.get("skill") is Dictionary and hd.get("skill") is Dictionary:
				var sk: Dictionary = p["skill"]
				var hsk: Dictionary = hd["skill"]
				sk["name"] = str(hsk.get("name", sk.get("name", "")))
				sk["desc"] = str(hsk.get("desc", sk.get("desc", "")))
