## 战后奖励：三选一加牌，或「不取牌、改删一张」
##
## 为什么要有第二个选项：牌组强度对奖励极度敏感（第 4 关 20 张裸牌组 30% vs
## 带 3 张奖励 57%），所以「跳过」不能是白跳过——它的价值在**删掉牌组里的废牌**。
## 实测（test/_tune-skip2.js）：删 1~2 张最弱牌 = 第 4 关 +7pp、第 8 关 +26pp，
## 比多拿一张奖励牌（3~6pp）更强；但删到 4 张开始回落（低费填线被删空）。
## 也就是说「拿牌 or 删牌」是一个真有取舍的构筑决策，而不是安慰按钮。
extends Control

var _picked := false
var _deck_layer: Control = null

func _ready() -> void:
	theme = UiTheme.build()
	GameData.ensure_loaded()
	if App.stage.is_empty():
		App.go(App.SCENE_MAP)
		return
	App.prepare_rewards()
	_build()

func _build() -> void:
	Widgets.paper_bg(self)

	var banner := ColorRect.new()
	banner.color = Color(UiTheme.SEAL.r, UiTheme.SEAL.g, UiTheme.SEAL.b, 0.06)
	banner.size = Vector2(1440, 200)
	Widgets.bleed_x(banner)
	add_child(banner)

	var title := Widgets.title("「%s」已 破" % str(App.stage.get("name", "")), 40)
	title.position = Vector2(0, 84)
	title.size = Vector2(1440, 56)
	add_child(title)

	var sub := Widgets.subtitle("选一张牌收入牌组 · 剩下的留在史书里", 16)
	sub.position = Vector2(0, 148)
	sub.size = Vector2(1440, 26)
	add_child(sub)

	var cards: Array = App.reward_cards
	if cards.is_empty():
		var none := Widgets.subtitle("此战无可用之牌，继续进军。", 18)
		none.position = Vector2(0, 400)
		none.size = Vector2(1440, 28)
		add_child(none)
		var go := UiTheme.button("继 续", true)
		go.position = Vector2(620, 460)
		go.size = Vector2(200, 56)
		go.pressed.connect(func (): App.take_reward(""))
		add_child(go)
		_build_skip_row()
		return

	var card_w := 214.0
	var gap := 56.0
	var total := cards.size() * card_w + (cards.size() - 1) * gap
	var x := (1440.0 - total) * 0.5
	for i in cards.size():
		var holder := Control.new()
		holder.position = Vector2(x + i * (card_w + gap), 236)
		holder.size = Vector2(card_w, 420)
		add_child(holder)

		var cv := Widgets.card_view(str(cards[i]), 1.3)
		cv.position = Vector2((card_w - CardView.SIZE.x * 1.3) * 0.5, 0)
		holder.add_child(cv)

		var pick := UiTheme.button("选 它", true)
		pick.position = Vector2(20, 300)
		pick.size = Vector2(card_w - 40, 48)
		var cid := str(cards[i])
		pick.pressed.connect(func (): _take(cid))
		holder.add_child(pick)

		holder.modulate.a = 0.0
		var tw := holder.create_tween()
		tw.tween_interval(0.12 + i * 0.1)
		tw.tween_property(holder, "modulate:a", 1.0, 0.3)
		tw.parallel().tween_property(holder, "position:y", 228.0, 0.35).from(260.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_build_skip_row()

func _take(card_id: String) -> void:
	if _picked:
		return
	_picked = true
	App.take_reward(card_id)

# ---------------- 次要选项：不取牌，改删一张 ----------------

func _build_skip_row() -> void:
	var skip := UiTheme.button("不取此牌 · 改删一张", false)
	skip.position = Vector2(560, 700)
	skip.size = Vector2(320, 52)
	if not Campaign.can_remove_card(App.progress):
		skip.disabled = true
		# 直接写 .text 绕过了 UiTheme 的翻译收口，英文模式下必须显式过一遍 T()
		skip.text = I18n.T("牌组已到下限")
	else:
		skip.pressed.connect(_open_drop)
	add_child(skip)

	# 文案不带数字：i18n 的英文键是整句匹配，塞 %d 就得额外维护一条正则规则
	var why := Widgets.subtitle("删掉一张废牌，比多拿一张更强 —— 但删太多会断了低费曲线", 14)
	why.position = Vector2(0, 758)
	why.size = Vector2(1440, 22)
	add_child(why)

func _open_drop() -> void:
	if _deck_layer != null or _picked:
		return
	_deck_layer = CardPicker.open(self, {
		"title": "删 去 一 张",
		"hint": "点选要删的牌 · 同名只删一张",
		"cards": (App.progress.get("deck", []) as Array).duplicate(),
		"mode": "remove",
		"count": 1,
		"confirm": "删 去 并 进 军",
		"on_done": func (ids: Array): _take_drop(str(ids[0])),
		"on_cancel": func (): _close_drop(),
	})

func _take_drop(card_id: String) -> void:
	if _picked:
		return
	_picked = true
	App.take_reward_skip(card_id)

func _close_drop() -> void:
	if _deck_layer != null and is_instance_valid(_deck_layer):
		_deck_layer.queue_free()
	_deck_layer = null
