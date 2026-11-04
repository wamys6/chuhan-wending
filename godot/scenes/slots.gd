## 存档位：3 个战役存档，各自的进度/牌组/军师互不干扰
extends Control

var _confirming := -1

func _ready() -> void:
	theme = UiTheme.build()
	GameData.ensure_loaded()
	_build()

func _build() -> void:
	Widgets.paper_bg(self)
	_add_back()

	var t := Widgets.title("存 档 位", 40)
	t.position = Vector2(0, 74)
	t.size = Vector2(1440, 56)
	add_child(t)

	var sub := Widgets.subtitle("三个存档各存一局战役 · 成就业绩为全局记录", 15)
	sub.position = Vector2(0, 140)
	sub.size = Vector2(1440, 26)
	add_child(sub)

	var card_w := 400.0
	var gap := 40.0
	var total := Campaign.slot_count() * card_w + (Campaign.slot_count() - 1) * gap
	var x := (1440.0 - total) * 0.5
	for i in Campaign.slot_count():
		var card := _slot_card(i)
		card.position = Vector2(x + i * (card_w + gap), 210)
		card.size = Vector2(card_w, 460)
		add_child(card)
		Widgets.rise_in(card, 0.1 + i * 0.08, 22.0)

func _slot_card(index: int) -> Panel:
	var info := Campaign.slot_summary(index)
	var card := Panel.new()
	var border := UiTheme.SEAL if bool(info["active"]) else UiTheme.INK
	card.add_theme_stylebox_override("panel",
		UiTheme.panel_style(UiTheme.PAPER if bool(info["active"]) else UiTheme.PAPER_DEEP, border, 8, 3))

	var badge := Panel.new()
	badge.position = Vector2(20, 20)
	badge.size = Vector2(44, 44)
	badge.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.INK, UiTheme.INK, 6, 0))
	card.add_child(badge)
	var num := UiTheme.label(str(index + 1), 24, UiTheme.PAPER)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(num)

	if bool(info["active"]):
		var tag := Widgets.chip("当 前", UiTheme.SEAL, UiTheme.PAPER)
		tag.position = Vector2(300, 26)
		card.add_child(tag)

	if bool(info["empty"]):
		var empty := UiTheme.label("空 位", 26, UiTheme.INK_SOFT)
		empty.position = Vector2(0, 150)
		empty.size = Vector2(400, 40)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(empty)

		var tip := Widgets.subtitle("未开战", 15)
		tip.position = Vector2(0, 196)
		tip.size = Vector2(400, 24)
		card.add_child(tip)

		var start := UiTheme.button("开 新 战 役", true)
		start.position = Vector2(90, 340)
		start.size = Vector2(220, 52)
		start.pressed.connect(func (): App.enter_slot(index))
		card.add_child(start)
		return card

	# 已有进度
	var hero := UiTheme.label(str(info["hero"]), 30, UiTheme.SEAL)
	hero.position = Vector2(80, 26)
	hero.size = Vector2(220, 40)
	card.add_child(hero)

	var progress_txt := "已通关 %d / %d" % [int(info["cleared"]), int(info["total"])]
	if bool(info["finished"]):
		progress_txt = "战役已终 · %d 关全胜" % int(info["total"])
	var p1 := UiTheme.label(progress_txt, 19, UiTheme.INK)
	p1.position = Vector2(24, 96)
	card.add_child(p1)

	var lines := [
		"下一关　%s" % str(info["nextStage"]),
		"牌组　　%d 张" % int(info["deckSize"]),
	]
	if str(info["advisor"]) != "":
		lines.append("军师　　%s" % str(info["advisor"]))
	if int(info["hpBonus"]) != 0:
		lines.append("生命　　%+d" % int(info["hpBonus"]))
	lines.append("保存　　%s" % _time_text(int(info["updatedAt"])))
	var y := 140.0
	for line in lines:
		var l := UiTheme.label(str(line), 16, UiTheme.INK_SOFT)
		l.position = Vector2(24, y)
		card.add_child(l)
		y += 30

	var enter := UiTheme.button("进 入 战 役", true)
	enter.position = Vector2(24, 356)
	enter.size = Vector2(210, 50)
	enter.pressed.connect(func (): App.enter_slot(index))
	card.add_child(enter)

	var wipe_text := "确 认 清 空" if _confirming == index else "清 空"
	var wipe := UiTheme.button(wipe_text)
	wipe.position = Vector2(250, 356)
	wipe.size = Vector2(126, 50)
	wipe.pressed.connect(func ():
		if _confirming != index:
			_confirming = index
			_refresh()
			return
		Campaign.clear_slot(index)
		_confirming = -1
		_refresh())
	card.add_child(wipe)
	return card

func _refresh() -> void:
	for child in get_children():
		child.queue_free()
	_build()

func _time_text(ts: int) -> String:
	if ts <= 0:
		return "—"
	var d := Time.get_datetime_dict_from_unix_time(ts)
	return "%d-%02d-%02d %02d:%02d" % [int(d["year"]), int(d["month"]), int(d["day"]),
		int(d["hour"]), int(d["minute"])]

func _add_back() -> void:
	var back := UiTheme.button("返 回")
	back.position = Vector2(40, 30)
	back.size = Vector2(120, 46)
	back.pressed.connect(func (): App.go(App.SCENE_MENU))
	add_child(back)
