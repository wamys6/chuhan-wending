extends SceneTree
## 跨语言等价性测试：重放 JS 版录制的动作表，逐回合比对状态指纹与战报
##
## 运行：godot --headless --path godot --script res://tests/replay.gd
## 数据：tests/fixtures/trace.json（由 node tools/trace.js 生成）

var checks := 0
var failures := 0
var failed_lines: Array = []

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	var line := "  ✗ " + label + ("" if detail == "" else "  ← " + detail)
	failed_lines.append(line)
	print(line)

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	print("== 等价性测试（GDScript 重放 JS 动作表） ==")
	var path := "res://tests/fixtures/trace.json"
	if not FileAccess.file_exists(path):
		print("缺少 %s，请先运行 node tools/trace.js" % path)
		quit(1)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		print("trace.json 解析失败")
		quit(1)
		return

	var total_marks := 0
	var total_logs := 0
	for sc in parsed["scenarios"]:
		var r := replay(sc)
		total_marks += int(r["marks"])
		total_logs += int(r["logs"])

	print("已校验 %d 项检查（%d 个场景 / %d 个回合指纹 / %d 条战报），用时 %d ms" % [
		checks, (parsed["scenarios"] as Array).size(), total_marks, total_logs,
		Time.get_ticks_msec() - t0])
	if failures == 0:
		print("通过 %d 项，失败 0 项" % checks)
		quit(0)
	else:
		print("通过 %d 项，失败 %d 项" % [checks - failures, failures])
		quit(1)

func replay(sc: Dictionary) -> Dictionary:
	var name := str(sc["name"])
	RulesEngine.rng = Rng.new(int(sc["seed"]))

	var o: Dictionary = sc.get("opts", {})
	var opts := {}
	if o.has("rules"):
		opts["rules"] = o["rules"]
	if o.has("p1Meta"):
		opts["p1Meta"] = o["p1Meta"]
	if o.has("p2Meta"):
		opts["p2Meta"] = o["p2Meta"]

	# 场景可以自带牌组（扩容卡的亡语/战吼分支要靠专门牌组才走得到）
	var decks := {}
	var sd: Dictionary = sc.get("decks", {})
	for k in sd.keys():
		var arr: Array = []
		for cid in sd[k]:
			arr.append(str(cid))
		decks[str(k)] = arr

	var state := RulesEngine.new_game(str(sc["hero"]), str(sc["foe"]), str(sc["first"]),
		"bijiang", decks, opts)

	var marks: Array = sc["marks"]
	var mi := 0
	var action_err := 0

	for act in sc["trace"]:
		var a := str(act["a"])
		var pid := str(state["current"])
		match a:
			"mull":
				RulesEngine.do_mulligan(state, "p1", [])
				RulesEngine.do_mulligan(state, "p2", [])
				RulesEngine.begin_game(state)
			"play":
				var rp := RulesEngine.play_card(state, pid, int(act["uid"]))
				if not bool(rp.get("ok", false)) and action_err < 3:
					action_err += 1
					ok(false, "[%s] 出牌被拒 uid=%d" % [name, int(act["uid"])], str(rp.get("reason", "")))
			"adv":
				var rad := RulesEngine.use_advisor_active(state, pid)
				if not bool(rad.get("ok", false)) and action_err < 3:
					action_err += 1
					ok(false, "[%s] 军师主动技被拒" % name, str(rad.get("reason", "")))
			"skill":
				var rs := RulesEngine.use_skill(state, pid)
				if not bool(rs.get("ok", false)) and action_err < 3:
					action_err += 1
					ok(false, "[%s] 技能被拒" % name, str(rs.get("reason", "")))
			"attack":
				var tgt: Dictionary = act["target"]
				var t := {"kind": str(tgt["kind"])}
				if tgt.has("uid"):
					t["uid"] = int(tgt["uid"])
				var ra := RulesEngine.attack(state, pid, int(act["uid"]), t)
				if not bool(ra.get("ok", false)) and action_err < 3:
					action_err += 1
					ok(false, "[%s] 攻击被拒 uid=%d" % [name, int(act["uid"])], str(ra.get("reason", "")))
			"end":
				RulesEngine.end_turn(state)
				if mi < marks.size():
					var got := RulesEngine.fingerprint(state)
					if got != str(marks[mi]):
						ok(false, "[%s] 第 %d 回合状态不一致" % [name, mi + 1],
							"\n      JS: " + str(marks[mi]) + "\n      GD: " + got)
					else:
						ok(true, "[%s] 第 %d 回合" % [name, mi + 1])
					mi += 1

	var final_ok := RulesEngine.fingerprint(state) == str(sc["final"])
	ok(final_ok, "[%s] 终局状态" % name,
		"\n      JS: " + str(sc["final"]) + "\n      GD: " + RulesEngine.fingerprint(state))
	ok(mi == marks.size(), "[%s] 回合数一致" % name, "GD %d / JS %d" % [mi, marks.size()])

	# 战报：累计条数必须一致；两边都是「最近 60 条」的滚动窗口，逐条比对
	var js_log: Array = sc["log"]
	var my_log: Array = state["log"]
	ok(int(state["logTotal"]) == int(sc["logTotal"]), "[%s] 战报累计条数一致" % name,
		"GD %d / JS %d" % [int(state["logTotal"]), int(sc["logTotal"])])
	var log_checked := 0
	if my_log.size() == js_log.size():
		for i in my_log.size():
			var mine := LogText.render(my_log[i])
			if mine != str(js_log[i]):
				ok(false, "[%s] 战报第 %d 条不一致" % [name, i + 1],
					"\n      JS: " + str(js_log[i]) + "\n      GD: " + mine)
				break
			log_checked += 1
	else:
		ok(false, "[%s] 战报窗口长度一致" % name, "GD %d / JS %d" % [my_log.size(), js_log.size()])
	ok(log_checked == js_log.size(), "[%s] 战报逐条一致" % name,
		"%d/%d" % [log_checked, js_log.size()])
	print("  · %-20s 回合 %d  战报 %d  终局 %s" % [name, mi, log_checked,
		RulesEngine.fingerprint(state).substr(0, 24)])
	return {"marks": mi, "logs": log_checked}
