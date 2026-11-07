extends SceneTree
## 把 78 张卡按当前语言铺成对照表，肉眼验卡面牌名排版（单行 / 两行 / 是否被切）。
## 数字契约在 legibility_test 里，这个只负责「看一眼」。
##
## 运行：
##   godot --path godot --resolution 1440x900 --script res://tests/cardnames_peek.gd -- --from=0
##   参数：--lang=en / --from=N（从第 N 张开始）/ --only-two（只铺两行牌名那批）
## 注意：会临时改语言，结束时自动还原；改语言会写盘，别在别的测试并行时跑。

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lang := "en"
	var start := 0
	var only_two := false
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--lang="):
			lang = str(a).substr(7)
		elif str(a).begins_with("--from="):
			start = str(a).substr(7).to_int()
		elif str(a) == "--only-two":
			only_two = true
	Settings.set_lang(lang)
	I18n.init_from_settings()

	var root_node := Control.new()
	root_node.size = Vector2(1500, 1700)
	root.add_child(root_node)
	var bg := ColorRect.new()
	bg.color = UiTheme.PAPER
	bg.size = Vector2(1500, 1700)
	root_node.add_child(bg)

	var ids: Array = GameData.cards.keys()
	ids.sort()
	var cols := 10
	var i := 0
	var drawn := 0
	var two := 0
	for id in ids:
		if i < start:
			i += 1
			continue
		if drawn >= 50:
			break
		var c: Dictionary = GameData.card(str(id))
		if c.is_empty():
			continue
		var cv := CardView.new()
		cv.setup(c.duplicate(true), str(id))
		root_node.add_child(cv)
		var is_two := str(cv._name_label.text).contains("\n")
		if only_two and not is_two:
			cv.queue_free()
			i += 1
			continue
		cv.position = Vector2(12 + (drawn % cols) * 147, 10 + (drawn / cols) * 205)
		if str(cv._name_label.text).contains("\n"):
			two += 1
		i += 1
		drawn += 1
	print("铺了 ", drawn, " 张（自 ", start, "），两行牌名 ", two, " 张 [", lang, "]")
	await create_timer(1.2).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/_gd-cardnames-%s-%d.png" % [lang, start])
	print("已存 _gd-cardnames-", lang, "-", start, ".png")
	# 一定要还原：Settings.set_lang 会写盘，忘了还原会把整台机器上的游戏语言留在英文，
	# 下一批测试就集体失败（battle_ui 断言「牌库 N」却读到「Deck N」）。
	Settings.set_lang("zh")
	quit(0)
