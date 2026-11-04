## 设置面板：音量 / 静音 / 动效 / 全屏
##
## 弹出式覆盖层，任何时候按 Esc 呼出。打开时暂停游戏树（设置面板自身
## 设为 PROCESS_MODE_ALWAYS 才能响应），关闭后恢复——避免打开设置时
## 对面 AI 还在出牌。
class_name SettingsPanel
extends Control

signal closed
signal lang_changed(lang: String)

const PANEL_W := 560.0
const PANEL_H := 646.0

var _slider_bgm: HSlider
var _slider_sfx: HSlider
var _value_bgm: Label
var _value_sfx: Label
var _btn_mute: Button
var _btn_motion: Button
var _btn_full: Button
var _reset_note: Label
var _closing := false

static func open_on(parent: Node) -> SettingsPanel:
	var p := SettingsPanel.new()
	p.name = "SettingsPanel"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(p)
	return p

func _ready() -> void:
	Settings.ensure_loaded()
	# 宽屏下场景整体右移，设置面板是挂在场景上的浮层：自己铺满屏幕（原点落在绝对 0），
	# 面板本体再按视口真宽居中，否则会跟着偏右
	Widgets.fill_screen(self)
	_build()
	_animate_in()

func _build() -> void:
	# 遮罩：压暗背景但保留一点战场轮廓，玩家仍有方位感
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.55)
	dim.size = Widgets.viewport_size()
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.INK, 8, 2))
	var vp := Widgets.viewport_size()
	panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - PANEL_H) * 0.5)
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	add_child(panel)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 36)
	pad.add_theme_constant_override("margin_right", 36)
	pad.add_theme_constant_override("margin_top", 26)
	pad.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	pad.add_child(col)

	var title := Widgets.title("设 置", 34, UiTheme.INK)
	title.custom_minimum_size = Vector2(0, 46)
	col.add_child(title)
	col.add_child(_rule())

	# 音乐音量
	var bgm_row := _volume_row(col, "音 乐", Settings.bgm)
	_slider_bgm = bgm_row["slider"]
	_value_bgm = bgm_row["value"]
	_slider_bgm.value_changed.connect(func (v: float) -> void:
		Settings.set_bgm(v / 100.0)
		_value_bgm.text = "%d%%" % roundi(v))

	# 音效音量（拖动途中不出声，松手才给一记点击音当试听）
	var sfx_row := _volume_row(col, "音 效", Settings.sfx)
	_slider_sfx = sfx_row["slider"]
	_value_sfx = sfx_row["value"]
	_slider_sfx.value_changed.connect(func (v: float) -> void:
		Settings.set_sfx(v / 100.0)
		_value_sfx.text = "%d%%" % roundi(v))
	_slider_sfx.drag_ended.connect(func (_c: bool) -> void: Audio.sfx("click"))

	col.add_child(_rule())

	_btn_mute = _toggle_row(col, "静 音", Settings.muted, func (v: bool) -> void:
		Settings.set_muted(v))
	_btn_motion = _toggle_row(col, "动 效", Settings.motion, func (v: bool) -> void:
		Settings.set_motion(v))
	_btn_full = _toggle_row(col, "全 屏", Settings.fullscreen, func (_v: bool) -> void:
		Settings.toggle_fullscreen())
	# 全屏按钮回到窗口模式后要按实际状态刷新文本
	_btn_full.pressed.connect(func (): _sync(_btn_full, Settings.fullscreen))

	col.add_child(_rule())

	# 语言：中 / EN 二选一，切完整个界面立刻跟着换
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 10)
	col.add_child(lang_row)
	var lang_lab := UiTheme.label("语 言", 19, UiTheme.INK_SOFT)
	lang_lab.custom_minimum_size = Vector2(76, 0)
	lang_row.add_child(lang_lab)
	lang_row.add_child(_lang_btn("中 文", "zh"))
	lang_row.add_child(_lang_btn("English", "en"))

	# 新手引导：回头的玩家可以重看一遍
	var guide_row := HBoxContainer.new()
	col.add_child(guide_row)
	var guide_lab := UiTheme.label("新手引导", 19, UiTheme.INK_SOFT)
	guide_lab.custom_minimum_size = Vector2(76, 0)
	guide_row.add_child(guide_lab)
	_reset_note = UiTheme.label("首局战斗自动出现", 13, UiTheme.INK_SOFT)
	_reset_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_row.add_child(_reset_note)
	var reset_btn := UiTheme.button("重 置")
	reset_btn.custom_minimum_size = Vector2(96, 44)
	reset_btn.add_theme_font_size_override("font_size", 17)
	reset_btn.pressed.connect(_on_reset_guide)
	guide_row.add_child(reset_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var close := UiTheme.button("返 回 · Esc", true)
	close.custom_minimum_size = Vector2(240, 50)
	close.pressed.connect(close_panel)
	row.add_child(close)

func _rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(UiTheme.INK_SOFT.r, UiTheme.INK_SOFT.g, UiTheme.INK_SOFT.b, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	return line

## 一行：名称 + 滑条 + 百分比
func _volume_row(col: VBoxContainer, name: String, value: float) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)

	var lab := UiTheme.label(name, 19, UiTheme.INK_SOFT)
	lab.custom_minimum_size = Vector2(76, 0)
	row.add_child(lab)

	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 1
	s.value = value * 100.0
	s.custom_minimum_size = Vector2(300, 32)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)

	var val := UiTheme.label("%d%%" % roundi(value * 100.0), 17, UiTheme.INK)
	val.custom_minimum_size = Vector2(56, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	return {"slider": s, "value": val}

## 一行：名称 + 开/关按钮
func _toggle_row(col: VBoxContainer, name: String, value: bool, on_change: Callable) -> Button:
	var row := HBoxContainer.new()
	col.add_child(row)

	var lab := UiTheme.label(name, 19, UiTheme.INK_SOFT)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)

	var b := UiTheme.button("", false)
	b.custom_minimum_size = Vector2(120, 44)
	row.add_child(b)
	_sync(b, value)
	b.pressed.connect(func () -> void:
		var next := not _is_on(b)
		_sync(b, next)
		on_change.call(next))
	return b

func _is_on(b: Button) -> bool:
	# 按 meta 判断，别比对按钮文字——英文模式下文字是 On / Off
	return bool(b.get_meta("on", false))

## 开=朱砂底白字，关=纸底墨字。样式表建一次缓存进按钮元数据。
func _sync(b: Button, on: bool) -> void:
	b.set_meta("on", on)
	b.text = I18n.T("开" if on else "关")
	if not b.has_meta("sb_on"):
		b.set_meta("sb_on", UiTheme.button("", true).get_theme_stylebox("normal"))
		b.set_meta("sb_off", UiTheme.button("", false).get_theme_stylebox("normal"))
	var key_on: StyleBox = b.get_meta("sb_on")
	var key_off: StyleBox = b.get_meta("sb_off")
	var base: StyleBoxFlat = key_on if on else key_off
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = base.bg_color.lightened(0.08) if on else UiTheme.PAPER_DEEP
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", UiTheme.PAPER if on else UiTheme.INK)
	b.add_theme_color_override("font_hover_color", UiTheme.PAPER if on else UiTheme.SEAL)

## 语言按钮：当前语言的那颗用朱砂底
func _lang_btn(text: String, code: String) -> Button:
	var b := UiTheme.button(text, Settings.lang == code)
	b.custom_minimum_size = Vector2(150, 44)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(func () -> void: _switch_lang(code))
	return b

func _switch_lang(code: String) -> void:
	if Settings.lang == code:
		return
	# 真正的切换与界面刷新交给 App：它要先把面板关掉，再重载/重画当前界面
	lang_changed.emit(code)

## 清掉引导与提示记录：下次进战斗会重新走一遍分步引导
func _on_reset_guide() -> void:
	Tutorial.reset()
	_reset_note.text = I18n.T("已重置，下次进战斗重新引导")
	_reset_note.add_theme_color_override("font_color", UiTheme.SEAL)
	Audio.sfx("click")

func _on_dim_input(event: InputEvent) -> void:
	# 点遮罩不关闭（避免战斗中误触丢进度），只吞掉点击
	if event is InputEventMouseButton:
		accept_event()

func _animate_in() -> void:
	if not Settings.motion:
		return
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.14)

func close_panel() -> void:
	if _closing:
		return
	_closing = true
	Audio.sfx("click")
	if Settings.motion:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.12)
		await tw.finished
	closed.emit()
	queue_free()
