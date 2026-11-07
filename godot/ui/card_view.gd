## 手牌卡片视图（卡面立绘 + 费用 + 名称 + 攻血）
class_name CardView
extends Control

## 左键点牌：把「点了哪张」交给场景层处理（本类只管画，不管规则）
signal clicked(uid: int)

const SIZE := Vector2(128, 186)
## 关键词小印边长。18（两枚加间距占 39/128）是「认得出字、又不抢立绘」的折中值；
## 20 时两枚印占满卡宽三分之一，在手里比立绘还抢眼
const STAMP_BOX := 18.0
## 牌名墨条高度。一行 12px 行高 ~16，两行要 32；取 34 给上下各 1px 余量。
## 立绘因此少 4px（156 → 152），换来英文 23 张长名从 8px 变 12px。
const NAME_BAND_H := 38.0

var card: Dictionary = {}
var _art: TextureRect
var _frame: Panel
var _glow: Panel
var _cost_bg: Panel
var _cost_label: Label
var _name_label: Label
var _atk_label: Label
var _hp_label: Label
var _playable := false
var _move_tw: Tween

func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 扇形旋转与悬停放大都绕底边中点：牌像"握在手里"，下端固定、上端散开
	pivot_offset = Vector2(SIZE.x * 0.5, SIZE.y)

## 排布动画统一走这里：先 kill 旧 tween，否则悬停与重排的 tween 同时改 position 会抖
func move_to(pos: Vector2, rot: float, sc: float, dur: float = 0.16) -> void:
	if _move_tw != null and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = create_tween().set_parallel(true)
	_move_tw.tween_property(self, "position", pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tw.tween_property(self, "rotation_degrees", rot, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tw.tween_property(self, "scale", Vector2(sc, sc), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## 点击出牌。子节点全是 MOUSE_FILTER_IGNORE，事件会落到这一层
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		clicked.emit(int(card.get("uid", 0)))

func setup(c: Dictionary, art_id: String = "") -> void:
	card = c
	name = "card_" + str(c.get("uid", 0))

	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var cid := art_id if art_id != "" else str(c["baseId"])
	var tex := UiTheme.art_texture(cid)
	if tex != null:
		_art.texture = tex
	add_child(_art)
	# 还没画立绘的卡顶一张墨纹占位（CardArt），别在手牌里留一块空白
	if tex == null:
		add_child(CardArt.placeholder(cid, SIZE))

	_frame = Panel.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.panel_style(Color(0, 0, 0, 0), UiTheme.INK, 4, 2)
	# 底边加粗到 4px：宣纸的裁切厚度，牌才不像贴在屏幕上的贴纸
	sb.border_width_bottom = 4
	_frame.add_theme_stylebox_override("panel", sb)
	add_child(_frame)

	# 可出牌的边光：外扩 4px 的金线。金色是全局「可操作」语义色（同可攻击单位、落点列）
	_glow = Panel.new()
	_glow.position = Vector2(-4, -4)
	_glow.size = SIZE + Vector2(8, 8)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.add_theme_stylebox_override("panel",
		UiTheme.panel_style(Color(0, 0, 0, 0), Color(UiTheme.GOLD, 0.92), 9, 2))
	_glow.visible = false
	add_child(_glow)

	# 费用：左上朱砂圆
	_cost_bg = Panel.new()
	_cost_bg.position = Vector2(-6, -6)
	_cost_bg.size = Vector2(30, 30)
	_cost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb := UiTheme.panel_style(UiTheme.SEAL, UiTheme.PAPER, 15, 2)
	_cost_bg.add_theme_stylebox_override("panel", csb)
	add_child(_cost_bg)

	_cost_label = UiTheme.label(str(int(c["cost"])), 16, UiTheme.PAPER)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_bg.add_child(_cost_label)

	# 名称：底部墨条。
	# 30 只能放一行 12px（行高 16）；两行要 32，实测第二行会被裁掉，所以取 34。
	# 代价是立绘少 4px（156 → 152），肉眼看不出来；换来英文 23 张长名从 8px 变 12px。
	var band := Panel.new()
	band.position = Vector2(0, SIZE.y - NAME_BAND_H)
	band.size = Vector2(SIZE.x, NAME_BAND_H)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := UiTheme.panel_style(Color(0.11, 0.10, 0.09, 0.82), Color(0, 0, 0, 0), 0, 0)
	band.add_theme_stylebox_override("panel", bsb)
	add_child(band)

	var shown := I18n.T(str(c["name"]))
	var name_style := _name_layout(shown)
	_name_label = UiTheme.label(str(name_style["text"]), int(name_style["font"]), UiTheme.PAPER)
	# **顺序要紧**：Label 的最小尺寸默认等于整句文本宽度，先设 size 会被顶回
	# （「General · Warlord of the Dead」29 字符把 124 顶成 230，名字就画出卡外压到邻牌）。
	# 而 clip_text = true 时最小尺寸才是 0，所以必须先开 clip 再设 size。
	# 这是 TextureRect「先赋纹理再 set_size 会被顶回」的同一个坑，换成 Label 又来一次。
	# 两行排版不能开 clip（clip 只按单行算，第二行会被切掉），但两行的最小宽度
	# 是「较长那一行」，本来就不超过 124，不存在顶回问题。
	var two := bool(name_style["two"])
	_name_label.clip_text = not two
	if not two:
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.position = Vector2(2, SIZE.y - NAME_BAND_H)
	_name_label.size = Vector2(SIZE.x - 4, NAME_BAND_H)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	if c["type"] == "piece":
		_atk_label = _corner_label(str(int(c["atk"])), Vector2(2, SIZE.y - 62), Color("#f0d48a"))
		_hp_label = _corner_label(str(int(c["hp"])), Vector2(SIZE.x - 30, SIZE.y - 62), Color("#e8897e"))

	# 关键词小印（右上角，与左上费用圆对称）。卡面原本完全不写关键词，死战/守御
	# 只能靠悬停浮层读——1.2 的死战专精按「牌组里死战牌占比」判档，没有这枚印
	# 玩家根本数不出手里有几张死战牌
	var stamps := KeywordStamp.row(c, STAMP_BOX, 3.0)
	if stamps.size.x > 0.0:
		stamps.position = Vector2(SIZE.x - 4.0 - stamps.size.x, 4.0)
		add_child(stamps)

## 卡名过长时缩小字号。不按字符数猜——中文一字约 1em、英文一个字母约 0.5em，
## 「萧何·粮草」6 字和「Xiao He · Grain Convoy」22 字符完全不是一回事。
## 直接拿真实字体量：从 14 号往下缩，量到放得下为止（下限 9 号，
## 还放不下就交给 `text_overrun_behavior` 收省略号，全名在悬停浮层里）
## 卡面牌名排版：先试单行；单行放不下就按「 · 」断成两行，最后才缩字号。
##
## 英文卡名比中文长一倍：78 张里 15 张单行要缩到 ≤10px（1366×768 下不到 8.5px，等于看不见）。
## 而「类型 · 名字」这种结构天生可以在 · 处断开，两行 11~12px 比一行 8px 好读得多。
## 断行只在「两半都放得下」时才用；断不了才回落到缩字号（8 是硬下限，再长就省略号）。
static func _name_layout(text: String) -> Dictionary:
	var f := UiTheme.font()
	var box := SIZE.x - 4.0
	if f == null:
		return {"text": text, "font": 10, "two": false}
	for fs in [14, 13, 12]:
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= box:
			return {"text": text, "font": fs, "two": false}
	var parts := text.split(" · ")
	if parts.size() == 2:
		var a: String = parts[0]
		var b: String = parts[1]
		for fs in [12, 11, 10]:
			# 行高也要过，而且要留 4px 呼吸：`<=` 会让两行正好填满墨条、字贴着下沿，
			# 看起来就是「被切了」（实测 11px 两行 = 34，正好等于 34 的墨条高）
			var fits_h := f.get_height(fs) * 2.0 + 4.0 <= NAME_BAND_H
			var fits_w := f.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= box \
				and f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= box
			if fits_h and fits_w:
				return {"text": a + "\n" + b, "font": fs, "two": true}
	for fs in [12, 11, 10, 9, 8]:
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= box:
			return {"text": text, "font": fs, "two": false}
	return {"text": text, "font": 8, "two": false}

func _corner_label(text: String, pos: Vector2, color: Color) -> Label:
	var l := UiTheme.label(text, 16, color)
	l.position = pos
	l.size = Vector2(28, 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.position = pos
	bg.size = Vector2(28, 28)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.11, 0.10, 0.09, 0.8), Color(0, 0, 0, 0), 14, 0))
	add_child(bg)
	add_child(l)
	return l

## 费用不够 / 列满时压暗，并给出「不可出」的视觉
##
## **不做「状态没变就跳过」的优化**：`_playable` 的初值是 false，但 modulate 初值是
## 全白——一旦这里 early-return，新抽到的手牌就永远不会被压暗，看起来「张张都能出」，
## 而真正的可出牌金边又被一堆同样亮的牌淹掉（玩家反馈「点数够的牌不高亮」）。
## 这个函数只改 modulate 和 glow.visible，10 张牌重画一次的成本远小于一次误判。
func set_playable(on: bool) -> void:
	_playable = on
	modulate = Color(1, 1, 1, 1) if on else Color(0.62, 0.6, 0.58, 0.9)
	if _glow != null:
		_glow.visible = on

func set_selected(on: bool) -> void:
	if _frame == null:
		return
	var sb := UiTheme.panel_style(Color(0, 0, 0, 0), UiTheme.GOLD if on else UiTheme.INK, 4, 3 if on else 2)
	_frame.add_theme_stylebox_override("panel", sb)

## 切语言后就地换名字（state 里的卡牌副本已由 I18n.localize_state 更新）
func refresh_text() -> void:
	if _name_label != null and not card.is_empty():
		# 切语言等于换了一串完全不同宽度的字，排版（字号 / 断行）要整块重算
		var style := _name_layout(I18n.T(str(card.get("name", ""))))
		var two := bool(style["two"])
		_name_label.text = str(style["text"])
		_name_label.add_theme_font_size_override("font_size", int(style["font"]))
		_name_label.clip_text = not two
		_name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if two \
			else TextServer.OVERRUN_TRIM_ELLIPSIS
		_pin_name_size()

## 把牌名 Label 的尺寸钉回墨条大小。
##
## **入树之后必须再钉一次**：建节点时它还没挂主题，最小尺寸按引擎默认字体（16px）算，
## 两行名（「General\nWarlord of the Dead」）会把 124×38 顶成 157×47.67 —— 名字于是
## 右移 16px、下移 5px、还压出墨条下沿。挂上主题后最小值回落成 108×33.7，但尺寸一旦
## 被顶大就不会自己回去。单行那条因为开着 clip（最小宽度 1）不受影响。
## `art_rect_test` 的「卡名 Label 不被文本宽度顶回」钉的就是这条。
func _pin_name_size() -> void:
	if _name_label != null:
		_name_label.size = Vector2(SIZE.x - 4, NAME_BAND_H)

func _ready() -> void:
	_pin_name_size()
