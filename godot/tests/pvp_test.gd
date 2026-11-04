extends SceneTree
## PvP 测试：锁步确定性 + 视角翻转 + 中继全链路 E2E
## 运行：godot --headless --path godot --script res://tests/pvp_test.gd

var _pass := 0
var _fail := 0

func ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  ✓ " + label)
	else:
		_fail += 1
		print("  ✗ " + label + ("" if detail == "" else "  → " + detail))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("== PvP 锁步确定性 ==")
	await _test_lockstep()
	print("== PvP 视角翻转（battle 场景）==")
	await _test_view_flip()
	print("== PvP 中继全链路 E2E ==")
	await _test_relay_e2e()

	print("")
	print("pvp: 通过 %d 项，失败 %d 项" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

# ---------------- ① 锁步确定性 ----------------

## 先录后放：AI 驱动录下线上格式动作序列（每 20 步留指纹快照），
## 再用同一 seed 的全新引擎盲放——这正是两端锁步的真实模型
## （各进程一份独立 rng，只交换动作）。重放走远端动作同款映射。
func _test_lockstep() -> void:
	for seed_v in [7, 123456789, 1999999999]:
		RulesEngine.rng = Rng.new(seed_v)
		var a := _fresh_game()
		var trace: Array = []
		var pids: Array = []
		var snaps: Dictionary = {}
		var guard := 0
		while not bool(a["over"]) and guard < 500:
			guard += 1
			var pid: String = str(a["current"])
			var act := Ai.next_action(a, pid)
			_apply(a, pid, act)
			trace.append(_wire(act))
			pids.append(pid)
			if trace.size() % 20 == 0:
				snaps[trace.size()] = RulesEngine.fingerprint(a)
		ok(bool(a["over"]), "seed %d 录制完成（%d 步）" % [seed_v, trace.size()])
		var winner := str(a["winner"])

		RulesEngine.rng = Rng.new(seed_v)
		var b := _fresh_game()
		var bad := ""
		for i in trace.size():
			_apply_wire(b, str(pids[i]), trace[i])
			if snaps.has(i + 1) and bad == "" \
					and RulesEngine.fingerprint(b) != str(snaps[i + 1]):
				bad = "第 %d 步" % (i + 1)
		ok(bad == "", "seed %d 重放指纹逐帧一致" % seed_v, bad)
		ok(bool(b["over"]) and str(b["winner"]) == winner,
			"seed %d 终局与胜者一致" % seed_v, str(b["winner"]) + " vs " + winner)

func _fresh_game() -> Dictionary:
	var s := RulesEngine.new_game("liubang", "xiangyu", "p1", "", {}, {})
	RulesEngine.do_mulligan(s, "p1", [])
	RulesEngine.do_mulligan(s, "p2", [])
	RulesEngine.begin_game(s)
	return s

func _apply(s: Dictionary, pid: String, act: Dictionary) -> void:
	match str(act["type"]):
		"play":
			RulesEngine.play_card(s, pid, int(act["uid"]))
		"skill":
			RulesEngine.use_skill(s, pid)
		"attack":
			RulesEngine.attack(s, pid, int(act["attacker"]), act["target"])
		"end":
			RulesEngine.end_turn(s)

## AI 动作 → 线上协议格式（与 battle/pvp_client 的映射一致）
func _wire(act: Dictionary) -> Dictionary:
	match str(act["type"]):
		"play":
			return {"a": "play", "uid": int(act["uid"])}
		"skill":
			return {"a": "skill"}
		"attack":
			return {"a": "attack", "uid": int(act["attacker"]),
				"kind": str(act["target"].get("kind", "unit")),
				"tid": int(act["target"].get("uid", -1))}
		_:
			return {"a": "end"}

## 线上格式 → 引擎操作（与 battle._apply_remote 完全同款）
func _apply_wire(s: Dictionary, pid: String, a: Dictionary) -> void:
	match str(a.get("a", "")):
		"play":
			RulesEngine.play_card(s, pid, int(a.get("uid", -1)))
		"skill":
			RulesEngine.use_skill(s, pid)
		"attack":
			var target := {"kind": str(a.get("kind", "unit")), "uid": int(a.get("tid", -1))}
			RulesEngine.attack(s, pid, int(a.get("uid", -1)), target)
		"end":
			RulesEngine.end_turn(s)

# ---------------- ② 视角翻转 ----------------

## 选楚的玩家：本地是引擎 p2，但 UI 上自己的军阵在下、手牌是自己的
func _test_view_flip() -> void:
	var app = root.get_node("App")
	var keep: Dictionary = app.battle_config
	app.battle_config = {"mode": "pvp", "mySide": "chu", "seed": 7, "stageName": "联机对战"}
	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	ok(scene.pvp and scene.my_pid == "p2" and scene.foe_id == "p1", "选楚 → 本地视角为 p2",
		scene.my_pid)
	# 主将卡：我方（p2）在左下角，敌方（p1）在左上角。
	# 断言用「上/下半屏」而不是具体像素，布局调整（栅格重排）时不会误报
	ok((scene.hero_bars["p2"]["holder"] as Control).position.y > 450.0, "我方主将卡在下半屏")
	ok((scene.hero_bars["p1"]["holder"] as Control).position.y < 450.0, "敌方主将卡在上半屏")
	# 军阵：我方单位落在下排 y
	var my_row: Array = scene.state["players"]["p2"]["board"]["front"]
	if my_row.is_empty():
		ok(true, "（开局前锋为空，跳过军阵位置断言）")
	else:
		var v = scene.unit_views.get(int(my_row[0]["uid"]), null)
		ok(v != null and v.position.y == scene.PLAYER_Y, "我方单位画在下排")
	# 手牌来自引擎 p2
	var hand_uids := {}
	for c in scene.state["players"]["p2"]["hand"]:
		hand_uids[int(c["uid"])] = true
	var shown := 0
	for uid in scene.card_views:
		if hand_uids.has(int(uid)):
			shown += 1
	ok(shown == scene.card_views.size() and shown > 0, "手牌区显示的是自己的牌",
		str(shown) + "/" + str(scene.card_views.size()))
	# 远端结束回合 → 轮到我
	scene._on_pvp_action({"a": "end"})
	await process_frame
	ok(str(scene.state["current"]) == "p2", "对方结束回合后轮到我方")
	ok(scene.turn_label.text.contains("我方"), "回合指示为「我方行动」", scene.turn_label.text)
	# 我方结束回合 → 状态交还对方（本地动作出口广播给 Pvp，未连接时静默）
	scene._on_end_turn()
	await process_frame
	ok(str(scene.state["current"]) == "p1", "我方结束回合后交还行动权")

	# 认输：假装在房间里（真实流程由 Pvp 状态机保证），状态置负、结算面板出现
	root.get_node("Pvp").status = root.get_node("Pvp").IN_ROOM
	scene._abandon_battle()
	await process_frame
	ok(bool(scene.state["over"]) and str(scene.state["winner"]) == "p1", "认输 → 对方胜")
	ok(scene._result_layer != null and is_instance_valid(scene._result_layer), "结算面板已弹出")

	scene.queue_free()
	root.get_node("Pvp").leave()
	app.battle_config = keep
	await process_frame

# ---------------- ③ 中继全链路 E2E ----------------

func _test_relay_e2e() -> void:
	var port := "27911"
	var host_out := ProjectSettings.globalize_path("res://tests/_pvp_host.txt")
	var guest_out := ProjectSettings.globalize_path("res://tests/_pvp_guest.txt")
	for p in [host_out, guest_out]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

	# 起中继
	var relay_pid := OS.create_process("node", [ProjectSettings.globalize_path("res://../tools/relay.js"), port])
	if relay_pid == -1:
		ok(false, "无法启动中继进程（需要 node 在 PATH）")
		return
	await create_timer(0.8).timeout

	var exe := OS.get_executable_path()
	var base := ProjectSettings.globalize_path("res://")
	# 工程目录是 <project>/godot，tools 在上一层
	var args_host: PackedStringArray = [exe, "--headless", "--path", base,
		"--script", "res://tests/pvp_client.gd", "--", "--role", "host", "--seed", "42", "--port", port]
	var host_pid := OS.create_process(exe, _trim_exe(args_host))
	ok(host_pid != -1, "房主客户端已启动")

	# 等房主写出房间码
	var code := ""
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and code == "":
		await create_timer(0.4).timeout
		code = _read_key(host_out, "CODE")
	ok(code != "", "拿到房间码", code)

	var args_guest: PackedStringArray = [exe, "--headless", "--path", base,
		"--script", "res://tests/pvp_client.gd", "--", "--role", "guest", "--seed", "42",
		"--port", port, "--code", code]
	var guest_pid := OS.create_process(exe, _trim_exe(args_guest))
	ok(guest_pid != -1, "加入方客户端已启动")

	# 等两端打完（最长 150 秒）
	deadline = Time.get_ticks_msec() + 150000
	while Time.get_ticks_msec() < deadline:
		await create_timer(1.0).timeout
		if FileAccess.file_exists(host_out) and FileAccess.file_exists(guest_out) \
				and _read_key(host_out, "FP") != "" and _read_key(guest_out, "FP") != "":
			break

	var fp_a := _read_key(host_out, "FP")
	var fp_b := _read_key(guest_out, "FP")
	var win_a := _read_key(host_out, "WIN")
	var win_b := _read_key(guest_out, "WIN")
	var err_a := _read_key(host_out, "ERR")
	var err_b := _read_key(guest_out, "ERR")
	ok(fp_a != "" and fp_b != "", "两端都打完了",
		"host_err=" + err_a + " guest_err=" + err_b)
	if fp_a != "" and fp_b != "":
		ok(fp_a == fp_b, "整局锁步指纹一致")
		ok(win_a == win_b and win_a != "", "两端胜者一致", win_a + " vs " + win_b)

	if relay_pid != -1:
		OS.kill(relay_pid)

func _trim_exe(args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for i in args.size():
		if i == 0:
			continue
		out.append(args[i])
	return out

func _read_key(path: String, key: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var txt := FileAccess.get_file_as_string(path)
	for line in txt.split("\n"):
		if line.begins_with(key + "="):
			return line.substr(key.length() + 1).strip_edges()
	return ""
