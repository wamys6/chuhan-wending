extends SceneTree
## 新手引导测试
##
## 运行：godot --headless --path godot --script res://tests/tutorial_test.gd
## 验四件事：①关键词释义覆盖全部牌面关键词（漏一个玩家就看不到解释）
##           ②引导/提示标记只写一次、能落盘、能重置
##           ③聚光灯浮层能建起来、能按动作推进、跳过不写完成标记
##           ④战斗界面里真的接上了引导与技能按钮（不是只写了个模块没人用）

var checks := 0
var failures := 0

var _sig_skipped := false
var _sig_finished_calls := 0

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("  ✗ " + label + ("" if detail == "" else "  ← " + detail))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var backup := _read(Tutorial.PATH)
	print("· 关键词释义")
	_test_keywords()
	print("· 标记与落盘")
	_test_store()
	print("· 一次性提示")
	_test_hints()
	print("· 引导浮层")
	_test_coach()
	print("· 卡牌浮层")
	_test_card_tip()
	print("· 战斗界面接线")
	await _test_battle()
	_write(Tutorial.PATH, backup)
	Tutorial._reload()
	# 让 queue_free 真的执行掉，避免退出时报节点泄漏
	await process_frame
	await process_frame
	if failures > 0:
		print("失败 %d 项 / 共 %d 项" % [failures, checks])
	else:
		print("通过 %d 项，失败 0 项" % checks)
	quit(1 if failures > 0 else 0)

# ---------------- 关键词 ----------------

func _test_keywords() -> void:
	GameData.ensure_loaded()
	for kw in Tutorial.KEYWORD_LIST + Tutorial.EXTRA_LIST:
		ok(Tutorial.KEYWORDS.has(kw), "「%s」已在释义表里" % kw)
		ok(Tutorial.explain(kw) != "", "「%s」有非空解释" % kw)

	# 牌面上真出现的关键词，必须都能被识别出来
	var cards_with_kw := 0
	for id in GameData.cards.keys():
		var desc := str(GameData.cards[id].get("desc", ""))
		var found := Tutorial.keywords_in(desc)
		if not found.is_empty():
			cards_with_kw += 1
			for kw in found:
				ok(Tutorial.explain(str(kw)) != "", "卡 %s 的关键词「%s」有释义" % [id, kw])
	ok(cards_with_kw >= 20, "至少 20 张卡带关键词可标注", str(cards_with_kw))

	# 排序与去重
	var order := Tutorial.keywords_in("守御。死战：友军 +1 攻。守御再写一次")
	ok(str(order[0]) == "守御" and str(order[1]) == "死战", "关键词按出现顺序返回", str(order))
	ok(order.size() == 2, "重复出现只算一次", str(order))

	var exps := Tutorial.explanations_for("冲锋。迂回")
	ok(exps.size() == 2, "解释列表两条", str(exps.size()))
	ok(str(exps[0]["kw"]) == "冲锋", "解释列表保持出现顺序")

	# 高亮：关键词裹上朱砂色，正文其余部分保留
	var hl := Tutorial.highlight_bbcode("守御：必须先打掉它")
	ok(hl.contains("[color=#7c1f1a][b]守御[/b][/color]"), "关键词被包成朱砂色")
	ok(hl.contains("必须先打掉它"), "正文未被吞掉")

# ---------------- 标记 ----------------

func _test_store() -> void:
	Tutorial.reset()
	ok(not Tutorial.done(Tutorial.BATTLE_INTRO), "重置后引导未完成")
	Tutorial.mark_done(Tutorial.BATTLE_INTRO)
	ok(Tutorial.done(Tutorial.BATTLE_INTRO), "标记后引导已完成")

	# 落盘：重新从磁盘读还在
	Tutorial._reload()
	ok(Tutorial.done(Tutorial.BATTLE_INTRO), "完成标记已落盘")

	Tutorial.reset()
	Tutorial._reload()
	ok(not Tutorial.done(Tutorial.BATTLE_INTRO), "重置后磁盘标记也清掉")

	Tutorial.reset()
	Tutorial.mark_done("")
	ok(not Tutorial.done(""), "空标记名不写入")

	# 坏档不能把游戏搞崩
	_write(Tutorial.PATH, "{ 这不是合法 JSON")
	Tutorial._reload()
	ok(not Tutorial.done(Tutorial.BATTLE_INTRO), "坏档当作空档处理")
	Tutorial.mark_done("afterBad")
	ok(Tutorial.done("afterBad"), "坏档之后仍能正常写入")
	Tutorial.reset()

# ---------------- 提示 ----------------

func _test_hints() -> void:
	ok(Tutorial.hint("noMana"), "首次触发该提示")
	ok(not Tutorial.hint("noMana"), "第二次不再触发")
	ok(Tutorial.hint_seen("noMana"), "已记下弹过")
	ok(Tutorial.hint("noMana", true), "force 可强制再弹")
	ok(not Tutorial.hint_seen("never"), "没弹过的记为未弹")

	Tutorial._reload()
	ok(Tutorial.hint_seen("noMana"), "提示标记已落盘")
	ok(not Tutorial.hint("noMana"), "重载后仍然只弹一次")

	Tutorial.reset()
	ok(Tutorial.hint("noMana"), "重置后重新可弹")

# ---------------- 引导浮层 ----------------

func _make_host() -> Control:
	var host := Control.new()
	host.size = Vector2(1440, 900)
	root.add_child(host)
	return host

func _test_coach() -> void:
	var host := _make_host()
	var target := Control.new()
	target.position = Vector2(120, 140)
	target.size = Vector2(160, 70)
	host.add_child(target)

	var steps := [
		{"title": "一", "text": "第一步", "node": target},
		{"title": "二", "text": "第二步", "tag": "play", "rect": Rect2(300, 320, 120, 80)},
		{"title": "三", "text": "第三步", "node": target},
	]
	var c := Coach.start(host, steps, "coachTest")
	ok(c != null, "引导层可创建")
	ok(c != null and c.active, "创建即生效")
	ok(c.get_child_count() == 6, "四块遮罩 + 描边框 + 提示框", str(c.get_child_count()))
	ok(str(c.current_step().get("title", "")) == "一", "起始在第一步")
	ok(c._target_rect().size.x == 160.0, "控件目标取实际尺寸")
	ok(c._step_label.text == "1 / 3", "步骤计数正确", c._step_label.text)

	c.advance()
	ok(str(c.current_step().get("title", "")) == "二", "手动推进到第二步")
	ok(c._target_rect().size.x == 120.0, "无控件时用矩形目标", str(c._target_rect()))
	c.notify("attack")
	ok(str(c.current_step().get("title", "")) == "二", "无关动作不推进")
	c.notify("play")
	ok(str(c.current_step().get("title", "")) == "三", "匹配动作自动推进")
	ok(not Tutorial.done("coachTest"), "走完前不写完成标记")

	c.finished.connect(func (_sk: bool) -> void:
		_sig_finished_calls += 1)
	c.advance()
	ok(Tutorial.done("coachTest"), "最后一步之后写入完成标记")
	ok(_sig_finished_calls == 1, "结束时发出一次 finished", str(_sig_finished_calls))
	ok(not c.active, "结束后失效")

	# 跳过：不算完成（下次还会再走一遍）
	var c2 := Coach.start(host, steps, "coachSkip")
	c2.finished.connect(func (sk: bool) -> void:
		_sig_skipped = sk)
	c2.skip()
	ok(_sig_skipped, "跳过时回调拿到 skipped=true")
	ok(not Tutorial.done("coachSkip"), "跳过不写完成标记")

	# 空步骤不创建
	ok(Coach.start(host, [], "x") == null, "空步骤不建浮层")

	# goto_step 越界不崩
	var c3 := Coach.start(host, steps, "")
	c3.goto_step(99)
	ok(c3.index == 0, "越界跳步被忽略")
	c3.goto_step(2)
	ok(str(c3.current_step().get("title", "")) == "三", "跳步生效")
	c3.skip()

	Tutorial.reset()
	host.queue_free()

# ---------------- 卡牌浮层 ----------------

func _test_card_tip() -> void:
	GameData.ensure_loaded()
	var host := _make_host()
	var tip := CardTip.create(host)
	ok(tip != null and not tip.visible, "浮层默认不显示")

	# 找一张带关键词的真牌
	var card := {}
	for id in GameData.cards.keys():
		var c: Dictionary = GameData.card(str(id)).duplicate(true)
		if str(c.get("type", "")) == "piece" and Tutorial.keywords_in(str(c.get("desc", ""))).size() > 0:
			card = c
			break
	ok(not card.is_empty(), "找到一张带关键词的牌")
	if card.is_empty():
		return
	card["uid"] = 777

	tip.show_card(card)
	ok(tip.visible, "显示后可见")
	var text := _rich_text(tip)
	var kw := str(Tutorial.keywords_in(str(card["desc"]))[0])
	ok(text.contains("[color=#7c1f1a][b]%s[/b][/color]" % kw), "描述里的关键词高亮")
	ok(text.contains(str(Tutorial.explain(kw))), "附上关键词释义", kw)

	tip.hide_tip()
	ok(not tip.visible, "隐藏生效")

	# 同一张牌不重复重建
	var before := tip.get_child_count()
	tip.show_card(card)
	tip.show_card(card)
	ok(tip.get_child_count() == before, "同牌重复显示不重建")

	# 无描述的牌也能显示（不能崩）
	var plain := GameData.card("n_bing1").duplicate(true)
	plain["uid"] = 778
	plain["desc"] = ""
	tip.show_card(plain)
	ok(tip.visible, "无描述牌也能显示")

	host.queue_free()

## 递归收集 RichTextLabel 上的 BBCode 文本
func _rich_text(node: Node) -> String:
	var out := ""
	if node is RichTextLabel:
		out += (node as RichTextLabel).text
	for ch in node.get_children():
		out += _rich_text(ch)
	return out

# ---------------- 战斗界面接线 ----------------

func _test_battle() -> void:
	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	# 技能按钮：走的是真数据（刘邦 约法三章 2 费）
	ok(scene.skill_btn != null, "战斗界面有主将技能按钮")
	ok(scene.skill_btn.text.begins_with("约法三章"), "技能按钮显示技能名", scene.skill_btn.text)

	# 第 1 回合军粮只有 1，用不起 → 给一句原因
	scene._on_skill()
	ok(scene.toast_label.text == "军粮不足", "军粮不够时提示原因", scene.toast_label.text)

	# 给足军粮 + 掉点血 → 技能该真的生效
	var me: Dictionary = scene.state["players"]["p1"]
	me["mana"] = 5
	me["hp"] = 20
	var before_hp := int(me["hp"])
	scene._on_skill()
	ok(int(me["hp"]) == before_hp + 2, "技能回血 2 点", str(me["hp"]))
	ok(bool(me["skillUsed"]), "用过之后标记已用")
	scene._on_skill()
	ok(scene.toast_label.text == "本回合已用过主将技能", "同一回合不能连用", scene.toast_label.text)

	# 引导步骤：六步齐全、每步都指得到东西
	var steps: Array = scene._intro_steps()
	ok(steps.size() == 6, "首局引导 6 步", str(steps.size()))
	var titled := 0
	var targeted := 0
	for st in steps:
		if str(st.get("title", "")) != "" and str(st.get("text", "")) != "":
			titled += 1
		if st.get("node", null) != null or st.has("rect"):
			targeted += 1
	ok(titled == 6, "每步都有标题与正文", str(titled))
	ok(targeted == 6, "每步都有目标", str(targeted))

	# 强制弹一次，确认真的建起来了
	scene._force_intro()
	await process_frame
	ok(scene.coach != null and is_instance_valid(scene.coach), "战斗中能弹出引导")
	var started_ok: bool = scene.coach != null and is_instance_valid(scene.coach) and scene.coach.active
	ok(started_ok, "引导处于激活态")
	if started_ok:
		ok(scene.coach.steps.size() == 6, "浮层步骤与来源一致")
		ok(scene.coach._box != null and scene.coach._box.visible, "提示框已显示")
		ok(scene.coach._frame.visible, "目标描边框已显示")
	# 收掉，且不能把「首局引导」记成已完成
	scene._close_coach()
	await process_frame
	ok(not is_instance_valid(scene.coach), "引导收走后释放")
	ok(not Tutorial.done(Tutorial.BATTLE_INTRO), "巡览/中途收掉不算完成")

	# 暂停菜单：呼出 → 树冻结、三键齐全 → 继续 → 恢复
	ok(scene.pause_btn != null, "战斗界面有暂停按钮")
	scene._open_pause()
	await process_frame
	ok(scene._pause_layer != null and is_instance_valid(scene._pause_layer),
		"能呼出暂停菜单")
	ok(paused, "暂停菜单冻结战斗")
	var pause_btns: Array = []
	for c in scene._pause_layer.find_children("*", "Button", true, false):
		pause_btns.append((c as Button).text)
	ok(pause_btns.size() == 3, "暂停菜单有 继续/设置/放弃 三个按钮", str(pause_btns))
	scene._close_pause()
	await process_frame
	ok(not paused, "继续后战斗恢复")
	ok(scene._pause_layer == null, "暂停层已释放")

	# 军粮圆点条：10 颗点，三种状态各自对应
	var bar: Dictionary = scene.hero_bars["p1"]
	var pips: Array = bar["pips"]
	ok(pips.size() == 10, "军粮条共 10 颗点", str(pips.size()))
	me["mana"] = 2
	me["maxMana"] = 5
	scene._sync_hero_bars()
	ok(pips[0].get_theme_stylebox("panel") == bar["sb_on"], "可用军粮＝实心点")
	ok(pips[3].get_theme_stylebox("panel") == bar["sb_spent"], "本回合已花＝空心点")
	ok(pips[6].get_theme_stylebox("panel") == bar["sb_off"], "未解锁＝灰点")
	ok(scene.hero_bars["p2"]["pips"].size() == 10, "敌方主将也有军粮点条")

	# 阵亡特效：烟尘 + 立绘碎片真的落到 fx_layer
	var base_id := str(GameData.cards.keys()[0])
	var uv := UnitView.new()
	scene.board_layer.add_child(uv)
	uv.setup({"uid": 999001, "baseId": base_id, "name": "试", "atk": 1, "hp": 1,
		"maxHp": 1, "col": "front", "canAttack": false, "taunt": false})
	var fx_before: int = int(scene.fx_layer.get_child_count())
	scene._death_fx(uv)
	ok(scene.fx_layer.get_child_count() >= fx_before + 2, "阵亡有烟尘/碎片特效",
		str(scene.fx_layer.get_child_count() - fx_before))
	uv.queue_free()

	scene.queue_free()
	await process_frame

# ---------------- 文件小工具 ----------------

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
	if text == "":
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
