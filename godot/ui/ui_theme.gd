## 视觉主题：宣纸米白 + 浓墨 + 朱砂红
##
## 字体：优先用项目内置的 Noto Serif SC（OFL 许可，见 fonts/LICENSE-OFL.txt），
## 导出包自带、不依赖玩家机器装没装中文字体；万一字体缺失再退回系统字体。
class_name UiTheme
extends RefCounted

const PAPER := Color("#f7f3e8")
const PAPER_DEEP := Color("#efe7d4")
const INK := Color("#1d1a16")
const INK_SOFT := Color("#4a4238")
const SEAL := Color("#7c1f1a")
const SEAL_LIGHT := Color("#b23a32")
const GOLD := Color("#c8a24a")

static var _font: Font
static var _bold: Font

static func font() -> Font:
	if _font != null:
		return _font
	if ResourceLoader.exists("res://fonts/NotoSerifSC-Regular.otf"):
		_font = load("res://fonts/NotoSerifSC-Regular.otf")
		return _font
	# 兜底：内置字体不在时（开发分支误删等）退回系统字体
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Microsoft YaHei", "Source Han Serif SC", "Noto Serif CJK SC",
		"SimSun", "PingFang SC", "Sans-Serif"
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_font = f
	return _font

static func bold_font() -> Font:
	if _bold != null:
		return _bold
	if ResourceLoader.exists("res://fonts/NotoSerifSC-Bold.otf"):
		_bold = load("res://fonts/NotoSerifSC-Bold.otf")
	return _bold

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	# 富文本 [b] 用真粗体（战报/引导高亮里有关键词加粗）
	if bold_font() != null:
		t.set_font("bold_font", "RichTextLabel", bold_font())
	return t

## 通用面板样式：宣纸底 + 细墨边
static func panel_style(bg: Color = PAPER, border: Color = INK, radius: int = 6, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

## 所有界面文字都从这两个函数出去，所以翻译只在这里做一遍。
## 直接 `.text = "…"` 赋值的地方走不到这里，需要各自包 I18n.T()。
static func label(text: String, size: int = 18, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = I18n.T(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## 按可用宽度自动降档，返回能放下的那一档字号。
## 名字这类「长度随语言变、又必须单行不折」的文本用它；给的是字号阶梯而不是任意值，
## 免得又长出一堆 17/19 的野档位。
static func fit_size(text: String, max_w: float, sizes: Array) -> int:
	var f := font()
	for s in sizes:
		var n := int(s)
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x <= max_w:
			return n
	return int(sizes[sizes.size() - 1])

static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = I18n.T(text)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	var normal := panel_style(SEAL if primary else PAPER, SEAL if primary else INK)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = SEAL_LIGHT if primary else PAPER_DEEP
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = SEAL.darkened(0.15) if primary else PAPER_DEEP.darkened(0.08)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", PAPER if primary else INK)
	b.add_theme_color_override("font_hover_color", PAPER if primary else SEAL)
	b.add_theme_color_override("font_pressed_color", PAPER if primary else SEAL)
	# 全局点击反馈：所有按钮自动带一记极轻的"嗒"，省得每个场景各接一次
	b.pressed.connect(func () -> void: Audio.sfx("tick"))
	return b

## 立绘缓存（避免每次 load 都走一次资源查找）
static var _tex_cache: Dictionary = {}

## 一块「铺满指定区域」的立绘节点。
##
## 顺序在这里收口，原因是 TextureRect 的最小尺寸默认等于纹理尺寸：
## **先赋 texture 再 set_size，小的 size 会被顶回原图尺寸**（1024×1024），
## 表现是「圆形插图里只看得见原画左上角一小块」——事件页踩过这个坑，
## 而代码读起来完全正常（size 明明写了 144）。所以 expand_mode 一定要在 texture 之前。
static func texture_rect(tex: Texture2D, box: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture = tex
	tr.size = box
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

static func art_texture(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := "res://assets/cards/%s.png" % id
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_tex_cache[id] = tex
	return tex
