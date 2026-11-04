extends SceneTree
## 立绘矩形 / 版式边界回归测试
##
## 运行：godot --headless --path godot --script res://tests/art_rect_test.gd
##
## 为什么要有这一支：TextureRect 的最小尺寸默认等于纹理尺寸，**先赋 texture 再 set_size
## 时，小的 size 会被顶回原图尺寸**（我们的立绘都是 1024×1024）。代码读起来完全正常
## （size 明明写了 144/520/90），画面上却是「只看见原画左上角一小块」，而且不崩、不报错，
## 靠肉眼扫截图才抓得到。历史上踩过三处：
##   ① 事件页圆形插图 → 十个事件的插画全是一块空白宣纸（最严重，玩家一直看着它）
##   ② 主菜单两侧立绘 → 1024 见方硬顶，构图整体偏移
##   ③ 对战冲刺残影 / 阵亡碎片 → 残影和碎片实际是巨型贴图
## 这里把「成品界面里那几个 TextureRect 到底多大」钉住，同时钉住被边框切掉的那行文字。

var checks := 0
var failures := 0
var app: Node

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("  ✗ " + label + ("" if detail == "" else "  ← " + detail))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	app = root.get_node("App")
	I18n.ensure_loaded()
	Settings.ensure_loaded()
	GameData.ensure_loaded()

	print("· texture_rect 收口")
	_test_helper()
	print("· 舞台对齐（宽屏留白）")
	_test_stage()
	print("· 卡名不被文本宽度顶回")
	await _test_card_name()
	print("· 事件页插图")
	await _test_event()
	print("· 主菜单侧立绘")
	await _test_menu()
	print("· 结局页统计不被边框切")
	await _test_ending()

	Campaign._wipe_all()
	app.progress = {}
	app.stage = {}
	app.pending_event = {}
	await process_frame
	print("\n通过 %d 项，失败 %d 项" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)

# ---------------- 单元：UiTheme.texture_rect ----------------

func _test_helper() -> void:
	var tex: Texture2D = UiTheme.art_texture("ev_laozu")
	ok(tex != null, "事件立绘存在", "ev_laozu")
	if tex == null:
		return
	var tr := UiTheme.texture_rect(tex, Vector2(144, 144))
	ok(tr.size == Vector2(144, 144), "小尺寸不被纹理顶回", str(tr.size))
	ok(tr.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "按比例铺满（不变形）")
	ok(tr.mouse_filter == Control.MOUSE_FILTER_IGNORE, "不吃鼠标事件")

	# 阵亡碎片用的是 AtlasTexture：切片本身 341 见方，同样不许把 size 顶回去
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(Vector2.ZERO, tex.get_size() / 3.0)
	var sh := UiTheme.texture_rect(at, Vector2(30, 41))
	ok(sh.size == Vector2(30, 41), "切片尺寸不被切片原尺寸顶回", str(sh.size))

# ---------------- 事件页：圆里的插画要真的铺满 144 ----------------

func _test_event() -> void:
	Campaign.use_slot(0)
	app.progress = Campaign.start_run("liubang",
		(GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	# 固定用有立绘的事件：pick_event 是随机的，抽到还没配图的新事件
	# （16 个事件里后 6 个暂无 ev_ 图）会让「取到插图」这条假红
	var ev: Dictionary = Campaign.event_by_id("laozu")
	app.pending_event = ev
	var scene: Node = load("res://scenes/event.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var want: Texture2D = UiTheme.art_texture("ev_" + str(ev["id"]))
	var art: TextureRect = _find_tex_rect(scene, want)
	ok(art != null, "事件页取到了本事件的插画", str(ev["id"]))
	if art != null:
		ok(art.size == Vector2(144, 144),
			"圆形插图铺满 144（不是 1024 的原图尺寸）", str(art.size))
		var mask := art.get_parent() as Control
		ok(mask != null and mask.size == Vector2(144, 144), "遮罩容器尺寸正确")
		ok(mask != null and mask.clip_children == CanvasItem.CLIP_CHILDREN_ONLY,
			"遮罩按父节点形状裁剪（圆形）")
		_ok_bleed_bg(scene, "事件页")
	scene.queue_free()
	await process_frame
	app.pending_event = {}

	await _test_event_art_complete()
	await _test_event_no_art()

## 16 个事件必须全部有插画——曾经的「后 6 个暂无 ev_ 图」已经被补上了，
## 这条断言从此盯住「以后加事件别忘了配图」，缺一张就红。
func _test_event_art_complete() -> void:
	var missing: Array = []
	for e in GameData.events:
		if UiTheme.art_texture("ev_" + str(e["id"])) == null:
			missing.append(str(e["id"]))
	ok(GameData.events.size() == 16, "事件数 16", str(GameData.events.size()))
	ok(missing.is_empty(), "16 个事件全部有插画", str(missing))

## 缺图兜底这条代码路径仍然要在：用合成事件测，不依赖真实数据里「有没有没配图的」
func _test_event_no_art() -> void:
	var fake := {
		"id": "__probe_no_art", "name": "无图事件", "glyph": "测",
		"text": "这条只为验证兜底路径。",
		"options": [{"label": "略过", "hint": "", "fx": {}}],
	}
	app.pending_event = fake
	ok(UiTheme.art_texture("ev_" + str(fake["id"])) == null, "合成事件确实没有立绘")
	var scene: Node = load("res://scenes/event.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	ok(_find_label_text(scene, str(fake["glyph"])) != null, "缺图事件显示单字 glyph 兜底")
	scene.queue_free()
	await process_frame
	app.pending_event = {}

func _find_label_text(node: Node, text: String) -> Label:
	if node is Label and str((node as Label).text) == text:
		return node as Label
	for c in node.get_children():
		var hit := _find_label_text(c, text)
		if hit != null:
			return hit
	return null

# ---------------- 主菜单：两侧立绘 520×780 ----------------

func _test_menu() -> void:
	var keep: Dictionary = app.progress
	app.progress = {}
	var scene: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var art: TextureRect = _find_tex_rect(scene, UiTheme.art_texture("liubang"))
	ok(art != null, "主菜单取到了主将立绘")
	if art != null:
		ok(art.size == Vector2(520, 900), "侧立绘 520×900（1024 会顶穿版心）", str(art.size))
		ok(art.position.x < 0.0, "左侧立绘出血到画外（不压版心）", str(art.position))
		_ok_bleed_bg(scene, "主菜单")
	scene.queue_free()
	await process_frame
	app.progress = keep

# ---------------- 结局页：六行纸面不能被下边框切 ----------------

func _test_ending() -> void:
	var keep: Dictionary = app.progress
	app.progress = Campaign.start_run("liubang",
		(GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	for s in Campaign.stages():
		(app.progress["cleared"] as Array).append(str(s["id"]))
	var scene: Node = load("res://scenes/ending.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	# 「生涯作战」是纸面的最后一行：它必须完整落在面板里（原来 250 高的面板装不下）
	var career: Label = _find_label(scene, "生涯")
	ok(career != null, "结局页有「生涯作战」一行")
	if career != null:
		var panel := career.get_parent() as Control
		ok(panel != null, "生涯行在纸面面板里")
		if panel != null:
			var row_bottom: float = career.position.y + career.get_combined_minimum_size().y
			ok(row_bottom <= panel.size.y,
				"最后一行完整落在纸面内（不被边框切）",
				"行底 %.0f / 面板 %.0f" % [row_bottom, panel.size.y])
			# 面板之下还有「已解锁下一级心魔」提示与两个按钮，别互相压
			var hint: Label = _find_label(scene, "已解锁下一级心魔")
			if hint != null:
				var panel_bottom: float = panel.position.y + panel.size.y
				ok(hint.position.y >= panel_bottom, "解锁提示在纸面之下",
					"提示 %.0f / 面板底 %.0f" % [hint.position.y, panel_bottom])
	scene.queue_free()
	await process_frame
	app.progress = keep


# ---------------- 舞台对齐：宽屏下背景必须铺满整屏 ----------------

func _test_stage() -> void:
	var vp := Widgets.viewport_size()
	# 测试环境就是设计分辨率，偏移应为 0（有偏移说明常量或算法被改坏）
	ok(Widgets.stage_offset() == 0.0, "设计分辨率下不偏移", str(Widgets.stage_offset()))

	var c := ColorRect.new()
	Widgets.fill_screen(c)
	ok(c.position == Vector2.ZERO, "fill_screen 起点落在屏幕原点", str(c.position))
	ok(c.size == vp, "fill_screen 铺满可见区", str(c.size))
	ok(str(c.get_meta("bleed", "")) == "all", "fill_screen 打上 bleed 标记")

	var band := ColorRect.new()
	band.size = Vector2(1440, 200)
	Widgets.bleed_x(band)
	ok(band.size == Vector2(vp.x, 200), "bleed_x 只铺横向、保留高度", str(band.size))
	ok(str(band.get_meta("bleed", "")) == "x", "bleed_x 标记为 x")
	c.free()
	band.free()

## 每屏都必须有一个「铺满整屏」的底：换成 anchor 就不会跟着舞台位移走，
## 宽屏下左边会留一条没铺到的亮带
func _ok_bleed_bg(scene: Node, label: String) -> void:
	var vp := Widgets.viewport_size()
	var hits: Array = []
	_collect_bleed(scene, hits)
	ok(hits.size() > 0, "%s 有铺满整屏的背景/遮罩" % label)
	var all_cover := true
	for n in hits:
		var c := n as Control
		if str(c.get_meta("bleed")) == "all":
			if c.position != Vector2.ZERO or c.size != vp:
				all_cover = false
	ok(all_cover, "%s 的整屏背景几何正确" % label, str(hits.size()))

func _collect_bleed(n: Node, out: Array) -> void:
	if n is Control and (n as Control).has_meta("bleed"):
		out.append(n)
	for c in n.get_children():
		_collect_bleed(c, out)


# ---------------- 卡名 Label：同一个坑的第二次 ----------------

## Label 的最小尺寸默认等于整句文本宽度，**先设 size 会被顶回**；
## 而 clip_text = true 时最小尺寸才是 0。于是「先 set_size 再开 clip」等于没开——
## 29 个字符的英文卡名会把 124 宽的 Label 顶成 230，名字画出卡外压到邻牌上。
## 中文卡名短，这个 bug 只在英文化之后才看得见。
func _test_card_name() -> void:
	var host := Control.new()
	root.add_child(host)
	var before := I18n.lang
	I18n.set_lang_soft(I18n.EN)

	# 最长的一条：General · Warlord of the Dead（29 字符）
	var c: Dictionary = GameData.card("n_jiang2").duplicate()
	c["uid"] = 1
	c["baseId"] = "n_jiang2"
	var v := CardView.new()
	v.setup(c)
	host.add_child(v)
	var nl: Label = _find_label(v, "Warlord")
	ok(nl != null, "找到卡名 Label")
	if nl != null:
		ok(nl.size.x <= CardView.SIZE.x - 4.0 + 0.01, "卡名 Label 不被文本宽度顶回", str(nl.size))
		var fs := nl.get_theme_font_size("font_size")
		var w := UiTheme.font().get_string_size(nl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ok(w <= nl.size.x + 0.5, "最长卡名在该字号下真的放得下（%d 号 %.0fpx）" % [fs, w],
			"%.0f vs %.0f" % [w, nl.size.x])
		ok(fs >= 8, "字号不低于 8（再小就没人看得见）", str(fs))

	# 中文短名不该被误伤：仍走 14 号
	I18n.set_lang_soft(I18n.ZH)
	var c2: Dictionary = GameData.card("n_bing1").duplicate()
	c2["uid"] = 2
	c2["baseId"] = "n_bing1"
	var v2 := CardView.new()
	v2.setup(c2)
	host.add_child(v2)
	var nl2: Label = _find_label(v2, "新卒")
	if nl2 != null:
		ok(nl2.get_theme_font_size("font_size") == 14, "中文短名仍是 14 号",
			str(nl2.get_theme_font_size("font_size")))
	await process_frame
	I18n.set_lang_soft(before)
	host.free()

# ---------------- 工具 ----------------

func _find_tex_rect(n: Node, want: Texture2D) -> TextureRect:
	if want != null and n is TextureRect and (n as TextureRect).texture == want:
		return n
	for c in n.get_children():
		var hit := _find_tex_rect(c, want)
		if hit != null:
			return hit
	return null

func _find_label(n: Node, needle: String) -> Label:
	if n is Label and (n as Label).text.contains(needle):
		return n
	for c in n.get_children():
		var hit := _find_label(c, needle)
		if hit != null:
			return hit
	return null
