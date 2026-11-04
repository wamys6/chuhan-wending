## 新手引导数据层：关键词释义 + 一次性提示标记 + 引导完成标记
##
## 与 Web 版 js/tutorial.js 同口径。这里只管「数据与判定」，画界面的是 ui/coach.gd。
## 拆开的好处：关键词释义能被图鉴、卡牌浮层、引导三处共用，改一处全局生效。
##
## 存档：user://chuhan_tutorial.json
##   flags —— 某段引导是否已完成（如 battleIntro）
##   hints —— 某条规则提示是否已弹过（避免每回合都弹）
class_name Tutorial
extends RefCounted

const PATH := "user://chuhan_tutorial.json"
## 首局战斗的分步引导标记
const BATTLE_INTRO := "battleIntro"

## 关键词释义。牌面上加粗标注的只有 KEYWORD_LIST 里那六个真正的战斗关键词；
## 「军粮」「召唤失调」属于解释性词条，只出现在提示里，不在牌面画线。
const KEYWORDS := {
	"守御": "敌人必须先打掉它，才能碰到它后面的部队。",
	"迂回": "可以直接攻击敌方前锋或中军，不用等前面的列清空。",
	"远程": "可以攻击敌方任意一列，不受排列顺序限制。",
	"冲锋": "登场当回合就能攻击，不用等一回合。",
	"死战": "阵亡时触发一次效果，比如让友军全体加攻。",
	"连击": "本回合此前已经打出过别的牌，才会触发。",
	"召唤失调": "兵种登场当回合不能攻击（带「冲锋」的除外）。",
	"军粮": "出牌要花的资源。第 N 回合上限为 N（最多 10），每回合回满。",
}

## 牌面上会被标注/解释的关键词（顺序即扫描优先级）
const KEYWORD_LIST := ["守御", "迂回", "远程", "冲锋", "死战", "连击"]
## 牌面里出现时也值得解释，但不做加粗标注
const EXTRA_LIST := ["军粮", "召唤失调"]

static var _loaded := false
static var _flags: Dictionary = {}
static var _hints: Dictionary = {}

# ---------------- 读写 ----------------

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	# 用 JSON 实例而不是 parse_string：坏档只当作空档处理，不往控制台喷错误
	var j := JSON.new()
	if j.parse(raw) != OK or not (j.data is Dictionary):
		return
	var parsed: Dictionary = j.data
	var pf = parsed.get("flags")
	var ph = parsed.get("hints")
	if pf is Dictionary:
		_flags = pf
	if ph is Dictionary:
		_hints = ph

static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"flags": _flags, "hints": _hints}))
	f.close()

## 清空全部记录（设置面板里的「重置引导」）
static func reset() -> void:
	_flags = {}
	_hints = {}
	_loaded = true
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

## 强制重新从磁盘读（测试用）
static func _reload() -> void:
	_loaded = false
	_flags = {}
	_hints = {}
	_load()

# ---------------- 引导完成标记 ----------------

static func done(flag: String) -> bool:
	_load()
	return _flags.has(flag)

static func mark_done(flag: String) -> void:
	if flag == "":
		return
	_load()
	_flags[flag] = 1
	_save()

# ---------------- 一次性提示 ----------------

## 第一次调用返回 true（该弹），之后返回 false（弹过了）。
## 注意：判定与记录是同一次调用完成的，所以「只弹一次」是幂等的。
static func hint(id: String, force: bool = false) -> bool:
	_load()
	if not force and _hints.has(id):
		return false
	if not force:
		_hints[id] = 1
		_save()
	return true

static func hint_seen(id: String) -> bool:
	_load()
	return _hints.has(id)

# ---------------- 关键词 ----------------

## 文本里出现了哪些关键词（按出现位置排序，去重）
## 名称与释义都取当前语言：中文是「守御」，英文是 Taunt / Flank / Last Stand…
static func keywords_in(text: String) -> Array:
	var hits: Array = []
	for p in I18n.keyword_pairs():
		var name := str(p["name"])
		var idx := text.find(name)
		if idx >= 0:
			hits.append({"kw": name, "at": idx})
	hits.sort_custom(func (a: Dictionary, b: Dictionary) -> bool:
		return int(a["at"]) < int(b["at"]))
	var out: Array = []
	for h in hits:
		if not out.has(str(h["kw"])):
			out.append(str(h["kw"]))
	return out

static func explain(kw: String) -> String:
	for p in I18n.keyword_pairs():
		if str(p["name"]) == kw:
			return str(p["text"])
	return ""

## 牌面描述里出现的关键词的释义列表 [{kw, text}]，供卡牌浮层使用
static func explanations_for(text: String) -> Array:
	var out: Array = []
	for kw in keywords_in(text):
		out.append({"kw": kw, "text": explain(kw)})
	return out

## 把关键词用朱砂色裹起来（RichTextLabel 用），其余原文保留
static func highlight_bbcode(text: String) -> String:
	var out := text
	for name in I18n.keyword_list():
		var kw := str(name)
		if kw != "" and out.contains(kw):
			out = out.replace(kw, "[color=#7c1f1a][b]%s[/b][/color]" % kw)
	return out
