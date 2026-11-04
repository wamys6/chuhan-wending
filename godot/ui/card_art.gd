## 缺图卡面的程序化占位（**兜底**，当前卡池 70 张已全部有立绘）
##
## 来历：卡池从 45 扩到 70 时新增的 24 张没有画。缺图不能留一块空白——
## 图鉴一屏十五张里有七张是空的，看起来像资源没加载完，而不是「设计如此」。
##
## 试过三版：随机墨点叠成灰团（放大像污渍）、斜扫笔触（像划痕）、
## 空画心加细框（干净，但缺图感反而更重）。最后落在「一个字」：
## 牌名首字用大字号淡墨压在画心上，读起来像令牌/签条，字够大也不会糊。
##
## 24 张已于 2026-11-03 补齐，`UiTheme.art_texture()` 一旦找到图就自动接管，
## 这个文件现在只在**新扩池的过渡期**生效。不要删：它是加卡不配图的永久兜底，
## 也是 `card_art_test` 的测试对象。
class_name CardArt
extends RefCounted

## 占位根的节点名：调用方与测试靠它分辨「这块是占位还是真立绘」
const NODE_NAME := "CardArtPlaceholder"

## 画心占卡面的比例：竖向只取上半，下半要留给名牌和数值
const HEART := Rect2(0.09, 0.075, 0.82, 0.60)

## 牌名去掉「兵·」这类前缀：GameData 里的名字已随语言切换，
## 所以中英模式下这里各自是「刑徒」和 “Convict”，不需要单独建表
static func subtitle_of(card_id: String) -> String:
	var c := GameData.card(card_id)
	if c.is_empty():
		return ""
	var nm := str(c.get("name", ""))
	var parts := nm.split("·")
	if parts.size() > 1:
		nm = parts[parts.size() - 1]
	return nm.strip_edges()

## 占位卡面本体。box 传容器的固定尺寸：card_view/unit_view 用各自的 SIZE，
## 图鉴详情用 290×360——都由调用方给准数，不依赖 anchors 的解析时机
static func placeholder(card_id: String, box: Vector2) -> Control:
	var root := Control.new()
	root.name = NODE_NAME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 纸色比卡面本体深半档：整屏看是一叠略旧的卡，而不是一排白洞
	var bg := ColorRect.new()
	bg.color = UiTheme.PAPER_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var word := subtitle_of(card_id)
	if word == "":
		return root

	var head := word.substr(0, 1).to_upper()

	# 字号跟着卡面走，且一定大于「糊」的临界——小卡上也有近半个卡宽
	var fs := int(clampf(minf(box.x * 0.44, box.y * 0.26), 11.0, 130.0))
	var l := UiTheme.label(head, fs, Color(UiTheme.INK, 0.28))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(box.x, fs * 1.3)
	# 行框比字面高（Noto Serif 约 1.3~1.4 em），居中只是「行框居中」，字形会偏上。
	# 0.53 是实测出来的字面中心相对 position 的偏移量（单位：字高）
	l.position = Vector2(0, box.y * (HEART.position.y + HEART.size.y * 0.5) - fs * 0.53)
	root.add_child(l)

	return root
