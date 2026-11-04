## 战场单位视图（立绘 + 攻/血 + 可攻击高亮 + 守御描边）
class_name UnitView
extends Control

## 左键点部队：选中自己人 / 指定攻击目标是场景层的规则
signal clicked(uid: int)

## 90×124：一列满编 3 张（含 4px 间隔）总宽 278，列框 296 里左右各留 9px。
## 之前 96×132 满编正好等于框宽，牌边压着框线，满场时看不出列界。
const SIZE := Vector2(90, 124)
## 关键词小印边长。90 宽卡面上 14 是「两枚放得下、单枚不压主体」的上限；
## 这一档字已经糊了，靠色块（朱砂/墨/赭）分辨，见 keyword_stamp.gd
const STAMP_BOX := 14.0

var uid: int = 0
var unit: Dictionary = {}
var _art: TextureRect
var _frame: Panel
var _atk_bg: Panel
var _hp_bg: Panel
var _atk: Label
var _hp: Label
var _selected := false
## 冲刺动画进行中为 true：_sync_board 期间不瞬移回位，避免打断回程
var lunging := false
## 这一列的基准缩放（一列超过 3 张时整列等比缩小）。pop_in 以它为终值。
var base_scale := 1.0

func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

## 点击部队：子节点（立绘/边框/攻血章）都是 IGNORE，事件落到这一层
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		clicked.emit(uid)

func setup(u: Dictionary) -> void:
	unit = u
	uid = int(u["uid"])
	name = "unit_" + str(uid)

	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex := UiTheme.art_texture(str(u["baseId"]))
	if tex != null:
		_art.texture = tex
	add_child(_art)
	# 占位只走画面，不进 _art.texture：冲刺残影与阵亡碎片要求真立绘，
	# 缺图时那两段特效直接跳过（烟尘照放），比碎一块墨有意思
	if tex == null:
		add_child(CardArt.placeholder(str(u["baseId"]), SIZE))

	_frame = Panel.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	# 攻血章横向不出血（0 与 SIZE.x−30）：原来左右各探出 6px，满编 3 张时
	# 右章会压到下一张的左章上。现在相邻两张的章之间留 4px，正好等于列内间隔。
	_atk_bg = _badge(Vector2(0, SIZE.y - 28))
	_atk = _badge_label(_atk_bg, Color("#f0d48a"))
	_hp_bg = _badge(Vector2(SIZE.x - 30, SIZE.y - 28))
	_hp = _badge_label(_hp_bg, Color("#e8897e"))

	# 关键词小印：场上也要认得出死战牌——死战专精的援军是从哪张牌冒出来的，
	# 玩家得在阵亡那一刻把「这张是死战牌」和「加了 buff」连起来
	var stamps := KeywordStamp.row(unit, STAMP_BOX, 2.0)
	if stamps.size.x > 0.0:
		stamps.position = Vector2(SIZE.x - 3.0 - stamps.size.x, 3.0)
		add_child(stamps)

	refresh(u)

func _badge(pos: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(30, 30)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.09, 0.08, 0.07, 0.88), Color(0, 0, 0, 0), 15, 0))
	add_child(p)
	return p

func _badge_label(parent: Panel, color: Color) -> Label:
	var l := UiTheme.label("0", 16, color)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## 状态变了就地刷新，不重建节点（保住动画连续性）
func refresh(u: Dictionary) -> void:
	unit = u
	_atk.text = str(int(u["atk"]))
	_hp.text = str(int(u["hp"]))
	var edge := UiTheme.INK
	var w := 2
	if bool(u.get("canAttack", false)) and int(u["atk"]) > 0:
		edge = UiTheme.GOLD
		w = 3
	if bool(u.get("taunt", false)):
		edge = UiTheme.SEAL_LIGHT if not bool(u.get("canAttack", false)) else edge
	_frame.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0, 0, 0, 0), edge, 4, w))
	if _selected:
		_frame.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0, 0, 0, 0), UiTheme.GOLD, 4, 4))
	_atk_bg.visible = int(u["atk"]) > 0

func set_selected(on: bool) -> void:
	_selected = on
	refresh(unit)

func set_dim(on: bool) -> void:
	modulate = Color(0.7, 0.68, 0.66, 1) if on else Color(1, 1, 1, 1)

## 设定这一列的基准缩放。缩放轴固定在牌中心（pop_in 要用），
## 所以调用方摆位时要把左上角按 pivot 反向补偿：pos = 目标左上 − SIZE/2·(1−s)。
func set_base_scale(s: float) -> void:
	if is_equal_approx(base_scale, s):
		return
	base_scale = s
	pivot_offset = SIZE * 0.5
	scale = Vector2(s, s)

## 登场动画：缩放弹出
func pop_in() -> void:
	pivot_offset = SIZE * 0.5
	scale = Vector2(base_scale * 0.7, base_scale * 0.7)
	modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	# 不用 TRANS_BACK：回弹会冲到 1.1 倍，单位的 rect 短暂超出列框、压住列名带
	t.tween_property(self, "scale", Vector2(base_scale, base_scale), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.18)

## 立绘纹理（冲刺残影、阵亡碎片都靠它复制）
func art_texture() -> Texture2D:
	return _art.texture if _art != null else null

## 受击闪红：半拍红光再褪回
func hit_flash() -> void:
	modulate = Color(1.0, 0.45, 0.38, 1.0)
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.22)

## 阵亡动画：缩小淡出后自毁
func die() -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_property(self, "scale", Vector2(0.7, 0.7), 0.3)
	t.chain().tween_callback(queue_free)
