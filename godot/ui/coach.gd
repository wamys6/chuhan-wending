## 分步引导浮层（聚光灯式）
##
## 做法：用四块压暗矩形围出一个「洞」，洞里露出真实控件——玩家仍可点击目标，
## 洞外的点击被遮罩吞掉，避免引导途中误触。顶部一条朱砂描边的提示框说明当前步。
##
## 步骤结构（由调用方给出，见 battle.gd 的 _intro_steps）：
##   {title, text, node: Control, rect: Rect2, tag: String, no_skip: bool}
##   node —— 目标控件（每帧跟随它的实际位置，手牌抽入动画也能跟上）
##   rect —— 目标矩形（没有控件可指时用，如「这一列」）
##   tag  —— 该步要求玩家做的动作；battle 里动作完成时调 notify(tag) 自动推进
class_name Coach
extends Control

signal finished(skipped: bool)

const BOX_W := 392.0
const HOLE_PAD := 6.0

var steps: Array = []
var index := 0
var flag := ""
var active := false

var _dims: Array = []
var _frame: Panel
var _box: PanelContainer
var _step_label: Label
var _title_label: Label
var _text_label: Label
var _next_btn: Button
var _skip_btn: Button
var _poll := 0.0

## 起一段引导。parent 一般是当前场景根节点，list 为空则不起。
static func start(parent: Node, list: Array, done_flag: String = "") -> Coach:
	if list.is_empty() or parent == null:
		return null
	var c := Coach.new()
	c.name = "Coach"
	c.steps = list
	c.flag = done_flag
	parent.add_child(c)
	return c

func _ready() -> void:
	# 用 fill_screen 而不是 FULL_RECT：宽屏下场景整体右移，聚光灯的四块压暗要铺到
	# 屏幕左边缘（本地原点要落在绝对 0 上，否则左边会留一条没压暗的亮带）
	Widgets.fill_screen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	_build()
	active = true
	_render()

func _build() -> void:
	for i in 4:
		var d := ColorRect.new()
		d.color = Color(0.05, 0.04, 0.03, 0.55)
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(d)
		_dims.append(d)

	_frame = Panel.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.panel_style(Color(0, 0, 0, 0), UiTheme.GOLD, 10, 3)
	_frame.add_theme_stylebox_override("panel", sb)
	add_child(_frame)

	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.SEAL, 10, 2))
	_box.custom_minimum_size = Vector2(BOX_W, 0)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_box)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	_box.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)

	_step_label = UiTheme.label("", 13, UiTheme.INK_SOFT)
	col.add_child(_step_label)

	_title_label = UiTheme.label("", 23, UiTheme.SEAL)
	col.add_child(_title_label)

	_text_label = UiTheme.label("", 16, UiTheme.INK)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(BOX_W - 40, 0)
	col.add_child(_text_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)

	_skip_btn = UiTheme.button("跳 过", false)
	_skip_btn.add_theme_font_size_override("font_size", 16)
	_skip_btn.custom_minimum_size = Vector2(96, 42)
	_skip_btn.pressed.connect(skip)
	row.add_child(_skip_btn)

	_next_btn = UiTheme.button("下 一 步", true)
	_next_btn.add_theme_font_size_override("font_size", 16)
	_next_btn.custom_minimum_size = Vector2(140, 42)
	_next_btn.pressed.connect(advance)
	row.add_child(_next_btn)

func _render() -> void:
	if index >= steps.size():
		_finish(false)
		return
	var st: Dictionary = steps[index]
	_step_label.text = "%d / %d" % [index + 1, steps.size()]
	_title_label.text = I18n.T(str(st.get("title", "")))
	_text_label.text = I18n.T(str(st.get("text", "")))
	_next_btn.text = I18n.T("开 始 出 征" if index == steps.size() - 1 else "下 一 步")
	_skip_btn.visible = not bool(st.get("no_skip", false))
	# 需要动手的那一步：把「下一步」弱化，鼓励真的去点
	var actionable := str(st.get("tag", "")) != ""
	_next_btn.modulate.a = 0.55 if actionable else 1.0
	_place()
	# 换步时闪一下提示框，视线容易跟上
	if Settings.motion:
		_box.modulate.a = 0.0
		var tw := _box.create_tween()
		tw.tween_property(_box, "modulate:a", 1.0, 0.18)
		_frame.modulate.a = 0.0
		var tw2 := _frame.create_tween()
		tw2.tween_property(_frame, "modulate:a", 1.0, 0.2)

## 当前步的目标矩形（控件优先，其次显式矩形；都没有就返回空矩形）
func _target_rect() -> Rect2:
	if index >= steps.size():
		return Rect2()
	var st: Dictionary = steps[index]
	var node = st.get("node", null)
	if node != null and is_instance_valid(node) and node is Control:
		var c := node as Control
		if c.is_inside_tree() and c.is_visible_in_tree():
			return c.get_global_rect()
	if st.has("rect"):
		return st.get("rect")
	return Rect2()

func _place() -> void:
	if _dims.is_empty():
		return
	var vp := get_viewport_rect().size
	var r := _target_rect()
	var has_target := r.size.x > 1.0 and r.size.y > 1.0
	var st: Dictionary = steps[index] if index < steps.size() else {}
	var pad := float(st.get("pad", HOLE_PAD))

	if has_target:
		r = r.grow(pad)
		r.position = r.position.max(Vector2.ZERO)
		r.size = r.size.min(vp - r.position)
		var x0 := r.position.x
		var y0 := r.position.y
		var x1 := minf(r.end.x, vp.x)
		var y1 := minf(r.end.y, vp.y)
		_set_rect(_dims[0], Vector2(0, 0), Vector2(vp.x, y0))
		_set_rect(_dims[1], Vector2(0, y1), Vector2(vp.x, vp.y - y1))
		_set_rect(_dims[2], Vector2(0, y0), Vector2(x0, y1 - y0))
		_set_rect(_dims[3], Vector2(x1, y0), Vector2(vp.x - x1, y1 - y0))
		_frame.visible = true
		_set_rect(_frame, r.position, r.size)
	else:
		# 没有目标：整屏压暗，提示框落到底部中间
		_set_rect(_dims[0], Vector2.ZERO, vp)
		for i in range(1, 4):
			_set_rect(_dims[i], Vector2.ZERO, Vector2.ZERO)
		_frame.visible = false

	var bh: float = _box.get_combined_minimum_size().y
	var bx := (vp.x - BOX_W) * 0.5
	var by := vp.y - bh - 56.0
	if has_target:
		bx = clampf(r.position.x + r.size.x * 0.5 - BOX_W * 0.5, 16.0, vp.x - BOX_W - 16.0)
		by = r.end.y + 16.0
		if by + bh > vp.y - 12.0:
			by = r.position.y - bh - 16.0
		if by < 12.0:
			by = vp.y - bh - 16.0
	_box.position = Vector2(roundf(bx), roundf(by))

func _set_rect(c: Control, pos: Vector2, size: Vector2) -> void:
	c.position = pos
	c.size = Vector2(maxf(0.0, size.x), maxf(0.0, size.y))

func _process(delta: float) -> void:
	# 目标可能在动（抽牌滑入、单位换位），低频跟一下位置即可
	if not active:
		return
	_poll += delta
	if _poll < 0.06:
		return
	_poll = 0.0
	_place()

# ---------------- 推进 ----------------

func advance() -> void:
	if not active:
		return
	index += 1
	if index >= steps.size():
		_finish(false)
		return
	_render()

func skip() -> void:
	if not active:
		return
	_finish(true)

## 玩家完成了某类动作（出牌 / 攻击…），若当前步在等这个动作就自动推进
func notify(tag: String) -> void:
	if not active or tag == "" or index >= steps.size():
		return
	var st: Dictionary = steps[index]
	if str(st.get("tag", "")) == tag:
		advance()

func _finish(skipped: bool) -> void:
	if not active:
		return
	active = false
	set_process(false)
	if not skipped and flag != "":
		Tutorial.mark_done(flag)
	finished.emit(skipped)
	queue_free()

## 测试/调试用：直接跳步
func goto_step(i: int) -> void:
	if i < 0 or i >= steps.size():
		return
	index = i
	_render()

func current_step() -> Dictionary:
	if index >= steps.size():
		return {}
	return steps[index]
