extends SceneTree
## 一次性：拍一张「打到一半」的战斗截图给商店用（不进正式测试集）
##
## 巡览（--tour）里那张 _gd-battle-campaign.png 是开局瞬间，盘面全空，
## 作为商店首图看不出这是卡牌对战。这里用 Ai 双方对下四五回合，停在我方回合再拍。
##
## 运行：Godot --path godot --script res://tests/battle_shot_peek.gd

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app: Node = root.get_node_or_null("App")
	if app == null:
		print("没有 App autoload")
		quit(1)
		return
	Tutorial.mark_done(Tutorial.BATTLE_INTRO)
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
		print("没进战斗场景")
		quit(1)
		return

	var st: Dictionary = scene.state
	if not bool(st.get("over", false)) and str(st.get("current", "")) == "p2":
		# 先手可能是敌方：先让它走完，把回合给回我方
		Ai.apply_action(st, "p2", {"type": "end"})
	await _advance(st, 5)

	scene.busy = false
	scene._sync_all()
	await create_timer(0.9).timeout
	_shot("_gd-battle-mid.png")

	# 再来一张英文的：商店页按语言分流
	Settings.set_lang("en")
	I18n.init_from_settings()
	scene._sync_all()
	await create_timer(0.6).timeout
	_shot("_gd-battle-mid-en.png")
	Settings.set_lang("zh")
	I18n.init_from_settings()
	quit(0)


## 让 AI 替双方下到第 target 回合、且轮到我方时停手
func _advance(st: Dictionary, target: int) -> void:
	for i in range(400):
		if bool(st.get("over", false)):
			return
		var turn := int(st.get("turnNo", 0))
		var cur := str(st.get("current", ""))
		if turn >= target and cur == "p1" and _units(st, "p1") >= 2 and _units(st, "p2") >= 2:
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


func _shot(fname: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/" + fname)
	print("已存 ", fname, " turn=", int(current_scene.state.get("turnNo", 0)),
		" 我方兵 ", _units(current_scene.state, "p1"), " 敌方兵 ", _units(current_scene.state, "p2"))
