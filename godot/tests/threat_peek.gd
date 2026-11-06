## 一次性验证：敌方意图预告「险」印抓拍（不进正式测试集）
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.4).timeout

	var me: Dictionary = scene.state["players"]["p1"]
	var foe: Dictionary = scene.state["players"]["p2"]
	for pid in ["p1", "p2"]:
		for r in RulesEngine.RANKS:
			(scene.state["players"][pid]["board"][r] as Array).clear()
	if scene.get("_close_coach") != null:
		scene._close_coach()

	# 敌方：戎车 5/5 前锋 + 飞石炮 2/4 后军；我方：锐士 2/3 前锋（被单杀，亮印）、
	# 持戟卫 1/4 守御中军（5 攻打不死，不亮印——火力被前锋吸走前它够不着，正好同框对比）
	foe["board"]["front"].append(RulesEngine.new_instance("n_che1"))
	foe["board"]["back"].append(RulesEngine.new_instance("n_pao1"))
	me["board"]["front"].append(RulesEngine.new_instance("n_bing2"))
	me["board"]["mid"].append(RulesEngine.new_instance("n_shi1"))
	me["hp"] = 26
	scene.state["current"] = "p1"
	scene._sync_all()
	await create_timer(0.7).timeout
	_shot(scene, "_gd-threat-marks.png")

	# 主将斩杀线：全场无兵 + 血量进线 → 血条亮印
	for r in RulesEngine.RANKS:
		(me["board"][r] as Array).clear()
	me["hp"] = 5
	scene._sync_all()
	await create_timer(0.7).timeout
	_shot(scene, "_gd-threat-hero.png")

	# 牌库/疲劳标签：正常余量 → 抽空转疲劳态
	me["hp"] = 30
	me["fatigue"] = 2
	(me["deck"] as Array).clear()
	scene._sync_all()
	await create_timer(0.7).timeout
	_shot(scene, "_gd-deck-fatigue.png")
	me["fatigue"] = 0
	(me["deck"] as Array).append(RulesEngine.new_instance("n_bing2"))
	(me["deck"] as Array).append(RulesEngine.new_instance("n_shi1"))
	scene._sync_all()
	await create_timer(0.7).timeout
	_shot(scene, "_gd-deck-low.png")

	quit(0)

func _shot(scene: Node, fname: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/" + fname)
	print("已存 ", fname)
