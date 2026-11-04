extends SceneTree
## PvP E2E 客户端（配 pvp_test.gd 用，不进常规测试集）
##
## 与中继握手后，用 AI 策略打完整局锁步对局：本方动作本地执行 + 发送，
## 对方动作收到后在本地引擎重放。结束把最终指纹写到 tests/_pvp_<role>.txt，
## 由主测试比对两端是否一致。
##
## 用法：godot --headless --path godot --script res://tests/pvp_client.gd -- \
##   --role host --seed 42 --port 27901 [--code ABCDEF]

const OUT_HOST := "res://tests/_pvp_host.txt"
const OUT_GUEST := "res://tests/_pvp_guest.txt"

var state: Dictionary = {}
var my_pid := "p1"
var foe_id := "p2"
var applied := 0
var _pvp: Node
var _out_path := ""
var _inbox: Array = []
var _err := ""

func _initialize() -> void:
	_run.call_deferred()

func _fail(msg: String) -> void:
	_err = msg
	_write_out("", "", msg)
	print("PVP-CLIENT-FAIL: " + msg)
	quit(1)

func _write_out(fp: String, winner: String, err: String = "") -> void:
	var f := FileAccess.open(_out_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("FP=%s\nWIN=%s\nACTIONS=%d\nERR=%s\n" % [fp, winner, applied, err])
	f.close()

func _run() -> void:
	var role := "host"
	var seed_v := 42
	var port := "27901"
	var code := ""
	var cargs := OS.get_cmdline_user_args()
	var i := 0
	while i < cargs.size():
		match str(cargs[i]):
			"--role": role = str(cargs[i + 1])
			"--seed": seed_v = int(cargs[i + 1])
			"--port": port = str(cargs[i + 1])
			"--code": code = str(cargs[i + 1])
		i += 1
	_out_path = OUT_HOST if role == "host" else OUT_GUEST

	Settings.pvp_relay = "ws://127.0.0.1:" + port
	_pvp = root.get_node("Pvp")
	_pvp.relay_url = "ws://127.0.0.1:" + port
	_pvp.action_in.connect(func (a: Dictionary):
		print("[dbg] RECV log=%d %s" % [_pvp.action_log.size(), str(a)])
		_inbox.append(a))
	_pvp.net_error.connect(func (msg: String): _err = msg)

	# 握手
	if role == "host":
		_pvp.host_create({"side": "han", "seed": seed_v})
		var deadline := Time.get_ticks_msec() + 15000
		while _pvp.code == "" and Time.get_ticks_msec() < deadline and _err == "":
			await process_frame
		if _pvp.code == "":
			return _fail("建房超时: " + _err)
		# 把房间码写给父进程（转给加入方）
		var f := FileAccess.open(_out_path, FileAccess.WRITE)
		f.store_string("CODE=" + str(_pvp.code) + "\n")
		f.close()
		deadline = Time.get_ticks_msec() + 30000
		while _pvp.status != _pvp.IN_ROOM and Time.get_ticks_msec() < deadline and _err == "":
			await process_frame
	else:
		var deadline := Time.get_ticks_msec() + 20000
		_pvp.guest_join(code)
		while _pvp.status != _pvp.IN_ROOM and Time.get_ticks_msec() < deadline and _err == "":
			await process_frame
	if _err != "":
		return _fail(_err)
	if _pvp.status != _pvp.IN_ROOM:
		return _fail("未能进入房间")

	# 建局：两端完全相同的引擎参数（p1 恒为刘邦侧）；settings.side 是房主的选边
	var host_side := str(_pvp.settings.get("side", "han"))
	if role == "host":
		my_pid = "p1" if host_side == "han" else "p2"
	else:
		my_pid = "p2" if host_side == "han" else "p1"
	foe_id = RulesEngine.other(my_pid)
	RulesEngine.rng = Rng.new(seed_v)
	state = RulesEngine.new_game("liubang", "xiangyu", "p1", "", {}, {})
	RulesEngine.do_mulligan(state, "p1", [])
	RulesEngine.do_mulligan(state, "p2", [])
	RulesEngine.begin_game(state)

	# 主循环
	var turns := 0
	while not bool(state["over"]) and turns < 400:
		turns += 1
		if _err != "":
			return _fail(_err)
		if str(state["current"]) == my_pid:
			var act := Ai.next_action(state, my_pid)
			var ok := _apply_own(act)
			if not bool(ok.get("ok", false)) and str(act["type"]) != "end":
				return _fail("本方动作被拒: " + str(act) + " " + str(ok))
			print("[dbg] SEND log=%d %s" % [_pvp.action_log.size(), str(_wire(act))])
			_pvp.send_action(_wire(act))
			applied += 1
			await process_frame
			await create_timer(0.02).timeout
		else:
			# 等对方动作（20 秒超时保护）
			var wait_frames := 0
			while _inbox.is_empty() and wait_frames < 1200 and _err == "":
				wait_frames += 1
				await process_frame
			if _err != "":
				return _fail(_err)
			if _inbox.is_empty():
				return _fail("等待对方动作超时")
			var a: Dictionary = _inbox.pop_front()
			_apply_remote(a)
			applied += 1
			await process_frame

	if _err != "":
		return _fail(_err)
	_write_out(RulesEngine.fingerprint(state), str(state["winner"]))
	print("PVP-CLIENT-DONE winner=%s fp_ok" % str(state["winner"]))
	quit(0)

## 本方动作：走与远端重放相同的引擎入口，保证两端操作序列一致
func _apply_own(act: Dictionary) -> Dictionary:
	match str(act["type"]):
		"play":
			return RulesEngine.play_card(state, my_pid, int(act["uid"]))
		"skill":
			return RulesEngine.use_skill(state, my_pid)
		"attack":
			return RulesEngine.attack(state, my_pid, int(act["attacker"]), act["target"])
		"end":
			RulesEngine.end_turn(state)
			return {"ok": true}
	return {"ok": false}

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

## 远端动作重放（与 battle._apply_remote 同一套映射）
func _apply_remote(a: Dictionary) -> void:
	match str(a.get("a", "")):
		"play":
			RulesEngine.play_card(state, foe_id, int(a.get("uid", -1)))
		"skill":
			RulesEngine.use_skill(state, foe_id)
		"attack":
			var target := {"kind": str(a.get("kind", "unit")), "uid": int(a.get("tid", -1))}
			RulesEngine.attack(state, foe_id, int(a.get("uid", -1)), target)
		"end":
			RulesEngine.end_turn(state)
		_:
			pass
