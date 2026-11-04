## 卡面关键词小印
##
## 卡面只有 128×186，位置被分完了：费用圆占左上、攻血章占下方两侧、名字条占底部 30px。
## 六个关键词（死战/守御/冲锋/迂回/远程/连击）原本只能靠悬停浮层读文本——
## 1.2 的死战专精要按「牌组里死战牌占比」判档，玩家在手里数不出哪些是死战牌，
## 机制就等于隐形。所以要一枚一眼能认的标记。
##
## 位置放右上角：那是最空的一块（费用圆在对称的左上）。素材规范要求头部落在
## 纵向 15%~30%（手牌上 y≈28~56），20px 的印压在 y=4~24，不会挡住脸。
## 实测卡池最多两个关键词（单关键词 36 张、双关键词 9 张），一行两枚够用，不换行。
##
## 三种印面用来分类。三档都是**深底 + 纸色字**，靠色相分：朱砂 / 墨 / 靛。
##   seal   朱砂（死战：亡命、见血，全场唯一一档强提示）
##   ink    墨（守御：厚重、挡在前）
##   indigo 靛（冲锋/迂回/远程/连击：战术动作）
## 为什么不是「亮底暗字」或「空心印」——试过两版都不行：
##   ① 空心印（纸底墨框）：20px 上看着雅，缩到场上单位的 14px 时框吃掉半个字，
##      压在浅色立绘上直接消失；
##   ② 赭石亮底配墨字：明度差只有 3~5:1，14px 的汉字笔画糊成一团，
##      而朱砂/墨配纸白字是 8~10:1，同样字号清清楚楚。
## 结论是深底色块 + 亮字。三色也正好是中国印谱里实际有的三种印泥色（朱/墨/靛）。
##
## 印面印中文单字，**刻意不翻译**：20px 方印里塞 "LS"/"GU" 这种缩写，缩到卡面
## 小卡上必然糊成一团；印章本身是图形语言，规则文本在悬停浮层里是完整中英双语。
## `i18n_test` 的「单个汉字＝朱砂印章式徽记」白名单也是为此存在的。
class_name KeywordStamp
extends RefCounted

## 顺序即排布顺序（从左往右）：最影响构筑判断的放最左
const STAMPS := [
	{"key": "deathrattle", "zh": "死", "face": "seal"},
	{"key": "taunt", "zh": "守", "face": "ink"},
	{"key": "charge", "zh": "冲", "face": "indigo"},
	{"key": "flank", "zh": "迂", "face": "indigo"},
	{"key": "ranged", "zh": "远", "face": "indigo"},
	{"key": "combo", "zh": "连", "face": "indigo"},
]

## 这张卡该盖哪几枚。数据里没有 keywords 数组，关键词是从机制字段推的：
## taunt/charge/flank/ranged 是 true，deathrattle/combo 是效果对象（非 null 即有关键词）
static func of(card: Dictionary) -> Array:
	var out: Array = []
	for s in STAMPS:
		if _has(card, str(s["key"])):
			out.append(s)
	return out

## 一行印的容器。box 是单枚边长，调用方决定（手牌 20、场上单位 16）。
## 容器宽度按实际枚数算好，调用方右对齐直接 position.x = 右边距 − root.size.x
static func row(card: Dictionary, box: float = 20.0, gap: float = 3.0) -> Control:
	var root := Control.new()
	root.name = "keyword_stamps"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var items := of(card)
	if items.is_empty():
		root.size = Vector2.ZERO
		return root
	var x := 0.0
	for st in items:
		var s := _stamp(str(st["zh"]), str(st["face"]), box)
		s.position = Vector2(x, 0.0)
		root.add_child(s)
		x += box + gap
	root.size = Vector2(x - gap, box)
	return root

## 单枚印。box 同时决定圆角、边框与字号（20 → 3px 圆角 / 12 号字）
static func _stamp(word: String, face: String, box: float) -> Control:
	var p := Panel.new()
	p.size = Vector2(box, box)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 供测试与调试辨识：「这枚印是哪一派」
	p.set_meta("stamp_word", word)
	p.set_meta("stamp_face", face)

	var bg := UiTheme.INK
	var fg := UiTheme.PAPER
	match face:
		"seal":
			bg = Color(UiTheme.SEAL.r, UiTheme.SEAL.g, UiTheme.SEAL.b, 0.92)
		"indigo":
			# 靛青：比墨冷、比朱砂沉，是三档里最安静的一档。
			# 深底才扛得住 14px 的汉字（亮底暗字的笔画会糊）
			bg = Color(0.15, 0.26, 0.37, 0.92)
		_:
			bg = Color(0.11, 0.10, 0.09, 0.88)
	# 印是方的：2px 圆角只是把抗锯齿的硬角磨一下，再圆就像现代 UI 的圆角卡片了
	p.add_theme_stylebox_override("panel",
		UiTheme.panel_style(bg, Color(0, 0, 0, 0), int(maxf(2.0, box * 0.11)), 0))

	var l := Label.new()
	# 不走 I18n.T：印面是图形，切语言不换字
	l.text = word
	l.add_theme_font_override("font", UiTheme.font())
	l.add_theme_font_size_override("font_size", int(roundf(box * 0.62)))
	l.add_theme_color_override("font_color", fg)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

static func _has(card: Dictionary, key: String) -> bool:
	if not card.has(key):
		return false
	var v = card[key]
	# 布尔型关键词（taunt/charge/…）看真假；对象型（deathrattle/combo）非 null 即算
	if typeof(v) == TYPE_BOOL:
		return bool(v)
	return v != null
