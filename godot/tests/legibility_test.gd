## 可读性下限：字号不许太小、战报文案不许超出它所在的框
##
## 两件事都是「截图才看得出来」的那类问题，所以在测试里钉死：
##
## 一、字号下限。战报栏内宽 184px、卡面 128px 这些框都是按 1440×900 设计分辨率写死的，
##     1366×768 笔记本上整屏缩到 0.853 —— 12px 的字只剩 10.2px，汉字「牌库」「疲劳」
##     的撇捺开始糊在一起。所以全局最小字号定 13px（13×0.8=10.4，仍可辨）。
##
## 二、战报文案宽度。抬头行「—— 第 5 回合：我方（军粮 10/10）」实测 231px > 184px，
##     在每一块屏幕上都会折成两行，而且正好断在「军粮」两个字中间 —— 这个折行跟屏幕
##     大小无关，是文案本身放不下。判据用字体真实度量，不用眼睛。
##
## 运行：Godot --headless --path godot --script res://tests/legibility_test.gd
extends SceneTree

const MIN_FONT := 13
## 不用 preload：preload 会在 autoload 之前编译 battle.gd，那时 App 还没注册，
## 直接 Compile Error（Identifier not found: App）。运行到 _initialize 再 load。
var Battle: GDScript = null

var checks := 0
var failures := 0

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("  ✗ " + label + ("" if detail == "" else "  ← " + detail))

func _initialize() -> void:
	print("== 可读性下限 ==")
	Battle = load("res://scenes/battle.gd")
	ok(Battle != null, "battle.gd 拿得到（常量要对齐版式）")
	if Battle == null:
		print("通过 %d 项，失败 %d 项" % [checks, failures])
		quit(1)
		return
	_test_font_floor()
	_test_log_width()
	_test_hero_bar()
	_test_goal_line()
	_test_card_names()
	print("通过 %d 项，失败 %d 项" % [checks, failures])
	quit(0 if failures == 0 else 1)

# ---------------- 一、字号下限 ----------------

## 扫源码里的字号字面量。用一个小解析器取「UiTheme.label 的第二个实参」，
## 而不是正则数逗号——`UiTheme.label("a", 14, X)` 与 `panel_style(C, C, 13, 0)`
## 用正则根本分不开。
func _test_font_floor() -> void:
	var offenders: Array = []
	var scanned := 0
	var files: Array = []
	_walk("res://", files)
	for path in files:
		var src := FileAccess.get_file_as_string(str(path))
		if src == "":
			continue
		scanned += 1
		for n in _literal_sizes(src):
			if n < MIN_FONT:
				offenders.append("%s:%d" % [str(path).get_file(), n])
	ok(scanned > 30, "扫到了源码（%d 个 .gd）" % scanned, str(scanned))
	ok(offenders.is_empty(), "没有小于 %dpx 的字号" % MIN_FONT, str(offenders))

func _walk(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir_path.path_join(f)
		if d.current_is_dir():
			if not f.begins_with("."):
				_walk(p, out)
		elif f.ends_with(".gd"):
			out.append(p)
		f = d.get_next()
	d.list_dir_end()

func _literal_sizes(src: String) -> Array:
	var found: Array = []
	# UiTheme.label( ... , N, ... )：第 2 个实参若是整数就收
	for m in _calls(src, "UiTheme.label("):
		var args := _split_args(src, m)
		if args.size() >= 2:
			var a := str(args[1]).strip_edges()
			if a.is_valid_int():
				found.append(a.to_int())
	# add_theme_font_size_override("font_size", N)
	for m in _calls(src, "add_theme_font_size_override("):
		var args := _split_args(src, m)
		if args.size() == 2:
			var a := str(args[1]).strip_edges()
			if a.is_valid_int():
				found.append(a.to_int())
	# 常量阶梯 const FS_X := N
	var re := RegEx.new()
	re.compile("const\\s+FS_[A-Z_]+\\s*:=\\s*(\\d+)")
	for mm in re.search_all(src):
		found.append(mm.get_string(1).to_int())
	return found

## 返回每个调用点的「实参起始下标」（左括号之后）
func _calls(src: String, needle: String) -> Array:
	var out: Array = []
	var i := src.find(needle)
	while i >= 0:
		out.append(i + needle.length())
		i = src.find(needle, i + needle.length())
	return out

## 从 start 开始按逗号切实参，尊重括号、中英文引号、注释
func _split_args(src: String, start: int) -> Array:
	var args: Array = []
	var depth := 0
	var quote := ""
	var cur := ""
	var i := start
	while i < src.length():
		var c := src[i]
		if quote != "":
			cur += c
			if c == quote:
				quote = ""
			i += 1
			continue
		match c:
			"\"", "'":
				quote = c
				cur += c
			"(", "[", "{":
				depth += 1
				cur += c
			")":
				if depth == 0:
					args.append(cur)
					return args
				depth -= 1
				cur += c
			"]", "}":
				depth -= 1
				cur += c
			",":
				if depth == 0:
					args.append(cur)
					cur = ""
				else:
					cur += c
			_:
				cur += c
		i += 1
	return args

# ---------------- 二、战报文案宽度 ----------------

func _test_log_width() -> void:
	var f := UiTheme.font()
	var box: float = float(Battle.get_script_constant_map()["LOG_BOX_W"])
	ok(is_equal_approx(box, 184.0), "战报内宽仍是 184（版式没被偷偷改动）", str(box))

	var narrow: Array = []
	var wide: Array = []
	var args := {"n": 12, "m": 10, "mm": 10, "name": "Chariot", "rank": "Vanguard",
		"target": "Chariot", "a": 9, "d": 9, "h": 9, "side": "p1"}
	for lang in ["zh", "en"]:
		I18n.set_lang_soft(str(lang))
		# 最长的一行是抬头：回合数会变两位数、双方都要能站住
		for n in [1, 9, 10, 12, 20]:
			for side in ["p1", "p2"]:
				var a: Dictionary = args.duplicate()
				a["n"] = n
				a["side"] = side
				var line := LogText.render({"k": "turn", "a": a})
				var w := _width(f, line)
				if w > box:
					narrow.append("%s %s %.0f" % [lang, line, w])
		# 其余条目按 battle.gd 的 max_lines_visible 给预算：中文 2 行、英文 3 行。
		# 英文句子比中文长六成，两行会静默截断（实测最长 539px ≈ 2.9 行）。
		var budget: float = box * (3.0 if str(lang) == "en" else 2.0)
		for key in LogText.ZH.keys():
			if str(key) == "turn":
				continue
			var line2 := "· " + LogText.render({"k": key, "a": args})
			var w2 := _width(f, line2)
			if w2 > budget:
				wide.append("%s %s %.0f" % [lang, line2, w2])
	I18n.set_lang_soft("zh")

	ok(narrow.is_empty(), "战报抬头单行放得下（≤ %.0fpx）" % box, str(narrow))
	ok(wide.is_empty(), "其余战报条目不被截断（中 2 行 / 英 3 行）", str(wide))
	# 上界也要验：一条条都极短说明词表被换空过，判据会假通过
	var sample := _width(f, LogText.render({"k": "turn", "a": {"n": 12, "side": "p1"}}))
	ok(sample > box * 0.4, "抬头行确实有内容（%.0fpx）" % sample, str(sample))

func _width(f: Font, text: String) -> float:
	var fs := int(Battle.get_script_constant_map()["FS_SMALL"])
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

# ---------------- 三、主将卡两处「长度随语言变」的文字 ----------------

## 主将卡左栏名字只有 210px、右栏提示只有 136px。
## 中文都富余，英文会超出：名字「Xiang Yu · Hegemon-King」20px 要 252px，
## 提示「Click to strike the commander」13px 要 192px —— 后者右对齐且不裁剪，
## 直接溢出卡片、压到顶部的关卡目标条上（1920 商店截图里糊成一片才发现）。
## 判据：名字必须能在「20 或 16」里找到一档放得下（再小就低于正文档），
## 提示必须 13px 单行 ≤136；并且提示要开着裁剪，作为最后一道兜底。
func _test_hero_bar() -> void:
	var f := UiTheme.font()
	var name_w := 210.0
	var hint_w := 136.0
	var title: int = int(Battle.get_script_constant_map()["FS_TITLE"])
	var body: int = int(Battle.get_script_constant_map()["FS_BODY"])
	var micro: int = int(Battle.get_script_constant_map()["FS_MICRO"])
	var overflow: Array = []
	var too_small: Array = []
	for lang in ["zh", "en"]:
		I18n.set_lang_soft(str(lang))
		for hid in GameData.heroes.keys():
			var h: Dictionary = GameData.hero(str(hid))
			var line := "%s · %s" % [str(h.get("name", "")), str(h.get("title", ""))]
			var w_title := text_width(f, line, title)
			var w_body := text_width(f, line, body)
			if w_title > name_w and w_body > name_w:
				overflow.append("%s %s %.0f/%.0f" % [lang, line, w_title, w_body])
			if UiTheme.fit_size(line, name_w, [title, body]) < body:
				too_small.append("%s %s" % [lang, line])
		var hint := I18n.T("点此直取敌将")
		if text_width(f, hint, micro) > hint_w:
			overflow.append("%s %s %.0f" % [lang, hint, text_width(f, hint, micro)])
		if UiTheme.fit_size(hint, hint_w, [micro]) < micro:
			too_small.append("%s 提示" % lang)
	var src := FileAccess.get_file_as_string("res://scenes/battle.gd")
	I18n.set_lang_soft("zh")
	ok(overflow.is_empty(), "主将卡名字与提示都放得下（名字 ≤%.0f / 提示 ≤%.0fpx）" % [name_w, hint_w], str(overflow))
	ok(too_small.is_empty(), "降档后仍不低于正文档 %dpx" % body, str(too_small))
	ok(src.contains("hint.clip_text = true"), "敌将提示开着裁剪（溢出时截断而不是压到目标条上）")

func text_width(f: Font, text: String, size: int) -> float:
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

# ---------------- 四、顶部关卡目标条 ----------------

## 目标条内宽 856px（左让开敌将卡 484、右让开暂停 1340），给两行。
## 中文 8 关最长 619px，永远一行；英文 5 关超 856，最坏的垓下 1281px —— 两行是 1712px 的预算，
## 刚好够，但只剩 30% 余量，所以这条要钉死：任何一关的目标句不许超两行，
## 也不许因为「反正会换行」就把句子越写越长。
func _test_goal_line() -> void:
	var f := UiTheme.font()
	var box_w := 856.0
	var box_h := 48.0
	var body: int = int(Battle.get_script_constant_map()["FS_BODY"])
	var line_h: float = f.get_height(body)
	ok(box_h >= line_h * 2.0, "目标条高度放得下两行（%.0f ≥ %.0f×2）" % [box_h, line_h], str(line_h))

	var over: Array = []
	var widest := 0.0
	for lang in ["zh", "en"]:
		I18n.set_lang_soft(str(lang))
		for s in GameData.stages:
			var name_txt := str(s.get("name", ""))
			var goal := str(s.get("goalText", ""))
			var line := I18n.T(("%s · %s" % [name_txt, goal]) if goal != "" else name_txt)
			var w := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, body).x
			widest = maxf(widest, w)
			if w > box_w * 2.0:
				over.append("%s %s %.0f" % [lang, str(s.get("id", "")), w])
	I18n.set_lang_soft("zh")
	ok(over.is_empty(), "8 关目标句都能在 %.0fpx 内换两行放下" % box_w, str(over))
	# 下界：如果全都远短于一行，说明两行的预算根本没被用到，这条断言就没在验证东西
	ok(widest > box_w, "至少有一关真的需要换行（最长 %.0fpx > %.0f）" % [widest, box_w], str(widest))

# ---------------- 五、卡面牌名 ----------------

## 卡面 128 宽、墨条 38 高。英文卡名比中文长一倍，原来只能一路缩字号：78 张里
## 15 张要 ≤10px（1366×768 下不到 8.5px，等于看不见）、2 张要 8px。
## 现在改成「单行放不下就在 · 处断两行」，两行 11px 比一行 8px 好读得多。
## 这条钉三件事：① 没有牌名小到 11px 以下；② 两行的行高必须装得进墨条（否则第二行被切）；
## ③ 至少真有几张走了两行——否则「两行放得下」这条在全是短名时永远为真。
func _test_card_names() -> void:
	var f := UiTheme.font()
	var box: float = float(CardView.SIZE.x) - 4.0
	var band: float = float(CardView.NAME_BAND_H)
	var too_small: Array = []
	var clipped: Array = []
	var two_count := 0
	var total := 0
	for lang in ["zh", "en"]:
		I18n.set_lang_soft(str(lang))
		for id in GameData.cards.keys():
			var nm := I18n.T(str(GameData.card(str(id)).get("name", "")))
			if nm == "":
				continue
			total += 1
			var st: Dictionary = CardView._name_layout(nm)
			var fs := int(st["font"])
			var two := bool(st["two"])
			if two:
				two_count += 1
			if fs < 11:
				too_small.append("%s %dpx %s" % [lang, fs, nm])
			if two:
				# 两行：行高＋4px 呼吸必须装进墨条，否则第二行下半截被切（实测过）
				if f.get_height(fs) * 2.0 + 4.0 > band:
					clipped.append("%s %dpx %s" % [lang, fs, nm])
			else:
				# 单行：不能靠省略号收场
				if text_width(f, nm, fs) > box:
					clipped.append("%s %dpx %s" % [lang, fs, nm])
	I18n.set_lang_soft("zh")
	ok(total > 140, "两种语言都扫到了卡名（%d 条）" % total, str(total))
	ok(too_small.is_empty(), "没有牌名小于 11px", str(too_small))
	ok(clipped.is_empty(), "牌名都装得下（单行不省略 / 两行不被切）", str(clipped))
	ok(two_count >= 10, "确实有一批牌名走了两行（%d 条）" % two_count, str(two_count))
