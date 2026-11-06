extends SceneTree
## 对战界面交互与布局回归测试
##
## 运行：godot --headless --path godot --script res://tests/battle_ui_test.gd
## 背景：曾经出过三个「界面看着在、其实点不动」的问题，这里是它们的看门狗：
##   ① 卡牌/部队视图没有任何输入接线 → 点牌没反应、点兵没反应（整局打不下去）
##   ② _sync_board 各自维护 alive → 每同步一次就把对面部队的视图当阵亡清掉
##      （表现就是「对面出的兵一上场就没了」）
##   ③ busy 放开后不刷新手牌明暗 → 所有牌一直保持压暗（看起来像不能出牌）

var checks := 0
var failures := 0

var _tut_backup := ""

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("  ✗ " + label + ("" if detail == "" else "  ← " + detail))

func _initialize() -> void:
	_run.call_deferred()

func _count_units(s: Dictionary, pid: String) -> int:
	var n := 0
	for r in RulesEngine.RANKS:
		n += (s["players"][pid]["board"][r] as Array).size()
	return n

func _click(view: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	view._gui_input(ev)

func _run() -> void:
	_tut_backup = _read(Tutorial.PATH)
	Tutorial.mark_done(Tutorial.BATTLE_INTRO)   # 别让引导浮层挡住点击
	# 主脚本编译时单例名还没注册，运行期从 root 取
	var app: Node = root.get_node_or_null("App")
	ok(app != null, "App 单例存在")
	if app != null:
		app.battle_config = {
			"hero": "liubang", "foe": "xiangyu", "foeMeta": {}, "rules": {},
			"deck": [], "enemyDeck": [], "aiLevel": "bijiang",
			"stageName": "布局测试", "goalText": "撑过 5 回合", "mode": "quick",
		}
	var scene: Control = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	ok(not scene.state.is_empty(), "对战场景已开局")
	ok(scene.stage_label.text != "", "顶部显示关卡/目标", scene.stage_label.text)
	await _test_click_play(scene)
	await _test_both_sides_units(scene)
	_test_hand_playable(scene)
	await _test_log_panel(scene)
	await _test_unit_click(scene)
	await _test_layout(scene)
	await _test_threat(scene)
	await _test_deck_label(scene)

	scene.queue_free()
	await process_frame
	_write(Tutorial.PATH, _tut_backup)
	Tutorial._reload()
	if failures > 0:
		print("失败 %d 项 / 共 %d 项" % [failures, checks])
	else:
		print("通过 %d 项，失败 0 项" % checks)
	quit(1 if failures > 0 else 0)

# ---------------- ① 点牌能出 ----------------

func _test_click_play(scene: Control) -> void:
	var me: Dictionary = scene.state["players"]["p1"]
	me["mana"] = 10
	scene.state["current"] = "p1"   # 先机随机，测试里固定成我方回合
	scene.busy = false
	scene._sync_all()
	await process_frame

	var target: CardView = null
	for v in scene.card_views.values():
		if RulesEngine.can_play(scene.state, "p1", v.card):
			target = v
			break
	ok(target != null, "起手至少有一张可出的牌")
	if target == null:
		return
	ok(target.modulate.a > 0.99, "可出的牌是亮的", str(target.modulate.a))
	# 卡面立绘/边框若设成 MOUSE_FILTER_STOP 会吞掉点击（真实点击就点不动了）
	var blockers := 0
	for c in target.get_children():
		if (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			blockers += 1
	ok(blockers == 0, "卡面子节点不吞点击", "%d 个拦截层" % blockers)

	var board_before := _count_units(scene.state, "p1")
	var uid := int(target.card["uid"])
	_click(target)
	# 不能断言「手牌 -1」：抽牌类计谋出牌后会立刻补一张，数量不变。
	# 本质是「这张牌从手里离开了」。
	var still_in_hand := false
	for c in me["hand"]:
		if int(c["uid"]) == uid:
			still_in_hand = true
	ok(not still_in_hand, "点牌即出牌：这张牌已离开手牌")
	ok(_count_units(scene.state, "p1") >= board_before, "点牌后场上部队数不减")
	ok(scene.busy, "出牌动画期间 busy=true（防连点）")

	await create_timer(0.5).timeout
	ok(not scene.busy, "动画结束 busy 复位")
	ok(scene.card_views.has(uid) == false, "出掉的牌不再留在手里")
	var views := 0
	for v in scene.card_views.values():
		if (v as CardView).card.get("uid", -1) == uid:
			views += 1
	ok(views == 0, "出掉的牌视图已销毁")

# ---------------- ② 双方部队同时可见 ----------------

func _test_both_sides_units(scene: Control) -> void:
	var p2: Dictionary = scene.state["players"]["p2"]
	p2["mana"] = 10
	var prev_current := str(scene.state["current"])
	scene.state["current"] = "p2"
	var uid := -1
	for c in p2["hand"]:
		if str(c["type"]) == "piece" and RulesEngine.can_play(scene.state, "p2", c):
			uid = int(c["uid"])
			break
	ok(uid >= 0, "敌方手里有可出的部队牌")
	if uid < 0:
		scene.state["current"] = prev_current
		return
	RulesEngine.play_card(scene.state, "p2", uid)
	scene.state["current"] = prev_current
	scene._sync_all()
	await process_frame

	var total := _count_units(scene.state, "p1") + _count_units(scene.state, "p2")
	ok(_count_units(scene.state, "p2") >= 1, "敌方部队已在引擎棋盘上")
	ok(scene.unit_views.size() == total,
		"双方部队都有视图（不再互相清除）", "%d 视图 / %d 部队" % [scene.unit_views.size(), total])

	# 再来一次：AI 每动一步都会同步，重复同步不能把对面清掉
	scene._sync_all()
	scene._sync_all()
	await process_frame
	ok(scene.unit_views.size() == total,
		"重复同步不会误删任何一方", "%d 视图 / %d 部队" % [scene.unit_views.size(), total])

# ---------------- ③ 手牌明暗跟着回合走 ----------------

func _test_hand_playable(scene: Control) -> void:
	scene.busy = true
	scene._sync_all()
	await process_frame
	var dimmed := 0
	for v in scene.card_views.values():
		if (v as CardView).modulate.a < 0.9:
			dimmed += 1
	ok(dimmed == scene.card_views.size(), "动画中手牌整体压暗")

	scene.busy = false
	scene._refresh_hand_playable()
	await process_frame
	var wrong := 0
	for v in scene.card_views.values():
		var want: bool = scene._can_play_ui((v as CardView).card)
		var lit: bool = (v as CardView).modulate.a > 0.99
		if want != lit:
			wrong += 1
	ok(wrong == 0, "busy 放开后手牌明暗立刻恢复正确", "%d 张不一致" % wrong)

# ---------------- ④ 战报不溢出 ----------------

func _test_log_panel(scene: Control) -> void:
	var clip: Control = scene.log_clip
	ok(clip is Control and (clip as Control).clip_contents, "战报有一层硬裁剪容器")
	# 面板高度随条目自适应：开局两三条就矮，打久了长满到 LOG_MAX_H
	var panel_h0: float = scene.log_panel.size.y
	ok(panel_h0 >= scene.LOG_MIN_H - 0.5 and panel_h0 <= scene.LOG_MAX_H + 0.5,
		"战报面板高度在 [LOG_MIN_H, LOG_MAX_H] 内", str(panel_h0))

	# 塞满战报（真实对局后期就是这个量级）
	var src: Array = scene.state["log"]
	if src.size() > 0:
		var seed_size := src.size()
		for i in 40:
			src.append(src[i % maxi(1, mini(seed_size, 6))].duplicate(true))
	scene._sync_log()
	await process_frame
	await process_frame

	ok(scene.log_panel.size.y <= scene.LOG_MAX_H + 0.5,
		"塞满后战报面板不超过上限", str(scene.log_panel.size.y))
	ok(clip.size.y >= scene.log_box.get_combined_minimum_size().y - 0.5,
		"战报内容不超出可视区高度",
		"%.0f > %.0f" % [scene.log_box.get_combined_minimum_size().y, clip.size.y])
	ok(scene.log_box.get_child_count() <= scene.LOG_LIMIT,
		"战报条数不超过上限", "%d 条 > %d" % [scene.log_box.get_child_count(), scene.LOG_LIMIT])

	var max_right := 0.0
	for c in scene.log_box.get_children():
		max_right = maxf(max_right, (c as Control).position.x + (c as Control).size.x)
	ok(max_right <= scene.LOG_BOX_W + 1.0, "战报内容不超出可视区宽度", "%.0f" % max_right)

	# 最新一条必须在最上面：以前旧的在上、新的在下，一溢出就被裁掉最新的那条
	var newest := "· " + LogText.render((scene.state["log"] as Array).back())
	var first_line := (scene.log_box.get_child(0) as Label).text
	ok(first_line == newest, "最新一条战报排在最上面",
		first_line.substr(0, 14) + " ≠ " + newest.substr(0, 14))

	# 有字不等于看得见：容器宽度为 0 时标签会被折成竖条，这里盯住实际占位
	var visible_lines := 0
	for c in scene.log_box.get_children():
		var l := c as Label
		if l.size.x > 80.0 and l.size.y > 10.0 and l.text != "":
			visible_lines += 1
	ok(visible_lines >= 3, "战报条目真的有可见尺寸", "%d 条可见" % visible_lines)

# ---------------- ⑤ 关键 UI 不互相压 ----------------

func _test_layout(scene: Control) -> void:
	var stage_rect: Rect2 = scene.stage_label.get_global_rect()
	var foe_bar: Rect2 = (scene.hero_bars["p2"]["holder"] as Control).get_global_rect()
	var my_bar: Rect2 = (scene.hero_bars["p1"]["holder"] as Control).get_global_rect()
	var pause_rect: Rect2 = scene.pause_btn.get_global_rect()
	ok(not stage_rect.intersects(foe_bar), "关卡目标条不压敌将卡")
	ok(not stage_rect.intersects(pause_rect), "关卡目标条不压暂停按钮")
	ok(not scene.toast_label.get_global_rect().intersects(my_bar), "提示条不压我方主将卡")
	ok(not scene.toast_label.get_global_rect().intersects(scene.skill_btn.get_global_rect()),
		"提示条不压技能按钮")

	# 主将卡内部：名字 / 血量 / 军粮圆点三块不许互压
	for pid in ["p1", "p2"]:
		var bar: Dictionary = scene.hero_bars[pid]
		var name_rect: Rect2 = (bar["name"] as Control).get_global_rect()
		var pip_rect: Rect2 = (bar["pips"][0] as Control).get_global_rect()
		var hp_rect: Rect2 = (bar["hp"] as Control).get_global_rect()
		ok(not name_rect.intersects(pip_rect), "%s 名字不压军粮圆点" % pid)
		ok(not hp_rect.intersects(pip_rect), "%s 血量不压军粮圆点" % pid)

	# 战报面板不压军阵格位
	var log_rect: Rect2 = scene.log_panel.get_global_rect()
	var hit := 0
	for key in scene.col_frames:
		if log_rect.intersects((scene.col_frames[key] as Control).get_global_rect()):
			hit += 1
	ok(hit == 0, "战报面板不压军阵格位", "%d 个格位被压" % hit)

	# 栅格：左右边距都是 24（原来左 20 / 右 44）
	ok(is_equal_approx(log_rect.position.x, 24.0), "左栏左对齐 24", str(log_rect.position.x))
	ok(is_equal_approx(scene.end_btn.get_global_rect().end.x, 1416.0),
		"操作栏右对齐 1416（右边距 24）", str(scene.end_btn.get_global_rect().end.x))
	ok(is_equal_approx(my_bar.end.y, 880.0), "主将面板底对齐 880（下边距 20）", str(my_bar.end.y))

	# 列名带：六列各有一条列名，且任何部队都不许压上去
	var labels: Array = []
	for key in scene.col_frames:
		for c in (scene.col_frames[key] as Control).get_children():
			if c is Label:
				labels.append(c)
	ok(labels.size() == 6, "六列各有列名", "%d 个" % labels.size())
	# 用 position + 尺寸算矩形，不用 get_global_rect：pop_in 动画期间 scale<1，
	# 全局矩形会偏小，反而看不出「排版上压没压」
	var covered := 0
	for v in scene.unit_views.values():
		var r := Rect2((v as Control).position, UnitView.SIZE)
		for lb in labels:
			if r.intersects((lb as Control).get_global_rect()):
				covered += 1
	ok(covered == 0, "部队不压列名（列框顶留 24px 列名带）", "%d 处重叠" % covered)

	# 部队必须落在列框里，不许越界（满编 3 张 = 3×90 + 2×4 = 278，框宽 296，两边各余 9）
	var outside := 0
	for v in scene.unit_views.values():
		var r := Rect2((v as Control).position, UnitView.SIZE)
		var inside := false
		for key in scene.col_frames:
			if (scene.col_frames[key] as Control).get_global_rect().grow(0.5).encloses(r):
				inside = true
				break
		if not inside:
			outside += 1
	ok(outside == 0, "所有部队都在列框内", "%d 个越界" % outside)

	# 字号阶梯只有五档：抽查主界面各处文字
	var ladder := [12, 14, 16, 20, 26]
	var off := []
	for pair in [[scene.stage_label, "关卡目标"], [scene.turn_label, "回合提示"],
			[scene.pause_btn, "暂停"], [scene.end_btn, "结束回合"]]:
		var fs := (pair[0] as Control).get_theme_font_size("font_size")
		if not ladder.has(fs):
			off.append("%s=%d" % [pair[1], fs])
	for pid in ["p1", "p2"]:
		var nm := (scene.hero_bars[pid]["name"] as Control).get_theme_font_size("font_size")
		if not ladder.has(nm):
			off.append("%s 主将名=%d" % [pid, nm])
	ok(off.is_empty(), "主界面字号都在五档阶梯内", ", ".join(off))

	# 手牌与主将面板靠「垂直分层」错开，不靠横向避让：
	# 主将面板在 y 792~880，手牌底 770，两者不在同一水平带
	var hand_bottom: float = scene.HAND_Y + CardView.SIZE.y + scene.HAND_ARC
	ok(hand_bottom <= my_bar.position.y, "手牌底在主将面板之上（垂直分层）",
		"%.0f > %.0f" % [hand_bottom, my_bar.position.y])
	ok(scene.HAND_X_MIN < my_bar.position.x + 40.0, "手牌区间横跨全宽（牌少时能居中）",
		"%.0f" % scene.HAND_X_MIN)

	# 手牌不与主将卡、按钮重叠。不能用 get_global_rect：它对旋转控件只转位置、不重算尺寸，
	# 扇形里的牌会报出错误的包围盒。改为 position+SIZE 再按两端旋转余量外扩。
	for v in scene.card_views.values():
		var r := Rect2((v as Control).position, CardView.SIZE).grow(scene.HAND_ROT_HALF)
		if r.intersects(my_bar) or r.intersects(scene.end_btn.get_global_rect()) \
				or r.intersects(scene.skill_btn.get_global_rect()):
			ok(false, "手牌不与主将卡/按钮重叠", "%s" % str(r))
			return
	ok(true, "手牌不与主将卡/按钮重叠")

	# 手牌区间两端让出的旋转余量，必须刚好够两端牌转过 8° 后不越界
	# 外伸的是斜对的顶角，不是底角：64·cosθ + 186·sinθ − 64
	var th := deg_to_rad(scene.HAND_MAX_ROT)
	var half_out: float = CardView.SIZE.x * 0.5 * cos(th) + CardView.SIZE.y * sin(th) - CardView.SIZE.x * 0.5
	ok(scene.HAND_ROT_HALF >= half_out, "旋转余量覆盖两端牌的外伸量",
		"%.1f < %.1f" % [scene.HAND_ROT_HALF, half_out])

	# 悬停浮层不能盖住手牌：盖住了就看不清要点哪张（以前浮层底边会压进牌面 20 多像素）
	if scene.card_tip != null and scene.card_views.size() > 0:
		var any_card: CardView = scene.card_views.values()[0]
		scene.card_tip.show_card(any_card.card)
		scene.card_tip.place_near(any_card.get_global_rect(), Rect2(), scene.HAND_Y - 18.0)
		await process_frame
		ok(scene.card_tip.get_global_rect().end.y <= scene.HAND_Y + 0.5,
			"悬停浮层不压手牌",
			"浮层底 %.0f > 手牌顶 %.0f" % [scene.card_tip.get_global_rect().end.y, scene.HAND_Y])
		scene.card_tip.hide_tip()

	# 列满编（3 张）时的横向留白：以前 96×132 满编正好等于框宽 296，
	# 牌边和列框线完全重合，满场看不出列界
	await _test_full_column(scene)
	# 超编兜底：规则层必须拦第 4 张；万一状态里真有 4~6 张，UI 要整列缩小而不是溢出
	await _test_over_capacity(scene)

# ---------------- ⑤b 单列满编 / 超编 ----------------

func _first_piece_id() -> String:
	for key in GameData.cards:
		if str(GameData.cards[key].get("type", "")) == "piece":
			return str(key)
	return ""

## 部队的**可见**矩形：缩放轴在牌中心，所以左上角 = position + SIZE/2·(1−s)
func _visual_rect(v: UnitView) -> Rect2:
	var s: float = v.base_scale
	return Rect2(v.position + UnitView.SIZE * 0.5 * (1.0 - s), UnitView.SIZE * s)

func _test_full_column(scene: Control) -> void:
	var front: Array = scene.state["players"]["p1"]["board"]["front"]
	front.clear()
	var piece_id := _first_piece_id()
	ok(piece_id != "", "卡池里找得到部队牌")
	var uids: Array = []
	# 直接造出「一列满编」：每列上限就是 column_limit()，正常出牌也是这个数
	for i in GameData.column_limit():
		var u: Dictionary = RulesEngine.new_instance(piece_id)
		u["canAttack"] = false
		front.append(u)
		uids.append(int(u["uid"]))
	scene._sync_all()
	await process_frame

	var frame: Rect2 = (scene.col_frames["p1_front"] as Control).get_global_rect()
	var rects: Array = []
	for uid in uids:
		var v: UnitView = scene.unit_views.get(uid, null)
		ok(v != null, "满编的兵都有视图", str(uid))
		if v != null:
			rects.append(_visual_rect(v))
	ok(rects.size() == GameData.column_limit(),
		"前锋列满编 %d 张" % GameData.column_limit(), "%d 张有视图" % rects.size())
	if rects.size() < 2:
		return
	rects.sort_custom(func(a, b): return a.position.x < b.position.x)
	var left_gap: float = rects[0].position.x - frame.position.x
	var right_gap: float = frame.end.x - (rects[-1] as Rect2).end.x
	ok(left_gap >= 6.0, "满编时左侧留白 ≥6px", "%.1f" % left_gap)
	ok(right_gap >= 6.0, "满编时右侧留白 ≥6px", "%.1f" % right_gap)
	for i in range(1, rects.size()):
		var gap: float = rects[i].position.x - (rects[i - 1] as Rect2).end.x
		ok(is_equal_approx(gap, scene.UNIT_GAP), "满编相邻间隔 = %.0f" % scene.UNIT_GAP, "%.1f" % gap)
	for r in rects:
		ok(frame.encloses(r), "满编部队纵向也在框内", str(r))
		ok(r.position.y - frame.position.y >= scene.COL_LABEL_H, "满编部队不压列名带",
			"%.1f" % (r.position.y - frame.position.y))

func _test_over_capacity(scene: Control) -> void:
	var me: Dictionary = scene.state["players"]["p1"]
	var front: Array = me["board"]["front"]
	var piece_id := _first_piece_id()
	var frame: Rect2 = (scene.col_frames["p1_front"] as Control).get_global_rect()

	# ① 规则层：满编之后再出第 4 张必须被拒（这是第一道防线，UI 兜底是第二道）
	var extra: Dictionary = RulesEngine.new_instance(piece_id)
	extra["cost"] = 0
	me["hand"].append(extra)
	me["mana"] = 10
	ok(not RulesEngine.can_play(scene.state, "p1", extra), "满编后 can_play 判第 4 张不可出")
	var res: Dictionary = RulesEngine.play_card(scene.state, "p1", int(extra["uid"]))
	ok(not bool(res.get("ok", true)), "满编后出第 4 张被规则层拒绝", str(res.get("reason", "")))
	ok(str(res.get("reason", "")).find("已满") >= 0, "拒绝原因说明该列已满", str(res.get("reason", "")))
	ok(me["board"]["front"].size() == GameData.column_limit(),
		"被拒后场上仍是 %d 张" % GameData.column_limit(), "%d" % me["board"]["front"].size())

	# ② UI 兜底：假设状态里真有 4/5/6 张（上限被调大或异常注入），
	#    整列要等比缩小塞进列框，绝不溢出到邻列
	for total in [4, 5, 6]:
		while front.size() < total:
			var u: Dictionary = RulesEngine.new_instance(piece_id)
			u["canAttack"] = false
			front.append(u)
		scene._sync_all()
		await process_frame
		var rects: Array = []
		for u in front:
			var v: UnitView = scene.unit_views.get(int(u["uid"]), null)
			if v != null:
				rects.append(_visual_rect(v))
		ok(rects.size() == total, "%d 张都有视图" % total, "%d" % rects.size())
		if rects.size() != total:
			continue
		rects.sort_custom(func(a, b): return a.position.x < b.position.x)
		ok(rects[0].position.x >= frame.position.x - 0.5 and rects[-1].end.x <= frame.end.x + 0.5,
			"%d 张时不越列框" % total,
			"%.1f~%.1f vs 框 %.1f~%.1f" % [rects[0].position.x, rects[-1].end.x,
				frame.position.x, frame.end.x])
		var overlap := 0
		for i in range(1, rects.size()):
			if rects[i].position.x < (rects[i - 1] as Rect2).end.x - 0.5:
				overlap += 1
		ok(overlap == 0, "%d 张时相邻不重叠" % total, "%d 处重叠" % overlap)
		ok(rects[0].size.x >= 40.0, "%d 张时单张仍有 %.0f 宽（可辨认）" % [total, rects[0].size.x])
		var v0: UnitView = scene.unit_views.get(int(front[0]["uid"]), null)
		ok(v0 != null and v0.base_scale < 1.0, "%d 张时整列已缩小" % total,
			"%.2f" % (v0.base_scale if v0 != null else -1.0))
	# 收尾：把超编的假兵清掉，别影响后面的用例。等阵亡动画（0.3s）跑完再往下走，
	# 否则节点还在 tween 里就被场景销毁，退出时会报 ObjectDB 泄漏告警
	while front.size() > GameData.column_limit():
		front.pop_back()
	scene._sync_all()
	await create_timer(0.6).timeout

# ---------------- ⑥ 扇形排布与悬停放大 ----------------

func _test_fan(scene: Control) -> void:
	var hand: Array = scene.state["players"]["p1"]["hand"]
	var n := hand.size()
	ok(n >= 3, "起手至少 3 张（少于 3 张看不出扇形）", str(n))
	if n < 3:
		return
	var first: CardView = scene.card_views.get(int(hand[0]["uid"]), null)
	var last: CardView = scene.card_views.get(int(hand[n - 1]["uid"]), null)
	ok(first != null and last != null, "两端手牌都有视图")
	if first == null or last == null:
		return

	ok(is_equal_approx(first.rotation_degrees, -scene.HAND_MAX_ROT),
		"最左牌左倾 8°", str(first.rotation_degrees))
	ok(is_equal_approx(last.rotation_degrees, scene.HAND_MAX_ROT),
		"最右牌右倾 8°", str(last.rotation_degrees))
	ok(absf(first.rotation_degrees + last.rotation_degrees) < 0.01, "左右倾角对称")

	# 弧落：两端牌底比基准线低 14，中间牌不低于基准线
	ok(is_equal_approx(last.position.y - scene.HAND_Y, scene.HAND_ARC),
		"两端牌落到弧线最低点（弧落 14）", str(last.position.y - scene.HAND_Y))
	var lowest_mid := 0.0
	for i in range(1, n - 1):
		var v: CardView = scene.card_views.get(int(hand[i]["uid"]), null)
		if v != null:
			lowest_mid = maxf(lowest_mid, v.position.y - scene.HAND_Y)
	ok(lowest_mid < scene.HAND_ARC, "中间牌都比两端高", "%.1f" % lowest_mid)

	# 悬停：放大 1.4 / 旋转归零 / 置顶 / 牌顶不顶进战场
	var target: CardView = first
	target.emit_signal("mouse_entered")
	await create_timer(0.3).timeout
	ok(is_equal_approx(target.scale.x, scene.HAND_HOVER_SCALE),
		"悬停放大到 1.3 倍", str(target.scale.x))
	ok(is_equal_approx(target.rotation_degrees, 0.0), "悬停牌旋转归零（正着看）",
		str(target.rotation_degrees))
	var top_z := 0
	for v in scene.card_views.values():
		top_z = maxi(top_z, (v as Control).z_index)
	ok(target.z_index == top_z and target.z_index > 0, "悬停牌压在最上层", str(target.z_index))

	var card_top: float = target.position.y - CardView.SIZE.y * (scene.HAND_HOVER_SCALE - 1.0)
	ok(card_top >= 472.0, "悬停放大后牌顶不顶进战场（军阵框底 472）", "%.1f" % card_top)
	# 牌顶必须让开说明行：放大倍率与说明行位置是绑定的，改一个不改另一个就会压住
	ok(card_top >= scene.hand_hint.get_global_rect().end.y,
		"悬停牌顶让开了说明行", "%.1f < %.1f" % [card_top, scene.hand_hint.get_global_rect().end.y])
	var my_bar: Rect2 = (scene.hero_bars["p1"]["holder"] as Control).get_global_rect()
	ok(target.position.y + CardView.SIZE.y <= my_bar.position.y,
		"悬停牌底不压主将面板", "%.0f > %.0f" % [target.position.y + CardView.SIZE.y, my_bar.position.y])

	# 悬停牌的规则文字挂在手牌上方一行（放大后不再弹浮层）
	ok(scene.hand_hint.text != "", "悬停时手牌上方显示卡牌说明", scene.hand_hint.text.substr(0, 12))
	ok(not scene.hand_hint.get_global_rect().intersects(Rect2(Vector2(0, scene.HAND_Y), Vector2(1440, 330))),
		"说明行不压手牌")

	target.emit_signal("mouse_exited")
	await create_timer(0.3).timeout
	ok(is_equal_approx(target.scale.x, 1.0), "鼠标移开后牌恢复原尺寸", str(target.scale.x))
	ok(scene.hand_hint.text == "", "移开后说明行清空")

# ---------------- ⑦ 点部队能选中 ----------------

func _test_unit_click(scene: Control) -> void:
	var me: Dictionary = scene.state["players"]["p1"]
	# 上一步出的可能是计谋牌，这里保证场上有我方部队（否则点兵无从验起）
	if _count_units(scene.state, "p1") == 0:
		var prev_current := str(scene.state["current"])
		me["mana"] = 10
		scene.state["current"] = "p1"
		for c in me["hand"]:
			if str(c["type"]) == "piece" and RulesEngine.can_play(scene.state, "p1", c):
				RulesEngine.play_card(scene.state, "p1", int(c["uid"]))
				break
		scene.state["current"] = prev_current
		scene._sync_all()
		await process_frame

	var target_uid := -1
	for r in RulesEngine.RANKS:
		var row: Array = me["board"][r]
		if row.size() > 0:
			var u: Dictionary = row[0]
			u["canAttack"] = true
			u["atk"] = maxi(1, int(u["atk"]))
			target_uid = int(u["uid"])
			break
	scene._sync_all()
	await process_frame

	var found: UnitView = scene.unit_views.get(target_uid, null)
	ok(found != null, "我方场上有可点的部队视图")
	if found == null:
		return
	_click(found)
	ok(scene.selected_uid == int(found.uid), "点部队能选中（selected_uid 已设置）", str(scene.selected_uid))

# ---------------- ⑧ 敌方意图预告 ----------------

func _clear_board(scene: Control) -> void:
	for pid in ["p1", "p2"]:
		for r in RulesEngine.RANKS:
			(scene.state["players"][pid]["board"][r] as Array).clear()

func _test_threat(scene: Control) -> void:
	var foe: Dictionary = scene.state["players"]["p2"]
	var me: Dictionary = scene.state["players"]["p1"]

	# ① 单杀：5 攻敌车打得死 2/3 前锋 → 险印亮出；敌方部队不亮印
	_clear_board(scene)
	var car: Dictionary = RulesEngine.new_instance("n_che1")      # 5/5
	foe["board"]["front"].append(car)
	var mine: Dictionary = RulesEngine.new_instance("n_bing2")    # 2/3
	me["board"]["front"].append(mine)
	scene.state["current"] = "p1"
	scene.busy = false
	scene._sync_all()
	await create_timer(0.6).timeout   # 让上一组用例旧视图的阵亡动画走完
	var pv: Dictionary = RulesEngine.threat_preview(scene.state, "p1")
	ok(pv["kill"].has(int(mine["uid"])), "引擎预览：5 攻 ≥ 3 血标记前锋")
	var v: UnitView = scene.unit_views.get(int(mine["uid"]), null)
	ok(v != null and v._threat.visible, "被标记部队亮「险」印")
	var foe_v: UnitView = scene.unit_views.get(int(car["uid"]), null)
	ok(foe_v != null and not foe_v._threat.visible, "敌方部队不亮印")

	# ② 守御吸火力：火力被守御强制接管，中军解除威胁
	_clear_board(scene)
	foe["board"]["front"].append(RulesEngine.new_instance("n_che1"))
	var guard: Dictionary = RulesEngine.new_instance("n_shi1")    # 1/4 守御
	me["board"]["front"].append(guard)
	var mid: Dictionary = RulesEngine.new_instance("n_bing2")
	me["board"]["mid"].append(mid)
	scene._sync_all()
	await create_timer(0.6).timeout
	pv = RulesEngine.threat_preview(scene.state, "p1")
	ok(pv["kill"].has(int(guard["uid"])), "引擎预览：守御强制先挨打，5 攻 ≥ 4 血")
	ok(not pv["kill"].has(int(mid["uid"])), "引擎预览：有守御时中军不在威胁名单")
	var gv: UnitView = scene.unit_views.get(int(guard["uid"]), null)
	var mv: UnitView = scene.unit_views.get(int(mid["uid"]), null)
	ok(gv != null and gv._threat.visible, "守御部队亮「险」印")
	ok(mv != null and not mv._threat.visible, "被保护的中军不亮印")

	# ③ 主将斩杀线：全场无兵才暴露；脱离斩杀线 / 敌方回合告警熄灭
	_clear_board(scene)
	foe["board"]["front"].append(RulesEngine.new_instance("n_che1"))
	me["hp"] = 5
	scene._sync_all()
	await create_timer(0.6).timeout
	ok(bool(RulesEngine.threat_preview(scene.state, "p1")["hero"]),
		"引擎预览：无兵且 5 攻 ≥ 5 血，主将告警")
	var danger: Control = scene.hero_bars["p1"]["danger"]
	ok(danger.visible, "主将血条亮「险」印")
	# 险印不许压主将卡内的任何已有元素（曾经放右上角，盖掉了第 10 颗军粮点）
	for pid in ["p1", "p2"]:
		var b: Dictionary = scene.hero_bars[pid]
		var dr: Rect2 = (b["danger"] as Control).get_global_rect()
		ok(not dr.intersects((b["pips"][9] as Control).get_global_rect()),
			"%s 险印不压军粮圆点" % pid)
		ok(not dr.intersects((b["hp"] as Control).get_global_rect()),
			"%s 险印不压血量" % pid)
		ok(not dr.intersects((b["name"] as Control).get_global_rect()),
			"%s 险印不压名字" % pid)
	me["hp"] = 30
	scene._sync_all()
	await process_frame
	ok(not bool(RulesEngine.threat_preview(scene.state, "p1")["hero"]), "引擎预览：30 血脱离斩杀线")
	ok(not danger.visible, "脱离斩杀线告警熄灭")
	scene.state["current"] = "p2"
	scene._sync_all()
	await process_frame
	ok(not danger.visible, "敌方回合主将告警熄灭")
	var any_lit := false
	for u in me["board"]["front"]:
		var uv: UnitView = scene.unit_views.get(int(u["uid"]), null)
		if uv != null and uv._threat.visible:
			any_lit = true
	ok(not any_lit, "敌方回合部队险印全部熄灭")

	# 恢复我方回合，收尾（后续无用例依赖场面对象）
	scene.state["current"] = "p1"
	scene._sync_all()
	await create_timer(0.6).timeout

## 牌库余量 / 疲劳告警标签：余量如实显示、抽空转疲劳态、布局不压血条右栏既有元素
func _test_deck_label(scene: Control) -> void:
	for pid in ["p1", "p2"]:
		var p: Dictionary = scene.state["players"][pid]
		var bar: Dictionary = scene.hero_bars[pid]
		var dl: Label = bar["deck"]
		var n: int = (p["deck"] as Array).size()
		ok(dl.text == "牌库 %d" % n, "%s 牌库余量如实显示" % pid, dl.text)
		# 不压血条右栏既有元素（军粮数字 / 军粮圆点 / 险印）
		var dr: Rect2 = dl.get_global_rect()
		ok(not dr.intersects((bar["mana"] as Control).get_global_rect()),
			"%s 牌库标签不压军粮数字" % pid,
			"deck=%s mana=%s" % [dr, (bar["mana"] as Control).get_global_rect()])
		ok(not dr.intersects((bar["pips"][0] as Control).get_global_rect()),
			"%s 牌库标签不压军粮圆点" % pid)
		ok(not dr.intersects((bar["danger"] as Control).get_global_rect()),
			"%s 牌库标签不压险印" % pid)
		# 在血条框内
		var holder: Control = bar["holder"]
		ok(holder.get_global_rect().encloses(dr), "%s 牌库标签在血条框内" % pid,
			"deck=%s holder=%s" % [dr, holder.get_global_rect()])

	# 抽空 → 疲劳态：显示下一跳伤害（fatigue + 1），朱砂色
	var me: Dictionary = scene.state["players"]["p1"]
	var bar1: Dictionary = scene.hero_bars["p1"]
	var dl1: Label = bar1["deck"]
	var keep: Array = (me["deck"] as Array).duplicate()
	(me["deck"] as Array).clear()
	me["fatigue"] = 2
	scene._sync_all()
	await process_frame
	ok(dl1.text == I18n.T("疲劳 3 伤"), "牌库抽空显示下一跳疲劳伤（已跳 2 → 3）", dl1.text)
	ok(dl1.get_theme_color("font_color") == UiTheme.SEAL, "疲劳态用朱砂色")
	# 少量余量 → 琥珀警示
	(me["deck"] as Array).append_array(keep.slice(0, 2))
	scene._sync_all()
	await process_frame
	ok(dl1.text == "牌库 2", "余量 ≤3 显示牌库数", dl1.text)
	ok(dl1.get_theme_color("font_color") == Color("#8a6416"), "余量 ≤3 用深琥珀警示色")
	# 恢复
	(me["deck"] as Array).clear()
	(me["deck"] as Array).append_array(keep)
	me["fatigue"] = 0
	scene._sync_all()
	await process_frame
	ok(dl1.text == "牌库 %d" % keep.size(), "恢复后余量如实显示", dl1.text)

# ---------------- 文件工具 ----------------

func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
