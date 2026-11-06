## 关卡过场：场景立绘 + 史实背景 + 本关目标，确认后出阵
extends Control

func _ready() -> void:
	theme = UiTheme.build()
	GameData.ensure_loaded()
	if App.stage.is_empty():
		App.go(App.SCENE_MAP)
		return
	_build()

func _build() -> void:
	var st := App.stage
	Widgets.paper_bg(self)
	Widgets.art_bg(self, "sc_" + str(st["id"]), 0.80)

	# 章回标签
	var chapter := Widgets.chip(str(st["chapter"]), UiTheme.SEAL, UiTheme.PAPER)
	chapter.position = Vector2(720 - 40, 92)
	add_child(chapter)

	var title := Widgets.title(str(st["name"]), 46)
	title.position = Vector2(0, 132)
	title.size = Vector2(1440, 64)
	add_child(title)

	var year := Widgets.subtitle("%s · %s" % [str(st["year"]), str(st["subtitle"])], 17)
	year.position = Vector2(0, 200)
	year.size = Vector2(1440, 26)
	add_child(year)

	# 正文纸面
	var panel := Panel.new()
	panel.position = Vector2(360, 258)
	panel.size = Vector2(720, 300)
	panel.add_theme_stylebox_override("panel",
		UiTheme.panel_style(Color(0.973, 0.961, 0.925, 0.9), UiTheme.INK_SOFT, 8, 2))
	add_child(panel)

	var lore := Widgets.paragraph(str(st["lore"]), 17, UiTheme.INK, 660.0)
	lore.position = Vector2(30, 30)
	panel.add_child(lore)

	var goal_chip := Widgets.chip("本关目标 · " + str(st.get("goalText", "")), UiTheme.PAPER_DEEP, UiTheme.SEAL)
	goal_chip.position = Vector2(30, 236)
	panel.add_child(goal_chip)

	# 重整机会：出征前必须知道「这一仗还有没有第二次机会」
	# 文案不写次数，写「有没有」——玩家关心的是还有没有退路，不是余量数字
	var retry_line := "本关重整：尚有一次" if App.stage_retry_left() > 0 else "本关重整：已用完 · 再败即终局"
	var retry_label := UiTheme.label(retry_line, 13, UiTheme.INK_SOFT)
	retry_label.position = Vector2(30, 272)
	retry_label.clip_text = true
	retry_label.size = Vector2(660, 20)
	panel.add_child(retry_label)

	# 本局的两条全局规则（心魔 / 天时）：出征前必须让玩家看到
	var run_line := _run_rules_text()
	if run_line != "":
		var rl := Widgets.subtitle(run_line, 15)
		rl.position = Vector2(0, 562)
		rl.size = Vector2(1440, 22)
		add_child(rl)

	var fight := UiTheme.button("出 阵", true)
	fight.position = Vector2(720 - 110, 600)
	fight.size = Vector2(220, 60)
	fight.add_theme_font_size_override("font_size", 24)
	fight.pressed.connect(func (): App.launch_stage())
	add_child(fight)

	var back := UiTheme.button("返 回")
	back.position = Vector2(720 - 200, 676)
	back.size = Vector2(400, 44)
	back.pressed.connect(func (): App.go(App.SCENE_MAP))
	add_child(back)

	Widgets.fade_in(panel, 0.1, 0.3)
	Widgets.rise_in(fight, 0.35, 16.0)
	Widgets.fade_in(back, 0.4, 0.25)

## 心魔 + 天时（数据已按当前语言本地化，这里只拼装）
func _run_rules_text() -> String:
	var p := App.progress
	var parts: Array = []
	var lv := int(p.get("ascension", 0))
	if lv > 0:
		var acc := Campaign.ascension_by_level(lv)
		if not acc.is_empty():
			parts.append("%s · %s" % [str(acc.get("name", "")), Campaign.ascension_summary(lv)])
	var ts := Campaign.tian_shi_by_id(str(p.get("tianShi", "")))
	if not ts.is_empty():
		parts.append("%s · %s" % [str(ts.get("name", "")), str(ts.get("desc", ""))])
	return "　·　".join(parts)
