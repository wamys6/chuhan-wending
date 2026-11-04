extends SceneTree

## 字体覆盖校验：子集化后的字体必须包含所有会被显示的字符。
##
## 背景：Noto Serif SC 原版两个字重 42MB，子集化后 1.8MB（省 46MB）。
## 代价是新加文案如果用到字体里没有的字，会回退系统字体（字形不一致）
## 或者显示成方块（allow_system_fallback 关闭时）。
## 这个测试把「漏字」挡在发布前，而不是等玩家看见豆腐块。
##
## 扫描口径：
##   - data/*.json 的所有字符串值（卡名/描述/关卡/军师/天时/事件全在这里）
##   - *.gd 里字符串字面量的内容（跳过注释，注释不显示）
## 只检查中日韩统一表意文字区，ASCII 与标点由子集脚本强制保留。

const FONT_REGULAR := "res://fonts/NotoSerifSC-Regular.otf"
const FONT_BOLD := "res://fonts/NotoSerifSC-Bold.otf"

var _ok := 0
var _bad := 0

func _init() -> void:
	print("=== 字体覆盖校验 ===")
	var chars := _collect_chars()
	print("待查字符 ", chars.size(), " 个")
	_check_font(FONT_REGULAR, chars)
	_check_font(FONT_BOLD, chars)
	print("=== 通过 %d 项，失败 %d 项 ===" % [_ok, _bad])
	quit(1 if _bad > 0 else 0)

func _ok_assert(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		_ok += 1
	else:
		_bad += 1
		print("  ✗ ", label, "  ", detail)

## 只收汉字：其余字符（ASCII/标点/数字）由子集脚本的 EXTRA 常量保证
func _is_cjk(c: int) -> bool:
	return c >= 0x4E00 and c <= 0x9FFF

func _collect_chars() -> Dictionary:
	var out := {}
	# 1) 数据文件：整份文本扫一遍最省事，JSON 的键名也是中文
	for f in ["res://data/game.json", "res://data/lang-en.json", "res://data/lang-godot-en.json"]:
		if not FileAccess.file_exists(f):
			continue
		for c in FileAccess.get_file_as_string(f):
			if _is_cjk(c.unicode_at(0)):
				out[c] = true
	# 2) 脚本里的字符串字面量（跳过注释）
	var dirs := ["res://core", "res://ui", "res://scenes"]
	var re := RegEx.new()
	re.compile("\"([^\"\\\\]*(?:\\\\.[^\"\\\\]*)*)\"")
	for d in dirs:
		for path in _gd_files(d):
			var lines := FileAccess.get_file_as_string(path).split("\n")
			for line in lines:
				var trimmed := line.strip_edges()
				if trimmed.begins_with("#"):
					continue
				for m in re.search_all(line):
					for c in m.get_string(1):
						if _is_cjk(c.unicode_at(0)):
							out[c] = true
	return out

func _gd_files(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_gd_files(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
	return out

func _check_font(path: String, chars: Dictionary) -> void:
	var font: FontFile = load(path)
	if font == null:
		_ok_assert(false, "字体可加载", path)
		return
	var supported := font.get_supported_chars()
	var have := {}
	for c in supported:
		have[c] = true
	var missing: Array = []
	for c in chars:
		if not have.has(c):
			missing.append(c)
	missing.sort()
	_ok_assert(missing.is_empty(),
		"%s 覆盖全部用字" % path.get_file(),
		"缺 %d 个：%s" % [missing.size(), "".join(missing).substr(0, 80)] if not missing.is_empty() else "")
	if not missing.is_empty():
		print("    提示：重跑 python tools/subset-fonts.py 可补齐")
