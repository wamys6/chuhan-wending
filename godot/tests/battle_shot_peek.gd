extends SceneTree
## 一次性：拍一张「打到一半」的战斗截图给商店用（不进正式测试集）
##
## 巡览（--tour）里那张 _gd-battle-campaign.png 是开局瞬间，盘面全空，
## 作为商店首图看不出这是卡牌对战。这里用 Ai 双方对下四五回合，停在我方回合再拍。
##
## 语言必须在开打之前定：战报条目里的卡名是生成那一刻写进 {k,a} 的，
## 打完再切语言只会换掉卡面、换不掉已经写进战报的历史条目（截图里会出现
## 中文卡名混在英文句子里）。所以中英各跑一整局，而不是一局切两次语言。
##
## 运行：Godot --path godot --resolution 1920x1080 --script res://tests/battle_shot_peek.gd

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app: Node = root.get_node_or_null("App")
	if app == null:
		print("没有 App autoload")
		quit(1)
		return
	Tutorial.mark_done(Tutorial.BATTLE_INTRO)
	var ok := await _shoot(app, "zh", "_gd-battle-mid.png")
	if ok:
		ok = await _shoot(app, "en", "_gd-battle-mid-en.png")
	Settings.set_lang("zh")
	I18n.init_from_settings()
	quit(0 if ok else 1)


func _shoot(app: Node, lang: String, fname: String) -> bool:
	Settings.set_lang(lang)
	I18n.init_from_settings()
	# 造一份打到一半的战役：前三关已破，进第四关荥阳
	var p: Dictionary = Campaign.start_run(
		"liubang", (GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	Campaign.clear_stage(p, "peixian", "n_shi5")
	Campaign.clear_stage(p, "hongmen", "n_cheng2")
	Campaign.clear_stage(p, "pengcheng", "n_shi4")
	app.progress = p
	app.stage = Campaign.stage_by_id("xingyang")
	app.launch_stage()
	await create_timer(2.6).timeout

	var scene: Node = current_scene
	if scene == null or not ("state" in scene):
		print("没进战斗场景（", lang, "）")
		return false

	var st: Dictionary = scene.state
	if not bool(st.get("over", false)) and str(st.get("current", "")) == "p2":
		# 先手可能是敌方：先让它走完，把回合给回我方
		Ai.apply_action(st, "p2", {"type": "end"})
	# 盘面要铺开：每边 3 支部队才看得出「三列军阵」。第 6 回合起找机会，
	# 到第 14 回合还没铺满就直接拍，不再等（再往后血条会掉太多、不好看）。
	await _advance(st, 6, 3)

	scene.busy = false
	scene._sync_all()
	# 指针默认停在窗口中央，正好压在手牌上 → 卡牌放大悬出来糊住战场。
	# 挪到左上角战报栏那种没有交互的空处，拍干净盘面。
	Input.warp_mouse(Vector2(24, 300))
	await create_timer(0.9).timeout
	_shot(fname, lang)
	return true


## 让 AI 替双方下到第 target 回合、两边各有 need 支部队、且轮到我方时停手
func _advance(st: Dictionary, target: int, need: int) -> void:
	for i in range(600):
		if bool(st.get("over", false)):
			return
		var turn := int(st.get("turnNo", 0))
		var cur := str(st.get("current", ""))
		var u1 := _units(st, "p1")
		var u2 := _units(st, "p2")
		if cur == "p1":
			# 首选两边都铺满；退一步两边各 2 支也拍（再等下去常有一边被打空，
			# 拍出来对面空场，看不出是双方对攻）
			if (turn >= target and u1 >= need and u2 >= need) or (turn >= 10 and u1 >= 2 and u2 >= 2):
				return
		if turn > target + 8:
			return
		var pid := cur
		var act: Dictionary = Ai.next_action(st, pid)
		Ai.apply_action(st, pid, act)
		await process_frame


func _units(st: Dictionary, pid: String) -> int:
	var n := 0
	for r in RulesEngine.RANKS:
		n += (st["players"][pid]["board"][r] as Array).size()
	return n


func _shot(fname: String, lang: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/" + fname)
	print("已存 ", fname, " [", lang, "] turn=", int(current_scene.state.get("turnNo", 0)),
		" 我方兵 ", _units(current_scene.state, "p1"), " 敌方兵 ", _units(current_scene.state, "p2"))
