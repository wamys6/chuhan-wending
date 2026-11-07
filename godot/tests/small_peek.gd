extends SceneTree
## 一次性：1366×768 小屏抓拍（不进正式测试集）
##
## 目的：量清楚「基准 1440×900 + stretch expand」在 1366 宽笔记本上的实际观感。
## 缩放比 = min(1366/1440, 768/900) = 0.853，12px 字只剩 10.2px。
##
## 运行：Godot --path godot --resolution 1366x768 --script res://tests/small_peek.gd

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var win := root
	DisplayServer.window_set_size(Vector2i(1366, 768))
	await process_frame
	await process_frame
	var vs: Vector2 = win.get_visible_rect().size
	print("窗口 ", DisplayServer.window_get_size(), " 视口 ", vs,
		" 缩放 ", minf(vs.x / 1440.0, vs.y / 900.0))

	var app: Node = root.get_node_or_null("App")
	if app == null:
		print("没有 App autoload")
		quit(1)
		return
	Tutorial.mark_done(Tutorial.BATTLE_INTRO)
	Campaign._wipe_all()

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
		Ai.apply_action(st, "p2", {"type": "end"})
	await _advance(st, 5)
	scene.busy = false
	scene._sync_all()
	await create_timer(0.8).timeout
	_shot("_gd-small-battle.png")

	Campaign._wipe_all()
	quit(0)


func _advance(st: Dictionary, target: int) -> void:
	for i in range(400):
		if bool(st.get("over", false)):
			return
		if int(st.get("turnNo", 0)) >= target and str(st.get("current", "")) == "p1" \
				and _units(st, "p1") >= 2 and _units(st, "p2") >= 2:
			return
		var pid := str(st.get("current", ""))
		Ai.apply_action(st, pid, Ai.next_action(st, pid))
		await process_frame


func _units(st: Dictionary, pid: String) -> int:
	var n := 0
	for r in RulesEngine.RANKS:
		n += (st["players"][pid]["board"][r] as Array).size()
	return n


func _shot(fname: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/" + fname)
	print("已存 ", fname, " ", img.get_size())
