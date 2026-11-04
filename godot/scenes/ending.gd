## 结局画面：八关全破后的收束——史实叙事 + 本局回顾
##
## 打通垓下（选完最后一张奖励牌）抵达。叙事随主将不同：
## 刘邦线是「即皇帝位」，项羽线是「霸王定鼎」。看完回主菜单/开新局。
extends Control

func _ready() -> void:
	theme = UiTheme.build()
	if App.progress.is_empty() or not Campaign.is_finished(App.progress):
		# 只该在通关后抵达；误入（调试直进等）就送回主菜单
		App.go(App.SCENE_MENU)
		return
	_build()

func _build() -> void:
	Widgets.paper_bg(self)
	Widgets.art_bg(self, "sc_gaixia", 0.86)

	var hero_id := str(App.progress.get("hero", "liubang"))
	var advisor := Campaign.advisor_by_id(str(App.progress.get("advisor", "")))
	var lb := App.last_battle
	var career := Codex.current()

	var title := Widgets.title("问 鼎 天 下", 52, UiTheme.SEAL)
	title.position = Vector2(0, 96)
	title.size = Vector2(1440, 72)
	add_child(title)
	Widgets.fade_in(title, 0.15, 0.5)

	# 史实收束（随主将）
	var lore := "项羽兵败垓下，自刎乌江。刘邦即皇帝位，国号汉，四海再归一统。"
	if hero_id == "xiangyu":
		lore = "汉军溃于垓下，刘邦北走。霸王定鼎彭城，楚旗蔽野，天下再入楚制。"
	var story := Widgets.subtitle(lore, 18)
	story.position = Vector2(0, 186)
	story.size = Vector2(1440, 30)
	add_child(story)
	Widgets.fade_in(story, 0.45, 0.5)

	var epilog := Widgets.paragraph(
		"楚河汉界，至此落定。从沛县起兵到垓下一战，你打出的每一张牌，都是这段历史的注脚。",
		16, UiTheme.INK_SOFT, 900.0)
	epilog.position = Vector2(270, 228)
	epilog.size = Vector2(900, 26)
	add_child(epilog)

	# 本局回顾纸面
	# 高度按 6 行 × 40 的节奏留足余量：原来 250 高、末行写到 230，
	# 「生涯作战」那行正好被下边框切掉半截（2026-11-03 表现打磨修）
	var panel := Panel.new()
	panel.position = Vector2(420, 296)
	panel.size = Vector2(600, 288)
	panel.add_theme_stylebox_override("panel",
		UiTheme.panel_style(Color(0.973, 0.961, 0.925, 0.9), UiTheme.INK_SOFT, 8, 2))
	add_child(panel)
	Widgets.fade_in(panel, 0.7, 0.4)

	var lv := int(App.progress.get("ascension", 0))
	var diff_text: String = I18n.T("常规难度") if lv == 0 else I18n.T("心魔 %d" % lv)
	var rows := [
		"主将　%s" % str(GameData.hero(hero_id).get("name", hero_id)),
		"军师　%s" % str(advisor.get("name", "—")),
		"本局难度　%s" % diff_text,
		"牌组　　%d 张" % (App.progress.get("deck", []) as Array).size(),
		"造成伤害 %d　直击主将 %d　出兵 %d　用计 %d" % [
			int(lb.get("dmg", 0)), int(lb.get("heroDmg", 0)),
			int(lb.get("units", 0)), int(lb.get("spells", 0))],
		"生涯作战 %d 场 · 胜 %d 场" % [int(career.get("battles", 0)), int(career.get("wins", 0))],
	]
	var y := 28.0
	for i in rows.size():
		# 生涯战绩和「本局回顾」不是一回事，用一条极淡的线隔开，免得读成同一组数字
		if i == rows.size() - 1:
			var line := ColorRect.new()
			line.color = Color(UiTheme.INK_SOFT.r, UiTheme.INK_SOFT.g, UiTheme.INK_SOFT.b, 0.18)
			line.position = Vector2(48, y - 12)
			line.size = Vector2(504, 1)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(line)
			y += 4.0
		var l := UiTheme.label(str(rows[i]), 17, UiTheme.INK)
		l.position = Vector2(48, y)
		panel.add_child(l)
		y += 40.0

	# 长线钩子：这一局打完了，下一级心魔就该露面了
	var unlock := Codex.ascension_unlocked()
	if unlock > lv:
		var hint := Widgets.subtitle("已解锁下一级心魔 —— 下次择师时可选，难度更高", 16)
		hint.position = Vector2(0, 596)
		hint.size = Vector2(1440, 24)
		add_child(hint)
		Widgets.fade_in(hint, 0.9, 0.4)

	# 出口
	var again := UiTheme.button("再 开 一 局", true)
	again.position = Vector2(720 - 230, 626)
	again.size = Vector2(210, 58)
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(func (): App.go(App.SCENE_SLOTS))
	add_child(again)

	var menu := UiTheme.button("返 回 主 菜 单")
	menu.position = Vector2(720 + 20, 626)
	menu.size = Vector2(210, 58)
	menu.add_theme_font_size_override("font_size", 22)
	menu.pressed.connect(func (): App.back_to_menu())
	add_child(menu)

	var foot := Widgets.subtitle("战役 8 关 · 卡池 %d 张" % GameData.cards.size(), 14)
	foot.position = Vector2(0, 812)
	foot.size = Vector2(1440, 22)
	add_child(foot)
