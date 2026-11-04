## 开新战役：军师三选一（决定整局的被动加成）+ 心魔难度选择
extends Control

var _asc := 0
var _asc_hint: Label = null
## 刚点完心魔按钮：重建后要给选中项补一次「落印」动画
var _seal_pending := false
## 巡览/调试时临时把解锁上限提到最高（-1 = 按真实生涯进度）
var _unlock_override := -1

func _ready() -> void:
	theme = UiTheme.build()
	GameData.ensure_loaded()
	if App.advisor_choices.is_empty():
		App.advisor_choices = Campaign.roll_advisors(3)
	_build()

func _build() -> void:
	Widgets.paper_bg(self)
	_build_pressure()

	var title := Widgets.title("择 一 军 师 随 军", 40)
	title.position = Vector2(0, 62)
	title.size = Vector2(1440, 56)
	add_child(title)

	var sub := Widgets.subtitle("军师之策将随你走完全程八关", 16)
	sub.position = Vector2(0, 122)
	sub.size = Vector2(1440, 26)
	add_child(sub)

	var choices: Array = App.advisor_choices
	var card_w := 380.0
	var gap := 40.0
	var total := choices.size() * card_w + (choices.size() - 1) * gap
	var x := (1440.0 - total) * 0.5
	for i in choices.size():
		var a: Dictionary = choices[i]
		var card := _advisor_card(a)
		card.position = Vector2(x + i * (card_w + gap), 176)
		card.size = Vector2(card_w, 476)
		add_child(card)
		Widgets.rise_in(card, 0.12 + i * 0.1, 24.0)

	_build_ascension()

## 心魔等级越高，页面四周的暗红越重——不看文字也能感到「这一局不一样」。
## 用暗角而不是整屏压暗：中间的选择区必须保持纸白，否则读不清卡面。
## 颜色取偏黑的赭红而不是 UiTheme.SEAL：朱砂在低透明度下会发粉，像打翻了水彩。
func _build_pressure() -> void:
	if _asc <= 0:
		return
	var v := Widgets.vignette(self, Color(0.36, 0.07, 0.05), 0.16 * float(_asc))
	v.modulate.a = 0.0
	Widgets.fade_in(v, 0.05, 0.35)

# ---------------- 心魔难度 ----------------

## 心魔在开局时选：通关常规才解锁 1 级，通关 N 级才解锁 N+1 级。
## 放在这里而不是地图上，是因为它必须和一整轮绑定（中途改等于作弊）。
func _build_ascension() -> void:
	var unlocked := _unlock_override if _unlock_override >= 0 else Codex.ascension_unlocked()
	var row := HBoxContainer.new()
	row.position = Vector2(0, 686)
	row.size = Vector2(1440, 46)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	add_child(row)

	var cap := UiTheme.label("心 魔", 18, UiTheme.SEAL)
	row.add_child(cap)

	# 常规 + 各级心魔；未解锁的置灰并标注需要先通关
	var levels := Campaign.ascension_max()
	var buttons: Array = []
	for lv in range(0, levels + 1):
		var btn := UiTheme.button("常 规" if lv == 0 else "心魔 %d" % lv, lv == _asc)
		btn.custom_minimum_size = Vector2(104, 42)
		btn.size = Vector2(104, 42)
		if lv > unlocked:
			btn.disabled = true
			btn.tooltip_text = I18n.T("先通关前一等级才解锁")
			# 默认的禁用色在纸底上几乎看不见，单独给一档可读的灰
			btn.add_theme_color_override("font_disabled_color", Color(0.42, 0.40, 0.37, 0.75))
		else:
			var level_copy := lv
			btn.pressed.connect(func (): _pick_asc(level_copy, unlocked))
		row.add_child(btn)
		buttons.append(btn)

	_asc_hint = Widgets.subtitle(_hint_text(), 15)
	_asc_hint.position = Vector2(0, 740)
	_asc_hint.size = Vector2(1440, 24)
	add_child(_asc_hint)

	# 刚点下的那一级：补一次落印（放大回弹 + 轻微旋转），让「加重难度」有手感
	if _seal_pending and _asc < buttons.size():
		_stamp(buttons[_asc])
	_seal_pending = false

## 落印动画：像把一枚印章按在纸上——先放大压下去，再回弹复位。
func _stamp(btn: Button) -> void:
	if not Settings.motion:
		return
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(1.22, 1.22)
	btn.rotation = deg_to_rad(-3.0)
	var tw := btn.create_tween()
	tw.set_parallel(true)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "rotation", 0.0, 0.26)

## 把 1..N 级的效果串起来给玩家看（数据已按当前语言本地化）
func _hint_text() -> String:
	if _asc <= 0:
		return "常规难度：不作任何额外限制"
	var parts: Array = []
	for lv in range(1, _asc + 1):
		var a := Campaign.ascension_by_level(lv)
		if not a.is_empty():
			parts.append("%s：%s" % [str(a.get("name", "")), str(a.get("desc", ""))])
	return "　".join(parts)

func _pick_asc(level: int, unlocked: int) -> void:
	if level > unlocked or level == _asc:
		return
	_asc = level
	_seal_pending = true
	# 加重难度要「听得见」：一键盖章（按钮本身的 tick 太轻，压不住这个决定）
	if level > 0:
		Audio.sfx("seal")
	_rebuild()

## 巡览 / 调试用：无视解锁直接摆出某一档。
## 截图验收需要看到「选中态 + 暗角」，而真实解锁要通关才给——不能为了截图去改存档。
## 必须连解锁上限一起放开：选中样式会被 disabled 的禁用样式盖掉，否则截出来
## 只是一排灰按钮，看不出选了哪一级。
func _force_asc(level: int) -> void:
	_unlock_override = Campaign.ascension_max()
	_asc = clampi(level, 0, Campaign.ascension_max())
	_seal_pending = true
	_rebuild()

## 重建整页：心魔按钮的选中态、提示行、暗角要一起更新
func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_asc_hint = null
	_build()

func _advisor_card(a: Dictionary) -> Panel:
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.INK, 8, 2))

	var portrait := TextureRect.new()
	portrait.position = Vector2(110, 26)
	portrait.size = Vector2(160, 160)
	var tex := UiTheme.art_texture("ad_" + str(a["id"]))
	if tex != null:
		portrait.texture = tex
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		card.add_child(portrait)
	else:
		var glyph := UiTheme.label(str(a.get("glyph", "")), 56, UiTheme.PAPER)
		glyph.position = Vector2(0, 0)
		glyph.size = Vector2(380, 160)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(glyph)

	var name_label := UiTheme.label(str(a["name"]), 28, UiTheme.SEAL)
	name_label.position = Vector2(0, 200)
	name_label.size = Vector2(380, 36)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	var title_label := UiTheme.label(str(a["title"]), 15, UiTheme.INK_SOFT)
	title_label.position = Vector2(0, 238)
	title_label.size = Vector2(380, 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title_label)

	var desc := Widgets.paragraph(str(a["desc"]), 16, UiTheme.INK, 320.0)
	desc.position = Vector2(30, 266)
	card.add_child(desc)

	var flavor := Widgets.paragraph(str(a.get("flavor", "")), 13, UiTheme.INK_SOFT, 320.0)
	flavor.position = Vector2(30, 352)
	flavor.modulate = Color(1, 1, 1, 0.85)
	card.add_child(flavor)

	var btn := UiTheme.button("拜 为 军 师", true)
	btn.position = Vector2(90, 408)
	btn.size = Vector2(200, 48)
	var aid := str(a["id"])
	var level := _asc
	btn.pressed.connect(func (): App.begin_run(aid, level))
	card.add_child(btn)
	return card
