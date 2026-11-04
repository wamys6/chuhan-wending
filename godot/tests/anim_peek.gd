## 一次性验证：攻击冲刺动画 + 命中特效抓拍（不进正式测试集）
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.4).timeout

	# 真实引擎流程：给足军粮出一张部队牌（冲锋/强攻都行），手动允许攻击后打敌将
	var me: Dictionary = scene.state["players"]["p1"]
	me["mana"] = 10
	var piece: Dictionary = {}
	for c in me["hand"]:
		if str(c.get("type", "")) == "piece" and int(c.get("atk", 0)) > 0:
			piece = c
			break
	if piece.is_empty():
		print("手里没有部队牌，跳过")
		quit(1)
		return
	var r0: Dictionary = RulesEngine.play_card(scene.state, "p1", int(piece["uid"]))
	if not bool(r0.get("ok", false)):
		print("出牌失败: ", r0)
		quit(1)
		return
	await process_frame
	# 直接动引擎后必须手动同步，UnitView 才会建出来（真实流程由 UI 出牌驱动）
	scene._sync_all()
	await create_timer(0.5).timeout
	# 找到刚登场的单位（可能在任意列），允许攻击
	var attacker: Dictionary = {}
	for r in RulesEngine.RANKS:
		for u in scene.state["players"]["p1"]["board"][r]:
			if int(u["uid"]) == int(piece["uid"]):
				attacker = u
	if attacker.is_empty():
		print("单位不在场上")
		quit(1)
		return
	attacker["canAttack"] = true
	var p2hp_before := int(scene.state["players"]["p2"]["hp"])

	# 发起攻击（打敌将），在冲刺途中和命中瞬间各抓一帧
	if scene.get("_close_coach") != null:
		scene._close_coach()
	await process_frame
	scene._do_attack(int(attacker["uid"]), {"kind": "hero"})
	var uv2: UnitView = scene.unit_views[int(attacker["uid"])]
	print("sync-probe: lunging=%s pos=%s busy=%s" % [str(uv2.lunging), str(uv2.position), str(scene.busy)])
	await process_frame
	print("probes: uid_in_views=%s toast=%s p2hp=%d p2hp_before=%d" % [
		str(scene.unit_views.has(int(attacker["uid"]))),
		str(scene.toast_label.text),
		int(scene.state["players"]["p2"]["hp"]), int(p2hp_before)])
	for i in 6:
		await create_timer(0.02).timeout
		print("t=%.2f fx_layer=%d lunging=%s" % [0.02 * (i + 1),
			scene.fx_layer.get_child_count(), str(scene.unit_views[attacker["uid"]].lunging)])
	_shot(scene, "_gd-anim-lunge.png")
	await create_timer(0.11).timeout
	_shot(scene, "_gd-anim-impact.png")
	await create_timer(0.6).timeout
	_shot(scene, "_gd-anim-after.png")

	# 阵亡碎裂/烟尘：在空位上摆一个兵再触发
	var base_id := str(GameData.cards.keys()[0])
	var uv := UnitView.new()
	scene.board_layer.add_child(uv)
	uv.setup({"uid": 991000, "baseId": base_id, "name": "试", "atk": 2, "hp": 2,
		"maxHp": 2, "col": "front", "canAttack": false, "taunt": false})
	uv.position = Vector2(396 - 48, 332)
	await create_timer(0.15).timeout
	scene._death_fx(uv)
	uv.die()
	await create_timer(0.1).timeout
	_shot(scene, "_gd-anim-death.png")
	await create_timer(0.5).timeout
	quit(0)

func _shot(scene: Node, fname: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/" + fname)
	print("已存 ", fname)
