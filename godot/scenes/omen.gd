## 天时揭晓：新手开局抽到的「全局天时」在这里落地
##
## 为什么单独一屏：天时是整局 8 关都吃到的修正，如果只在地图上挂一枚 chip，
## 玩家会在第 3 关才发现「怎么我起手少一张」。给一次仪式，把它变成"这局的命"。
##
## 动效序列（Settings.motion 关掉时全部直出）：
##   摇签（lottery）→ 签纸落下 → 落地一震 + 铜锣（omen）→ 「受命」按钮淡入
extends Control

const PAPER_W := 360.0
const PAPER_H := 400.0
const PAPER_TOP := 258.0
const START_Y := -470.0

## 签纸中段的水印字：按天时 id 取，不走本地化。
## 英文模式下名字变成 "Fate: Fat Year"，切不出尾字；而这块空档必须填住，
## 否则英文版的签纸中间会豁一大块。它是装饰性的墨迹（8% 不透明度），
## 和项目里其它「单个汉字＝朱砂印记」的处理一致，不当作文案。
const OMEN_GLYPH := {
	"qingfeng": "风", "fengnian": "丰", "shuangjiang": "霜",
	"kuhan": "寒", "lihuo": "火", "xingbian": "星",
}

var _tian: Dictionary = {}
var _paper: Panel
var _go: Button

func _ready() -> void:
	theme = UiTheme.build()
	GameData.ensure_loaded()
	_tian = Campaign.tian_shi_by_id(str(App.progress.get("tianShi", "")))
	if _tian.is_empty():
		# 老存档（v1 迁移上来的）没有天时，或者被调试直进：不拦流程
		App.go(App.SCENE_MAP)
		return
	_build()
	_play()

func _build() -> void:
	Widgets.paper_bg(self)

	# 墨纱：压暗纸面，让签纸成为唯一焦点。
	# 0.52 是看着调的——再浅签纸不跳出来，再深标题的白字开始发灰
	var veil := ColorRect.new()
	veil.color = Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.0)
	Widgets.fill_screen(veil)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var vtw := veil.create_tween()
	vtw.tween_property(veil, "color:a", 0.46, 0.5)
	# 再加一层墨色暗角：纯平压暗会显得像蒙了层灰，有暗角才有「灯下看签」的纵深
	Widgets.vignette(self, Color(0.10, 0.09, 0.08), 0.62)

	var title := Widgets.title("天 时 已 定", 44, UiTheme.PAPER)
	title.position = Vector2(0, 96)
	title.size = Vector2(1440, 60)
	add_child(title)
	Widgets.fade_in(title, 0.25, 0.5)

	var sub := Widgets.subtitle("一军之中，唯天时最不可测", 17)
	sub.add_theme_color_override("font_color", Color(0.92, 0.89, 0.84, 0.85))
	sub.position = Vector2(0, 162)
	sub.size = Vector2(1440, 26)
	add_child(sub)
	Widgets.fade_in(sub, 0.4, 0.5)

	_paper = _build_paper()
	_paper.position = Vector2((1440.0 - PAPER_W) * 0.5, START_Y)
	_paper.size = Vector2(PAPER_W, PAPER_H)
	add_child(_paper)

	_go = UiTheme.button("受 命 出 征", true)
	_go.position = Vector2((1440.0 - 260.0) * 0.5, 730)
	_go.size = Vector2(260, 56)
	_go.add_theme_font_size_override("font_size", 22)
	_go.disabled = true
	_go.modulate.a = 0.0
	_go.pressed.connect(_continue)
	add_child(_go)

	var foot := Widgets.subtitle(_run_line(), 14)
	foot.add_theme_color_override("font_color", Color(0.90, 0.87, 0.82, 0.8))
	foot.position = Vector2(0, 806)
	foot.size = Vector2(1440, 22)
	add_child(foot)

## 签纸本体：竖长条，纸白 + 双线边 + 一枚朱砂/墨色吉凶印。
## 中段留了一大片空白，用天时尾字（风 / 丰 / 霜 / 寒 / 火 / 星）做淡水印填住，
## 既当装饰又不用为每个天时单独配图。
func _build_paper() -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.INK, 4, 2))

	# 信笺式内框：给纸面一点结构，英文版字少时也不至于显得空
	var frame := Panel.new()
	frame.position = Vector2(16, 16)
	frame.size = Vector2(PAPER_W - 32, PAPER_H - 32)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UiTheme.panel_style(
		Color(0, 0, 0, 0), Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.16), 2, 1))
	p.add_child(frame)

	var cap := UiTheme.label("天　时", 15, UiTheme.INK_SOFT)
	cap.position = Vector2(0, 26)
	cap.size = Vector2(PAPER_W, 22)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(cap)

	var name_label := UiTheme.label(str(_tian.get("name", "")), 32, UiTheme.INK)
	name_label.position = Vector2(0, 56)
	name_label.size = Vector2(PAPER_W, 46)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(name_label)

	# 朱砂/墨色小印：吉用朱砂，凶用墨——不看描述也能一眼判断这一局是顺是逆。
	# 单个汉字是项目里既定的「朱砂印章」语汇，英文界面也保留（i18n 扫描对此豁免）。
	var bad := _is_bad()
	var seal := UiTheme.label("凶" if bad else "吉", 15, UiTheme.PAPER)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var seal_box := Panel.new()
	seal_box.position = Vector2(PAPER_W - 58, 20)
	seal_box.size = Vector2(30, 30)
	seal_box.add_theme_stylebox_override("panel", UiTheme.panel_style(
		UiTheme.INK if bad else UiTheme.SEAL, UiTheme.INK if bad else UiTheme.SEAL, 3, 0))
	seal.size = Vector2(30, 30)
	seal_box.add_child(seal)
	p.add_child(seal_box)

	var rule := ColorRect.new()
	rule.color = Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.35)
	rule.position = Vector2(60, 116)
	rule.size = Vector2(PAPER_W - 120, 1)
	p.add_child(rule)

	var desc := Widgets.paragraph(str(_tian.get("desc", "")), 17, UiTheme.INK, PAPER_W - 96)
	desc.position = Vector2(48, 138)
	p.add_child(desc)

	var glyph := _tail_glyph()
	if glyph != "":
		# 字框要留足行高：Label 会把超出 rect 的部分裁掉，框太矮就会出现半截字
		var mark := UiTheme.label(glyph, 96, UiTheme.INK)
		mark.position = Vector2(0, 196)
		mark.size = Vector2(PAPER_W, 132)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.modulate = Color(1, 1, 1, 0.08)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(mark)

	var tip := Widgets.paragraph("此局八关，皆在此天时之下。", 13, UiTheme.INK_SOFT, PAPER_W - 96)
	tip.position = Vector2(48, PAPER_H - 58)
	tip.modulate = Color(1, 1, 1, 0.85)
	p.add_child(tip)
	return p

## 天时对应的水印字（按 id 查表，与语言无关）
func _tail_glyph() -> String:
	return str(OMEN_GLYPH.get(str(_tian.get("id", "")), ""))

func _is_bad() -> bool:
	var mods: Dictionary = _tian.get("mods", {})
	if int(mods.get("playerStartMana", 0)) < 0 or int(mods.get("playerHpBonus", 0)) < 0:
		return true
	if int(mods.get("enemyStartMana", 0)) > 0:
		return true
	return false

func _run_line() -> String:
	var lv := int(App.progress.get("ascension", 0))
	var diff := I18n.T("常规难度") if lv == 0 else I18n.T("心魔 %d" % lv)
	return "%s · %s" % [diff, str(GameData.advisor_by_id(str(App.progress.get("advisor", ""))).get("name", ""))]

# ---------------- 动效 ----------------

func _play() -> void:
	if not Settings.motion:
		_paper.position.y = PAPER_TOP
		_go.disabled = false
		_go.modulate.a = 1.0
		Audio.sfx("omen")
		return

	# ① 摇签：先给一声，制造「正在抽」的悬念
	var t0 := create_tween()
	t0.tween_interval(0.35)
	t0.tween_callback(func (): Audio.sfx("lottery"))
	# ② 签纸落下
	t0.tween_property(_paper, "position:y", PAPER_TOP, 0.62) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t0.tween_callback(_on_land)

func _on_land(attempt: int = 0) -> void:
	# 落地：铜锣 + 横向一震（幅度小、次数少，别做成地震）
	Audio.sfx("omen")
	var base_x := _paper.position.x
	var tw := create_tween()
	for i in 3:
		tw.tween_property(_paper, "position:x", base_x + (5.0 if i % 2 == 0 else -5.0), 0.055)
	tw.tween_property(_paper, "position:x", base_x, 0.055)
	_ripple()
	# 按钮稍等半拍再出现：先让玩家读完签文
	var t2 := create_tween()
	t2.tween_interval(0.85)
	t2.tween_callback(func ():
		_go.disabled = false
		Widgets.fade_in(_go, 0.0, 0.35))

## 落地时的墨圈：一圈朱砂细框从签纸边缘扩散出去
func _ripple() -> void:
	var ring := Panel.new()
	var sb := UiTheme.panel_style(Color(0, 0, 0, 0), UiTheme.SEAL, 4, 3)
	ring.add_theme_stylebox_override("panel", sb)
	ring.position = _paper.position
	ring.size = _paper.size
	ring.pivot_offset = _paper.size * 0.5
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.modulate.a = 0.55
	add_child(ring)
	move_child(ring, _paper.get_index())
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(1.28, 1.18), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.75)
	tw.chain().tween_callback(ring.queue_free)

# ---------------- 出口 ----------------

func _continue() -> void:
	_go.disabled = true
	Audio.sfx("click")
	App.flush_announce()
	App.go(App.SCENE_MAP)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _go.disabled:
		_continue()
