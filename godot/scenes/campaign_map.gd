## 战役地图：8 关节点 + 当前军师与加成 + 牌组预览
extends Control

const NODE_W := 150.0
const NODE_H := 196.0
const NODE_GAP := 18.0
const NODE_Y := 356.0

var _deck_overlay: Control = null

func _ready() -> void:
	theme = UiTheme.build()
	GameData.ensure_loaded()
	if App.progress.is_empty():
		App.progress = Campaign.load_slot(Campaign.active_slot())
	_build()

func _build() -> void:
	Widgets.paper_bg(self)
	_build_header()
	_build_info()
	_build_path()

# ---------------- 顶部 ----------------

func _build_header() -> void:
	var back := UiTheme.button("返 回")
	back.position = Vector2(40, 28)
	back.size = Vector2(110, 44)
	back.pressed.connect(func (): App.back_to_menu())
	add_child(back)

	var title := UiTheme.label("楚 汉 战 役", 32, UiTheme.INK)
	title.position = Vector2(180, 30)
	add_child(title)

	var sub := UiTheme.label("自沛县起兵，至垓下决战", 15, UiTheme.INK_SOFT)
	sub.position = Vector2(184, 70)
	add_child(sub)

	var slots := UiTheme.button("存 档 位")
	slots.position = Vector2(1150, 30)
	slots.size = Vector2(130, 44)
	slots.pressed.connect(func (): App.go(App.SCENE_SLOTS))
	add_child(slots)

	var deck := UiTheme.button("牌 组")
	deck.position = Vector2(1290, 30)
	deck.size = Vector2(110, 44)
	deck.pressed.connect(_open_deck)
	add_child(deck)

	var line := ColorRect.new()
	line.color = Color(0.11, 0.10, 0.09, 0.12)
	line.position = Vector2(40, 110)
	line.size = Vector2(1360, 2)
	add_child(line)

# ---------------- 战役状态条 ----------------

func _build_info() -> void:
	var p := App.progress
	var hero := GameData.hero(str(p.get("hero", "liubang")))
	var cleared := (p.get("cleared", []) as Array).size()
	var total := Campaign.stages().size()

	# 顶栏用横向容器按内容排：英文比中文宽不少，固定坐标会互相压字
	var bar := HBoxContainer.new()
	bar.position = Vector2(44, 134)
	bar.size = Vector2(1352, 40)
	bar.add_theme_constant_override("separation", 28)
	add_child(bar)
	bar.add_child(UiTheme.label("主将　%s" % str(hero.get("name", "刘邦")), 19, UiTheme.SEAL))
	bar.add_child(UiTheme.label("进度　%d / %d" % [cleared, total], 19, UiTheme.INK))
	var adv := Campaign.advisor_by_id(str(p.get("advisor", "")))
	if not adv.is_empty():
		bar.add_child(UiTheme.label("军师　%s" % str(adv.get("name", "")), 19, UiTheme.INK))

	# 加成 chips
	var chips: Array = []
	if int(p.get("hpBonus", 0)) != 0:
		chips.append("生命 %+d" % int(p["hpBonus"]))
	if int(p.get("manaBonus", 0)) != 0:
		chips.append("军粮 %+d" % int(p["manaBonus"]))
	if int(p.get("drawBonus", 0)) != 0:
		chips.append("起手 %+d" % int(p["drawBonus"]))
	if int(p.get("enemyManaBonus", 0)) != 0:
		chips.append("敌粮 %+d" % int(p["enemyManaBonus"]))
	# 死战专精：牌组属性，不是临时加成——一旦达标，后面每关都在，所以常驻显示。
	# 未达标时不显示，免得每局都在一个用不上的 chip 上分散注意力。
	var ls_tier := Campaign.last_stand_tier(p.get("deck", []))
	if ls_tier > 0:
		var lsb := Campaign.last_stand_bonus(p.get("deck", []))
		chips.append("死战专精 +%d/+%d" % [int(lsb[0]), int(lsb[1])])
	for c in chips:
		bar.add_child(Widgets.chip(str(c), UiTheme.PAPER_DEEP, UiTheme.SEAL))

	if cleared > 0:
		var log_btn := UiTheme.button("行 军 记")
		log_btn.position = Vector2(1230, 132)
		log_btn.size = Vector2(130, 42)
		log_btn.pressed.connect(_toggle_log)
		add_child(log_btn)

	_build_run_bar(p)

# ---------------- 本局规则：心魔 + 天时 ----------------

## 单独一行放在状态条下方：心魔是玩家自己选的难度，天时是开局抽到的全局修正，
## 两者都贯穿八关，必须让玩家在每关出征前都看得见。
func _build_run_bar(p: Dictionary) -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(44, 182)
	bar.size = Vector2(1180, 32)
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)

	var lv := int(p.get("ascension", 0))
	if lv > 0:
		bar.add_child(Widgets.chip("心魔 %d" % lv, UiTheme.SEAL, UiTheme.PAPER))
		bar.add_child(UiTheme.label(Campaign.ascension_summary(lv), 15, UiTheme.INK_SOFT))
	else:
		bar.add_child(Widgets.chip("常规难度", UiTheme.PAPER_DEEP, UiTheme.INK_SOFT))

	var ts := Campaign.tian_shi_by_id(str(p.get("tianShi", "")))
	if not ts.is_empty():
		bar.add_child(Widgets.chip(str(ts.get("name", "")), UiTheme.PAPER_DEEP, UiTheme.SEAL))
		bar.add_child(UiTheme.label(str(ts.get("desc", "")), 15, UiTheme.INK_SOFT))

# ---------------- 关卡路径 ----------------

func _build_path() -> void:
	var list := Campaign.stages()
	var total_w := list.size() * NODE_W + (list.size() - 1) * NODE_GAP
	var start_x := (1440.0 - total_w) * 0.5
	var mid_y := NODE_Y + NODE_H * 0.5

	var path := ColorRect.new()
	path.color = Color(0.11, 0.10, 0.09, 0.14)
	path.position = Vector2(start_x + NODE_W * 0.5, mid_y - 1.0)
	path.size = Vector2(total_w - NODE_W, 2)
	add_child(path)

	for i in list.size():
		var st: Dictionary = list[i]
		var status := Campaign.status_of(App.progress, str(st["id"]))
		var node := _stage_node(st, i, status)
		node.position = Vector2(start_x + i * (NODE_W + NODE_GAP), NODE_Y)
		node.size = Vector2(NODE_W, NODE_H)
		add_child(node)
		Widgets.rise_in(node, 0.08 + i * 0.05, 20.0)

	# 待战关卡目标条
	for i in list.size():
		var st: Dictionary = list[i]
		if Campaign.status_of(App.progress, str(st["id"])) != "open":
			continue
		var goal_txt := str(st.get("goalText", ""))
		if goal_txt == "":
			break
		var bar := Panel.new()
		# 英文目标句长得多，横幅加宽一截
		bar.position = Vector2(210, 604)
		bar.size = Vector2(1020 if I18n.is_en() else 680, 56)
		bar.add_theme_stylebox_override("panel",
			UiTheme.panel_style(UiTheme.PAPER_DEEP, UiTheme.SEAL, 28, 2))
		add_child(bar)
		var tag := UiTheme.label("本关目标", 14, UiTheme.PAPER)
		tag.position = Vector2(24, 6)
		var tag_w := 98.0 if I18n.is_en() else 70.0
		tag.size = Vector2(tag_w, 20)
		var tagbg := Panel.new()
		tagbg.position = Vector2(18, 14)
		tagbg.size = Vector2(tag_w + 12, 28)
		tagbg.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SEAL, UiTheme.SEAL, 14, 0))
		bar.add_child(tagbg)
		tagbg.add_child(tag)
		var goal_label := UiTheme.label(goal_txt, 16, UiTheme.INK)
		goal_label.position = Vector2(116, 0)
		goal_label.size = Vector2(bar.size.x - 140, 56)
		goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bar.add_child(goal_label)
		break

func _stage_node(st: Dictionary, index: int, status: String) -> Panel:
	var node := Panel.new()
	var border := UiTheme.INK
	var bg := UiTheme.PAPER
	if status == "cleared":
		border = UiTheme.GOLD
		bg = UiTheme.PAPER
	elif status == "open":
		border = UiTheme.SEAL
		bg = UiTheme.PAPER
	else:
		border = Color(0.11, 0.10, 0.09, 0.25)
		bg = UiTheme.PAPER_DEEP
	node.add_theme_stylebox_override("panel", UiTheme.panel_style(bg, border, 8, 3 if status != "locked" else 1))
	if status == "locked":
		node.modulate = Color(1, 1, 1, 0.55)

	var chapter := UiTheme.label(str(st["chapter"]), 13, UiTheme.INK_SOFT)
	chapter.position = Vector2(0, 12)
	chapter.size = Vector2(NODE_W, 20)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(chapter)

	# 序号圆牌
	var badge := Panel.new()
	badge.position = Vector2(NODE_W * 0.5 - 22, 36)
	badge.size = Vector2(44, 44)
	var badge_bg := UiTheme.SEAL if status == "open" else UiTheme.INK
	if status == "locked":
		badge_bg = Color(0.55, 0.53, 0.5)
	badge.add_theme_stylebox_override("panel", UiTheme.panel_style(badge_bg, badge_bg, 22, 0))
	node.add_child(badge)
	var mark := "✓" if status == "cleared" else str(index + 1)
	var num := UiTheme.label(mark, 20, UiTheme.PAPER)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(num)

	var name_label := UiTheme.label(str(st["name"]), 19, UiTheme.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if I18n.is_en():
		# 英文关名长（The Standoff at Xingyang），节点里折成两行小字
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.position = Vector2(6, 84)
		name_label.size = Vector2(NODE_W - 12, 44)
	else:
		name_label.position = Vector2(0, 92)
		name_label.size = Vector2(NODE_W, 28)
	node.add_child(name_label)

	var status_text: String = str({"cleared": "已 破", "open": "待 战", "locked": "未 解 锁"}.get(status, ""))
	var state_label := UiTheme.label(str(status_text), 14,
		UiTheme.SEAL if status == "open" else UiTheme.INK_SOFT)
	state_label.position = Vector2(0, 122)
	state_label.size = Vector2(NODE_W, 22)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(state_label)

	# 待战节点的目标统一放到路径下方的目标条里，节点内不再塞小字

	if status == "open":
		# 呼吸提示挂在序号圆牌上，避免和入场淡入抢同一个属性
		var tw := badge.create_tween().set_loops()
		tw.tween_property(badge, "modulate", Color(1, 1, 1, 0.72), 0.9)
		tw.tween_property(badge, "modulate", Color(1, 1, 1, 1.0), 0.9)
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func (): App.open_stage(str(st["id"])))
		node.add_child(btn)
	return node

# ---------------- 牌组预览 ----------------

func _open_deck() -> void:
	if _deck_overlay != null:
		_deck_overlay.queue_free()
		_deck_overlay = null
		return
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 50
	add_child(layer)
	_deck_overlay = layer

	var dim := ColorRect.new()
	dim.color = Color(0.11, 0.10, 0.09, 0.5)
	Widgets.fill_screen(dim)
	dim.gui_input.connect(func (e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_open_deck())
	layer.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(120, 70)
	panel.size = Vector2(1200, 760)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.SEAL, 8, 3))
	layer.add_child(panel)

	var deck: Array = App.progress.get("deck", [])
	var title := UiTheme.label("牌 组 · %d 张" % deck.size(), 26, UiTheme.SEAL)
	title.position = Vector2(32, 24)
	panel.add_child(title)

	var hint := UiTheme.label("同名最多 2 张 · 战后奖励会加入这里", 14, UiTheme.INK_SOFT)
	hint.position = Vector2(220, 34)
	panel.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 76)
	scroll.size = Vector2(1144, 650)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var counts := {}
	for id in deck:
		counts[str(id)] = int(counts.get(str(id), 0)) + 1
	for id in counts.keys():
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(120, 196)
		var cv := Widgets.card_view(str(id), 0.86)
		cv.position = Vector2(4, 0)
		holder.add_child(cv)
		if int(counts[id]) > 1:
			var tag := Widgets.chip("×%d" % int(counts[id]), UiTheme.SEAL, UiTheme.PAPER)
			tag.position = Vector2(70, 4)
			holder.add_child(tag)
		grid.add_child(holder)

	Widgets.fade_in(panel, 0.0, 0.18)

# ---------------- 行军记 ----------------

var _log_panel: Control = null

func _toggle_log() -> void:
	if _log_panel != null:
		_log_panel.queue_free()
		_log_panel = null
		return
	var log_entries: Array = App.progress.get("eventLog", [])
	var layer := Control.new()
	layer.z_index = 50
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	_log_panel = layer

	var dim := ColorRect.new()
	dim.color = Color(0.11, 0.10, 0.09, 0.35)
	Widgets.fill_screen(dim)
	dim.gui_input.connect(func (e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_toggle_log())
	layer.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(860, 120)
	panel.size = Vector2(500, 520)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.INK, 8, 2))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var title := UiTheme.label("行 军 记", 24, UiTheme.SEAL)
	title.position = Vector2(28, 22)
	panel.add_child(title)

	var y := 70.0
	if log_entries.is_empty():
		var empty := UiTheme.label("尚无行军际遇。", 16, UiTheme.INK_SOFT)
		empty.position = Vector2(28, y)
		panel.add_child(empty)
	for entry in log_entries:
		var line := UiTheme.label("%s　—　%s" % [str(entry.get("name", "")), str(entry.get("choice", ""))],
			15, UiTheme.INK_SOFT)
		line.position = Vector2(28, y)
		line.size = Vector2(440, 24)
		panel.add_child(line)
		y += 30
		if y > 470:
			break
	Widgets.fade_in(panel, 0.0, 0.18)
