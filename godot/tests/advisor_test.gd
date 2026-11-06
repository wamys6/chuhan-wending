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
	print("· 军师主动技（每场 1 次）")
	_test_active()
	print("· 主动技文案与数值一致")
	_test_active_text_numbers()
	print("· AI 认得每一种主动技")
	_test_ai_covers_all_fx()

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
	# 张良是同类坑的第二例：返还力被砍到 0，文案却还写着「并返还 1 点军粮」，
	# 玩家照着文案规划费用会亏。判据由常量生成——返粮 > 0 就必须写数额，= 0 就必须不提军粮。
	var zl_desc := str(GameData.advisor_by_id("zhangliang").get("desc", ""))
	ok(zl_desc.contains("额外抽一张牌"), "张良文案写明抽牌", zl_desc)
	if RulesEngine.ADV_ZHANGLIANG_REFUND > 0:
		ok(zl_desc.contains("返还 %d 点军粮" % RulesEngine.ADV_ZHANGLIANG_REFUND),
			"张良文案返还数额与 ADV_ZHANGLIANG_REFUND 一致", zl_desc)
	else:
		ok(not zl_desc.contains("军粮"),
			"张良已不返粮，文案不得再提军粮", zl_desc)

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


# ---------------- 军师主动技（P6，每场 1 次） ----------------

## 建一局带「主动技定义」的战斗——真实对局里这份定义由 Campaign.engine_rules 注入
func _adv_state(advisor_id: String) -> Dictionary:
	var st := RulesEngine.new_game("liubang", "xiangyu", "p1", "bijiang", null,
		{"rules": {"advisor": advisor_id}})
	var adv := GameData.advisor_by_id(advisor_id)
	if adv.has("active"):
		st["rules"]["advisorActive"] = (adv["active"] as Dictionary).duplicate(true)
	st["players"]["p1"]["mana"] = 10
	st["players"]["p1"]["maxMana"] = 10
	return st


func _put(st: Dictionary, side: String, rank: String, base: String,
		atk: int = -1, hp: int = -1) -> Dictionary:
	var u := RulesEngine.new_instance(base)
	if atk >= 0:
		u["atk"] = atk
	if hp >= 0:
		u["hp"] = hp
		u["maxHp"] = hp
	u["canAttack"] = false
	st["players"][side]["board"][rank].append(u)
	return u


func _test_active() -> void:
	# ① 数据齐全：8 位都要有 name/cost/desc/fx，中英都要有
	for adv in GameData.advisors:
		var id := str(adv.get("id", ""))
		ok(adv.has("active"), "%s：配了主动技" % id)
		var a: Dictionary = adv.get("active", {})
		ok(str(a.get("name", "")) != "" and str(a.get("desc", "")) != "",
			"%s：主动技有名有述" % id)
		ok(int(a.get("cost", 0)) >= 1, "%s：主动技有费用" % id)
		ok(a.get("fx", {}) is Dictionary and not (a.get("fx", {}) as Dictionary).is_empty(),
			"%s：主动技有效果" % id)
	I18n.set_lang_soft("en")
	for adv in GameData.advisors:
		var id := str(adv.get("id", ""))
		var an := str((adv.get("active", {}) as Dictionary).get("name", ""))
		ok(an != "" and not I18n.has_cjk(an), "%s：英文主动技名" % id, an)
	I18n.set_lang_soft("zh")

	# ② 门槛：无军师 / 军粮不足 / 用过 / 敌方 都不行
	var none_st := RulesEngine.new_game("liubang", "xiangyu", "p1", "bijiang", null, {"rules": {}})
	none_st["players"]["p1"]["mana"] = 10
	ok(not RulesEngine.can_advisor_active(none_st, "p1"), "无军师：没有主动技")

	var st := _adv_state("zhoubo")
	st["players"]["p1"]["mana"] = 0
	ok(not RulesEngine.can_advisor_active(st, "p1"), "军粮不足：不可发动")
	ok(not RulesEngine.can_advisor_active(st, "p2"), "军师技不给敌方")
	st["players"]["p1"]["mana"] = 10
	_put(st, "p1", "front", "n_bing1")
	ok(RulesEngine.can_advisor_active(st, "p1"), "条件齐备：可发动")
	var cost := int((GameData.advisor_by_id("zhoubo")["active"] as Dictionary)["cost"])
	var mana_before := int(st["players"]["p1"]["mana"])
	var r := RulesEngine.use_advisor_active(st, "p1")
	ok(bool(r["ok"]), "发动成功")
	ok(int(st["players"]["p1"]["mana"]) == mana_before - cost, "扣费 = 主动技费用")
	ok(not RulesEngine.can_advisor_active(st, "p1"), "同一场不能二次发动")

	# ③ 逐个效果
	# 张良·献策：抽 2
	st = _adv_state("zhangliang")
	var hand_before: int = (st["players"]["p1"]["hand"] as Array).size()
	RulesEngine.use_advisor_active(st, "p1")
	ok((st["players"]["p1"]["hand"] as Array).size() == hand_before + 2, "张良：抽两张")

	# 萧何·转输：主将 +2，不超上限
	st = _adv_state("xiaohe")
	st["players"]["p1"]["hp"] = int(st["players"]["p1"]["maxHp"]) - 1
	RulesEngine.use_advisor_active(st, "p1")
	ok(int(st["players"]["p1"]["hp"]) == int(st["players"]["p1"]["maxHp"]), "萧何：回血且封顶")

	# 韩信·点兵：只加前锋
	st = _adv_state("hanxin")
	var fr := _put(st, "p1", "front", "n_bing1", 1, 2)
	var md := _put(st, "p1", "mid", "n_bing1", 1, 2)
	RulesEngine.use_advisor_active(st, "p1")
	ok(int(fr["atk"]) == 2, "韩信：前锋 +1 攻")
	ok(int(md["atk"]) == 1, "韩信：中军不动")

	# 樊哙·冲阵：全体 +1
	st = _adv_state("fankuai")
	var a1 := _put(st, "p1", "front", "n_bing1", 1, 2)
	var a2 := _put(st, "p1", "mid", "n_bing1", 1, 2)
	RulesEngine.use_advisor_active(st, "p1")
	ok(int(a1["atk"]) == 2 and int(a2["atk"]) == 2, "樊哙：全体 +1 攻")

	# 夏侯婴·救驾：回 2 血 + 本场死战额外次数 +1
	# （只给 xyCap 时实测差值精确等于 0pp：AI 整轮按下去也换不来任何结果，
	#   不是「技能弱」而是「技能等于没有」。加了回血才真的有人用）
	st = _adv_state("xiangying")
	st["players"]["p1"]["hp"] = int(st["players"]["p1"]["maxHp"]) - 3
	RulesEngine.use_advisor_active(st, "p1")
	ok(int(st["players"]["p1"].get("xyCapBonus", 0)) == 1, "夏侯婴：死战次数上限 +1")
	ok(int(st["players"]["p1"]["hp"]) == int(st["players"]["p1"]["maxHp"]) - 1, "夏侯婴：同时回 2 血")

	# 陈平·反间：削敌方最高攻的血
	st = _adv_state("chenping")
	var big := _put(st, "p2", "front", "n_bing1", 3, 3)
	var small := _put(st, "p2", "mid", "n_bing1", 1, 1)
	RulesEngine.use_advisor_active(st, "p1")
	ok(int(big["hp"]) == 2, "陈平：打的是最高攻")
	ok(int(small["hp"]) == 1, "陈平：小兵不挨打")

	# 周勃·整军：我方全体生命上限 +1（攻不动，当前血量与上限一起加）
	# 单个 +1/+1 实测只有 +0.3pp（4 费换不起一张牌的收益），改成全体加血才立得住
	st = _adv_state("zhoubo")
	var tall := _put(st, "p1", "front", "n_bing1", 2, 2)
	var wide := _put(st, "p1", "mid", "n_bing1", 1, 1)
	var foe := _put(st, "p2", "front", "n_bing1", 1, 2)
	RulesEngine.use_advisor_active(st, "p1")
	ok(int(tall["hp"]) == 3 and int(tall["maxHp"]) == 3, "周勃：我方全体生命上限 +1")
	ok(int(wide["hp"]) == 2 and int(wide["maxHp"]) == 2, "周勃：另一列也加")
	ok(int(tall["atk"]) == 2, "周勃：攻击力不动")
	ok(int(foe["hp"]) == 2, "周勃：敌方不加")

	# 郦食其·说降：削敌方最高攻，不削到负
	st = _adv_state("liyiji")
	var ebig := _put(st, "p2", "front", "n_bing1", 3, 3)
	RulesEngine.use_advisor_active(st, "p1")
	ok(int(ebig["atk"]) == 2, "郦食其：削 1 攻")
	st = _adv_state("liyiji")
	var ezero := _put(st, "p2", "front", "n_dun1", 0, 3)
	RulesEngine.use_advisor_active(st, "p1")
	ok(int(ezero["atk"]) == 0, "郦食其：0 攻不会被削成负数")

	# ④ 战报三键中英都渲染得出来（缺 key 会原样吐 {name}）
	for key in ["adv_active", "buff_highest", "debuff_highest", "buff_all_hp"]:
		var args := {"name": "试兵", "atk": 1, "hp": 1, "n": 1}
		var zh_line := LogText.zh(key, args)
		var en_line := LogText.en(key, args)
		ok(not zh_line.begins_with("{") and not zh_line.contains("{name}"), "%s：中文战报" % key, zh_line)
		ok(not en_line.begins_with("{") and not en_line.contains("{name}"), "%s：英文战报" % key, en_line)


# ---------------- 文案数字 ← 数值（踩坑 42 家族：英文单边写错） ----------------

## 把 fx 里所有数字摊平：[healHero:2, xyCap:1] → [2, 1]，buffHighest{atk,hp} 也摊平
func _fx_numbers(fx: Dictionary) -> Array:
	var out := []
	for k in fx.keys():
		var v = fx[k]
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			out.append(int(v))
		elif v is Dictionary:
			for k2 in (v as Dictionary).keys():
				var v2 = (v as Dictionary)[k2]
				if typeof(v2) == TYPE_INT or typeof(v2) == TYPE_FLOAT:
					out.append(int(v2))
	return out


## 文案里写到的数字：阿拉伯数字 + 中文数字 + 英文数词。
## 中文卡面用「两」，英文爱写 "one more time"——只查阿拉伯数字会漏掉一半。
func _desc_numbers(text: String, english: bool) -> Array:
	var out := []
	var re := RegEx.new()
	re.compile("[0-9]+")
	for m in re.search_all(text):
		out.append(int(m.get_string()))
	var cn := {"一": 1, "两": 2, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6}
	for ch in cn.keys():
		if text.contains(str(ch)):
			out.append(int(cn[ch]))
	if english:
		var en := {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5}
		for w in en.keys():
			if text.to_lower().contains(str(w)):
				out.append(int(en[w]))
	return out


func _test_active_text_numbers() -> void:
	# 文案里出现的每个数字，都必须能在 fx 里找到；反之 fx 里的数不一定写进文案（hp:0 之类）
	for lang in ["zh", "en"]:
		I18n.set_lang_soft(lang)
		for adv in GameData.advisors:
			var id := str(adv.get("id", ""))
			var a: Dictionary = adv.get("active", {})
			var allow := _fx_numbers(a.get("fx", {}))
			var nums := _desc_numbers(str(a.get("desc", "")), lang == "en")
			for n in nums:
				ok(allow.has(int(n)),
					"%s/%s：文案里的 %d 必须来自 fx（fx=%s）" % [id, lang, int(n), str(allow)],
					str(a.get("desc", "")))
	I18n.set_lang_soft("zh")


# ---------------- AI 认得每一种主动技 ----------------

## 一个「所有条件都满足」的局面：血量不满、前锋有兵、有死战兵、敌方也列了阵。
## 只测「AI 会不会按这个按钮」——韩信的点兵曾经因为 ai.js 少一个 buffCol 分支，
## 整轮一次都没被按过，A/B 差值精确等于 0.0pp，看起来像「技能弱」，其实是「没人用」。
func _test_ai_covers_all_fx() -> void:
	# ① 逐个 fx 键单独喂给 AI。只测「整个技能认不认得」会被组合掩盖：
	#    韩信的点兵现在是 {draw, buffCol}，少了 buffCol 分支时 draw 分支照样返回 adv，
	#    测试全绿——本条第一版就是这样假绿的，故意删掉分支验证过。
	var seen := {}
	for adv in GameData.advisors:
		var afx: Dictionary = (adv.get("active", {}) as Dictionary).get("fx", {})
		for k in afx.keys():
			seen[str(k)] = afx[k]
	# 跳过「参数键」：它们是某个效果的入参（buffCol 的 atk、summon 的 rank/baseId），
	# 不是独立效果。想把新效果塞进这张白名单蒙混过去，等于自己承认没接 AI 分支。
	const FX_PARAMS := ["atk", "hp", "count", "rank", "baseId"]
	for k in seen.keys():
		if FX_PARAMS.has(str(k)):
			continue
		var solo := _adv_state("zhoubo")
		solo["rules"]["advisorActive"] = {
			"name": "试", "cost": 1, "desc": "试", "fx": {str(k): seen[k]}
		}
		solo["players"]["p1"]["hp"] = int(solo["players"]["p1"]["maxHp"]) - 3
		_put(solo, "p1", "front", "n_bing5")
		_put(solo, "p1", "mid", "n_bing1")
		_put(solo, "p2", "front", "n_bing1")
		var solo_act = Ai.adv_action(solo, "p1")
		ok(solo_act != null and typeof(solo_act) == TYPE_DICTIONARY,
			"AI 认得单个 fx 键「%s」" % k, str(solo_act))

	# ② 再按真实军师整份定义过一遍（防「单键都对、组合就漏」）
	for adv in GameData.advisors:
		var id := str(adv.get("id", ""))
		var st := _adv_state(id)
		st["players"]["p1"]["hp"] = int(st["players"]["p1"]["maxHp"]) - 3
		_put(st, "p1", "front", "n_bing5")      # 死战兵（夏侯婴的 xyCap 需要）
		_put(st, "p1", "mid", "n_bing1")
		st["players"]["p1"]["board"]["front"][0]["canAttack"] = false
		_put(st, "p2", "front", "n_bing1")
		ok(RulesEngine.can_advisor_active(st, "p1"), "%s：AI 场景可发动" % id)
		var act = Ai.adv_action(st, "p1")
		ok(act != null and typeof(act) == TYPE_DICTIONARY,
			"%s：AI 认得这个主动技（条件齐全时应当出手）" % id, str(act))
