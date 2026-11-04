extends SceneTree
## 卡面关键词小印回归测试
##
## 运行：godot --headless --path godot --script res://tests/keyword_stamp_test.gd
##
## 为什么要有这一支：关键词原本只存在于数据字段里（taunt/deathrattle/charge/…），
## 卡面完全不写，玩家只能靠悬停浮层读描述。1.2 的死战专精按「牌组里死战牌占比」
## 判档，玩家数不出手里有几张死战牌，机制就是隐形的。印补上之后要守住三件事：
##   ① 判据对得上数据（六个字段一个不漏、false / null 不算）
##   ② 印面分类不被改坏（死战朱砂 / 守御墨 / 其余空心）
##   ③ 印不出界、不压费用圆、无关键词的卡不出现空容器

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

	print("· 判据：六个关键词字段")
	_test_detect()
	print("· 顺序与组合")
	_test_order()
	print("· 印面分类与字号")
	_test_face()
	print("· 卡面装配（位置/不出界/不压费用）")
	await _test_mount()
	print("· 全卡池一致性")
	_test_pool()
	print("· 换语言不换字")
	_test_lang()

	print("\n通过 %d 项，失败 %d 项" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)

# ---------------- 判据 ----------------

## 每张假卡只带一个字段，验证「一个字段 → 一枚印、字对得上」
func _test_detect() -> void:
	var cases := [
		[{"deathrattle": {"draw": 1}}, "死"],
		[{"taunt": true}, "守"],
		[{"charge": true}, "冲"],
		[{"flank": true}, "迂"],
		[{"ranged": true}, "远"],
		[{"combo": {"draw": 1}}, "连"],
	]
	for c in cases:
		var got := KeywordStamp.of(c[0])
		ok(got.size() == 1, "%s 字段 → 一枚印" % str(c[0].keys()[0]), str(got.size()))
		if got.size() == 1:
			ok(str(got[0]["zh"]) == str(c[1]), "%s 印面是「%s」" % [str(c[0].keys()[0]), str(c[1])],
				str(got[0]["zh"]))

	# 显式 false / null 都不算关键词——引擎里 taunt 默认 false、deathrattle 默认 null
	ok(KeywordStamp.of({"taunt": false}).is_empty(), "taunt=false 不算关键词")
	ok(KeywordStamp.of({"deathrattle": null}).is_empty(), "deathrattle=null 不算关键词")
	ok(KeywordStamp.of({"combo": null}).is_empty(), "combo=null 不算关键词")
	ok(KeywordStamp.of({}).is_empty(), "空卡不算关键词")
	ok(KeywordStamp.of(new_card()).is_empty(), "普通兵卒（n_bing1）没有印")

	# 假卡：只带 id/name，避免测试被数值改动牵连
func new_card(extra: Dictionary = {}) -> Dictionary:
	var c := {"id": "t", "name": "测试", "type": "piece", "cost": 1, "atk": 1, "hp": 1}
	c.merge(extra, true)
	return c

# ---------------- 顺序与组合 ----------------

func _test_order() -> void:
	# 死战 + 守御：死战在前（构筑判断看的是死战张数，让它离眼睛最近）
	var both := new_card({"deathrattle": {"draw": 1}, "taunt": true})
	var got := KeywordStamp.of(both)
	ok(got.size() == 2, "死战+守御 → 两枚", str(got.size()))
	if got.size() == 2:
		ok(str(got[0]["zh"]) == "死", "死战排在最左", str(got[0]["zh"]))
		ok(str(got[1]["zh"]) == "守", "守御其次", str(got[1]["zh"]))

	if KeywordStamp.of(both).size() == 2:
		var r := KeywordStamp.row(both, 20.0, 3.0)
		ok(r.size == Vector2(43, 20), "两枚宽 20+3+20=43", str(r.size))
		ok(r.get_child_count() == 2, "容器里有两个印节点", str(r.get_child_count()))
		ok(r.get_child(1).position == Vector2(23, 0), "第二枚紧随其后（间距 3）",
			str(r.get_child(1).position))
		r.free()

	# 三枚（卡池里没有，但代码不该假设只有两个）
	var three := new_card({"taunt": true, "charge": true, "ranged": true})
	var r3 := KeywordStamp.row(three, 20.0, 3.0)
	ok(r3.get_child_count() == 3, "三关键词也能排", str(r3.get_child_count()))
	ok(r3.size == Vector2(66, 20), "三枚宽 3×20+2×3=66", str(r3.size))
	r3.free()

	# 空卡：返回空容器而不是 null（调用方直接 add_child，不必判空）
	var empty := KeywordStamp.row({}, 20.0, 3.0)
	ok(empty != null, "无关键词也返回容器（非 null）")
	ok(empty.size == Vector2.ZERO, "无关键词容器尺寸为 0", str(empty.size))
	empty.free()

# ---------------- 印面分类与字号 ----------------

func _test_face() -> void:
	var seal := KeywordStamp.row(new_card({"deathrattle": {"draw": 1}}), 20.0, 3.0)
	var ink := KeywordStamp.row(new_card({"taunt": true}), 20.0, 3.0)
	var indigo := KeywordStamp.row(new_card({"charge": true}), 20.0, 3.0)

	ok(_meta(seal) == "seal", "死战印面是 seal", _meta(seal))
	ok(_meta(ink) == "ink", "守御印面是 ink", _meta(ink))
	ok(_meta(indigo) == "indigo", "冲锋印面是 indigo", _meta(indigo))

	# 朱砂：红通道明显高于绿蓝
	var s_sb := _style(seal)
	var i_sb := _style(ink)
	var i2_sb := _style(indigo)
	ok(s_sb != null and s_sb.bg_color.r > 0.35 and s_sb.bg_color.g < 0.2,
		"死战底是朱砂（不是墨也不是纸）", str(s_sb.bg_color) if s_sb else "null")
	ok(i_sb != null and i_sb.bg_color.get_luminance() < 0.2, "守御底是深墨",
		str(i_sb.bg_color) if i_sb else "null")
	# 三档都必须「深底」：亮底配暗字在 14px 上笔画就糊了（赭石版实测如此）
	for pair in [["朱砂", s_sb], ["墨", i_sb], ["靛", i2_sb]]:
		var sb: StyleBoxFlat = pair[1]
		ok(sb != null and sb.bg_color.get_luminance() < 0.3,
			"%s印是深底（纸白字才压得住）" % str(pair[0]),
			str(sb.bg_color) if sb else "null")
	# 色相要分得开：朱砂偏红、靛偏蓝、墨几乎中性
	ok(s_sb != null and s_sb.bg_color.r - s_sb.bg_color.b > 0.25, "朱砂偏红")
	ok(i2_sb != null and i2_sb.bg_color.b - i2_sb.bg_color.r > 0.15, "靛印偏蓝")
	ok(i_sb != null and absf(i_sb.bg_color.r - i_sb.bg_color.b) < 0.1, "墨印接近中性")
	ok(s_sb != null and s_sb.border_width_left == 0 and i_sb.border_width_left == 0
		and i2_sb.border_width_left == 0, "印面不描边（细框在 14~20px 上会脏）")
	# 三档的字色都是纸白，否则对比度掉到 5:1 以下
	for pair in [["朱砂", seal], ["墨", ink], ["靛", indigo]]:
		ok(_font_color(pair[1]).get_luminance() > 0.8, "%s印配纸白字" % str(pair[0]),
			str(_font_color(pair[1])))

	# 字号随 box 走：手牌 20 → 12、场上 16 → 10
	ok(_font_size(seal) == 12, "20px 印字号 12", str(_font_size(seal)))
	var small := KeywordStamp.row(new_card({"deathrattle": {"draw": 1}}), 16.0, 3.0)
	ok(_font_size(small) == 10, "16px 印字号 10", str(_font_size(small)))
	# 印是方的：圆角只能磨角，不能磨成现代 UI 的圆角卡片（≤边长的 15%）
	ok(s_sb != null and float(s_sb.corner_radius_top_left) <= 20.0 * 0.15,
		"圆角不超过边长 15%（看起来仍是一枚方印）", str(s_sb.corner_radius_top_left))

	# 印不能吃掉点击：整张牌的点击由 CardView 自己接
	ok(_all_ignore(seal) and _all_ignore(ink) and _all_ignore(indigo),
		"印与字都是 MOUSE_FILTER_IGNORE")

	seal.free()
	ink.free()
	indigo.free()
	small.free()

# ---------------- 真装配 ----------------

func _test_mount() -> void:
	var host := Control.new()
	host.size = Vector2(1440, 900)
	root.add_child(host)

	# 两枚印的卡：左边不越界、右上角贴着、不压左上费用圆
	var two: Dictionary = GameData.card("n_shi5").duplicate()   # 士·骸骨：死战
	two["uid"] = 1
	two["baseId"] = "n_shi5"
	two["taunt"] = true
	var cv := CardView.new()
	cv.setup(two)
	host.add_child(cv)
	var box := cv.get_node_or_null("keyword_stamps")
	ok(box != null, "CardView 挂了关键词小印")
	if box != null:
		ok((box as Control).get_child_count() == 2, "死战+守御两张印", str((box as Control).get_child_count()))
		var right := (box as Control).position.x + (box as Control).size.x
		ok(absf(right - (CardView.SIZE.x - 4.0)) < 0.01, "右缘内缩 4px", str(right))
		ok((box as Control).position.y >= 3.0, "不贴顶边", str((box as Control).position.y))
		ok((box as Control).position.x > 24.0, "左缘不压费用圆（费用圆右缘 24）",
			str((box as Control).position.x))
		ok((box as Control).position.y + (box as Control).size.y < 62.0,
			"不压攻血章（攻血章顶 124）", str((box as Control).position.y))

	# 无关键词的卡：连容器都不该出现（否则每张牌都多一个空节点）
	var plain: Dictionary = GameData.card("n_bing1").duplicate()
	plain["uid"] = 2
	plain["baseId"] = "n_bing1"
	var cv2 := CardView.new()
	cv2.setup(plain)
	host.add_child(cv2)
	var box2 := cv2.get_node_or_null("keyword_stamps")
	ok(box2 == null, "无关键词的卡不挂空容器")

	# 场上单位：90 宽，两枚 16px 印 + 内缩 3 仍要放得下
	var u: Dictionary = RulesEngine.new_instance("n_shi5")
	u["taunt"] = true
	var uv := UnitView.new()
	host.add_child(uv)
	uv.setup(u)
	var ubox := uv.get_node_or_null("keyword_stamps")
	ok(ubox != null, "UnitView 也挂了小印")
	if ubox != null:
		var uright := (ubox as Control).position.x + (ubox as Control).size.x
		ok(absf(uright - (UnitView.SIZE.x - 3.0)) < 0.01, "场上单位右缘内缩 3px", str(uright))
		ok((ubox as Control).position.x >= 0.0, "场上单位印不越左界",
			str((ubox as Control).position.x))
		ok((ubox as Control).size.y < UnitView.SIZE.y * 0.3, "印不到单位高度的三成",
			str((ubox as Control).size.y))

	# 图鉴大卡：左侧列表有小印、右侧大图没有会很割裂，两边的判据必须是同一套
	var codex: Node = load("res://scenes/codex.tscn").instantiate()
	host.add_child(codex)
	await process_frame
	codex._select_card("n_shi7")   # 士·死节：死战 + 守御（双关键词，才能验排版）
	await process_frame
	var detail: Node = codex.find_child("detail_art", true, false)
	ok(detail != null, "图鉴大卡有立绘容器（detail_art）")
	var big: Node = detail.get_node_or_null("keyword_stamps") if detail != null else null
	ok(big != null, "图鉴大卡也盖了关键词印")
	if big != null:
		# 枚数跟数据走，不写死：以后这张卡被改数值不该让测试红
		var want: int = KeywordStamp.of(GameData.card("n_shi7")).size()
		ok(want == 2, "测试样本是双关键词卡（n_shi7）", str(want))
		ok((big as Control).get_child_count() == want, "大卡印数与数据一致",
			"%d vs %d" % [(big as Control).get_child_count(), want])
		var dc := big as Control
		ok(dc.position.x >= 8.0 and dc.position.y >= 8.0, "大卡印不贴边（内缩 ≥8）",
			str(dc.position))
		ok(dc.position.x + dc.size.x <= (detail as Control).size.x, "大卡印不出画",
			str(dc.position.x + dc.size.x))
	# 换成无关键词的卡：大卡上的印要跟着消失（不是建一次就不动）
	codex._select_card("n_bing1")
	await process_frame
	var detail2: Node = codex.find_child("detail_art", true, false)
	ok(detail2 != null and detail2.get_node_or_null("keyword_stamps") == null,
		"换成无关键词的卡后大卡不留空印")
	await process_frame
	codex.queue_free()
	await process_frame
	await process_frame
	host.free()

# ---------------- 全卡池一致性 ----------------

## 独立数一遍数据里的关键词，与 KeywordStamp.of 的结果对齐。
## 这条其实是「印的判据」与「引擎的关键词判据」之间的契约：任何一方改了字段名，
## 都会在这里立刻红——而不是等玩家发现某张死战牌没印。
func _test_pool() -> void:
	var total := 0
	var stamped := 0
	var by_word := {}
	var mismatch: Array = []
	for id in GameData.cards.keys():
		var c: Dictionary = GameData.card(str(id))
		var want := 0
		for k in ["deathrattle", "taunt", "charge", "flank", "ranged", "combo"]:
			var v = c.get(k, null)
			var on := bool(v) if typeof(v) == TYPE_BOOL else v != null
			if on:
				want += 1
		var got := KeywordStamp.of(c)
		if got.size() != want:
			mismatch.append("%s(%d≠%d)" % [str(id), got.size(), want])
		total += 1
		if got.size() > 0:
			stamped += 1
			for s in got:
				by_word[str(s["zh"])] = int(by_word.get(str(s["zh"]), 0)) + 1
	ok(mismatch.is_empty(), "全卡池 %d 张的印数与数据一致" % total, str(mismatch))
	ok(stamped == 53, "53 张卡有关键词印", str(stamped))
	# 这几个数来自卡池实测分布，改动卡池时应当同步——不然就是有人动了关键词。
	# 2026-11-04 P2 连击 8 张：连 1→9、死 +1（接武）、守 +1（叠阵）、有印卡 45→53
	ok(int(by_word.get("死", 0)) == 21, "死战 21 张", str(by_word.get("死", 0)))
	ok(int(by_word.get("守", 0)) == 19, "守御 19 张", str(by_word.get("守", 0)))
	ok(int(by_word.get("冲", 0)) == 6, "冲锋 6 张", str(by_word.get("冲", 0)))
	ok(int(by_word.get("迂", 0)) == 6, "迂回 6 张", str(by_word.get("迂", 0)))
	ok(int(by_word.get("远", 0)) == 3, "远程 3 张", str(by_word.get("远", 0)))
	ok(int(by_word.get("连", 0)) == 9, "连击 9 张", str(by_word.get("连", 0)))

# ---------------- 语言 ----------------

func _test_lang() -> void:
	var before := I18n.lang
	I18n.set_lang_soft(I18n.EN)
	var c := new_card({"deathrattle": {"draw": 1}})
	var got := KeywordStamp.of(c)
	var word := str(got[0]["zh"]) if got.size() > 0 else ""
	ok(word == "死", "英文模式下印面仍是「死」（印是图形，不翻译）", word)
	ok(I18n.has_cjk(word), "印面是汉字")
	ok(KeywordStamp.of(c).size() == 1, "判据在英文模式下不变")
	# 印面不能走 I18n.T：否则字典里一旦出现同名键，印会变英文
	ok(I18n.T("死") == "死", "I18n.T 不改写单字（印面文本直出）", I18n.T("死"))
	I18n.set_lang_soft(before)

# ---------------- 工具 ----------------

func _meta(container: Control) -> String:
	if container.get_child_count() == 0:
		return ""
	return str(container.get_child(0).get_meta("stamp_face", ""))

func _style(container: Control) -> StyleBoxFlat:
	if container.get_child_count() == 0:
		return null
	var p := container.get_child(0) as Panel
	if p == null:
		return null
	return p.get_theme_stylebox("panel") as StyleBoxFlat

func _font_color(container: Control) -> Color:
	if container.get_child_count() == 0:
		return Color.BLACK
	var p := container.get_child(0) as Panel
	if p == null or p.get_child_count() == 0:
		return Color.BLACK
	return (p.get_child(0) as Label).get_theme_color("font_color")

func _font_size(container: Control) -> int:
	if container.get_child_count() == 0:
		return -1
	var p := container.get_child(0) as Panel
	if p == null or p.get_child_count() == 0:
		return -1
	return (p.get_child(0) as Label).get_theme_font_size("font_size")

func _all_ignore(container: Control) -> bool:
	for c in container.get_children():
		var ctl := c as Control
		if ctl == null or ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
		for g in ctl.get_children():
			var g2 := g as Control
			if g2 != null and g2.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				return false
	return true
