extends Control
## 联机大厅：建房（选边）/ 按房间码加入
##
## 流程：房主选中边 → 创建房间 → 拿到 6 位码 → 对方输入码加入 →
## 两端各自带着对局参数（选边 + 种子）进 battle 场景，开始锁步对局。

var status_label: Label
var relay_edit: LineEdit
var code_edit: LineEdit
var side := "han"           # 建房者自己的阵营：han=刘邦(p1) / chu=项羽(p2)
var side_btns: Dictionary = {}
var create_btn: Button
var join_btn: Button
var code_panel: Panel
var code_label: Label
var wait_label: Label
var back_btn: Button
var _busy := false

func _ready() -> void:
	theme = UiTheme.build()
	_build()
	Pvp.room_created.connect(_on_created)
	Pvp.peer_joined.connect(_on_peer_joined)
	Pvp.room_joined.connect(_on_joined)
	Pvp.net_error.connect(_on_error)
	Pvp.relay_failed.connect(func (msg: String): _on_error(msg))
	Pvp.self_dropped.connect(func (): _on_error("与中继的连接断开"))

func _exit_tree() -> void:
	# 只有还在大厅阶段（没进对局）才断开房间；进对局后由 battle 接管连接
	if Pvp.status == Pvp.LOBBY or Pvp.status == Pvp.CONNECTING:
		Pvp.leave()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.PAPER
	Widgets.fill_screen(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	Widgets.art_bg(self, "sc_peixian", 0.85)

	var title := UiTheme.label("联 机 对 战", 44, UiTheme.SEAL)
	title.position = Vector2(0, 70)
	title.size = Vector2(1440, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := Widgets.subtitle("楚汉对垒 · 与好友实时切磋", 15)
	if sub != null:
		sub.position = Vector2(0, 138)
		sub.size = Vector2(1440, 24)
		add_child(sub)

	# 中央面板
	var panel := Panel.new()
	panel.position = Vector2(430, 200)
	panel.size = Vector2(580, 560)
	panel.add_theme_stylebox_override("panel",
		UiTheme.panel_style(Color(1, 1, 1, 0.5), UiTheme.INK, 10, 2))
	add_child(panel)

	# —— 中继地址 ——
	var rl := UiTheme.label("中继服务器", 15, UiTheme.INK_SOFT)
	rl.position = Vector2(36, 26)
	panel.add_child(rl)
	relay_edit = LineEdit.new()
	relay_edit.text = Pvp.relay_url
	relay_edit.position = Vector2(36, 52)
	relay_edit.size = Vector2(508, 38)
	relay_edit.add_theme_font_size_override("font_size", 14)
	panel.add_child(relay_edit)

	# —— 选边（建房用）——
	var sl := UiTheme.label("选择阵营", 15, UiTheme.INK_SOFT)
	sl.position = Vector2(36, 108)
	panel.add_child(sl)
	side_btns["han"] = _side_btn(panel, "汉 · 刘邦", Vector2(36, 134))
	side_btns["chu"] = _side_btn(panel, "楚 · 项羽", Vector2(304, 134))
	_sync_sides()

	# —— 操作按钮 ——
	create_btn = UiTheme.button("创 建 房 间", true)
	create_btn.position = Vector2(36, 196)
	create_btn.size = Vector2(508, 52)
	create_btn.pressed.connect(_on_create)
	panel.add_child(create_btn)

	var sep := UiTheme.label("—— 或 ——", 13, UiTheme.INK_SOFT)
	sep.position = Vector2(0, 262)
	sep.size = Vector2(580, 20)
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sep)

	var jl := UiTheme.label("加入朋友的房间", 15, UiTheme.INK_SOFT)
	jl.position = Vector2(36, 292)
	panel.add_child(jl)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = I18n.T("输入 6 位房间码")
	code_edit.position = Vector2(36, 318)
	code_edit.size = Vector2(508, 44)
	code_edit.add_theme_font_size_override("font_size", 20)
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_edit.max_length = 6
	panel.add_child(code_edit)
	join_btn = UiTheme.button("加 入 房 间")
	join_btn.position = Vector2(36, 376)
	join_btn.size = Vector2(508, 52)
	join_btn.pressed.connect(_on_join)
	panel.add_child(join_btn)

	# —— 状态与等待面板 ——
	status_label = UiTheme.label("", 15, UiTheme.SEAL)
	status_label.position = Vector2(0, 448)
	status_label.size = Vector2(580, 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(status_label)

	code_panel = Panel.new()
	code_panel.position = Vector2(40, 480)
	code_panel.size = Vector2(500, 64)
	code_panel.add_theme_stylebox_override("panel",
		UiTheme.panel_style(Color(0.95, 0.9, 0.78, 0.9), UiTheme.GOLD, 8, 2))
	code_panel.visible = false
	panel.add_child(code_panel)
	code_label = UiTheme.label("", 30, UiTheme.SEAL)
	code_label.position = Vector2(0, 12)
	code_label.size = Vector2(500, 40)
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_panel.add_child(code_label)

	back_btn = UiTheme.button("返 回")
	back_btn.position = Vector2(660, 800)
	back_btn.size = Vector2(120, 44)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

## 返回/取消：手里还攥着房间就一并退掉
func _on_back() -> void:
	if code_panel.visible or Pvp.is_in_room():
		App.pvp_leave_to_menu()
	else:
		App.back_to_menu()

func _side_btn(parent: Control, text: String, pos: Vector2) -> Button:
	var b := UiTheme.button(text, false)
	b.position = pos
	b.size = Vector2(240, 46)
	b.pressed.connect(func ():
		side = "han" if text.contains("刘邦") else "chu"
		_sync_sides())
	parent.add_child(b)
	return b

func _sync_sides() -> void:
	for k in side_btns:
		var b: Button = side_btns[k]
		b.set_meta("on", k == side)
		b.add_theme_stylebox_override("normal",
			UiTheme.panel_style(UiTheme.SEAL, Color(1, 1, 1), 6, 1) if k == side
			else UiTheme.panel_style(Color(1, 1, 1, 0.5), UiTheme.INK, 6, 1))
		b.add_theme_color_override("font_color",
			Color(1, 1, 1) if k == side else UiTheme.INK)

## ---------- 动作 ----------

func _on_create() -> void:
	if _busy:
		return
	_busy = true
	_set_buttons(false)
	status_label.text = I18n.T("正在连接中继…")
	var seed_value := int(randi() % 2000000000) + 1
	Pvp.host_create({"side": side, "seed": seed_value}, relay_edit.text.strip_edges())

func _on_join() -> void:
	if _busy:
		return
	var c := code_edit.text.strip_edges().to_upper()
	if c.length() != 6:
		status_label.text = I18n.T("请输入 6 位房间码")
		return
	_busy = true
	_set_buttons(false)
	status_label.text = I18n.T("正在连接中继…")
	Pvp.guest_join(c, relay_edit.text.strip_edges())

func _set_buttons(on: bool) -> void:
	create_btn.disabled = not on
	join_btn.disabled = not on

## ---------- 网络回调 ----------

func _on_created(c: String) -> void:
	status_label.text = I18n.T("房间已建好，把房间码发给朋友：")
	code_panel.visible = true
	code_label.text = c
	back_btn.text = I18n.T("取 消")

## 切语言：手里没有房间时整屏重载；等对手时保持不动（文本短暂不随语言切换）
func relang() -> void:
	if Pvp.code == "":
		get_tree().reload_current_scene()

func _on_peer_joined() -> void:
	# 房主：对手已入房 → 带着参数开局
	_start_battle_from(Pvp.settings)

func _on_joined(info: Dictionary) -> void:
	# 加入方：拿到对局参数 → 开局
	_start_battle_from(info)

func _start_battle_from(info: Dictionary) -> void:
	var host_side := str(info.get("side", "han"))
	App.battle_config = {
		"mode": "pvp",
		"mySide": host_side,          # 房主视角：他的 side 就是他自己的阵营
		"seed": int(info.get("seed", 1)),
		"stageName": "联机对战",
	}
	# 对局参数只在房主侧的 Pvp.settings 里完整保存（含自己的选边），
	# 加入方需要换算出自己的阵营
	if Pvp.role == "guest":
		App.battle_config["mySide"] = "chu" if host_side == "han" else "han"
	get_tree().change_scene_to_file(App.SCENE_BATTLE)

func _on_error(msg: String) -> void:
	_busy = false
	_set_buttons(true)
	status_label.text = I18n.T(msg)
