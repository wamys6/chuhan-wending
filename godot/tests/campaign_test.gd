extends SceneTree
## 战役层逻辑测试：进度 / 存档位 / 规则合并 / 奖励池 / 事件
##
## 运行：godot --headless --path godot --script res://tests/campaign_test.gd
## 与 Web 版 test/campaign.js、test/roguelike.js 的关键断言同口径。

var checks := 0
var failures := 0

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("  ✗ " + label + ("" if detail == "" else "  ← " + detail))

func _initialize() -> void:
	print("== 战役层测试（GDScript） ==")
	Campaign._wipe_all()

	_test_status_flow()
	_test_engine_rules()
	_test_last_stand()
	_test_boosts()
	_test_reward_pool()
	_test_skip_reward()
	_test_events()
	_test_ascension()
	_test_tianshi()
	_test_slots()

	print("通过 %d 项，失败 %d 项" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _test_status_flow() -> void:
	print("· 关卡解锁")
	var stages := Campaign.stages()
	ok(stages.size() == 8, "8 关")
	var p := Campaign.empty_progress("liubang")
	p["deck"] = (GameData.decks.get("han", []) as Array).duplicate()
	ok(Campaign.status_of(p, "peixian") == "open", "首关开放")
	ok(Campaign.status_of(p, "hongmen") == "locked", "第二关锁定")
	ok(Campaign.status_of({}, "peixian") == "locked", "空进度全锁")
	p["cleared"].append("peixian")
	ok(Campaign.status_of(p, "hongmen") == "open", "破沛县后鸿门开放")
	ok(Campaign.status_of(p, "peixian") == "cleared", "已破状态")
	var nxt := Campaign.next_stage(p)
	ok(str(nxt.get("id", "")) == "hongmen", "下一关指向鸿门宴")
	ok(not Campaign.is_finished(p), "未通关")
	for s in stages:
		if not (str(s["id"]) in p["cleared"]):
			p["cleared"].append(str(s["id"]))
	ok(Campaign.is_finished(p), "八关全破即通关")

func _test_engine_rules() -> void:
	print("· 规则合并")
	var p := Campaign.empty_progress("liubang")
	p["advisor"] = "zhangliang"
	p["hpBonus"] = 4
	p["manaBonus"] = 2
	p["drawBonus"] = 1
	p["enemyManaBonus"] = 3
	var hongmen := Campaign.stage_by_id("hongmen")
	var r := Campaign.engine_rules(hongmen, p)
	ok(str(r.get("goal", "")) == "survive", "goal 并入 rules")
	ok(int(r.get("goalTurns", 0)) == 10, "goalTurns 并入")
	ok(int(r.get("handLimit", 0)) == 3, "关卡 handLimit 保留")
	ok(int(r.get("playerHp", 0)) == 12, "关卡 playerHp 保留")
	ok(int(r.get("playerHpBonus", 0)) == 4, "hpBonus → playerHpBonus")
	ok(int(r.get("playerStartMana", 0)) == 2, "manaBonus 加进 playerStartMana")
	ok(int(r.get("openingDraw", 0)) == 1, "drawBonus 加进 openingDraw")
	ok(int(r.get("enemyStartMana", 0)) == 4, "enemyManaBonus 加进 enemyStartMana（含全局 +1 难度）")
	ok(str(r.get("advisor", "")) == "zhangliang", "军师并入")
	# 荥阳自带 playerStartMana 2，再叠 manaBonus 2 → 4
	p["manaBonus"] = 2
	var xy := Campaign.engine_rules(Campaign.stage_by_id("xingyang"), p)
	ok(int(xy.get("playerStartMana", 0)) == 4, "关卡军粮与事件军粮叠加")

func _test_last_stand() -> void:
	print("· 死战专精")
	# 比例口径：死战牌占牌组 20% / 25% / 30% 三档，幅度 0/+1、+1/+1、+2/+2。
	# 用 n_shi5（士·骸骨，带死战）与 n_bing1（兵·新卒，不带）拼出精确比例。
	var d100: Array = []
	for i in 6:
		d100.append("n_shi5")
	ok(Campaign.last_stand_tier(d100) == 3, "100% → 第三档")
	ok(Campaign.last_stand_bonus(d100) == [2, 2], "第三档幅度 +2/+2")

	var d25: Array = ["n_shi5", "n_shi5", "n_shi5", "n_shi5", "n_shi5", "n_shi5", "n_shi5"]
	for i in 21:
		d25.append("n_bing1")               # 7 / 28 = 25.0%
	ok(Campaign.last_stand_tier(d25) == 2, "25% → 第二档")
	ok(Campaign.last_stand_bonus(d25) == [1, 1], "第二档幅度 +1/+1")

	var d21: Array = ["n_shi5", "n_shi5", "n_shi5", "n_shi5", "n_shi5", "n_shi5"]
	for i in 22:
		d21.append("n_bing1")               # 6 / 28 = 21.4%
	ok(Campaign.last_stand_tier(d21) == 1, "21% → 第一档")
	ok(Campaign.last_stand_bonus(d21) == [0, 1], "第一档只给血")

	var d17: Array = ["n_shi5", "n_shi5", "n_shi5", "n_shi5", "n_shi5"]
	for i in 23:
		d17.append("n_bing1")               # 5 / 28 = 17.9%
	ok(Campaign.last_stand_tier(d17) == 0, "18% → 未达标")
	ok(Campaign.last_stand_bonus(d17) == [0, 0], "未达标无加成")

	# 比例而非张数：同样的 6 张死战，牌组越大档位越低
	var small: Array = ["n_shi5", "n_shi5", "n_shi5", "n_shi5", "n_shi5", "n_shi5"]
	var big: Array = small.duplicate()
	for i in 14:
		big.append("n_bing1")               # 6 / 20 = 30%
	ok(Campaign.last_stand_tier(small) == 3 and Campaign.last_stand_tier(big) == 3,
		"6 张在 6 张牌组与 20 张牌组都是 30%")
	var thin: Array = small.duplicate()
	for i in 8:
		thin.append("n_bing1")              # 6 / 14 = 43%，仍第三档（比例足够）
	ok(Campaign.last_stand_tier(thin) == 3, "牌组变小不会掉档")

	# 注入 rules：引擎只认这两个数字
	var p := Campaign.empty_progress("liubang")
	p["deck"] = d25
	var r := Campaign.engine_rules(Campaign.stage_by_id("peixian"), p)
	ok(int(r.get("lastStandAtk", -1)) == 1, "lastStandAtk 注入 rules")
	ok(int(r.get("lastStandHp", -1)) == 1, "lastStandHp 注入 rules")
	ok(int(r.get("lastStandTier", -1)) == 2, "lastStandTier 同时给出（界面用）")


func _test_boosts() -> void:
	print("· 一次性加成")
	var p := Campaign.empty_progress("liubang")
	p["deck"] = ["n_bing1"]
	p["hpBonus"] = 3
	p["manaBonus"] = 2
	p["drawBonus"] = 1
	p["enemyManaBonus"] = 1
	Campaign.use_slot(0)
	Campaign._wipe_all()
	Campaign.save_slot(0, p)
	Campaign.consume_boosts(p)
	ok(int(p["manaBonus"]) == 0 and int(p["drawBonus"]) == 0 and int(p["enemyManaBonus"]) == 0,
		"用完即清三项临时加成")
	ok(int(p["hpBonus"]) == 3, "生命上限是永久加成，不清")
	var disk := Campaign.load_slot(0)
	ok(int(disk["hpBonus"]) == 3 and int(disk["manaBonus"]) == 0, "清零已落盘")

func _test_reward_pool() -> void:
	print("· 奖励池")
	var p := Campaign.empty_progress("liubang")
	p["deck"] = (GameData.decks.get("han", []) as Array).duplicate()
	var peixian := Campaign.stage_by_id("peixian")
	# 沛县 tier=1：只给 ≤2 费（特色牌除外）
	var pool := Campaign.reward_pool(peixian, "han", p["deck"])
	var tier_ok := true
	var faction_ok := true
	for id in pool:
		var c: Dictionary = GameData.card(str(id))
		if Campaign.rarity_of(c) > 1 and not (str(id) in peixian.get("rewards", [])):
			tier_ok = false
		if GameData.faction_of(str(id)) == "chu":
			faction_ok = false
	ok(tier_ok, "低关卡不出高稀有度（特色牌豁免）")
	ok(faction_ok, "汉营不出楚牌")
	# 上面那条只有在阵营表真的加载时才有效——2026-11-04 发现 game.json 漏导 faction，
	# faction_of() 全返回 neutral，于是「汉营不出楚牌」永远通过（假绿），
	# 而 Godot 版奖励池一直在给玩家发楚牌。这条守卫把"表是空的"变成红灯。
	ok(GameData.faction_of("c_xiangzhuang") == "chu" and GameData.faction_of("h_caocan") == "han",
		"阵营映射已加载（漏导会让所有卡变中立）",
		"%s / %s" % [GameData.faction_of("c_xiangzhuang"), GameData.faction_of("h_caocan")])
	ok(GameData.faction_of("n_bing1") == "neutral", "中立牌仍是中立")
	ok(pool.size() >= 5, "池子非空（%d 张）" % pool.size())
	# 同名 ≤2：把两张兵·锐士塞进牌组，兵·锐士应从池里消失
	var p2: Dictionary = p.duplicate(true)
	p2["deck"] = p["deck"] + ["n_bing2", "n_bing2"]
	var pool2 := Campaign.reward_pool(peixian, "han", p2["deck"])
	ok(not ("n_bing2" in pool2), "已有两张的牌不再进池")
	# 抽 3 张：互不重复
	var rolled := Campaign.roll_rewards(peixian, "han", 3, p["deck"])
	ok(rolled.size() == 3, "抽出 3 张")
	var uniq := {}
	for id in rolled:
		uniq[str(id)] = true
	ok(uniq.size() == 3, "三张互不重复")
	# 高关卡 tier=3 能出史诗
	var gaixia := Campaign.stage_by_id("gaixia")
	var pool3 := Campaign.reward_pool(gaixia, "han", p["deck"])
	var has_epic := false
	for id in pool3:
		if Campaign.rarity_of(GameData.card(str(id))) == 3:
			has_epic = true
	ok(has_epic, "垓下池子里有史诗牌")

	# ---- 连击牌：后置到第 4 关 + 构筑引导（P2）----
	# 两个规则都是「不做就会悄悄失效」的类型：后置写错会让 1 费连击牌挤进第 1 关池子，
	# 引导写错则玩家永远凑不出连击流（实测八关只拿得到 1~2 张）。
	var combo_n := 0
	for id in GameData.cards.keys():
		var cc: Dictionary = GameData.card(str(id))
		if cc.get("combo", null) != null:
			combo_n += 1
	ok(combo_n == 9, "全池 9 张连击牌（汉 8 + 楚项庄）", str(combo_n))
	var early_combo := false
	for id in pool:
		var ec: Dictionary = GameData.card(str(id))
		if ec.get("combo", null) != null:
			early_combo = true
	ok(not early_combo, "第 1 关池子里没有连击牌（已后置到第 4 关）")
	var late_combo := 0
	for id in pool3:
		var lc: Dictionary = GameData.card(str(id))
		if lc.get("combo", null) != null:
			late_combo += 1
	ok(late_combo == 8, "第 4 关起汉营池子里 8 张连击牌都在", str(late_combo))

	var deck_combo: Array = (p["deck"] as Array).duplicate()
	deck_combo.append("h_zhiji")
	deck_combo.append("s_lianhuan")
	var hit_plain := 0
	var hit_combo := 0
	for i in 200:
		for id in Campaign.roll_rewards(gaixia, "han", 3, p["deck"]):
			if (GameData.card(str(id)) as Dictionary).get("combo", null) != null:
				hit_plain += 1
				break
		for id in Campaign.roll_rewards(gaixia, "han", 3, deck_combo):
			if (GameData.card(str(id)) as Dictionary).get("combo", null) != null:
				hit_combo += 1
				break
	ok(hit_combo >= hit_plain + 20,
		"构筑引导提高连击牌出现率（有 %d / 无 %d，共 200 次）" % [hit_combo, hit_plain])

## 奖励页的次要选项：不取牌，改为从牌组删一张
func _test_skip_reward() -> void:
	print("· 不取牌改删一张")
	Campaign.use_slot(0)
	Campaign._wipe_all()
	var p := Campaign.start_run("liubang",
		(GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	var before: int = (p["deck"] as Array).size()
	var victim := str((p["deck"] as Array)[0])

	Campaign.clear_stage(p, "peixian", "")
	ok((p["deck"] as Array).size() == before, "不取牌时牌组张数不变",
		str((p["deck"] as Array).size()))
	ok("peixian" in (p.get("cleared", []) as Array), "不取牌也算通关")

	ok(Campaign.can_remove_card(p), "牌组可删（%d 张）" % before)
	ok(Campaign.remove_card(p, victim), "删掉一张成功")
	ok((p["deck"] as Array).size() == before - 1, "牌组少一张",
		str((p["deck"] as Array).size()))
	var reload := Campaign.load_slot(Campaign.active_slot())
	ok((reload["deck"] as Array).size() == before - 1, "删牌已落盘",
		str((reload["deck"] as Array).size()))
	ok(not Campaign.remove_card(p, "s_not_a_card"), "删不存在的牌返回 false")

	# 下限：一直删到 MIN_DECK 就必须停手
	var guard := 0
	while Campaign.can_remove_card(p) and guard < 60:
		Campaign.remove_card(p, str((p["deck"] as Array)[0]))
		guard += 1
	ok((p["deck"] as Array).size() == Campaign.MIN_DECK, "删到下限 %d 张停手" % Campaign.MIN_DECK,
		str((p["deck"] as Array).size()))
	ok(not Campaign.can_remove_card(p), "到下限后不再允许删")
	ok(not Campaign.remove_card(p, str((p["deck"] as Array)[0])),
		"到下限后 remove_card 返回 false")

func _test_events() -> void:
	print("· 行军事件")
	Campaign.use_slot(0)
	Campaign._wipe_all()
	var p := Campaign.start_run("liubang", (GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	var ev := Campaign.event_by_id("liumin")
	ok(not ev.is_empty(), "事件存在")
	# 开仓赈济：hp +3
	var res := Campaign.apply_event(p, "liumin", 0)
	ok(bool(res.get("ok", false)), "结算成功")
	ok(int(p["hpBonus"]) == 3, "生命上限 +3")
	ok(p["events"].size() == 1 and str(p["events"][0]) == "liumin", "事件已记录")
	ok((p["eventLog"] as Array).size() == 1, "行军记有日志")
	# 重复结算同一事件：不再重复记录
	Campaign.apply_event(p, "liumin", 1)
	ok((p["events"] as Array).size() == 1, "同事件不重复记录")
	# 编入行伍：得一张随机兵种牌
	var before := (p["deck"] as Array).size()
	Campaign.apply_event(p, "liumin", 1)
	# 编入行伍 fx.card=piece 需 UI 层调 grant_random_piece，这里直接测发牌函数
	Campaign.grant_random_piece(p)
	ok((p["deck"] as Array).size() == before + 1, "随机兵种牌入组")
	var added: String = str(p["deck"][p["deck"].size() - 1])
	ok(GameData.card(added)["type"] == "piece" and GameData.faction_of(added) != "chu",
		"发的是中立/汉营兵种牌")
	# 疫病：选项 0 删 1 张牌；选项 1 扣血 3（压到下限 -8）
	p["hpBonus"] = -7
	var plague := Campaign.event_by_id("yiqing")
	ok(not plague.is_empty(), "疫病事件存在")
	var deck_before := (p["deck"] as Array).size()
	Campaign.apply_event(p, "yiqing", 0)
	ok((p["deck"] as Array).size() == deck_before - 1, "隔离病卒：随机删 1 张")
	Campaign.apply_event(p, "yiqing", 1)
	ok(int(p["hpBonus"]) == -8, "倾力救治：血线触底 -8（实际 %d）" % int(p["hpBonus"]))
	# needs_event：最后一关不需要事件
	ok(not Campaign.needs_event(p, Campaign.stage_by_id("gaixia")), "垓下后无事件")
	ok(Campaign.needs_event(p, Campaign.stage_by_id("peixian")), "沛县后有事件")

	_test_events_batch2()

## 第二批事件（2026-11-03，10 → 16）：数据自检 + 得牌/删牌通路
##
## 为什么单独一节：这 6 个事件引入了四条以前没用过的轴（mana +3 / draw +2 /
## draw 负值 / enemyMana 正值 / cardCount 3），任何一条没接上都不会崩，
## 只会「选了没反应」——只有逐条断言能抓住。
func _test_events_batch2() -> void:
	print("· 行军事件（第二批）")
	var all_events := GameData.events
	ok(all_events.size() == 16, "事件 16 个", str(all_events.size()))
	var fx_keys := ["hp", "mana", "draw", "enemyMana", "card", "cardCount",
		"remove", "removeRandom"]
	var ids := {}
	var bad_key := ""
	var short_opt := ""
	for e in all_events:
		var eid := str(e["id"])
		ids[eid] = true
		if (e.get("options", []) as Array).size() < 2:
			short_opt = eid
		if str(e.get("glyph", "")).length() != 1:
			bad_key = eid + ".glyph"
		for o in e.get("options", []):
			for k in (o.get("fx", {}) as Dictionary).keys():
				if not (str(k) in fx_keys):
					bad_key = "%s.%s" % [eid, str(k)]
	ok(ids.size() == 16, "事件 id 唯一", str(ids.size()))
	ok(bad_key == "", "事件字段合法（fx 键 / 单字 glyph）", bad_key)
	ok(short_opt == "", "每个事件至少两个选项", short_opt)
	ok(not Campaign.event_by_id("honggou").is_empty(), "新事件 honggou 可查")

	# 得牌候选：牌类过滤 + 张数×3
	Campaign.use_slot(0)
	var p := Campaign.start_run("liubang",
		(GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	var spell_ids := Campaign.event_candidates(p, {"card": "spell"})
	ok(spell_ids.size() == 3, "计谋事件给 3 张候选", str(spell_ids.size()))
	var all_spell := true
	for id in spell_ids:
		if str((GameData.card(str(id)) as Dictionary)["type"]) != "spell":
			all_spell = false
	ok(all_spell, "候选全是计谋牌", str(spell_ids))
	var two := Campaign.event_candidates(p, {"card": "any", "cardCount": 2})
	ok(two.size() == 6, "两张牌的事件给 6 张候选", str(two.size()))
	var piece_ids := Campaign.event_candidates(p, {"card": "piece"})
	var all_piece := true
	for id in piece_ids:
		if str((GameData.card(str(id)) as Dictionary)["type"]) != "piece":
			all_piece = false
	ok(all_piece, "兵种事件候选全是兵种牌", str(piece_ids))

	# 入组 / 删牌：下限保护
	var n0 := (p["deck"] as Array).size()
	ok(Campaign.add_card(p, str(p["deck"][0])), "add_card 成功")
	ok((p["deck"] as Array).size() == n0 + 1, "牌组 +1")
	ok(not Campaign.add_card(p, "no_such_card"), "非法牌 id 被拒")
	while (p["deck"] as Array).size() > Campaign.MIN_DECK:
		Campaign.remove_card(p, str(p["deck"][0]))
	ok((p["deck"] as Array).size() == Campaign.MIN_DECK, "可以删到下限")
	ok(not Campaign.remove_card(p, str(p["deck"][0])), "牌组到下限后拒绝删牌")

	# 一次性加成能不能真的进 rules（负 draw 与正 enemyMana 都是第一次出现）
	var s := Campaign.empty_progress("liubang")
	s["deck"] = (GameData.decks.get("han", []) as Array).duplicate()
	Campaign.apply_event(s, "shibing", 0)          # 生命上限 +3，起手少摸一张
	ok(int(s["hpBonus"]) == 3, "许诺还乡：生命上限 +3")
	var r_neg := Campaign.engine_rules(Campaign.stage_by_id("peixian"), s)
	ok(int(r_neg.get("openingDraw", 0)) == -1, "许诺还乡：openingDraw -1 真的进 rules",
		str(r_neg.get("openingDraw")))
	var w := Campaign.empty_progress("liubang")
	w["deck"] = (GameData.decks.get("han", []) as Array).duplicate()
	var base_enemy := int(Campaign.engine_rules(Campaign.stage_by_id("peixian"), w)
		.get("enemyStartMana", 0))
	Campaign.apply_event(w, "dujiang", 1)          # 起手多摸两张，敌军 +1 军粮
	var r_pos := Campaign.engine_rules(Campaign.stage_by_id("peixian"), w)
	ok(int(r_pos.get("openingDraw", 0)) == 2, "渡河等水：起手多摸两张")
	# 关卡的 GLOBAL_ENEMY_MANA 基线也在 enemyStartMana 里，所以比差值不比绝对值
	ok(int(r_pos.get("enemyStartMana", 0)) == base_enemy + 1, "渡河等水：敌军首回合 +1 军粮",
		"%d vs 基线 %d" % [int(r_pos.get("enemyStartMana", 0)), base_enemy])
	Campaign.consume_boosts(w)
	ok(int(w["drawBonus"]) == 0 and int(w["enemyManaBonus"]) == 0, "一次性加成战后清零")
	Campaign._wipe_all()

func _test_ascension() -> void:
	print("· 心魔")
	var levels := Campaign.ascension_levels()
	ok(levels.size() == 3, "心魔 3 级", str(levels.size()))
	ok(Campaign.ascension_max() == 3, "上限 3")
	ok(Campaign.ascension_mods(0).is_empty(), "常规难度没有任何修正")
	var m1 := Campaign.ascension_mods(1)
	ok(int(m1.get("playerHpBonus", 0)) == -3, "1 级：主将生命上限 -3", str(m1))
	var m2 := Campaign.ascension_mods(2)
	ok(int(m2.get("playerHpBonus", 0)) == -3 and int(m2.get("openingDraw", 0)) == -1,
		"2 级：累计生命 -3 且起手 -1 张", str(m2))
	var m3 := Campaign.ascension_mods(3)
	ok(int(m3.get("enemyStartMana", 0)) == 1 and int(m3.get("openingDraw", 0)) == -1,
		"3 级：再叠敌方首回合 +1 粮", str(m3))
	ok(Campaign.ascension_mods(99) == m3, "越界按最高级算")

	# 并进引擎规则：生命上限扣、起手扣、敌方军粮加
	var p := Campaign.empty_progress("liubang")
	p["ascension"] = 3
	var stage := Campaign.stage_by_id("peixian")
	var r := Campaign.engine_rules(stage, p)
	ok(int(r.get("playerHpBonus", 0)) == -3, "规则里带上主将生命扣减", str(r.get("playerHpBonus", 0)))
	ok(int(r.get("openingDraw", 0)) == -1, "规则里带上起手 -1 张", str(r.get("openingDraw", 0)))
	ok(int(r.get("enemyStartMana", 0)) == 2, "规则里带上敌方首回合 +1 粮（含全局 +1 难度）", str(r.get("enemyStartMana", 0)))

	# 与事件加成叠加（生命上限是同一字段，必须相加而不是覆盖）
	p["hpBonus"] = -2
	var r2 := Campaign.engine_rules(stage, p)
	ok(int(r2.get("playerHpBonus", 0)) == -5, "心魔与行军事件的生命加成相加", str(r2.get("playerHpBonus", 0)))

	# 老存档：没有 ascension 字段时要按常规难度兜底
	var old := Campaign.normalize({"cleared": [], "deck": []})
	ok(int(old.get("ascension", -1)) == 0, "老存档默认常规难度")
	ok(str(old.get("tianShi", "x")) == "", "老存档默认无天时")

func _test_tianshi() -> void:
	print("· 天时")
	ok(Campaign.tian_shi_list().size() == 6, "天时 6 种", str(Campaign.tian_shi_list().size()))
	var seen := {}
	var p := Campaign.empty_progress("liubang")
	p["deck"] = (GameData.decks.get("han", []) as Array).duplicate()
	for i in 40:
		var run := Campaign.start_run("liubang", p["deck"], "zhangliang", 0)
		var id := str(run.get("tianShi", ""))
		ok(id != "", "开局必抽到一个天时", "第 %d 次" % i)
		seen[id] = true
	ok(seen.size() >= 3, "随机抽到多个不同天时（%d 种）" % seen.size(), str(seen.keys()))
	# 天时的修正要真的进规则
	var q := Campaign.empty_progress("liubang")
	q["tianShi"] = "lihuo"
	var r := Campaign.engine_rules(Campaign.stage_by_id("peixian"), q)
	ok(int(r.get("playerHpBonus", 0)) == -4, "离火：生命上限 -4", str(r.get("playerHpBonus", 0)))
	q["tianShi"] = "qingfeng"
	var r2 := Campaign.engine_rules(Campaign.stage_by_id("peixian"), q)
	ok(int(r2.get("playerStartMana", 0)) >= 1, "清风：首回合多 1 粮",
		str(r2.get("playerStartMana", 0)))
	# 天时与心魔叠加
	q["ascension"] = 1
	var r3 := Campaign.engine_rules(Campaign.stage_by_id("peixian"), q)
	ok(int(r3.get("playerHpBonus", 0)) == -3, "心魔 1 叠在清风的军粮上，互不干扰",
		str(r3))

func _test_slots() -> void:
	print("· 存档位")
	Campaign._wipe_all()
	Campaign.use_slot(1)
	var p := Campaign.start_run("liubang", (GameData.decks.get("han", []) as Array).duplicate(), "xiaohe")
	p["cleared"].append("peixian")
	Campaign.save_slot(1, p)
	ok(Campaign.active_slot() == 1, "当前位 = 1")
	var s1 := Campaign.slot_summary(1)
	ok(not bool(s1["empty"]), "1 号位非空")
	ok(str(s1["hero"]) == "刘邦", "摘要带主将名")
	ok(int(s1["cleared"]) == 1, "摘要带进度")
	ok(str(s1["advisor"]) == "萧何", "摘要带军师")
	ok(bool(s1["active"]), "摘要标当前位")
	var s0 := Campaign.slot_summary(0)
	ok(bool(s0["empty"]), "0 号位仍为空")
	# 换位互不干扰
	Campaign.use_slot(2)
	var q := Campaign.start_run("liubang", (GameData.decks.get("han", []) as Array).duplicate(), "")
	ok((q["deck"] as Array).size() == 20 and (q["cleared"] as Array).is_empty(), "2 号位全新进度")
	Campaign.use_slot(1)
	var back := Campaign.load_slot(1)
	ok((back["cleared"] as Array).size() == 1, "切回 1 号位进度仍在")
	# 清空
	Campaign.clear_slot(1)
	ok(bool(Campaign.slot_summary(1)["empty"]), "清空生效")
	Campaign.use_slot(0)
	Campaign._wipe_all()
