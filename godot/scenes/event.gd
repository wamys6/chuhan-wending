## 行军事件：一个抉择，直接改写后面的路
extends Control

var _done := false

func _ready() -> void:
	theme = UiTheme.build()
	GameData.ensure_loaded()
	if App.pending_event.is_empty():
		App.go(App.SCENE_MAP)
		return
	_build()

func _build() -> void:
	var ev: Dictionary = App.pending_event
	Widgets.paper_bg(self)

	var panel := Panel.new()
	panel.position = Vector2(330, 120)
	panel.size = Vector2(780, 640)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.SEAL, 10, 3))
	add_child(panel)

	# 圆形插图：外圈朱砂环 + 内嵌水墨图
	var ring := Panel.new()
	ring.position = Vector2(310, 32)
	ring.size = Vector2(160, 160)
	ring.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.SEAL, 80, 3))
	panel.add_child(ring)

	var tex := UiTheme.art_texture("ev_" + str(ev["id"]))
	if tex != null:
		# 顺序交给 UiTheme.texture_rect：直接写 texture 再 size 会被纹理最小尺寸顶回 1024，
		# 圆里就只剩原画左上角一块空白（这张图一直是错的，2026-11-03 表现打磨时发现）
		var art := UiTheme.texture_rect(tex, Vector2(144, 144))
		# 圆形遮罩用 clip_children 实现（Godot 4 支持 CanvasItem 裁剪到父节点形状）
		var mask := Panel.new()
		mask.position = Vector2(8, 8)
		mask.size = Vector2(144, 144)
		mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		mask.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER_DEEP, UiTheme.PAPER_DEEP, 72, 0))
		ring.add_child(mask)
		mask.add_child(art)
	else:
		var glyph := UiTheme.label(str(ev.get("glyph", "事")), 54, UiTheme.SEAL)
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ring.add_child(glyph)

	var title := UiTheme.label(str(ev["name"]), 32, UiTheme.INK)
	title.position = Vector2(0, 208)
	title.size = Vector2(780, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var text := Widgets.paragraph(str(ev["text"]), 17, UiTheme.INK_SOFT, 640.0)
	text.position = Vector2(70, 262)
	panel.add_child(text)

	var y := 400.0
	var options: Array = ev.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(70, y)
		b.size = Vector2(640, 64)
		var sb := UiTheme.panel_style(UiTheme.PAPER_DEEP, UiTheme.INK_SOFT, 6, 2)
		sb.content_margin_left = 18
		b.add_theme_stylebox_override("normal", sb)
		var hover := sb.duplicate() as StyleBoxFlat
		hover.bg_color = Color(UiTheme.SEAL.r, UiTheme.SEAL.g, UiTheme.SEAL.b, 0.1)
		hover.border_color = UiTheme.SEAL
		b.add_theme_stylebox_override("hover", hover)
		var pressed := sb.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(UiTheme.SEAL.r, UiTheme.SEAL.g, UiTheme.SEAL.b, 0.18)
		pressed.border_color = UiTheme.SEAL
		b.add_theme_stylebox_override("pressed", pressed)
		panel.add_child(b)

		var label := UiTheme.label(str(opt["label"]), 20, UiTheme.INK)
		label.position = Vector2(18, 8)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(label)

		var hint := UiTheme.label(str(opt.get("hint", "")), 14, UiTheme.SEAL)
		hint.position = Vector2(18, 36)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hint)

		var idx := i
		b.pressed.connect(func (): _choose(idx))
		Widgets.rise_in(b, 0.15 + i * 0.08, 14.0)
		y += 76

	Widgets.fade_in(panel, 0.0, 0.28)

func _choose(index: int) -> void:
	if _done:
		return
	_done = true
	var ev: Dictionary = App.pending_event
	var res := Campaign.apply_event(App.progress, str(ev["id"]), index)
	if not bool(res.get("ok", false)):
		App.finish_event()
		return
	var fx: Dictionary = res.get("fx", {})
	# 得牌 / 删牌不在这里落地：事件数据只写「要几张、要哪一类」，
	# 具体拿哪张由玩家在选牌层里挑（与 Web 版 ui.js 的 chooseEventOption 一致）。
	# 迁移期这里曾简化成「一律发一张随机兵种牌」，于是「三选一计谋牌」「移除一张」
	# 两条事件文案与实际行为对不上（2026-11-03 补）。
	if fx.has("card"):
		var ids := Campaign.event_candidates(App.progress, fx)
		if ids.is_empty():
			App.finish_event()
			return
		_open_picker(ids, "add", maxi(1, int(fx.get("cardCount", 1))))
		return
	if fx.has("remove"):
		_open_picker((App.progress.get("deck", []) as Array).duplicate(), "remove",
			int(fx["remove"]))
		return
	App.finish_event()

## 事件选牌层。不给「取消」：事件在 apply_event 时已写进进度并存档，
## 关掉窗口等于白吞一个事件，所以只能选完进军（牌组到下限时自动降为可删张数）。
## 返回建出来的选牌层（没建则为 null），方便测试与 i18n 扫描清理。
func _open_picker(ids: Array, mode: String, count: int) -> CardPicker:
	if mode == "remove":
		count = mini(count, maxi(0, ids.size() - Campaign.MIN_DECK))
		if count <= 0:
			App.finish_event()
			return null
	var cfg := {
		"cards": ids,
		"mode": mode,
		"count": count,
		"on_done": func (picked: Array): _apply_pick(picked, mode),
	}
	if mode == "add":
		cfg["title"] = "收 入 牌 组"
		cfg["hint"] = "点选要收的牌"
		cfg["confirm"] = "收 下 并 进 军"
	else:
		cfg["title"] = "删 去 牌 组"
		cfg["hint"] = "点选要删的牌"
		cfg["confirm"] = "删 去 并 进 军"
	return CardPicker.open(self, cfg)

func _apply_pick(picked: Array, mode: String) -> void:
	for id in picked:
		if mode == "add":
			Campaign.add_card(App.progress, str(id))
		else:
			Campaign.remove_card(App.progress, str(id))
	App.finish_event()
