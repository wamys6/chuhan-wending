extends SceneTree
## 图鉴 / 成就 / 战绩测试
##
## 运行：godot --headless --path godot --script res://tests/codex_test.gd
## 重点验两件事：①18 项成就都「真的能达成」（条件写错会导致永远解锁不了）
##               ②战绩累计与存档读写不串味

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
	_run.call_deferred()

func _run() -> void:
	var backup := _read_career_file()
	print("· 空档结构")
	_test_shape()
	print("· 战阵成就")
	_test_battle_achievements()
	print("· 战役成就")
	_test_campaign_achievements()
	print("· 阅历成就")
	_test_career_achievements()
	print("· 战绩累计")
	_test_stats()
	print("· 图鉴筛选")
	_test_filters()
	print("· 存档")
	_test_persist()
	print("· 心魔解锁")
	_test_ascension_unlock()
	print("· 解锁式 meta")
	_test_run_unlocks()
	_restore_career_file(backup)
	print("通过 %d 项，失败 %d 项" % [checks, failures])
	quit(1 if failures > 0 else 0)

# ---------------- 工具 ----------------

func fresh() -> void:
	Codex.reset()
	Codex.ensure_loaded()

## 造一场战斗记录。opts 覆盖默认值（默认是一场普通的满血胜利）
func battle(win: bool = true, opts: Dictionary = {}) -> Dictionary:
	var b := {
		"win": win, "turns": 18, "hp": 12, "maxHp": 30,
		"heroId": "liubang", "level": "bijiang",
		"turns_total": 18,
		"dmg": 30, "heroDmg": 5, "units": 4, "spells": 1,
	}
	for k in opts.keys():
		b[k] = opts[k]
	return b

func unlock_ids(list: Array) -> Array:
	var out: Array = []
	for a in list:
		out.append(str(a["id"]))
	return out

func _read_career_file() -> String:
	if not FileAccess.file_exists(Codex.PATH):
		return ""
	return FileAccess.get_file_as_string(Codex.PATH)

func _restore_career_file(text: String) -> void:
	if text == "":
		if FileAccess.file_exists(Codex.PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Codex.PATH))
		return
	var f := FileAccess.open(Codex.PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	Codex._reset_memory()

# ---------------- 结构 ----------------

func _test_shape() -> void:
	fresh()
	var c := Codex.current()
	ok(Codex.ACHIEVEMENTS.size() == 19, "成就 19 项", str(Codex.ACHIEVEMENTS.size()))
	var ids := {}
	for a in Codex.ACHIEVEMENTS:
		ids[str(a["id"])] = true
		ok(str(a["name"]) != "" and str(a["desc"]) != "", "成就「%s」有名称与说明" % str(a["id"]))
		ok(str(a["glyph"]).length() == 1, "成就「%s」徽记为单字" % str(a["id"]))
		ok(Codex.GROUP_NAMES.has(str(a["group"])), "成就「%s」分组合法" % str(a["id"]))
	ok(ids.size() == 19, "成就 id 唯一")
	for key in ["battles", "wins", "losses", "streak", "bestStreak", "dmg", "ach", "clearedStages", "runWins", "ascensionBest", "finished"]:
		ok(c.has(key), "空档含字段 " + key)
	ok(int(c["battles"]) == 0 and Codex.unlocked_count() == 0, "空档战绩清零")
	ok(int(c["bestHpWin"]) == -1 and int(c["fastestWin"]) == -1, "空档用 -1 表示「暂无」")

# ---------------- 单场成就 ----------------

func _one_battle_unlocks(b: Dictionary) -> Array:
	fresh()
	return unlock_ids(Codex.record_battle(b))

func _test_battle_achievements() -> void:
	var ids := _one_battle_unlocks(battle(true))
	ok(ids.has("first_win"), "首胜解锁「首战告捷」")

	# 满血胜利
	ids = _one_battle_unlocks(battle(true, {"hp": 30, "maxHp": 30}))
	ok(ids.has("flawless"), "满血取胜解锁「全师而归」")
	ids = _one_battle_unlocks(battle(true, {"hp": 29, "maxHp": 30}))
	ok(not ids.has("flawless"), "掉血则不判「全师而归」")

	# 残血翻盘
	ids = _one_battle_unlocks(battle(true, {"hp": 5}))
	ok(ids.has("last_stand"), "5 血取胜解锁「背水一战」")
	ids = _one_battle_unlocks(battle(true, {"hp": 6}))
	ok(not ids.has("last_stand"), "6 血不判「背水一战」")

	# 速攻
	ids = _one_battle_unlocks(battle(true, {"turns": 12}))
	ok(ids.has("swift"), "12 回合取胜解锁「速战速决」")
	ids = _one_battle_unlocks(battle(true, {"turns": 13}))
	ok(not ids.has("swift"), "13 回合不判「速战速决」")
	# 败仗再快也不给
	ids = _one_battle_unlocks(battle(false, {"turns": 8}))
	ok(not ids.has("swift"), "败仗不判速攻")

	# 直取黄龙
	ids = _one_battle_unlocks(battle(true, {"heroDmg": 20}))
	ok(ids.has("decapitate"), "直击主将 20 解锁「直取黄龙」")
	ids = _one_battle_unlocks(battle(true, {"heroDmg": 19}))
	ok(not ids.has("decapitate"), "19 点不判「直取黄龙」")

	# 出兵 / 用计
	ids = _one_battle_unlocks(battle(true, {"units": 10}))
	ok(ids.has("army"), "出兵 10 解锁「兵强马壮」")
	ids = _one_battle_unlocks(battle(true, {"spells": 6}))
	ok(ids.has("strategist"), "用计 6 解锁「运筹帷幄」")

	# 名将难度
	ids = _one_battle_unlocks(battle(true, {"level": "mingjiang"}))
	ok(ids.has("mingjiang"), "名将难度取胜解锁「力敌名将」")
	ids = _one_battle_unlocks(battle(true, {"level": "bijiang"}))
	ok(not ids.has("mingjiang"), "裨将难度不判「力敌名将」")

# ---------------- 战役成就 ----------------

func _test_campaign_achievements() -> void:
	fresh()
	var ids := unlock_ids(Codex.record_clear("peixian", 0, 20, 8))
	ok(ids.has("stage_1"), "首关通关解锁「沛县起兵」")
	ok(int(Codex.current()["clearedCount"]) == 1, "通关计数 1")

	# 重打同一关不累加
	Codex.record_clear("peixian", 0, 20, 8)
	ok(int(Codex.current()["clearedCount"]) == 1, "重打同一关不重复计数")

	# 第 4 关（需 4 个不同关卡，重打不计数）
	unlock_ids(Codex.record_clear("hongmen", 1, 21, 8))
	unlock_ids(Codex.record_clear("pengcheng", 2, 22, 8))
	ids = unlock_ids(Codex.record_clear("xingyang", 3, 22, 8))
	ok(ids.has("stage_4"), "通关 4 关解锁「挺进中原」")
	ok(int(Codex.current()["maxStage"]) == 3, "最深关卡索引 3")
	ok(str(Codex.current()["maxStageId"]) == "xingyang", "最深关卡 id 记录")
	ok(not Codex.is_unlocked("stage_all"), "4 关时未判全通")

	# 全通
	var rest := [["pengcheng", 2], ["hongmen", 1], ["jingxing", 4], ["weishui", 5], ["guling", 6], ["gaixia", 7]]
	for pair in rest:
		ids = unlock_ids(Codex.record_clear(str(pair[0]), int(pair[1]), 30, 8))
	ok(ids.has("stage_all"), "8 关全通解锁「问鼎中原」")
	ok(bool(Codex.current()["finished"]), "全通标记 finished")

	# 牌组规模
	fresh()
	ids = unlock_ids(Codex.record_clear("peixian", 0, 26, 8))
	ok(ids.has("deck_26"), "牌组 26 张解锁「兵多将广」")
	Codex.record_clear("hongmen", 1, 22, 8)
	ok(int(Codex.current()["maxDeck"]) == 26, "最大牌组不被更小的覆盖")

	# 双主将各胜一场
	fresh()
	Codex.record_battle(battle(true, {"heroId": "liubang"}))
	ids = unlock_ids(Codex.record_battle(battle(true, {"heroId": "xiangyu"})))
	ok(ids.has("two_heroes"), "刘邦项羽各胜一场解锁「楚河汉界」")
	fresh()
	Codex.record_battle(battle(true, {"heroId": "liubang"}))
	ok(not Codex.is_unlocked("two_heroes"), "只有一方取胜不解锁")

# ---------------- 阅历成就 ----------------

func _test_career_achievements() -> void:
	fresh()
	var unlocked_at := -1
	for i in 20:
		var got := unlock_ids(Codex.record_battle(battle(true)))
		if got.has("veteran") and unlocked_at < 0:
			unlocked_at = i + 1
	ok(unlocked_at == 20, "第 20 场解锁「百战之将」", str(unlocked_at))
	ok(not Codex.is_unlocked("legend"), "20 场时未达成 50 战")
	for i in 30:
		Codex.record_battle(battle(true))
	ok(Codex.is_unlocked("legend"), "第 50 场解锁「五十战」")
	ok(Codex.is_unlocked("streak_5"), "50 连胜含「五连捷」")
	ok(int(Codex.current()["bestStreak"]) == 50, "最长连胜 50")

	# 连胜中断
	fresh()
	for i in 3:
		Codex.record_battle(battle(true))
	ok(int(Codex.current()["streak"]) == 3, "3 连胜")
	Codex.record_battle(battle(false))
	ok(int(Codex.current()["streak"]) == 0, "败仗清零连胜")
	ok(int(Codex.current()["bestStreak"]) == 3, "最长连胜保留")

	# 累计伤害
	fresh()
	var dmg_hit := -1
	for i in 25:
		var got := unlock_ids(Codex.record_battle(battle(true, {"dmg": 20})))
		if got.has("damage_500") and dmg_hit < 0:
			dmg_hit = (i + 1) * 20
	ok(dmg_hit == 500, "累计 500 伤害解锁「千里杀将」", str(dmg_hit))

	# 军师与事件
	fresh()
	unlock_ids(Codex.record_advisor("zhangliang"))
	unlock_ids(Codex.record_advisor("xiaohe"))
	var ids := unlock_ids(Codex.record_advisor("chenping"))
	ok(ids.has("advisors_3"), "3 位军师解锁「三军之师」")
	ok(int(Codex.current()["advisors"]["zhangliang"]) == 1, "军师使用次数记录")
	unlock_ids(Codex.record_advisor("zhangliang"))
	ok(int(Codex.current()["advisors"]["zhangliang"]) == 2, "重复使用累加次数")

	fresh()
	var ev_ids := ["liumin", "jisi", "qishu", "laozu", "pofu"]
	for e in ev_ids:
		unlock_ids(Codex.record_event(str(e)))
	ids = unlock_ids(Codex.record_event("chuge"))
	ok(ids.has("events_6"), "6 个事件解锁「阅尽行军」")
	ok(Codex.record_event("").is_empty(), "空事件 id 不记录")

# ---------------- 战绩 ----------------

func _test_stats() -> void:
	fresh()
	Codex.record_battle(battle(true, {"turns": 14, "hp": 9, "heroDmg": 7, "units": 5, "spells": 2, "dmg": 40}))
	Codex.record_battle(battle(true, {"turns": 11, "hp": 4}))
	Codex.record_battle(battle(false, {"turns": 20}))
	var s := Codex.summary()
	ok(int(s["battles"]) == 3, "总场次 3")
	ok(int(s["wins"]) == 2 and int(s["losses"]) == 1, "胜负计数正确")
	ok(int(s["winRate"]) == 67, "胜率四舍五入 67%", str(s["winRate"]))
	ok(int(s["fastestWin"]) == 11, "最快取胜取最小值")
	ok(int(s["bestHpWin"]) == 4, "最低血量取胜取最小值")
	ok(int(s["turns"]) == 45, "回合数累加 14+11+20")
	ok(int(s["dmg"]) == 100, "伤害累加 40+30+30", str(s["dmg"]))
	ok(int(s["streak"]) == 0, "败仗后当前连胜归零")
	ok(int(s["bestStreak"]) == 2, "最长连胜 2")

	fresh()
	ok(int(Codex.summary()["winRate"]) == 0, "零场次胜率为 0 不除零")

# ---------------- 图鉴 ----------------

func _test_filters() -> void:
	GameData.ensure_loaded()
	var all := Codex.filter_cards()
	ok(all.size() == 77, "构筑卡池 77 张（78 减去先机虎符）", str(all.size()))

	var pieces := Codex.filter_cards({"type": "piece"})
	var spells := Codex.filter_cards({"type": "spell"})
	ok(pieces.size() + spells.size() == all.size(), "按类型筛选不重不漏")
	ok(pieces.size() > 0 and spells.size() > 0, "兵种与计谋都非空")

	var han := Codex.filter_cards({"faction": "han"})
	var chu := Codex.filter_cards({"faction": "chu"})
	var neutral := Codex.filter_cards({"faction": "neutral"})
	ok(han.size() + chu.size() + neutral.size() == all.size(), "按阵营筛选不重不漏")
	var only_han := true
	for id in han:
		if GameData.faction_of(str(id)) != "han":
			only_han = false
	ok(only_han, "汉军筛选只含汉军牌")

	var stats := Codex.card_stats()
	ok(int(stats["total"]) == 77, "统计总数 77")
	ok(int(stats["byFaction"]["han"]) == han.size(), "统计汉军数量一致")
	ok(int(stats["byType"]["piece"]) == pieces.size(), "统计兵种数量一致")

	# 排序：费用升序，同费兵种在前
	var prev_cost := -1
	var sorted_ok := true
	for id in all:
		var c := GameData.card(str(id))
		if int(c["cost"]) < prev_cost:
			sorted_ok = false
		prev_cost = int(c["cost"])
	ok(sorted_ok, "图鉴按费用升序排列")

# ---------------- 存档 ----------------

func _test_persist() -> void:
	fresh()
	Codex.record_battle(battle(true, {"hp": 7, "heroId": "xiangyu", "level": "mingjiang", "units": 11}))
	Codex.record_clear("peixian", 0, 21, 8)
	Codex.record_advisor("hanxin")
	Codex.record_event("liumin")
	var before := Codex.summary()
	var ach_before := Codex.unlocked_count()
	ok(FileAccess.file_exists(Codex.PATH), "生涯存档已落盘")

	Codex._reset_memory()
	var after := Codex.summary()
	ok(int(after["battles"]) == int(before["battles"]), "重读后场次一致")
	ok(int(after["clearedCount"]) == int(before["clearedCount"]), "重读后通关数一致")
	ok(int(after["advisors"]) == 1, "重读后军师记录一致")
	ok(int(after["events"]) == 1, "重读后事件记录一致")
	ok(Codex.unlocked_count() == ach_before, "重读后成就数量一致")
	ok(Codex.is_unlocked("mingjiang"), "重读后具体成就仍在")

	# 缺字段的老存档也能读
	var f := FileAccess.open(Codex.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"battles": 5, "wins": 3}))
	f.close()
	Codex._reset_memory()
	var partial := Codex.current()
	ok(int(partial["battles"]) == 5, "残缺存档读出已有字段")
	ok(int(partial["losses"]) == 0 and partial.has("ach"), "残缺存档用空值补齐")

	Codex.reset()
	ok(int(Codex.current()["battles"]) == 0, "reset 清空内存战绩")
	ok(not FileAccess.file_exists(Codex.PATH), "reset 删除存档文件")

# ---------------- 心魔解锁 ----------------

## 心魔不是"玩过就算"，必须整轮打通才记成绩；解锁上限 = 已通关等级 + 1
func _test_ascension_unlock() -> void:
	fresh()
	ok(Codex.ascension_unlocked() == 0, "从没通关过时只能打常规", str(Codex.ascension_unlocked()))

	var stages := Campaign.stages()
	# 只打到第 5 关就断了：不算成绩
	for i in 4:
		Codex.record_clear(str(stages[i]["id"]), i, 24, stages.size(), 2)
	ok(Codex.ascension_best() == 0, "中途折戟不记心魔成绩", str(Codex.ascension_best()))
	ok(Codex.ascension_unlocked() == 0, "没通关就不解锁心魔", str(Codex.ascension_unlocked()))

	# 打穿常规
	for i in stages.size():
		Codex.record_clear(str(stages[i]["id"]), i, 27, stages.size(), 0)
	ok(Codex.ascension_best() == 0, "常规通关：最高成绩为 0", str(Codex.ascension_best()))
	ok(Codex.ascension_unlocked() == 1, "常规通关解锁心魔 1", str(Codex.ascension_unlocked()))

	# 打穿心魔 1 → 解锁 2
	for i in stages.size():
		Codex.record_clear(str(stages[i]["id"]), i, 27, stages.size(), 1)
	ok(Codex.ascension_best() == 1, "心魔 1 通关记 1", str(Codex.ascension_best()))
	ok(Codex.ascension_unlocked() == 2, "心魔 1 通关解锁心魔 2", str(Codex.ascension_unlocked()))

	# 打穿心魔 3 → 解锁上限封顶
	for i in stages.size():
		Codex.record_clear(str(stages[i]["id"]), i, 27, stages.size(), 3)
	ok(Codex.ascension_unlocked() == 3, "解锁封顶在心魔 3", str(Codex.ascension_unlocked()))


# ---------------- 解锁式 meta ----------------

## 解锁梯：runWins / ascensionBest 推高梯级，军师与事件分批入场
func _test_run_unlocks() -> void:
	fresh()
	var st := Codex.unlock_state()
	ok(int(st["advisors"].size()) == 4, "初始军师 4 位", str(st["advisors"].size()))
	ok(int(st["events"].size()) == 10, "初始事件 10 个", str(st["events"].size()))
	ok(int(st["level"]) == 0, "梯级 0")
	ok(not ("hanxin" in st["advisors"]), "韩信未解锁")
	ok(not ("dujiang" in st["events"]), "渡河沉舟未解锁")
	ok("pofu" in st["events"], "破釜沉舟在初始池（配平：它是强事件，锁外面会让新玩家难度上浮）")

	var stages := Campaign.stages()
	# 第一轮全通 → 韩信 + 破釜沉舟/渡河沉舟
	for i in stages.size():
		Codex.record_clear(str(stages[i]["id"]), i, 22, stages.size(), 0)
	st = Codex.unlock_state()
	ok(int(Codex.run_wins()) == 1, "整轮通关计 1 次", str(Codex.run_wins()))
	ok(int(st["level"]) == 1, "梯级 1")
	ok("hanxin" in st["advisors"], "韩信入场")
	ok(("dujiang" in st["events"]) and ("qishu" in st["events"]), "两个新事件入场")
	ok(int(st["events"].size()) == 12, "事件池 12", str(st["events"].size()))
	ok(not ("chenping" in st["advisors"]), "陈平还没到")

	# 第二轮全通 → 陈平
	for i in stages.size():
		Codex.record_clear(str(stages[i]["id"]), i, 24, stages.size(), 0)
	st = Codex.unlock_state()
	ok(int(st["level"]) == 2 and "chenping" in st["advisors"], "两次通关解锁陈平")

	# 心魔 1 通关 → 周勃；心魔 2 通关 → 郦食其（全解锁）
	for i in stages.size():
		Codex.record_clear(str(stages[i]["id"]), i, 24, stages.size(), 1)
	st = Codex.unlock_state()
	ok(int(st["level"]) == 3 and "zhoubo" in st["advisors"], "心魔一通关解锁周勃")
	ok(int(st["events"].size()) == 16, "事件池满 16", str(st["events"].size()))
	for i in stages.size():
		Codex.record_clear(str(stages[i]["id"]), i, 24, stages.size(), 2)
	st = Codex.unlock_state()
	ok(int(st["level"]) == 4 and "liyiji" in st["advisors"], "心魔二通关解锁郦食其")
	ok(int(st["advisors"].size()) == 8, "军师全解锁", str(st["advisors"].size()))

	# 梯级内容与数据一致：每一级恰好声明自己的军师与事件
	var ladder := Campaign.unlock_ladder()
	ok(int(ladder.size()) == 4, "解锁梯 4 级")
	var declared := {}
	for u in ladder:
		var aid := str(u.get("advisor", ""))
		if aid != "":
			declared[aid] = true
		for eid in (u.get("events", []) as Array):
			declared[str(eid)] = true
	ok(declared.size() == 4 + 6, "梯级共声明 4 军师 + 6 事件", str(declared.size()))

	# 抽取函数认池：初始池抽不出韩信；池空参数 = 全部
	var rolled := Campaign.roll_advisors(3, st["advisors"])
	ok(int(rolled.size()) == 3, "全解锁可抽 3")
	var base_roll := Campaign.roll_advisors(3, Campaign.base_advisors())
	for a in base_roll:
		ok(str(a["id"]) in Campaign.base_advisors(), "初始池只出初始军师 %s" % str(a["id"]))

	# 事件抽取认池：base 池永远抽不到 pofu
	var prog := Campaign.start_run("liubang", [], "zhangliang", 0, "regular")
	for i in 40:
		var ev := Campaign.pick_event(prog, Campaign.base_events())
		ok(str(ev["id"]) in Campaign.base_events(), "事件只从已解锁池出 %s" % str(ev["id"]))

	# 老存档迁移：通关过但没记次数 → 按 1 次算。
	# 先 reset（删旧档 + 置空内存），再写一份「老格式」档，关缓存标志逼它真读盘
	Codex.reset()
	var f := FileAccess.open(Codex.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "finished": true, "ascensionBest": 1}, "\t"))
	f.close()
	Codex._loaded = false  # 迁移路径必须真的从磁盘重读
	Codex.ensure_loaded()
	ok(int(Codex.run_wins()) == 1, "老存档迁移：finished → runWins 1", str(Codex.run_wins()))
	fresh()
