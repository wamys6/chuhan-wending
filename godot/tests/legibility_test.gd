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
