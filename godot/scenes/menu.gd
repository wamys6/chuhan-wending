## 主菜单：左右立绘氛围 + 标题 + 入口按钮
##
## 界面全部代码构建（tscn 只做入口），方便用参数微调而不用开编辑器。
extends Control

const BTN_W := 340.0
const BTN_H := 56.0

var _btns: Array = []

func _ready() -> void:
	theme = UiTheme.build()
	GameData.ensure_loaded()
	_build()
	_animate_in()

func _build() -> void:
	Widgets.paper_bg(self)
	_side_art("liubang", -150.0, 520.0, true)
	_side_art("xiangyu", 1070.0, 520.0, false)

	# 中间纸面：压住两侧立绘的内缘，保证文字干净
	var mid := ColorRect.new()
	mid.color = Color(UiTheme.PAPER.r, UiTheme.PAPER.g, UiTheme.PAPER.b, 0.93)
	mid.position = Vector2(400, 0)
	mid.size = Vector2(640, 900)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mid)

	# 楚河汉界：一条暗红细线
	var seam := ColorRect.new()
	seam.color = Color(UiTheme.SEAL.r, UiTheme.SEAL.g, UiTheme.SEAL.b, 0.5)
	seam.position = Vector2(719, 118)
	seam.size = Vector2(2, 74)
	seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seam)

	# 英文标题长得多，折成两行并缩小；中文维持单行大字
	var title := Widgets.title("楚 汉 · 问 鼎", 62)
	title.position = Vector2(400, 210)
	title.size = Vector2(640, 80)
	if I18n.is_en():
		title.text = "%s\n%s" % [I18n.T("楚汉"), I18n.T("问鼎")]
		title.add_theme_font_size_override("font_size", 40)
		title.position = Vector2(400, 186)
		title.size = Vector2(640, 116)
	add_child(title)
	title.name = "Title"

	var sub := Widgets.subtitle("楚 河 汉 界 · 兵 车 对 垒 · 逐 鹿 中 原", 17)
	sub.position = Vector2(400, 310 if I18n.is_en() else 300)
	sub.size = Vector2(640, 30)
	add_child(sub)
	sub.name = "Sub"

	# 入口按钮：主入口竖排，图鉴/设置作为次要入口并排放在最下
	var specs := _entry_labels()
	var y := 396.0
	var halves: Array = []
	for spec in specs:
		if bool(spec.get("half", false)):
			halves.append(spec)
			continue
		var b := UiTheme.button(str(spec["text"]), bool(spec.get("primary", false)))
		b.position = Vector2(720 - BTN_W * 0.5, y)
		b.size = Vector2(BTN_W, BTN_H)
		b.add_theme_font_size_override("font_size", 22)
		var action: Callable = spec["action"]
		b.pressed.connect(action)
		add_child(b)
		_btns.append(b)
		y += BTN_H + 16

	var half_w := (BTN_W - 16) * 0.5
	for i in halves.size():
		var spec: Dictionary = halves[i]
		var hb := UiTheme.button(str(spec["text"]), false)
		hb.position = Vector2(720 - BTN_W * 0.5 + i * (half_w + 16), y)
		hb.size = Vector2(half_w, BTN_H)
		hb.add_theme_font_size_override("font_size", 19)
		var act: Callable = spec["action"]
		hb.pressed.connect(act)
		add_child(hb)
		_btns.append(hb)

	# 数字从数据里算：以前写死「8 关 · 卡池 46 张」，1.1 扩池到 70 之后一直没跟上
	var foot := Widgets.subtitle("战役：%d 关 · 卡池 %d 张 · v0.9.1 (Godot)" % [
		GameData.stages.size(), GameData.cards.size()], 14)
	foot.position = Vector2(400, 828)
	foot.size = Vector2(640, 24)
	add_child(foot)

func _entry_labels() -> Array:
	var out: Array = []
	var active := Campaign.active_slot()
	var prog := Campaign.load_slot(active)
	if not prog.is_empty():
		var cleared := int(prog["cleared"].size())
		var total := Campaign.stages().size()
		var txt := "继 续 战 役  ·  %d / %d" % [cleared, total]
		if Campaign.is_finished(prog):
			txt = "战 役 已 终 · 重 温 垓 下"
		out.append({"text": txt, "primary": true, "action": func (): App.enter_slot(active)})
	else:
		out.append({"text": "开 始 战 役", "primary": true, "action": func (): App.enter_slot(active)})
	out.append({"text": "存 档 位", "action": func (): App.go(App.SCENE_SLOTS)})
	out.append({"text": "快 速 开 战", "action": func (): App.quick_battle()})
	out.append({"text": "联 机 对 战", "action": func (): App.open_lobby()})
	out.append({"text": "图 鉴", "half": true, "action": func (): App.go(App.SCENE_CODEX)})
	out.append({"text": "设 置", "half": true, "action": func (): App.toggle_settings()})
	out.append({"text": "退 出", "action": func (): get_tree().quit()})
	return out

## 两侧立绘：淡化处理，避免抢中间文字的视觉重心。
## 上下出血到画外、内缘再压一条渐隐带——只把图摆上去的话，边缘是一条笔直的硬线，
## 看起来像贴了张明信片；化进纸面之后才是「背景」。
func _side_art(art_id: String, x: float, w: float, inner_right: bool) -> void:
	var tex := UiTheme.art_texture(art_id)
	if tex == null:
		return
	var tr := UiTheme.texture_rect(tex, Vector2(w, 900.0))
	tr.position = Vector2(x, 0)
	tr.modulate = Color(0.97, 0.95, 0.9, 0.62)
	add_child(tr)
	var fade_w := 200.0
	var fade := Widgets.edge_fade(self, UiTheme.PAPER, fade_w, 900.0, not inner_right)
	fade.position = Vector2((x + w - fade_w) if inner_right else x, 0)

func _animate_in() -> void:
	var title := get_node_or_null("Title") as Control
	var sub := get_node_or_null("Sub") as Control
	if title:
		title.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(title, "modulate:a", 1.0, 0.7)
	if sub:
		Widgets.rise_in(sub, 0.25, 12.0)
	for i in _btns.size():
		Widgets.rise_in(_btns[i], 0.36 + i * 0.07, 16.0)
