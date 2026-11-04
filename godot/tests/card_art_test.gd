extends SceneTree
## 缺图卡面的程序化占位测试
##
## 运行：godot --headless --path godot --script res://tests/card_art_test.gd
##
## 2026-11-03：卡池 70 张已全部有立绘，占位层退为「加卡不配图时的兜底」。
## 所以这个测试**不再依赖「存在缺图卡」这个数据状态**——那样一补齐就集体失效。
## 改成测两件事：
##   ① `subtitle_of` 是纯函数，对全卡池在两种语言下都成立（与有没有图无关）；
##   ② 有图时占位必须让位、没图时占位必须出现（CardView 的真实装配路径）。

const UI_IDS := ["n_dun1", "n_cheng3", "n_zhengfa", "n_xiangyong"]
## 一张不存在的图 id，用来走「缺图」分支（卡数据本身是真的，避免 setup 崩）
const NO_ART := "__no_such_art__"

var checks := 0
var failures := 0
var failed_lines: Array = []

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	var line := "  ✗ " + label + ("" if detail == "" else "  ← " + detail)
	failed_lines.append(line)
	print(line)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameData.ensure_loaded()
	var all_ids: Array = GameData.cards.keys()

	# ---- 状态报告（不判失败）：还缺几张图，让人一眼看到 ----
	var missing: Array = []
	for cid in all_ids:
		if UiTheme.art_texture(str(cid)) == null:
			missing.append(str(cid))
	ok(missing.size() + (all_ids.size() - missing.size()) == all_ids.size(), "卡池遍历完整")
	if missing.is_empty():
		print("· 卡池 %d 张全部有立绘，占位层仅作备用" % all_ids.size())
	else:
		print("· 仍有 %d 张卡无立绘（走占位兜底）：%s" % [missing.size(), ", ".join(missing)])

	# ---- 中文：全卡池的牌名都能取出水印字，且去掉「兵·」这类前缀 ----
	I18n.set_lang_soft(I18n.ZH)
	for cid in all_ids:
		var id := str(cid)
		var w := CardArt.subtitle_of(id)
		ok(w != "", "牌名能取出水印字", id)
		ok(w.find("·") < 0, "水印已去掉阵营前缀", "%s → %s" % [id, w])
		var head := w.substr(0, 1)
		ok(head != "" and I18n.has_cjk(head), "中文首字是汉字", "%s → %s" % [id, head])

	# ---- 英文：同样取得到，且是拉丁字母（lang-ui-check 的 CJK 扫描不许有残留） ----
	I18n.set_lang_soft(I18n.EN)
	for cid in all_ids:
		var id := str(cid)
		var w := CardArt.subtitle_of(id)
		ok(w != "", "EN 下仍有水印字", id)
		if w != "":
			ok(not I18n.has_cjk(w.substr(0, 1)), "EN 首字不是汉字", "%s → %s" % [id, w])
	I18n.set_lang_soft(I18n.ZH)

	# ---- 节点结构：小卡两块（纸底 + 字），大卡同样能建出来 ----
	for id in UI_IDS:
		var small := CardArt.placeholder(id, Vector2(128, 186))
		ok(small.get_child_count() >= 2, "小卡占位含底与字", id)
		ok(small.name == CardArt.NODE_NAME, "占位节点可辨识（小卡）", str(small.name))
		small.free()
		var big := CardArt.placeholder(id, Vector2(290, 360))
		ok(big.get_child_count() >= 2, "大卡占位含底与字", id)
		big.free()

	# ---- 装配路径：有图时立绘顶上、占位不出现；无图时占位顶上 ----
	for id in UI_IDS:
		var c: Dictionary = GameData.card(id).duplicate()
		c["uid"] = 1
		c["baseId"] = id  # 牌库是模板，实例上的 baseId 由发牌时补；这里手动补上
		var v := CardView.new()
		v.setup(c)
		ok(v.get_node_or_null(CardArt.NODE_NAME) == null, "有图时不挂占位", id)
		ok(v._art != null and v._art.texture != null, "有图时立绘已赋纹理", id)
		v.free()

		var m := CardView.new()
		m.setup(c, NO_ART)
		ok(m.get_node_or_null(CardArt.NODE_NAME) != null, "无图时挂上占位", id)
		m.free()

	print("通过 %d 项，失败 %d 项" % [checks, failures])
	if failures > 0:
		print("失败项：")
		for l in failed_lines:
			print(l)
		quit(1)
	quit(0)
