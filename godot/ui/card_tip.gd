## 卡牌浮层：鼠标悬停手牌时显示牌面全貌
##
## 两件事：①Godot 版的 HandCard 太小放不下描述，这里补上完整文字；
## ②描述里出现的关键词自动附一句白话解释（释义来自 Tutorial.KEYWORDS，
## 与新手引导、图鉴共用一份，改一处全局生效）。
class_name CardTip
extends PanelContainer

const WIDTH := 306.0

var _col: VBoxContainer
var _built_for := ""

static func create(parent: Node) -> CardTip:
	var t := CardTip.new()
	t.name = "CardTip"
	t.z_index = 70
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.visible = false
	parent.add_child(t)
	return t

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.INK, 8, 2))
	custom_minimum_size = Vector2(WIDTH, 0)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	add_child(pad)

	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 6)
	pad.add_child(_col)

func show_card(c: Dictionary) -> void:
	var key := str(c.get("uid", 0)) + "|" + str(c.get("baseId", c.get("id", "")))
	if key != _built_for:
		_built_for = key
		_build(c)
	visible = true
	modulate.a = 1.0

func hide_tip() -> void:
	visible = false

func _build(c: Dictionary) -> void:
	for ch in _col.get_children():
		ch.queue_free()

	# 标题行：费用 + 名称
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_col.add_child(head)
	var cost := PanelContainer.new()
	cost.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SEAL, UiTheme.SEAL, 13, 0))
	cost.custom_minimum_size = Vector2(26, 26)
	head.add_child(cost)
	var cl := UiTheme.label(str(int(c.get("cost", 0))), 15, UiTheme.PAPER)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_child(cl)

	var name_l := UiTheme.label(str(c.get("name", "")), 20, UiTheme.INK)
	head.add_child(name_l)

	# 元信息：兵种/计谋 · 列 · 攻血
	var meta: Array = []
	var is_piece := str(c.get("type", "")) == "piece"
	meta.append("兵种" if is_piece else "计谋")
	if is_piece:
		meta.append(GameData.rank_name(str(c.get("col", "front"))))
		meta.append("%d 攻 · %d 血" % [int(c.get("atk", 0)), int(c.get("hp", 0))])
	_col.add_child(UiTheme.label(" · ".join(meta), 14, UiTheme.INK_SOFT))

	# 描述（关键词朱砂色）
	var desc := str(c.get("desc", ""))
	if desc != "":
		var rich := RichTextLabel.new()
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		rich.custom_minimum_size = Vector2(WIDTH - 34, 0)
		rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rich.add_theme_font_size_override("normal_font_size", 15)
		rich.add_theme_color_override("default_color", UiTheme.INK)
		rich.text = Tutorial.highlight_bbcode(desc.replace("[", "[lb]"))
		_col.add_child(rich)

	# 关键词释义
	var exps := Tutorial.explanations_for(desc)
	if exps.is_empty():
		return
	var line := ColorRect.new()
	line.color = Color(UiTheme.INK_SOFT.r, UiTheme.INK_SOFT.g, UiTheme.INK_SOFT.b, 0.25)
	line.custom_minimum_size = Vector2(0, 1)
	_col.add_child(line)
	for e in exps:
		var rich2 := RichTextLabel.new()
		rich2.bbcode_enabled = true
		rich2.fit_content = true
		rich2.scroll_active = false
		rich2.custom_minimum_size = Vector2(WIDTH - 34, 0)
		rich2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rich2.add_theme_font_size_override("normal_font_size", 13)
		rich2.add_theme_color_override("default_color", UiTheme.INK_SOFT)
		rich2.text = "[color=#7c1f1a][b]%s[/b][/color]　%s" % [str(e["kw"]), str(e["text"])]
		_col.add_child(rich2)

## 贴着目标卡放：优先在上方，放不下就放下方
## max_bottom > 0 时，浮层底边不许越过这条线（对战界面用它把手牌区挡在外面，
## 否则浮层会盖住被悬停那张牌上方的邻牌，玩家看不清要点哪张）
func place_near(target: Rect2, avoid: Rect2 = Rect2(), max_bottom: float = 0.0) -> void:
	var vp := get_viewport_rect().size
	var h: float = get_combined_minimum_size().y
	size = Vector2(WIDTH, h)
	var x := clampf(target.position.x + target.size.x * 0.5 - WIDTH * 0.5, 12.0, vp.x - WIDTH - 12.0)
	var y := target.position.y - h - 10.0
	if y < 12.0:
		y = target.end.y + 10.0
	if max_bottom > 0.0 and y + h > max_bottom:
		y = maxf(12.0, max_bottom - h)
	# avoid 区域（如我方主将卡）不能被盖住：整体挪到它右侧，放不下再挪左侧
	if avoid.size.x > 0.0 and Rect2(Vector2(x, y), size).intersects(avoid):
		var right_x := avoid.end.x + 14.0
		var left_x := avoid.position.x - WIDTH - 14.0
		x = right_x if right_x + WIDTH <= vp.x - 12.0 else left_x
		x = clampf(x, 12.0, vp.x - WIDTH - 12.0)
	position = Vector2(roundf(x), roundf(y))
