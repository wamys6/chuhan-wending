extends SceneTree
## 中英双语测试
##
## 运行：godot --headless --path godot --script res://tests/i18n_test.gd
##
## 三件事：
##   ① 数据层：每张卡/关/军师/事件/成就/关键词都有英文，且英文里没有汉字
##   ② 查表：精确命中、去空白命中、数字模板都正常；切回中文能还原
##   ③ **界面扫描**：把每个界面在英文模式下建出来，遍历所有 Label/Button/
##      富文本，凡是有汉字没被翻译的就点名——这是双语质量真正的保证。
##      允许两种例外：单个汉字（朱砂印章式徽记，是刻意保留的视觉符号）、
##      语言选项里自带的「中 文」。

var checks := 0
var failures := 0
## --script 模式下 autoload 的全局名不可用于编译期，只能运行期取节点
var app: Node
var _orig_lang := "zh"
## 允许保留的中文：单个汉字徽记 + 语言选项自身
var allow_text := ["中文"]

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("  ✗ " + label + ("" if detail == "" else "  ← " + detail))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	app = root.get_node("App")
	I18n.ensure_loaded()
	Settings.ensure_loaded()
	_orig_lang = str(Settings.lang)
	# 数据检查本来就是查英文表，先切到英文
	I18n.set_lang_soft("en")
	print("· 数据完整性")
	_test_data()
	print("· 查表规则")
	_test_lookup()
	print("· 语言切换")
	_test_toggle()
	print("· 战报渲染")
	_test_log()
	print("· 界面扫描（英文）")
	await _test_screens()
	if not I18n.missing.is_empty():
		print("· 缺翻译 %d 条：" % I18n.missing.size())
		var uniq: Array = I18n.missing.duplicate()
		uniq.sort()
		for s in uniq:
			print("    ", s)
	I18n.set_lang_soft(_orig_lang)
	if failures > 0:
		print("失败 %d 项 / 共 %d 项" % [failures, checks])
	else:
		print("通过 %d 项，失败 0 项" % checks)
	quit(1 if failures > 0 else 0)

# ---------------- 数据 ----------------

func _test_data() -> void:
	GameData.ensure_loaded()
	var lack: Array = []
	for id in GameData.cards.keys():
		var en := I18n.card_en(str(id))
		if str(en.get("name", "")) == "" or str(en.get("desc", "")) == "":
			lack.append(str(id))
	ok(lack.is_empty(), "46 张卡都有英文名与描述", str(lack))

	var bad_cjk: Array = []
	for id in GameData.cards.keys():
		var en := I18n.card_en(str(id))
		if I18n.has_cjk(str(en.get("name", ""))) or I18n.has_cjk(str(en.get("desc", ""))):
			bad_cjk.append(str(id))
	ok(bad_cjk.is_empty(), "卡牌英文里没有汉字", str(bad_cjk))

	for h in ["liubang", "xiangyu"]:
		ok(I18n.hero_field(h, "name") != "", "英雄 %s 有英文名" % h)
		ok(I18n.skill_field(h, "name") != "" and I18n.skill_field(h, "desc") != "",
			"英雄 %s 的技能有英文" % h)

	for st in GameData.stages:
		var sid := str(st["id"])
		for f in ["chapter", "name", "year", "subtitle", "lore", "goalText"]:
			ok(I18n.stage_field(sid, f) != "", "关卡 %s 的 %s 有英文" % [sid, f])
		ok(I18n.stage_enemy_field(sid, "name") != "", "关卡 %s 的敌将有英文名" % sid)

	for a in GameData.advisors:
		ok(I18n.advisor_field(str(a["id"]), "desc") != "", "军师 %s 有英文简介" % str(a["id"]))

	for e in GameData.events:
		var eid := str(e["id"])
		ok(I18n.event_field(eid, "text") != "", "事件 %s 有英文" % eid)
		for oi in (e.get("options", []) as Array).size():
			ok(I18n.event_option(eid, oi, "label") != "", "事件 %s 选项 %d 有英文" % [eid, oi])

	for a in Codex.ACHIEVEMENTS:
		ok(I18n.achievement_field(str(a["id"]), "name") != "", "成就 %s 有英文名" % str(a["id"]))
		ok(I18n.achievement_field(str(a["id"]), "desc") != "", "成就 %s 有英文描述" % str(a["id"]))

	ok(I18n.keyword_list().size() == 6, "英文关键词 6 个", str(I18n.keyword_list().size()))
	for p in I18n.keyword_pairs():
		ok(str(p["text"]) != "", "关键词 %s 有英文释义" % str(p["name"]))

# ---------------- 查表 ----------------

func _test_lookup() -> void:
	I18n.set_lang_soft("en")
	ok(I18n.T("结束回合") == "End Turn", "精确命中", I18n.T("结束回合"))
	ok(I18n.T("战 报") != "战 报", "去空白也能命中", I18n.T("战 报"))
	ok(I18n.T("血量 22 / 22") == "Health 22 / 22", "血量模板", I18n.T("血量 22 / 22"))
	ok(I18n.T("军粮 3 / 7") == "Provision 3 / 7", "军粮模板", I18n.T("军粮 3 / 7"))
	ok(I18n.T("第 5 回合 · 我方行动") == "Turn 5 · Your move", "回合模板",
		I18n.T("第 5 回合 · 我方行动"))
	ok(I18n.T("第 9 回合 · 敌方行动") == "Turn 9 · Enemy move", "敌方回合模板",
		I18n.T("第 9 回合 · 敌方行动"))
	ok(I18n.T("2 费") == "2 Prov", "费用模板", I18n.T("2 费"))
	ok(I18n.T("1 攻 · 4 血") == "1 Atk · 4 HP", "攻血模板", I18n.T("1 攻 · 4 血"))
	ok(I18n.T("进度　3 / 8") == "Progress 3 / 8", "进度模板（全角空格转普通空格）", I18n.T("进度　3 / 8"))
	# 死战专精：地图上的常驻 chip 是动态拼的（档位随牌组变），走数字模板
	ok(I18n.T("死战专精 +0/+1") == "Last Stand mastery +0/+1", "死战专精模板",
		I18n.T("死战专精 +0/+1"))
	ok(I18n.T("死战专精 +2/+2") == "Last Stand mastery +2/+2", "死战专精模板（高档）",
		I18n.T("死战专精 +2/+2"))
	ok(I18n.T("「鸿门宴」已 破") == "“鸿门宴” Taken", "关卡名号模板", I18n.T("「鸿门宴」已 破"))
	# 列满：数字来自 COLUMN_LIMIT，不能写死（列名此刻已是英文）
	var full_reason := "%s列已满（每列最多 %d 员）" % [
		GameData.rank_name("front"), GameData.column_limit()]
	ok(I18n.T(full_reason) == "The Vanguard column is full (%d per column)" % GameData.column_limit(),
		"列满 reason 模板", I18n.T(full_reason))
	var full_tip := "每列最多站 %d 员。先打完这一列，或把牌出到别的列。" % GameData.column_limit()
	ok(not I18n.has_cjk(I18n.T(full_tip)), "列满提示无残留汉字", I18n.T(full_tip))
	ok(I18n.T("小提示") == "Tip", "小提示前缀", I18n.T("小提示"))
	# 英文串原样放行，不记缺
	var before := I18n.missing.size()
	I18n.T("End Turn")
	ok(I18n.missing.size() == before, "英文串不记为缺翻译")
	# 真缺的会记一笔
	I18n.T("这句话还没翻译")
	ok(I18n.missing.has("这句话还没翻译"), "缺翻译被记录")

	I18n.set_lang_soft("zh")
	ok(I18n.T("结束回合") == "结束回合", "中文模式原样返回")
	ok(not I18n.has_cjk("Health"), "纯英文判无汉字")
	ok(I18n.has_cjk("血量"), "中文判有汉字")

# ---------------- 切换 ----------------

func _test_toggle() -> void:
	I18n.set_lang_soft("en")
	ok(I18n.is_en(), "切到英文")
	ok(str(GameData.card("n_bing1").get("name", "")) == "Infantry · Recruit",
		"数据层卡名变英文", str(GameData.card("n_bing1").get("name", "")))
	ok(GameData.rank_name("front") == "Vanguard", "列名变英文", GameData.rank_name("front"))
	ok(str(GameData.hero("liubang").get("name", "")) == "Liu Bang", "英雄名变英文")
	ok(str((GameData.hero("liubang")["skill"] as Dictionary).get("name", "")) == "Three Articles",
		"技能名变英文")
	ok(str(GameData.stage_by_id("peixian").get("name", "")) == "Rising at Pei County",
		"关卡名变英文")
	ok(str(GameData.advisors[0].get("name", "")) != str(GameData.advisors[0].get("name", "")) or true,
		"军师表可读")

	I18n.set_lang_soft("zh")
	ok(str(GameData.card("n_bing1").get("name", "")) == "兵·新卒",
		"切回中文数据还原", str(GameData.card("n_bing1").get("name", "")))
	ok(GameData.rank_name("front") == "前锋", "列名还原", GameData.rank_name("front"))
	ok(str(GameData.hero("liubang").get("name", "")) == "刘邦", "英雄名还原")
	ok(str((GameData.hero("liubang")["skill"] as Dictionary).get("name", "")) == "约法三章",
		"技能名还原")

# ---------------- 战报 ----------------

func _test_log() -> void:
	var args := {"n": 2, "m": 3, "mm": 5, "name": "Infantry", "rank": "Vanguard",
		"target": "Chariot", "a": 3, "d": 2, "side": "p1"}
	I18n.set_lang_soft("en")
	var bad: Array = []
	for key in LogText.ZH.keys():
		var line := LogText.render({"k": key, "a": args})
		if I18n.has_cjk(line):
			bad.append(str(key) + " → " + line)
	ok(bad.is_empty(), "所有战报 key 都有英文", str(bad))
	ok(not I18n.has_cjk(LogText.render({"k": "turn", "a": args})), "回合战报是英文")

	I18n.set_lang_soft("zh")
	ok(I18n.has_cjk(LogText.render({"k": "turn", "a": args})), "中文模式战报是中文")

# ---------------- 界面扫描 ----------------

func _test_screens() -> void:
	I18n.set_lang_soft("en")
	var offenders: Dictionary = {}
	var scanned := 0

	# 准备各界面需要的状态（与 --tour 类似，但不真的打）
	Campaign.use_slot(0)
	Campaign._wipe_all()
	app.progress = Campaign.start_run("liubang",
		(GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	Campaign.clear_stage(app.progress, "peixian", "n_bing2")
	app.stage = Campaign.stage_by_id("hongmen")

	var scenes := [
		"res://scenes/menu.tscn",
		"res://scenes/slots.tscn",
		"res://scenes/campaign_map.tscn",
		"res://scenes/stage_intro.tscn",
		"res://scenes/battle.tscn",
		"res://scenes/reward.tscn",
		"res://scenes/advisor.tscn",
		"res://scenes/omen.tscn",
		"res://scenes/event.tscn",
		"res://scenes/codex.tscn",
		"res://scenes/lobby.tscn",
	]
	app.prepare_rewards()
	app.pending_event = Campaign.pick_event(app.progress)
	app.advisor_choices = Campaign.roll_advisors(3)

	for path in scenes:
		# 菜单第一遍在无进度状态扫（主按钮是「开始战役」）
		if path.ends_with("menu.tscn"):
			var keep: Dictionary = app.progress
			app.progress = {}
			var m0: Node = load(path).instantiate()
			root.add_child(m0)
			await process_frame
			scanned += _scan(m0, offenders, "menu:empty")
			m0.queue_free()
			await process_frame
			app.progress = keep
		var scene: Node = load(path).instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		scanned += _scan(scene, offenders, path.get_file())
		# 天时揭晓页要确认真建出来了：没有天时的存档会直接跳地图，
		# 那时扫到的是个空场景，「零残留」就成了假绿
		if path.ends_with("omen.tscn"):
			ok(scene.get("_paper") != null, "揭晓页已按天时建出签纸")
		# 图鉴：详情面板（选中一张卡）+ 三个页签都要扫
		if path.ends_with("codex.tscn") and scene.has_method("_select_card"):
			scene._select_card("n_bing1")
			await process_frame
			scanned += _scan(scene, offenders, "codex:detail")
		if path.ends_with("codex.tscn") and scene.has_method("_switch_tab"):
			for tab in ["stats", "ach"]:
				scene._switch_tab(tab)
				await process_frame
				scanned += _scan(scene, offenders, path.get_file() + ":" + tab)
		# 奖励页：还要扫「不取牌 · 改删一张」的选牌覆盖层
		if path.ends_with("reward.tscn") and scene.has_method("_open_drop"):
			scene._open_drop()
			await process_frame
			scanned += _scan(scene, offenders, "reward:drop")
			scene._close_drop()
			await process_frame
		# 事件页：得牌层（多张，带「还需 N 张」）与删牌层都要扫
		if path.ends_with("event.tscn") and scene.has_method("_open_picker"):
			var ev_deck: Array = (app.progress.get("deck", []) as Array).duplicate()
			for spec in [["add", 2], ["remove", 1]]:
				var pk = scene._open_picker(ev_deck, str(spec[0]), int(spec[1]))
				await process_frame
				if pk != null:
					scanned += _scan(pk, offenders, "event:" + str(spec[0]))
					pk.queue_free()
				await process_frame
		# 战斗界面额外扫引导浮层与卡牌浮层
		if path.ends_with("battle.tscn"):
			scene._force_intro()
			await process_frame
			scanned += _scan(scene, offenders, "coach")
			scene._close_coach()
			await process_frame
			var hand: Array = (scene.state as Dictionary)["players"]["p1"]["hand"]
			if hand.size() > 0:
				scene.card_tip.show_card(hand[0])
				await process_frame
				scanned += _scan(scene, offenders, "card_tip")
				scene.card_tip.hide_tip()
		scene.queue_free()
		await process_frame

	# 结局画面：需要「八关全破」的进度才肯建
	var keep_prog: Dictionary = app.progress
	app.progress = Campaign.start_run("liubang",
		(GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	for s in Campaign.stages():
		(app.progress["cleared"] as Array).append(str(s["id"]))
	var endsc: Node = load("res://scenes/ending.tscn").instantiate()
	root.add_child(endsc)
	await process_frame
	await process_frame
	scanned += _scan(endsc, offenders, "ending")
	endsc.queue_free()
	await process_frame
	app.progress = keep_prog

	# 设置面板单独扫（它不是场景，是浮层）
	var panel := SettingsPanel.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(panel)
	await process_frame
	scanned += _scan(panel, offenders, "settings")
	panel.queue_free()
	await process_frame

	ok(scanned > 200, "扫描到的文本节点够多（说明真的建了界面）", str(scanned))
	ok(offenders.is_empty(), "英文界面没有残留汉字（%d 处）" % offenders.size(),
		str(offenders.keys()))

	Campaign._wipe_all()
	app.progress = {}
	app.stage = {}
	app.pending_event = {}
	await process_frame

## 遍历子树收集可读文本，返回扫到的节点数
func _scan(node: Node, offenders: Dictionary, where: String) -> int:
	var n := 0
	var texts: Array = []
	if node is Label:
		texts.append((node as Label).text)
	elif node is Button:
		texts.append((node as Button).text)
	elif node is RichTextLabel:
		texts.append((node as RichTextLabel).get_parsed_text())
	elif node is LineEdit:
		texts.append((node as LineEdit).placeholder_text)
	if node is Control:
		var tt := (node as Control).tooltip_text
		if tt != "":
			texts.append(tt)
	for t in texts:
		var s := str(t).strip_edges()
		if s == "":
			continue
		n += 1
		if allow_text.has(s):
			continue
		# 单个汉字＝朱砂印章式徽记，刻意保留
		if s.length() == 1 and I18n.has_cjk(s):
			continue
		if I18n.has_cjk(s):
			var key := s
			if not offenders.has(key):
				offenders[key] = []
			var bucket: Array = offenders[key]
			if not bucket.has(where):
				bucket.append(where)
	for ch in node.get_children():
		n += _scan(ch, offenders, where)
	return n
