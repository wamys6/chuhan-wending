extends SceneTree
## PvP E2E 客户端（配 pvp_test.gd 用，不进常规测试集）
##
## 与中继握手后，用 AI 策略打完整局锁步对局：本方动作本地执行 + 发送，
## 对方动作收到后在本地引擎重放。结束把最终指纹写到 tests/_pvp_<role>.txt，
## 由主测试比对两端是否一致。
##
## 远端动作**只认动作日志**（Pvp.action_log 是唯一真相，本端 applied 指向
## 「已应用到的下标」），和 battle.gd 的 `_applied` 完全同款——
## 这样中途断线时服务端补发的日志就是天然的补放清单，不需要另开一套缓冲。
##
## 用法：godot --headless --path godot --script res://tests/pvp_client.gd -- \
##   --role host --seed 42 --port 27901 [--code ABCDEF] [--drop-at 6] [--drop-delay 1200]
## `--drop-at N`：轮到对方且已应用 N 个动作时，真实断开 socket，`--drop-delay` 毫秒后 resume。

const OUT_HOST := "res://tests/_pvp_host.txt"
const OUT_GUEST := "res://tests/_pvp_guest.txt"

var state: Dictionary = {}
var my_pid := "p1"
var foe_id := "p2"
var applied := 0          # 已应用到的动作日志下标（含本端）
var _pvp: Node
var _out_path := ""
var _err := ""
var _drop_at := 0
var _drop_delay := 1200
var _dropped := false
var _recon := 0           # 成功重连次数
var _missed := 0          # 断线窗口里错过、靠日志补放的动作数

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
	f.store_string("FP=%s\nWIN=%s\nACTIONS=%d\nRECON=%d\nMISSED=%d\nERR=%s\n"
		% [fp, winner, applied, _recon, _missed, err])
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
			"--drop-at": _drop_at = int(cargs[i + 1])
			"--drop-delay": _drop_delay = int(cargs[i + 1])
		i += 1
	_out_path = OUT_HOST if role == "host" else OUT_GUEST

	Settings.pvp_relay = "ws://127.0.0.1:" + port
	_pvp = root.get_node("Pvp")
	_pvp.relay_url = "ws://127.0.0.1:" + port
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

		# 断线演练：等到「轮到对方」再断——此时不需要发任何东西，
		# 断线窗口里对方照常动作，正好验证「重连后用日志补放」这条路
		if _drop_at > 0 and not _dropped and applied >= _drop_at \
				and str(state["current"]) != my_pid:
			await _drill_reconnect()

		if str(state["current"]) == my_pid:
			if _pvp.status != _pvp.IN_ROOM:
				if not await _wait_room():
					return _fail("等待回到房间超时（本方回合）")
			var act := Ai.next_action(state, my_pid)
			var ok := _apply_own(act)
			if not bool(ok.get("ok", false)) and str(act["type"]) != "end":
				return _fail("本方动作被拒: " + str(act) + " " + str(ok))
			_pvp.send_action(_wire(act))
			applied += 1
			await process_frame
			await create_timer(0.02).timeout
		else:
			# 等对方动作落到日志尾部（20 秒超时保护）
			var wait_frames := 0
			while _pvp.action_log.size() <= applied and wait_frames < 1200 and _err == "":
				wait_frames += 1
				await process_frame
			if _err != "":
				return _fail(_err)
			if _pvp.action_log.size() <= applied:
				return _fail("等待对方动作超时（已应用 %d / 日志 %d）"
					% [applied, _pvp.action_log.size()])
			_apply_remote(_pvp.action_log[applied])
			applied += 1
			await process_frame

	if _err != "":
		return _fail(_err)
	_write_out(RulesEngine.fingerprint(state), str(state["winner"]))
	print("PVP-CLIENT-DONE winner=%s recon=%d" % [str(state["winner"]), _recon])
	quit(0)

## 真实断线 → 等一会 → resume → 用服务端日志补放错过的动作
## （与 battle.gd 的 `_on_self_dropped` / `_on_resumed` 同一套流程）
func _drill_reconnect() -> void:
	_dropped = true
	var code := str(_pvp.code)
	var before: int = _pvp.action_log.size()
	print("[drill] 断开连接（已应用 %d / 日志 %d）" % [applied, before])
	_pvp._close_socket()
	_pvp.status = _pvp.OFF
	await create_timer(float(_drop_delay) / 1000.0).timeout
	if code == "":
		_err = "断线时没有房间码，无法重连"
		return
	_pvp.resume(code)
	var deadline := Time.get_ticks_msec() + 15000
	while _pvp.status != _pvp.IN_ROOM and Time.get_ticks_msec() < deadline and _err == "":
		await process_frame
	if _pvp.status != _pvp.IN_ROOM:
		_err = "重连超时"
		return
	_recon += 1
	# 补放：日志是唯一真相，本端 applied 指向已应用位置，尾部全部按对方动作重放
	var missed := 0
	while applied < _pvp.action_log.size():
		_apply_remote(_pvp.action_log[applied])
		applied += 1
		missed += 1
	_missed = missed
	print("[drill] 重连成功，补放 %d 个动作（日志 %d）" % [missed, _pvp.action_log.size()])

func _wait_room() -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while _pvp.status != _pvp.IN_ROOM and Time.get_ticks_msec() < deadline:
		await process_frame
	return _pvp.status == _pvp.IN_ROOM

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
