extends SceneTree
## 军师被动回归测试（1.4 军师 6→8 新增两位时的护栏）
##
## 运行：godot --headless --path godot --script res://tests/advisor_test.gd
##
## 为什么单独一支：军师的强度是靠 tune-roguelike 跑通关率调的，但那是**统计**；
## 统计能告诉你「太强了」，不能告诉你「哪一行代码错了」。两位新军师的机制都挂在
## start_turn 上（周勃加、郦食其削），这类「每回合悄悄改数值」的分支一旦写错
## （比如削到敌方不存在的单位、次数上限写成 0、或者顺手把玩家也削了），
## 语法不报错、界面看不出来，只能靠逐条断言钉住。
##
## 盯四件事：
##   ① 周勃：只加我方、只加一个、只加最高攻、上限生效、生命上限同步
##   ② 郦食其：只削敌方、只削一个、削不到负数、零攻时不空耗次数
##   ③ 不越界：别的军师与无军师时数值一点不动
##   ④ 数据与文案：8 位齐全、字段完整、中英战报都有 key

var checks := 0
var failures := 0

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("  ✗ " + label + ("" if detail == "" else "  ← " + detail))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameData.ensure_loaded()
	I18n.ensure_loaded()

	print("· 周勃：成长")
	_test_zhoubo()
	print("· 郦食其：控场")
	_test_liyiji()
	print("· 不越界")
	_test_isolation()
	print("· 数据与文案")
	_test_data_and_text()

	print("\n通过 %d 项，失败 %d 项" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)


## 建一局指定军师的战斗，并往指定方的列里塞单位
func _board(advisor_id: String, spec: Array) -> Dictionary:
	var st := RulesEngine.new_game("liubang", "xiangyu", "p1", "bijiang", null,
		{"rules": {"advisor": advisor_id}})
	for s in spec:
		var u := RulesEngine.new_instance(str(s["base"]))
		u["canAttack"] = false
		st["players"][str(s["side"])]["board"][str(s["rank"])].append(u)
	return st

func _units(st: Dictionary, side: String) -> Array:
	var out: Array = []
	for r in RulesEngine.RANKS:
		for u in st["players"][side]["board"][r]:
			out.append(u)
	return out


func _test_zhoubo() -> void:
	var st := _board("zhoubo", [
		{"base": "n_bing1", "side": "p1", "rank": "front"},   # 1/2
		{"base": "n_shi1", "side": "p1", "rank": "mid"},      # 1/4
	])
	var us := _units(st, "p1")
	var a0 := int(us[0]["atk"])
	var h0 := int(us[0]["hp"])
	var mh0 := int(us[0]["maxHp"])
	var b_atk := int(us[1]["atk"])
	var b_hp := int(us[1]["hp"])

	RulesEngine.start_turn(st, "p1")
	ok(int(us[0]["atk"]) == a0 + RulesEngine.ADV_ZHOUBO_BUFF, "周勃：最高攻单位攻击力 +1",
		"%d → %d" % [a0, int(us[0]["atk"])])
	ok(int(us[0]["hp"]) == h0 + RulesEngine.ADV_ZHOUBO_BUFF, "周勃：同时 +1 血",
		"%d → %d" % [h0, int(us[0]["hp"])])
	ok(int(us[0]["maxHp"]) == mh0 + RulesEngine.ADV_ZHOUBO_BUFF, "周勃：生命上限同步 +1（不是临时血）",
		"%d → %d" % [mh0, int(us[0]["maxHp"])])
	ok(int(us[1]["atk"]) == b_atk and int(us[1]["hp"]) == b_hp, "周勃：只加一个单位，其余不动",
		"%d/%d → %d/%d" % [b_atk, b_hp, int(us[1]["atk"]), int(us[1]["hp"])])
	ok(int(st["players"]["p1"].get("zbBuffs", 0)) == 1, "周勃：计次 1")

	# 上限：cap=1 时第二个回合不再成长
	var a1 := int(us[0]["atk"])
	RulesEngine.start_turn(st, "p1")
	ok(int(us[0]["atk"]) == a1, "周勃：达到上限后不再成长（%d 次/场）" % RulesEngine.ADV_ZHOUBO_CAP,
		"%d → %d" % [a1, int(us[0]["atk"])])
	ok(int(st["players"]["p1"].get("zbBuffs", 0)) == RulesEngine.ADV_ZHOUBO_CAP, "周勃：计次停在 cap")

	# 场上没有部队时不该凭空触发（也不该把次数用掉）
	var empty := _board("zhoubo", [])
	RulesEngine.start_turn(empty, "p1")
	ok(int(empty["players"]["p1"].get("zbBuffs", 0)) == 0, "周勃：场上无兵不空耗次数")


func _test_liyiji() -> void:
	var st := _board("liyiji", [
		{"base": "n_shi1", "side": "p2", "rank": "front"},    # 1 攻
		{"base": "n_ma2", "side": "p2", "rank": "back"},      # 4 攻
	])
	var us := _units(st, "p2")
	var low: Dictionary = us[0]
	var high: Dictionary = us[1]
	var h_atk0 := int(high["atk"])
	var l_atk0 := int(low["atk"])

	RulesEngine.start_turn(st, "p2")
	ok(int(high["atk"]) == h_atk0 - RulesEngine.ADV_LIYIJI_DOWN, "郦食其：敌方最高攻单位 -1 攻",
		"%d → %d" % [h_atk0, int(high["atk"])])
	ok(int(low["atk"]) == l_atk0, "郦食其：只削一个，低攻单位不动",
		"%d → %d" % [l_atk0, int(low["atk"])])
	ok(int(st["players"]["p2"].get("lyCuts", 0)) == 1, "郦食其：计次 1")

	# 上限
	var h1 := int(high["atk"])
	RulesEngine.start_turn(st, "p2")
	RulesEngine.start_turn(st, "p2")
	ok(int(high["atk"]) == h1, "郦食其：达到上限后不再削（%d 次/场）" % RulesEngine.ADV_LIYIJI_CAP,
		"%d → %d" % [h1, int(high["atk"])])

	# 削不到负数：反复削一个 1 攻单位，最终应为 0 而不是负
	var st2 := _board("liyiji", [{"base": "n_bing1", "side": "p2", "rank": "front"}])
	var u2: Dictionary = _units(st2, "p2")[0]
	for i in 5:
		RulesEngine.start_turn(st2, "p2")
	ok(int(u2["atk"]) >= 0, "郦食其：攻击力削不到负数", str(int(u2["atk"])))
	ok(not bool(u2["canAttack"]) or int(u2["atk"]) > 0, "郦食其：削到 0 攻时不能攻击",
		"atk=%d canAttack=%s" % [int(u2["atk"]), str(bool(u2["canAttack"]))])

	# 全是 0 攻时不该空耗次数
	var st3 := _board("liyiji", [{"base": "n_bing1", "side": "p2", "rank": "front"}])
	var u3: Dictionary = _units(st3, "p2")[0]
	u3["atk"] = 0
	RulesEngine.start_turn(st3, "p2")
	ok(int(st3["players"]["p2"].get("lyCuts", 0)) == 0, "郦食其：无处可削时不空耗次数")


func _test_isolation() -> void:
	# 别人的军师不该动数值
	var st := _board("hanxin", [
		{"base": "n_bing1", "side": "p1", "rank": "front"},
		{"base": "n_ma2", "side": "p2", "rank": "back"},
	])
	var mine: Dictionary = _units(st, "p1")[0]
	var foe: Dictionary = _units(st, "p2")[0]
	var ma := int(mine["atk"])
	var mh := int(mine["hp"])
	var fa := int(foe["atk"])
	RulesEngine.start_turn(st, "p1")
	RulesEngine.start_turn(st, "p2")
	ok(int(mine["atk"]) == ma and int(mine["hp"]) == mh, "韩信局：周勃的成长不生效")
	ok(int(foe["atk"]) == fa, "韩信局：郦食其的削减不生效")

	# 周勃不碰敌方，郦食其不碰我方
	var z := _board("zhoubo", [
		{"base": "n_ma2", "side": "p2", "rank": "back"},
	])
	var zf: Dictionary = _units(z, "p2")[0]
	var za := int(zf["atk"])
	var zh := int(zf["hp"])
	RulesEngine.start_turn(z, "p1")
	ok(int(zf["atk"]) == za and int(zf["hp"]) == zh, "周勃：不加强敌方单位")

	var l := _board("liyiji", [
		{"base": "n_ma2", "side": "p1", "rank": "back"},
	])
	var lm: Dictionary = _units(l, "p1")[0]
	var la := int(lm["atk"])
	RulesEngine.start_turn(l, "p2")
	ok(int(lm["atk"]) == la, "郦食其：不削弱我方单位")


func _test_data_and_text() -> void:
	ok(GameData.advisors.size() == 8, "军师共 8 位", str(GameData.advisors.size()))
	var ids := {}
	var missing: Array = []
	for a in GameData.advisors:
		var id := str(a.get("id", ""))
		if ids.has(id):
			missing.append("重复 id " + id)
		ids[id] = true
		for f in ["name", "title", "desc", "glyph", "flavor"]:
			if str(a.get(f, "")) == "":
				missing.append(id + " 缺 " + f)
	ok(missing.is_empty(), "8 位军师字段完整、id 不重复", str(missing))

	ok(ids.has("zhoubo") and ids.has("liyiji"), "周勃与郦食其在池内")
	# 两位新军师必须有立绘位（glyph 单字兜底也要能显示）
	for id in ["zhoubo", "liyiji"]:
		var a: Dictionary = GameData.advisor_by_id(id)
		ok(str(a.get("glyph", "")).length() == 1, "%s：glyph 是单字" % id, str(a.get("glyph", "")))
		ok(str(a.get("desc", "")) != "", "%s：中文描述取得到" % id)

	# 文案里的次数必须与引擎常量同步。周勃/郦食其调档时 cap 从 2/3 砍到 1，
	# 文案却留在「至多两次/三次」——截图看起来毫无异常，玩家读到的是错的规则。
	# 中文数字表够用到四档；以后改 cap 忘了改文案，这条就红。
	var cn := {1: "一", 2: "两", 3: "三", 4: "四"}
	var zb_desc := str(GameData.advisor_by_id("zhoubo").get("desc", ""))
	var ly_desc := str(GameData.advisor_by_id("liyiji").get("desc", ""))
	var xy_desc := str(GameData.advisor_by_id("xiangying").get("desc", ""))
	ok(zb_desc.contains("每场战斗至多%s次" % cn.get(RulesEngine.ADV_ZHOUBO_CAP, "?")),
		"周勃文案次数与 ADV_ZHOUBO_CAP 一致", zb_desc)
	ok(ly_desc.contains("每场战斗至多%s次" % cn.get(RulesEngine.ADV_LIYIJI_CAP, "?")),
		"郦食其文案次数与 ADV_LIYIJI_CAP 一致", ly_desc)
	ok(xy_desc.contains("至多额外发动%s次" % cn.get(RulesEngine.ADV_XIANGYING_CAP, "?")),
		"夏侯婴文案次数与 ADV_XIANGYING_CAP 一致", xy_desc)

	# 英文：advisor_field 只在 EN 模式下取值。注意 apply_data() 会把 GameData.advisors
	# 本身覆盖成英文，所以中文快照必须在切语言**之前**取，否则两边都是英文、断言假绿。
	var zh_descs := {}
	for id in ["zhoubo", "liyiji"]:
		zh_descs[id] = str(GameData.advisor_by_id(id).get("desc", ""))
	var orig_lang := I18n.lang
	I18n.set_lang_soft("en")
	for id in ["zhoubo", "liyiji"]:
		var en := I18n.advisor_field(id, "desc")
		ok(en != "" and en != zh_descs[id], "%s：英文描述是独立文案" % id, en.substr(0, 40))
	# 英文也钉一次：只改中文、忘了英文，EN 玩家看到的还是旧次数
	var en_words := {1: "once", 2: "twice", 3: "three times", 4: "four times"}
	for pair in [["zhoubo", RulesEngine.ADV_ZHOUBO_CAP], ["liyiji", RulesEngine.ADV_LIYIJI_CAP]]:
		var en_desc := I18n.advisor_field(str(pair[0]), "desc")
		ok(en_desc.contains("at most %s per battle" % en_words.get(int(pair[1]), "?")),
			"%s：英文次数与常量一致" % str(pair[0]), en_desc)
	I18n.set_lang_soft(orig_lang)

	# 战报：两条新 key 中英都有，且能渲染出不含花括号的句子
	for key in ["adv_zhoubo", "adv_liyiji"]:
		var args := {"name": "试兵", "a": 1, "h": 1, "d": 1}
		var zh_line := LogText.zh(key, args)
		var en_line := LogText.en(key, args)
		ok(not zh_line.begins_with("{") and not zh_line.contains("{name}"),
			"%s：中文战报有文案" % key, zh_line)
		ok(not en_line.begins_with("{") and not en_line.contains("{name}"),
			"%s：英文战报有文案" % key, en_line)
