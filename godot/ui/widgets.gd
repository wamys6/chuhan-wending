## 界面通用件：宣纸底、标题、小标签、立绘背景、按钮行
##
## 这些是各屏共用的「视觉零件」，改一处全局生效，避免每个场景重复写样式。
class_name Widgets
extends RefCounted

const PAPER_HEX := "#f7f3e8"

## ---------------- 舞台对齐（16:9 / 21:9 的左右留白） ----------------
##
## 版式按 1440×900 设计，但 `stretch/aspect = expand` 在宽屏上会把画布撑得比它还宽
## （16:9 → 1638，21:9 → 2150）。做法是：**整屏内容整体右移，"多出来的那条"左右均分**。
## 于是所有「铺满屏幕」的元素（纸底、立绘底、遮罩、横幅）都不能再按 1440 版心铺，
## 必须自己向左补出那条边——统一走 fill_screen()，别各写各的 anchor。

const STAGE_W := 1440.0
const STAGE_H := 900.0

static func viewport_size() -> Vector2:
	var ml := Engine.get_main_loop() as SceneTree
	if ml == null or ml.root == null:
		return Vector2(STAGE_W, STAGE_H)
	return ml.root.get_visible_rect().size

## 舞台要右移多少：画布比 1440 宽出来的部分对半分（窄屏不左移，宁可裁）
static func stage_offset() -> float:
	return maxf(0.0, (viewport_size().x - STAGE_W) * 0.5)

## 把背景/遮罩类元素铺满整个可见区（而不是只铺 1440 版心）。
## 打上 bleed 标记，窗口尺寸变化时 App 会遍历场景重新铺一遍。
static func fill_screen(c: Control) -> void:
	c.set_meta("bleed", "all")
	c.position = Vector2(-stage_offset(), 0.0)
	c.size = viewport_size()

## 只横向铺满（固定高度的横幅、分隔线），纵向交给调用方
static func bleed_x(c: Control) -> void:
	c.set_meta("bleed", "x")
	c.position.x = -stage_offset()
	c.size.x = viewport_size().x

## 窗口尺寸变了（全屏开关）之后把场景里所有 bleed 元素重新铺满
static func refit(parent: Node) -> void:
	for child in parent.get_children():
		if child is Control and (child as Control).has_meta("bleed"):
			if str((child as Control).get_meta("bleed")) == "x":
				bleed_x(child)
			else:
				fill_screen(child)
		refit(child)

static func paper_bg(parent: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = UiTheme.PAPER
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_screen(bg)
	parent.add_child(bg)
	return bg

## 全屏立绘背景 + 可调的宣纸蒙版（关卡过场用）
static func art_bg(parent: Control, art_id: String, veil: float = 0.72) -> void:
	var tex := UiTheme.art_texture(art_id)
	if tex != null:
		var tr := UiTheme.texture_rect(tex, viewport_size())
		fill_screen(tr)
		parent.add_child(tr)
	var veil_rect := ColorRect.new()
	veil_rect.color = Color(UiTheme.PAPER.r, UiTheme.PAPER.g, UiTheme.PAPER.b, veil)
	veil_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_screen(veil_rect)
	parent.add_child(veil_rect)

## 全屏遮罩（弹窗压暗用）：跟着 fill_screen 走，不然宽屏下边上会留一条没压暗
static func scrim(parent: Control, color: Color) -> ColorRect:
	var dim := ColorRect.new()
	dim.color = color
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_screen(dim)
	parent.add_child(dim)
	return dim

static func title(text: String, size: int = 56, color: Color = UiTheme.INK) -> Label:
	var l := UiTheme.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func subtitle(text: String, size: int = 18) -> Label:
	var l := UiTheme.label(text, size, UiTheme.INK_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## 小标签（加成 / 军师 / 进度提示）
static func chip(text: String, bg: Color = UiTheme.PAPER_DEEP, fg: Color = UiTheme.INK_SOFT) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UiTheme.panel_style(bg, UiTheme.INK_SOFT, 12, 1)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", sb)
	var l := UiTheme.label(text, 15, fg)
	pc.add_child(l)
	return pc

## 卡面（复用 CardView，用于奖励三选一、牌组预览）
## 只读展示用的卡面（奖励、牌组、图鉴、选牌器）。
##
## **缩放必须绕左上角**（pivot = 0）：所有调用方都是按「左上角 + 宽×缩放」算位置的，
## 而 CardView 的 pivot 默认在中心（手牌扇形要绕底边转）。两种基准混用会让缩放后的
## 卡整体偏移「半个差值」：奖励页 1.3 倍时卡偏左 19px、高出容器 28px，看起来
## 就是三张卡跟下面的「选它」按钮对不齐（玩家反馈原话「战斗完的选牌 UI 没对齐」）。
static func card_view(card_id: String, scale: float = 1.0) -> Control:
	var c := CardView.new()
	var card: Dictionary = GameData.card(card_id).duplicate(true)
	card["uid"] = 0
	c.setup(card, card_id)
	if scale != 1.0:
		c.scale = Vector2(scale, scale)
		c.pivot_offset = Vector2.ZERO
	return c

## 一段可换行的正文
static func paragraph(text: String, size: int = 17, color: Color = UiTheme.INK_SOFT,
		width: float = 640.0) -> Label:
	var l := UiTheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l

## 淡入（入场动画统一入口）
static func fade_in(node: CanvasItem, delay: float = 0.0, dur: float = 0.25) -> void:
	if not Settings.motion:
		node.modulate.a = 1.0
		return
	node.modulate.a = 0.0
	var tw := node.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(node, "modulate:a", 1.0, dur)

## 从下方浮入
static func rise_in(node: Control, delay: float = 0.0, offset: float = 18.0) -> void:
	node.modulate.a = 1.0
	if not Settings.motion:
		return
	var target := node.position
	node.position = target + Vector2(0, offset)
	node.modulate.a = 0.0
	var tw := node.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(node, "position", target, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.3)

## ---------------- 暗角（难度压迫感） ----------------

static var _vig_cache: Dictionary = {}

## 径向暗角贴图：中心透明、四角染色，按颜色缓存。
## 取 128² 是有意的——铺满全屏后作为低对比渐变看不出像素块，而生成耗时只有
## 512² 的十六分之一（这里每次进择师页都要生成一次，别为看不出的精度付钱）。
static func vignette_tex(color: Color, size: int = 128) -> ImageTexture:
	var key := "%s|%d" % [color.to_html(), size]
	if _vig_cache.has(key):
		return _vig_cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size - 1, size - 1) * 0.5
	var max_d := center.length()
	for y in size:
		for x in size:
			var d := (Vector2(x, y) - center).length() / max_d
			# 从半径 42% 开始起雾，往外平方增长，四角最浓。
			# 起雾半径别取太大：55% 时只有最外圈一点点颜色，暗角会看不出存在感。
			var a := clampf((d - 0.42) / 0.58, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a * a * color.a))
	var tex := ImageTexture.create_from_image(img)
	_vig_cache[key] = tex
	return tex

## 铺一层暗角，返回 TextureRect（调用方可以后续调 modulate.a 做淡入）。
## strength 是四角的最大不透明度，0 表示不加（此时返回的节点也是空壳，方便统一处理）。
static func vignette(parent: Control, color: Color, strength: float) -> TextureRect:
	var tr := UiTheme.texture_rect(vignette_tex(Color(color.r, color.g, color.b, clampf(strength, 0.0, 1.0))),
		viewport_size())
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	fill_screen(tr)
	parent.add_child(tr)
	return tr

## ---------------- 边缘渐隐（把立绘化进纸面） ----------------

static var _fade_cache: Dictionary = {}

## 横向 0→1 的单色渐变，64×1 就够（拉伸后本来就是低对比过渡，看不出采样）
static func fade_tex(color: Color) -> ImageTexture:
	var key := color.to_html()
	if _fade_cache.has(key):
		return _fade_cache[key]
	var steps := 64
	var img := Image.create(steps, 1, false, Image.FORMAT_RGBA8)
	for i in steps:
		var a := float(i) / float(steps - 1)
		img.set_pixel(i, 0, Color(color.r, color.g, color.b, a))
	var tex := ImageTexture.create_from_image(img)
	_fade_cache[key] = tex
	return tex

## 一条横向渐隐带：从全透明渐变到 color（right_to_left 时反向）。
## 主菜单两侧立绘靠它去掉「贴上去的矩形」那种硬边——立绘本身的底色就是纸色，
## 平涂渐变与纸面完全同色，所以不会有色差。
static func edge_fade(parent: Control, color: Color, w: float, h: float,
		right_to_left: bool = false) -> TextureRect:
	var tr := UiTheme.texture_rect(fade_tex(color), Vector2(w, h))
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.flip_h = right_to_left
	parent.add_child(tr)
	return tr
