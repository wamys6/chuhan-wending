extends SceneTree
## 事件选牌层测试（2026-11-03）
##
## 运行：godot --headless --path godot --script res://tests/event_pick_test.gd
##
## 为什么单独一个脚本：事件「得牌 / 删牌」在 Godot 迁移时被简化成
## 「一律发一张随机兵种牌、remove 完全不处理」，于是「三选一计谋牌」
## 「从牌组移除一张」这几条文案与实际行为不符——而既有测试只断言
## 「事件结算成功」，文案骗人不会让任何测试变红。
##
## 这一层只盯一件事：**选了之后牌组到底变没变、变的是不是那一张。**

var checks := 0
var failures := 0
var app: Node

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("  ✗ " + label + ("" if detail == "" else "  ← " + detail))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("== 事件选牌层测试 ==")
	GameData.ensure_loaded()
	app = root.get_node("App")
	Campaign.use_slot(0)
	Campaign._wipe_all()

	await _test_picker_basic()
	await _test_event_add()
	await _test_event_remove()
	await _test_remove_two()
	await _test_remove_floor()

	print("通过 %d 项，失败 %d 项" % [checks, failures])
	Campaign._wipe_all()
	quit(1 if failures > 0 else 0)

func _fresh_run() -> void:
	app.progress = Campaign.start_run("liubang",
		(GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	app.stage = Campaign.stage_by_id("peixian")

func _last_picker(node: Node) -> CardPicker:
	var out: CardPicker = null
	for c in node.get_children():
		if c is CardPicker:
			out = c as CardPicker
	return out

# ---------------- 选牌层本身 ----------------

func _test_picker_basic() -> void:
	print("· 选牌层")
	var host := Control.new()
	host.theme = UiTheme.build()
	host.size = Vector2(1440, 900)
	root.add_child(host)
	await process_frame

	var got: Array = []
	var canceled := 0
	var picker := CardPicker.open(host, {
		"title": "收 入 牌 组",
		"hint": "点选要收的牌",
		"cards": ["n_bing1", "n_bing2", "n_bing3"],
		"mode": "add",
		"count": 2,
		"confirm": "收 下",
		"on_done": func (picked: Array): got.append_array(picked),
		"on_cancel": func (): canceled += 1,
	})
	await process_frame
	ok(picker.get_child_count() > 0, "选牌层已建出")
	ok(picker._views.size() == 3, "三张候选都在", str(picker._views.size()))
	ok(picker._confirm.disabled, "未选满时确认不可用")
	# 缩放随张数自适应：3 张候选不该缩成一小撮（第一版写死 0.62，只有 460px 宽）
	ok(picker._scale_for(3) > 1.0, "3 张候选会放大", str(picker._scale_for(3)))
	ok(picker._scale_for(10) < 1.0, "10 张候选会压缩", str(picker._scale_for(10)))
	ok(picker._scale_for(28) >= CardPicker.MIN_SCALE, "28 张仍在可读下限之上",
		str(picker._scale_for(28)))
	# 网格不能超出面板右缘（面板 100..1340，留 100 内边距 → 1240）
	var last_card := picker._views[picker._views.size() - 1] as CardView
	var right_edge := last_card.position.x + CardView.SIZE.x * last_card.scale.x
	ok(right_edge <= 1240.0, "最右一张不越出面板", "%.1f" % right_edge)

	(picker._views[0] as CardView).clicked.emit(0)
	ok(picker._confirm.disabled, "只选一张（需两张）仍不可用")
	(picker._views[2] as CardView).clicked.emit(0)
	ok(not picker._confirm.disabled, "选满两张后确认可用")

	# 选满之后再点第三张：换掉最早选的那张，而不是拒绝点击（点不动像卡死）
	(picker._views[1] as CardView).clicked.emit(0)
	ok(picker._picked.size() == 2, "选满后仍是两张", str(picker._picked.size()))
	picker._confirm.pressed.emit()
	await process_frame
	ok(got.size() == 2, "确认后回调收到两张", str(got))
	ok(str(got[0]) == "n_bing3" and str(got[1]) == "n_bing2",
		"回调是最后选中的那两张（先选的第一张被替换）", str(got))
	ok(canceled == 0, "确认路径不触发取消")

	# 点已选中的牌 = 取消选中
	var p2 := CardPicker.open(host, {
		"title": "收 入 牌 组", "hint": "点选要收的牌",
		"cards": ["n_bing1", "n_bing2"], "mode": "add", "count": 1,
		"on_done": func (_p: Array): pass,
	})
	await process_frame
	(p2._views[0] as CardView).clicked.emit(0)
	ok(not p2._confirm.disabled, "选一张后确认可用（需一张）")
	(p2._views[0] as CardView).clicked.emit(0)
	ok(p2._picked.is_empty() and p2._confirm.disabled, "再点一次取消选中")
	p2._close_cancel()

	# 没有 on_cancel：不生成取消按钮（事件结算不可撤销）
	var p3 := CardPicker.open(host, {
		"cards": ["n_bing1"], "mode": "add", "count": 1,
		"on_done": func (_p: Array): pass,
	})
	await process_frame
	var btns := 0
	for c in p3.get_children():
		if c is Button:
			btns += 1
	ok(btns == 1, "没有取消回调时只留确认按钮", str(btns))
	ok(p3._confirm.position.x + p3._confirm.size.x * 0.5 == 720.0,
		"没有取消按钮时确认按钮居中", str(p3._confirm.position.x))
	p3._close_cancel()

	host.queue_free()
	await process_frame

# ---------------- 事件结算：得牌 ----------------

func _test_event_add() -> void:
	print("· 事件得牌")
	_fresh_run()
	app.pending_event = Campaign.event_by_id("qishu")
	var scene: Node = load("res://scenes/event.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene._choose(0)          # 展卷夜读：三选一计谋牌
	await process_frame
	var picker := _last_picker(scene)
	ok(picker != null, "得牌层已打开")
	if picker == null:
		scene.queue_free()
		await process_frame
		return

	ok(picker._views.size() == 3, "候选三张", str(picker._views.size()))
	var all_spell := true
	for id in picker._ids:
		if str((GameData.card(str(id)) as Dictionary)["type"]) != "spell":
			all_spell = false
	ok(all_spell, "候选全是计谋牌（迁移期这里会塞兵种牌）", str(picker._ids))
	ok(picker._need == 1, "三选一只收一张", str(picker._need))

	var before := (app.progress["deck"] as Array).size()
	var chosen := str(picker._ids[1])
	(picker._views[1] as CardView).clicked.emit(0)
	picker._confirm.pressed.emit()
	await process_frame
	var after := (app.progress["deck"] as Array).size()
	ok(after == before + 1, "选中的牌真的进了牌组", "%d → %d" % [before, after])
	ok(str((app.progress["deck"] as Array)[after - 1]) == chosen, "进的是选的那一张", chosen)
	ok(str((GameData.card(chosen) as Dictionary)["type"]) == "spell", "进组的是计谋牌")
	ok(str(app.progress["eventLog"].back()["id"]) == "qishu", "行军记已登记")
	scene.queue_free()
	await process_frame

# ---------------- 事件结算：删牌 ----------------

func _test_event_remove() -> void:
	print("· 事件删牌")
	_fresh_run()
	app.pending_event = Campaign.event_by_id("laozu")
	var scene: Node = load("res://scenes/event.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var deck_before := (app.progress["deck"] as Array).size()
	var deck_before_ids: Array = (app.progress["deck"] as Array).duplicate()
	scene._choose(0)          # 准其归乡：从牌组移除一张
	await process_frame
	var picker := _last_picker(scene)
	ok(picker != null, "删牌层已打开（迁移期这里是空操作）")
	if picker == null:
		scene.queue_free()
		await process_frame
		return
	ok(picker._views.size() == deck_before, "删牌层铺的是整副牌组",
		"%d vs %d" % [picker._views.size(), deck_before])
	ok(picker._need == 1, "准其归乡只删一张", str(picker._need))

	var victim := str(picker._ids[2])
	(picker._views[2] as CardView).clicked.emit(0)
	picker._confirm.pressed.emit()
	await process_frame
	var deck_after: Array = app.progress["deck"]
	ok(deck_after.size() == deck_before - 1, "牌组少一张",
		"%d → %d" % [deck_before, deck_after.size()])
	# 牌组是多重集：同名两张时删哪一份都一样，所以比份数不比「在不在」
	ok(_count_of(deck_after, victim) == _count_of(deck_before_ids, victim) - 1,
		"选中的那张牌名份数减一（同名只删一张）", victim)
	scene.queue_free()
	await process_frame

## 厚赐遣归：一次删两张（remove: 2 是唯一的多张删牌事件）
func _test_remove_two() -> void:
	print("· 一次删两张")
	_fresh_run()
	app.pending_event = Campaign.event_by_id("laozu")
	var scene: Node = load("res://scenes/event.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var before := (app.progress["deck"] as Array).size()
	scene._choose(2)          # 厚赐遣归：生命上限 -1，移除两张
	await process_frame
	var picker := _last_picker(scene)
	ok(picker != null, "两张删牌层已打开")
	if picker == null:
		ok(false, "删牌层缺失，跳过后续断言")
		scene.queue_free()
		await process_frame
		return
	ok(picker._need == 2, "需要选两张", str(picker._need))
	(picker._views[0] as CardView).clicked.emit(0)
	(picker._views[1] as CardView).clicked.emit(0)
	picker._confirm.pressed.emit()
	await process_frame
	ok((app.progress["deck"] as Array).size() == before - 2, "牌组少两张",
		"%d → %d" % [before, (app.progress["deck"] as Array).size()])
	scene.queue_free()
	await process_frame

func _count_of(arr: Array, id: String) -> int:
	var n := 0
	for x in arr:
		if str(x) == id:
			n += 1
	return n

# ---------------- 牌组到下限 ----------------

func _test_remove_floor() -> void:
	print("· 牌组下限")
	_fresh_run()
	while (app.progress["deck"] as Array).size() > Campaign.MIN_DECK:
		(app.progress["deck"] as Array).pop_back()
	ok((app.progress["deck"] as Array).size() == Campaign.MIN_DECK, "已削到下限")

	app.pending_event = Campaign.event_by_id("laozu")
	var scene: Node = load("res://scenes/event.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._choose(0)
	await process_frame
	ok(_last_picker(scene) == null, "牌组到下限时不再开删牌层（避免删空）")
	scene.queue_free()
	await process_frame
