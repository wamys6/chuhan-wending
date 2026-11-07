## 通用选牌层：事件「得牌 / 删牌」与奖励页「不取牌、改删一张」共用。
##
## 为什么抽成一层：这三处都要「暗底 + 网格铺牌 + 选中态 + 确认」，各写一遍必然漂移
## ——reward 那份最初只支持删一张，事件那份干脆没实现（见下），同一个需求写了三遍
## 就会有两个是错的。
##
## 布局参数都是被踩出来的：10 列是为了牌组满 28 张时排三行不溢出面板；
## 缩放随张数自适应——事件得牌只有 3 张，用 0.62 会缩成一小撮挤在中间，
## 而删牌要铺 20 张，必须压到 0.76 才排得下（1.35 是奖励页选牌的大小）。
##
## 用法：
##   CardPicker.open(self, {
##       "title": "收 入 牌 组", "hint": "点选要收的牌",
##       "cards": ids, "mode": "add", "count": 2, "confirm": "收 下",
##       "on_done": func (ids: Array): ...,
##       "on_cancel": func (): ...,   # 不传则没有取消按钮（事件结算不可撤销）
##   })
class_name CardPicker
extends Control

const COLS := 10
const GAP_X := 14.0
const GAP_Y := 18.0
const GRID_TOP := 172.0
const GRID_BOTTOM := 700.0
const GRID_W := 1100.0
const MIN_SCALE := 0.5
const MAX_SCALE := 1.35

var _mode := "add"
var _need := 1
var _ids: Array = []
var _picked: Array = []          # 选中的下标（不是 id：同名牌可能有两张）
var _views: Array = []
var _confirm: Button = null
var _hint_base := ""
var _hint: Label = null
var _on_done: Callable
var _on_cancel: Callable
var _closed := false

static func open(parent: Control, cfg: Dictionary) -> CardPicker:
	var p := CardPicker.new()
	p._mode = str(cfg.get("mode", "add"))
	p._need = maxi(1, int(cfg.get("count", 1)))
	p._ids = (cfg.get("cards", []) as Array).duplicate()
	p._on_done = cfg.get("on_done", Callable())
	p._on_cancel = cfg.get("on_cancel", Callable())
	p.size = Vector2(1440, 900)
	parent.add_child(p)
	p._build(cfg)
	return p

func _build(cfg: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.04, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	Widgets.fill_screen(dim)
	add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(100, 74)
	panel.size = Vector2(1240, 736)
	panel.add_theme_stylebox_override("panel",
		UiTheme.panel_style(UiTheme.PAPER, UiTheme.INK, 10, 2))
	add_child(panel)

	var title := Widgets.title(str(cfg.get("title", "选 牌")), 26)
	title.position = Vector2(0, 96)
	title.size = Vector2(1440, 34)
	add_child(title)

	_hint_base = str(cfg.get("hint", ""))
	_hint = Widgets.subtitle(_hint_base, 14)
	_hint.position = Vector2(0, 136)
	_hint.size = Vector2(1440, 22)
	add_child(_hint)

	_build_grid()

	var by := 724.0
	if _on_cancel.is_valid():
		var cancel := UiTheme.button("取 消", false)
		cancel.position = Vector2(560, by)
		cancel.size = Vector2(90, 46)
		cancel.pressed.connect(_close_cancel)
		add_child(cancel)

	var ok_text := str(cfg.get("confirm", "确 定"))
	_confirm = UiTheme.button(ok_text, true)
	# 有取消按钮时两个并排（560 + 90 | 666 + 214，中心 720）；没有就自己居中
	_confirm.position.x = 666.0 if _on_cancel.is_valid() else 613.0
	_confirm.position.y = by
	_confirm.size = Vector2(214, 46)
	_confirm.disabled = true
	_confirm.pressed.connect(_confirm_pick)
	add_child(_confirm)

	_refresh_hint()
	Widgets.fade_in(self, 0.0, 0.18)

## 缩放随张数自适应：3 张放大到 1.35（与奖励页选牌同尺寸），20 张压到 0.76
func _scale_for(count: int) -> float:
	if count <= 0:
		return MIN_SCALE
	var usable := GRID_W - float(count - 1) * GAP_X
	return clampf(usable / (float(count) * CardView.SIZE.x), MIN_SCALE, MAX_SCALE)

func _build_grid() -> void:
	var n := _ids.size()
	var cols := mini(maxi(n, 1), COLS)
	var s := _scale_for(cols)
	var cw := CardView.SIZE.x * s
	var ch := CardView.SIZE.y * s
	var rows := maxi(1, int(ceil(float(n) / float(cols))))
	var grid_w := cols * cw + maxf(0.0, float(cols - 1)) * GAP_X
	var grid_h := rows * ch + maxf(0.0, float(rows - 1)) * GAP_Y
	var x0 := 720.0 - grid_w * 0.5
	var y0 := GRID_TOP + maxf(0.0, (GRID_BOTTOM - GRID_TOP - grid_h) * 0.5)
	for i in _ids.size():
		var col := i % cols
		var row := int(i / cols)
		var cv: CardView = Widgets.card_view(str(_ids[i]), s)
		# 缩放轴在左上角（见 Widgets.card_view 的注释），所以直接给格子左上角即可
		cv.position = Vector2(x0 + col * (cw + GAP_X), y0 + row * (ch + GAP_Y))
		var idx := i
		cv.clicked.connect(func (_uid: int): _toggle(idx))
		add_child(cv)
		_views.append(cv)

func _toggle(index: int) -> void:
	if _closed:
		return
	if _picked.has(index):
		_picked.erase(index)
	else:
		if _picked.size() >= _need:
			# 选满后再点别的牌：换掉最早选的那张，而不是拒绝点击（点不动像卡死）
			_picked.pop_front()
		_picked.append(index)
	_sync_selection()

func _sync_selection() -> void:
	for i in _views.size():
		(_views[i] as CardView).set_selected(_picked.has(i))
	_confirm.disabled = _picked.size() != _need
	_refresh_hint()

func _refresh_hint() -> void:
	if _hint == null:
		return
	var head := I18n.T(_hint_base)
	if _need <= 1:
		_hint.text = head
	else:
		# 复用 Web 版已有的「（还需 N 张）」键，N 由 core/i18n.gd 的 RULES 正则替换
		_hint.text = head + I18n.T("（还需 %d 张）" % (_need - _picked.size()))

func _confirm_pick() -> void:
	if _closed or _picked.size() != _need:
		return
	_closed = true
	var out: Array = []
	for i in _picked:
		out.append(str(_ids[i]))
	_dismiss()
	if _on_done.is_valid():
		_on_done.call(out)

func _close_cancel() -> void:
	if _closed:
		return
	_closed = true
	_dismiss()
	if _on_cancel.is_valid():
		_on_cancel.call()

func _dismiss() -> void:
	queue_free()
