## 图鉴 · 战绩 · 成就
##
## 三个 tab 共用一屏：卡牌图鉴（筛选 + 详情）、战绩数字、成就清单。
## 数据全部来自 Codex（生涯存档）与 GameData（卡池），本场景不持有状态。
extends Control

const SCREEN_W := 1440.0
const TABS := [
	{"id": "cards", "label": "卡牌图鉴"},
	{"id": "stats", "label": "战 绩"},
	{"id": "ach", "label": "成 就"},
]
const FACTION_FILTERS := [
	{"id": "all", "label": "全部阵营"},
	{"id": "neutral", "label": "中 立"},
	{"id": "han", "label": "汉 军"},
	{"id": "chu", "label": "楚 军"},
]
const TYPE_FILTERS := [
	{"id": "all", "label": "全部类型"},
	{"id": "piece", "label": "兵 种"},
	{"id": "spell", "label": "计 谋"},
]

var _tab := "cards"
var _faction := "all"
var _type := "all"
var _selected := ""
var _body: Control
var _tab_btns: Dictionary = {}

func _ready() -> void:
	theme = UiTheme.build()
	GameData.ensure_loaded()
	Codex.ensure_loaded()
	_build()

func _build() -> void:
	Widgets.paper_bg(self)
	_add_back()

	var t := Widgets.title("图 鉴", 40)
	t.position = Vector2(0, 56)
	t.size = Vector2(SCREEN_W, 54)
	add_child(t)

	var sub := Widgets.subtitle("卡池 %d 张 · 成就 %d / %d" % [
		Codex.card_stats()["total"], Codex.unlocked_count(), Codex.ACHIEVEMENTS.size()], 15)
	sub.position = Vector2(0, 116)
	sub.size = Vector2(SCREEN_W, 24)
	sub.name = "Sub"
	add_child(sub)

	_build_tabs()

	_body = Control.new()
	_body.position = Vector2(0, 186)
	_body.size = Vector2(SCREEN_W, 714)
	add_child(_body)
	_render_body()

func _build_tabs() -> void:
	var w := 168.0
	var gap := 14.0
	var total := w * TABS.size() + gap * (TABS.size() - 1)
	var x := (SCREEN_W - total) * 0.5
	for i in TABS.size():
		var spec: Dictionary = TABS[i]
		var b := UiTheme.button(str(spec["label"]), str(spec["id"]) == _tab)
		b.position = Vector2(x + i * (w + gap), 148)
		b.size = Vector2(w, 40)
		b.add_theme_font_size_override("font_size", 17)
		var id := str(spec["id"])
		b.pressed.connect(func (): _switch_tab(id))
		add_child(b)
		_tab_btns[id] = b

func _switch_tab(id: String) -> void:
	if id == _tab:
		return
	_tab = id
	for key in _tab_btns.keys():
		_style_tab(_tab_btns[key], key == id)
	_render_body()

func _style_tab(b: Button, active: bool) -> void:
	var primary := UiTheme.button("", true)
	var plain := UiTheme.button("", false)
	for key in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(key, (primary if active else plain).get_theme_stylebox(key))
	b.add_theme_color_override("font_color", UiTheme.PAPER if active else UiTheme.INK)
	b.add_theme_color_override("font_hover_color", UiTheme.PAPER if active else UiTheme.SEAL)

func _render_body() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match _tab:
		"cards": _render_cards()
		"stats": _render_stats()
		"ach": _render_achievements()

# ---------------- 卡牌图鉴 ----------------

func _render_cards() -> void:
	_build_filters()

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(268, 0)
	scroll.size = Vector2(790, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var ids := Codex.filter_cards({"faction": _faction, "type": _type})
	if ids.is_empty():
		var empty := Widgets.subtitle("此筛选下没有卡牌", 17)
		empty.position = Vector2(268, 40)
		empty.size = Vector2(780, 30)
		_body.add_child(empty)
	for id in ids:
		var cid := str(id)
		var view := Widgets.card_view(cid)
		view.gui_input.connect(func (e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				_select_card(cid))
		if cid == _selected:
			view.modulate = Color(1, 1, 1, 1)
		else:
			view.modulate = Color(0.99, 0.98, 0.95, 0.94)
		grid.add_child(view)

	_build_detail()

func _build_filters() -> void:
	var y := 4.0
	var lbl := UiTheme.label("筛 选", 16, UiTheme.INK_SOFT)
	lbl.position = Vector2(40, y)
	_body.add_child(lbl)
	y += 30.0
	for spec in FACTION_FILTERS:
		var id := str(spec["id"])
		var b := UiTheme.button(str(spec["label"]), id == _faction)
		b.position = Vector2(40, y)
		b.size = Vector2(196, 38)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func (): _set_filter("faction", id))
		_body.add_child(b)
		y += 44.0
	y += 24.0
	for spec in TYPE_FILTERS:
		var id := str(spec["id"])
		var b2 := UiTheme.button(str(spec["label"]), id == _type)
		b2.position = Vector2(40, y)
		b2.size = Vector2(196, 38)
		b2.add_theme_font_size_override("font_size", 16)
		b2.pressed.connect(func (): _set_filter("type", id))
		_body.add_child(b2)
		y += 44.0

	# 卡池统计
	var st := Codex.card_stats()
	var info := UiTheme.label("中立 %d · 汉 %d · 楚 %d\n兵种 %d · 计谋 %d" % [
		st["byFaction"]["neutral"], st["byFaction"]["han"], st["byFaction"]["chu"],
		st["byType"]["piece"], st["byType"]["spell"]], 14, UiTheme.INK_SOFT)
	info.position = Vector2(40, 560)
	info.size = Vector2(200, 60)
	_body.add_child(info)

func _set_filter(kind: String, id: String) -> void:
	if kind == "faction":
		_faction = id
	else:
		_type = id
	_render_body()

func _select_card(cid: String) -> void:
	_selected = cid
	Audio.sfx("tick")
	# 只重建详情与网格高亮：整块重绘最省事，46 张卡重建开销也很小
	_render_body()

func _build_detail() -> void:
	var box := Panel.new()
	box.position = Vector2(1090, 0)
	box.size = Vector2(310, 700)
	box.add_theme_stylebox_override("panel",
		UiTheme.panel_style(Color(1, 1, 1, 0.6), UiTheme.INK, 8, 2))
	_body.add_child(box)

	var cid := _selected
	if cid == "" or not GameData.has_card(cid):
		var hint := Widgets.subtitle("点选左侧任意卡牌\n查看详情", 17)
		hint.position = Vector2(0, 320)
		hint.size = Vector2(310, 60)
		box.add_child(hint)
		return

	var c := GameData.card(cid)
	# 立绘放进固定尺寸的容器再铺满，TextureRect 直接设 size 在部分
	# Godot 版本里会被纹理最小尺寸顶掉（CardView 同款做法）
	var holder := Control.new()
	holder.name = "detail_art"   # 给测试/调试一个稳定的落点（大图与关键词印都在这棵子树里）
	holder.position = Vector2(10, 10)
	holder.size = Vector2(290, 360)
	holder.clip_contents = true
	box.add_child(holder)
	var tex := UiTheme.art_texture(cid)
	if tex != null:
		var art := TextureRect.new()
		art.texture = tex
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		holder.add_child(art)
	else:
		holder.add_child(CardArt.placeholder(cid, Vector2(290, 360)))

	# 关键词印：与手牌上的小印同一套（这里立绘 290 宽是手牌 128 的两倍多，
	# 印按 1.5 倍放大，视觉比例才跟卡面一致）。图鉴是玩家查「这牌算不算死战牌」
	# 的地方，左侧列表有小印、右侧大图没有会很割裂
	var stamps := KeywordStamp.row(c, 28.0, 4.0)
	if stamps.size.x > 0.0:
		stamps.position = Vector2(holder.size.x - 12.0 - stamps.size.x, 12.0)
		holder.add_child(stamps)

	var name_t := UiTheme.label(str(c["name"]), 26, UiTheme.INK)
	name_t.position = Vector2(16, 380)
	name_t.size = Vector2(280, 34)
	box.add_child(name_t)

	var meta := _card_meta_line(c)
	# 英文元信息长（Neutral · Unit · 1 Prov · 1 Atk / 2 HP · Vanguard），
	# 缩一号并允许折两行；描述整体下移让位。
	# 注意先开 autowrap 再设尺寸——顺序反了 Label 会先按整句宽撑开、不再收窄。
	var meta_t := UiTheme.label(meta, 13 if I18n.is_en() else 15, UiTheme.SEAL)
	meta_t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_t.custom_minimum_size = Vector2(280, 0)
	meta_t.position = Vector2(16, 418)
	meta_t.size = Vector2(280, 40 if I18n.is_en() else 24)
	box.add_child(meta_t)

	var desc_y := 464.0 if I18n.is_en() else 452.0
	var desc := UiTheme.label(str(c.get("desc", "")), 15, UiTheme.INK_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(278, 0)
	desc.position = Vector2(16, desc_y)
	desc.size = Vector2(278, 0)
	box.add_child(desc)

	# 关键词释义：把卡面文字里出现的关键词列出来，新手不用查百科
	var kw := _keyword_notes(str(c.get("desc", "")), str(c.get("name", "")))
	if kw != "":
		var kw_t := UiTheme.label(kw, 13, UiTheme.INK_SOFT)
		kw_t.position = Vector2(16, desc.position.y + 78)
		kw_t.size = Vector2(278, 0)
		kw_t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kw_t.custom_minimum_size = Vector2(278, 0)
		box.add_child(kw_t)

func _card_meta_line(c: Dictionary) -> String:
	var parts: Array = []
	var fac := GameData.faction_of(str(c.get("id", "")))
	# 每一段单独翻译再拼接：整句一起翻会撞不上词典
	parts.append(I18n.T(str({"neutral": "中立", "han": "汉", "chu": "楚"}.get(fac, "中立"))))
	parts.append(I18n.T("兵种" if str(c.get("type", "")) == "piece" else "计谋"))
	parts.append(I18n.T("%d 费" % int(c.get("cost", 0))))
	if str(c.get("type", "")) == "piece":
		parts.append(I18n.T("%d 攻 / %d 血" % [int(c.get("atk", 0)), int(c.get("hp", 0))]))
		parts.append(GameData.rank_name(str(c.get("col", "front"))))
	return " · ".join(parts)

## 从卡牌文本里识别关键词，附上白话解释（统一取 Tutorial 的释义表，随语言切换）
func _keyword_notes(desc: String, card_name: String) -> String:
	var hits := Tutorial.explanations_for(desc + " " + card_name)
	var out: Array = []
	# 中文用【】括注；英文换 ASCII 方括号（全角括号会被扫描器当漏译拦下）
	var open := "["
	var close := "]"
	if not I18n.is_en():
		open = "【"
		close = "】"
	for h in hits:
		out.append("%s%s%s %s" % [open, str(h["kw"]), close, str(h["text"])])
	return "\n".join(out)

# ---------------- 战绩 ----------------

func _render_stats() -> void:
	var s := Codex.summary()
	var rows := [
		["总场次", str(s["battles"]), "胜 %d · 负 %d" % [s["wins"], s["losses"]]],
		["PvP 切磋", str(s["pvpWins"]), "负 %d 场（好友对战）" % s["pvpLosses"]],
		["胜 率", "%d%%" % s["winRate"], "共 %d 场" % s["battles"]],
		["当前连胜", str(s["streak"]), "最长 %d 连胜" % s["bestStreak"]],
		["最快取胜", ("%d 回合" % s["fastestWin"]) if int(s["fastestWin"]) > 0 else "—", "越少越猛"],
		["最低血量取胜", ("%d 点" % s["bestHpWin"]) if int(s["bestHpWin"]) >= 0 else "—", "越少越险"],
		["通关进度", "%d / %d" % [s["clearedCount"], Campaign.stages().size()],
			"问鼎中原" if bool(s["finished"]) else "尚未抵达垓下"],
		["最大牌组", "%d 张" % s["maxDeck"], "初始 20 张"],
		["累计伤害", str(s["dmg"]), "其中直击主将 %d" % s["heroDmg"]],
		["累计出兵", str(s["units"]), "用计 %d 次" % s["spells"]],
		["用过的军师", str(s["advisors"]), "共 %d 位" % GameData.advisors.size()],
		["经历事件", str(s["events"]), "共 %d 个" % GameData.events.size()],
		["成就", "%d / %d" % [s["ach"], Codex.ACHIEVEMENTS.size()], "达成即永久记录"],
	]
	var col_w := 420.0
	var row_h := 96.0
	var x0 := (SCREEN_W - col_w * 3 - 24 * 2) * 0.5
	for i in rows.size():
		var r: Array = rows[i]
		var col := i % 3
		var row := i / 3
		var card := Panel.new()
		card.position = Vector2(x0 + col * (col_w + 24), row * (row_h + 18))
		card.size = Vector2(col_w, row_h)
		card.add_theme_stylebox_override("panel",
			UiTheme.panel_style(Color(1, 1, 1, 0.62), UiTheme.INK_SOFT, 6, 1))
		_body.add_child(card)

		var label := UiTheme.label(str(r[0]), 15, UiTheme.INK_SOFT)
		label.position = Vector2(20, 12)
		card.add_child(label)

		var value := UiTheme.label(str(r[1]), 30, UiTheme.SEAL if i < 3 else UiTheme.INK)
		value.position = Vector2(20, 36)
		card.add_child(value)

		var note := UiTheme.label(str(r[2]), 13, UiTheme.INK_SOFT)
		note.position = Vector2(20, 72)
		card.add_child(note)
		Widgets.rise_in(card, 0.03 * i, 10.0)

# ---------------- 成就 ----------------

func _render_achievements() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(320, 0)
	scroll.size = Vector2(800, 704)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	var groups := ["battle", "campaign", "career"]
	for g in groups:
		var head := UiTheme.label("%s　·　%d / %d" % [
			Codex.group_name(str(g)), _group_done(g), _group_total(g)], 18, UiTheme.SEAL)
		head.custom_minimum_size = Vector2(0, 38)
		col.add_child(head)
		for a in Codex.ACHIEVEMENTS:
			if str(a["group"]) != g:
				continue
			col.add_child(_ach_row(a))
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		col.add_child(spacer)

func _group_total(g: String) -> int:
	var n := 0
	for a in Codex.ACHIEVEMENTS:
		if str(a["group"]) == g:
			n += 1
	return n

func _group_done(g: String) -> int:
	var n := 0
	for a in Codex.ACHIEVEMENTS:
		if str(a["group"]) == g and Codex.is_unlocked(str(a["id"])):
			n += 1
	return n

func _ach_row(a: Dictionary) -> Control:
	var done := Codex.is_unlocked(str(a["id"]))
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.add_theme_stylebox_override("panel",
		UiTheme.panel_style(Color(1, 1, 1, 0.6) if done else Color(0.93, 0.91, 0.86, 0.55),
			UiTheme.SEAL if done else UiTheme.INK_SOFT, 6, 2 if done else 1))

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	row.add_child(pad)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	pad.add_child(hb)

	# 成就徽记：达成是朱砂底白字，未达成是浅灰
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(48, 48)
	badge.size = Vector2(48, 48)
	badge.add_theme_stylebox_override("panel",
		UiTheme.panel_style(UiTheme.SEAL if done else Color(0.82, 0.8, 0.76), UiTheme.SEAL if done else UiTheme.INK_SOFT, 6, 1))
	hb.add_child(badge)
	var glyph := UiTheme.label(str(a["glyph"]), 22, UiTheme.PAPER if done else UiTheme.INK_SOFT)
	glyph.position = Vector2(0, 10)
	glyph.size = Vector2(48, 30)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(glyph)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(vb)

	var name_t := UiTheme.label(Codex.ach_name(a), 18, UiTheme.INK if done else UiTheme.INK_SOFT)
	vb.add_child(name_t)
	var desc_t := UiTheme.label(Codex.ach_desc(a), 14, UiTheme.INK_SOFT if done else Color(0.55, 0.51, 0.46))
	vb.add_child(desc_t)

	var state := UiTheme.label("已达成" if done else "未达成", 14,
		UiTheme.SEAL if done else Color(0.6, 0.56, 0.5))
	hb.add_child(state)
	return row

# ---------------- 返回 ----------------

func _add_back() -> void:
	var back := UiTheme.button("返 回")
	back.position = Vector2(40, 30)
	back.size = Vector2(120, 46)
	back.pressed.connect(_back)
	add_child(back)

## 从战役里进来的回地图，从主菜单进来的回主菜单
func _back() -> void:
	if not App.progress.is_empty():
		App.stage = Campaign.next_stage(App.progress)
		App.go(App.SCENE_MAP)
	else:
		App.go(App.SCENE_MENU)
