extends Control
## 对战界面（Godot 版）
##
## 结构：逻辑全在 RulesEngine，本文件只负责「把状态画出来 + 把点击变成动作 + 播动画」。
## 动画统一走「动作前拍快照 → 动作后比对」：谁掉血、谁阵亡都能自动得出，
## 新增效果（比如以后加溅射、吸血）不需要再改动画代码。

# ---------------- 栅格（1440×900 设计分辨率） ----------------
## 四边留白：左右 24、上 16、下 20。左右等宽是这套版式的基准线（原来左 20 右 44）。
const MARGIN_X := 24.0
const MARGIN_TOP := 16.0
const MARGIN_BOTTOM := 20.0
## 左右两栏各 216 宽（战报 / 操作钮），中间 952 留给军阵
const SIDE_COL_W := 208.0
const RIGHT_EDGE := 1416.0        # = 1440 - MARGIN_X

## 字号阶梯只有五档：微 12 / 辅助 14 / 正文 16 / 标题 20 / 显示 26
## （原来散着 12/13/14/15/16/17/18/20/22 九档，同层元素字号互不相等）
const FS_MICRO := 12
const FS_SMALL := 14
const FS_BODY := 16
const FS_TITLE := 20
const FS_DISPLAY := 26

const CARD_SIZE := Vector2(128, 186)
## 部队 90×124：一列满编 3 张 = 90×3 + 4×2 = 278，列框 296 里左右各余 9px。
## 原来 96×132 满编正好 296 = 框宽，牌边和框线严丝合缝地重合，看起来像糊在一起。
const UNIT_SIZE := Vector2(90, 124)
const UNIT_GAP := 4

## 军阵列框 296×156 = 列名带 24 + 部队 124 + 上下各 4 的呼吸缝。
## 列名在带里、部队从带下起摆，所以有兵也压不住列名（以前两者都从框顶起算，列名被立绘整条盖掉）。
const COL_W := 296.0
const COL_H := 156.0
const COL_LABEL_H := 24.0
## 列内左右各留 4：确定「一列最多能摆多宽」，超了整列等比缩小（见 _rank_scale）
const RANK_PAD_X := 4.0
const RANK_AVAIL_W := COL_W - RANK_PAD_X * 2.0
const COL_X: Array = [392.0, 720.0, 1048.0]
const ENEMY_FRAME_Y := 116.0
const PLAYER_FRAME_Y := 316.0
## 部队在列框里垂直居中：上下各留 (156 − 24 − 124) / 2 = 4
const RANK_PAD_Y := (COL_H - COL_LABEL_H - UNIT_SIZE.y) * 0.5
const ENEMY_Y := ENEMY_FRAME_Y + COL_LABEL_H + RANK_PAD_Y
const PLAYER_Y := PLAYER_FRAME_Y + COL_LABEL_H + RANK_PAD_Y
## 楚河汉界：一条中线，中间留 420 宽空档给回合提示压上去（两段线，不用遮罩）
const MID_LINE_Y := 294.0
const MID_GAP_L := 510.0
const MID_GAP_R := 930.0

const HAND_Y := 570.0
## 手牌区间＝整幅宽度。主将面板在 y 792~880，手牌底 770 —— 垂直方向根本不重叠，
## 当年"7 张会压主将面板"是按横向区间误判的，为此右移到 496 反而让牌少时整排偏右。
const HAND_X_MIN := 24.0
const HAND_X_MAX := 1416.0

## 手牌扇形：每张牌绕自身底边中点旋转，角度按距轴心的距离线性分布；
## 两端同时下沉形成弧线。8°/14 是 10 张时相邻牌顶角仍留约 8px 间隙的上限。
const HAND_MAX_ROT := 8.0
const HAND_ARC := 14.0
## 悬停：放大只向上长（轴心在底边中点）。牌顶 = HAND_Y − LIFT − 186×(SCALE−1)。
## 1.3 倍 → 牌顶 500.2，给手牌上方的说明行（474~495）留出 5px。
## 1.4 倍会把牌顶推到 481.6，说明行就没地方站了——这两个数是绑定的，不能单独调。
const HAND_HOVER_SCALE := 1.3
const HAND_HOVER_LIFT := 14.0
const HAND_HOVER_PUSH := 30.0
## 两端牌绕底边中点转过 8° 后，斜对的那个顶角横向外伸 64·cos8° + 186·sin8° − 64 ≈ 25.3px。
## 区间两端各让出这么多，否则最左那张会压主将面板、最右那张会出屏（已实测溢出 12px）。
const HAND_ROT_HALF := 26.0

## 战报：左栏 216 宽，高度随条目自适应（开局 2 条就矮，打到后期才长满）
const LOG_BOX_W := 184.0
const LOG_PAD_TOP := 36.0
const LOG_PAD_BOTTOM := 12.0
const LOG_MIN_H := 356.0
const LOG_MAX_H := 660.0          # 到主将面板顶（792）留 16px
const LOG_LIMIT := 10             # 条数上限，超出从最旧的丢

var state: Dictionary = {}
var card_views: Dictionary = {}     # uid -> CardView
var unit_views: Dictionary = {}     # uid -> UnitView
var selected_uid: int = -1
var busy := false
var _hover_uid := -1

var board_layer: Control
var hand_layer: Control
var fx_layer: Control
## 上一次同步时引擎报过的战报总数：用来只认「这帧新增的那几条」（state.log 会截断到 60，
## 用 size 判断在长局里会失效，logTotal 是单调计数器）
var _last_log_total := 0
var ui_layer: Control
var toast_label: Label
var turn_label: Label
var end_btn: Button
var hero_bars: Dictionary = {}      # pid -> Dictionary{hp, mana, avatar, name}
var flash_rect: ColorRect
var log_box: VBoxContainer
var log_panel: Panel
var log_clip: Control
var stage_label: Label
var skill_btn: Button
var adv_btn: Button            # 军师主动技（每场 1 次，没有军师时隐藏）
var pause_btn: Button
var phrase_btn: Button
var hand_zone: Control
var card_tip: CardTip
var hand_hint: Label
var coach: Coach = null
var _result_shown := false
var _result_layer: Control = null
var _pause_layer: Control = null
var col_frames: Dictionary = {}     # "p1_front" -> Panel（三列军阵底格）
var _skill_styles: Dictionary = {}  # true/false -> StyleBoxFlat（技能钮可用/不可用两态，建一次复用）

# ---------------- PvP（确定性锁步） ----------------
## 本地玩家的引擎侧 id。单机恒为 p1；PvP 里选楚的玩家是 p2，
## 引擎状态两端完全一致（p1 恒为刘邦侧），只是 UI 视角随 my_pid 翻转。
var my_pid := "p1"
var foe_id := "p2"
var pvp := false
var _pvp_queue: Array = []      # 远端动作待办（动画播放期间先排队）
var _applied := 0               # 已应用的动作数（含本端），重连补放用
var turn_left := -1.0           # 本回合剩余秒数（PvP 60 秒限时；<0 表示不计时）
var _phrase_layer: Control = null

func _foe() -> String:
	return foe_id

func _ready() -> void:
	theme = UiTheme.build()
	pvp = str(App.battle_config.get("mode", "")) == "pvp"
	if pvp:
		my_pid = "p1" if str(App.battle_config.get("mySide", "han")) == "han" else "p2"
		foe_id = RulesEngine.other(my_pid)
	_build_background()
	_build_layers()
	_start_battle()
	_maybe_shot()

# ---------------- 初始化 ----------------

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.PAPER
	Widgets.fill_screen(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 楚河汉界：一条中线，中间 420 的空档留给回合提示压在上面
	for seg in [[COL_X[0] - COL_W * 0.5, MID_GAP_L], [MID_GAP_R, COL_X[2] + COL_W * 0.5]]:
		var line := ColorRect.new()
		line.color = Color(0.11, 0.10, 0.09, 0.16)
		line.position = Vector2(float(seg[0]), MID_LINE_Y)
		line.size = Vector2(float(seg[1]) - float(seg[0]), 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)

# ---------------- 军阵底格 ----------------

func _build_col_frames() -> void:
	for pid in [foe_id, my_pid]:
		var y := ENEMY_FRAME_Y if pid == foe_id else PLAYER_FRAME_Y
		for rank in RulesEngine.RANKS:
			var ci: int = RulesEngine.RANKS.find(str(rank))
			var f := Panel.new()
			f.position = Vector2(COL_X[ci] - COL_W * 0.5, y)
			f.size = Vector2(COL_W, COL_H)
			f.add_theme_stylebox_override("panel", _col_style(false))
			f.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# 列名占顶部 20px 带：部队从带下开始摆，所以永远压不住它
			var lb := UiTheme.label(GameData.rank_name(str(rank)), FS_MICRO,
				Color(UiTheme.INK_SOFT.r, UiTheme.INK_SOFT.g, UiTheme.INK_SOFT.b, 0.8))
			lb.position = Vector2.ZERO
			lb.size = Vector2(COL_W, COL_LABEL_H)
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			f.add_child(lb)
			board_layer.add_child(f)
			col_frames[pid + "_" + str(rank)] = f

func _col_style(hi: bool) -> StyleBoxFlat:
	return UiTheme.panel_style(
		Color(0.91, 0.86, 0.68, 0.55) if hi else Color(1, 1, 1, 0.3),
		UiTheme.GOLD if hi else Color(0.11, 0.10, 0.09, 0.2),
		8, 2 if hi else 1)

## 点亮某一方某一列（悬停手牌 = 预览这张牌会落到哪）
func _highlight_col(pid: String, rank: String) -> void:
	for key in col_frames:
		(col_frames[key] as Panel).add_theme_stylebox_override("panel",
			_col_style(str(key) == pid + "_" + rank))

func _clear_col_highlight() -> void:
	for key in col_frames:
		(col_frames[key] as Panel).add_theme_stylebox_override("panel", _col_style(false))

func _build_layers() -> void:
	board_layer = Control.new()
	board_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_layer)

	hand_layer = Control.new()
	hand_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_layer)

	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)

	ui_layer = Control.new()
	ui_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_layer)

	# 三列军阵底格 + 列名：空场也看得出阵型，悬停手牌时高亮落点列
	# （必须在 board_layer 建好之后）
	_build_col_frames()

	# 提示条：操作栏左侧空档（技能按钮 x≥1044），与按钮同一条水平带
	toast_label = UiTheme.label("", FS_SMALL, UiTheme.INK_SOFT)
	# 提示条不能跟着 HAND_X_MIN 走（那个现在是整幅左界，会落到主将面板上）：
	# 钉在「主将面板右缘 484」与「技能按钮左缘 1044」之间的空档
	toast_label.position = Vector2(496, 836)
	toast_label.size = Vector2(536, 28)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_layer.add_child(toast_label)

	# 关卡目标条：顶部中线。左界让开敌将卡（484），右界让开暂停（1340）
	stage_label = UiTheme.label("", FS_BODY, UiTheme.INK_SOFT)
	stage_label.position = Vector2(484, 24)
	stage_label.size = Vector2(856, 24)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_layer.add_child(stage_label)

	# 回合提示：压在中线空档（510~930）正中，不再浮在线条上方
	turn_label = UiTheme.label("", FS_TITLE, UiTheme.SEAL)
	turn_label.position = Vector2(MID_GAP_L, MID_LINE_Y - 13.0)
	turn_label.size = Vector2(MID_GAP_R - MID_GAP_L, 26)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_layer.add_child(turn_label)

	end_btn = UiTheme.button("结束回合", true)
	end_btn.position = Vector2(RIGHT_EDGE - 176.0, 828)
	end_btn.size = Vector2(176, 52)
	end_btn.pressed.connect(_on_end_turn)
	ui_layer.add_child(end_btn)

	# 主将技能：与结束回合同一条操作栏、同尺寸，紧挨在左侧
	skill_btn = UiTheme.button("主将技能", false)
	skill_btn.position = Vector2(RIGHT_EDGE - 176.0 * 2.0 - 20.0, 828)
	skill_btn.size = Vector2(176, 52)
	skill_btn.add_theme_font_size_override("font_size", FS_TITLE)
	skill_btn.pressed.connect(_on_skill)
	ui_layer.add_child(skill_btn)

	# 军师主动技（P6）：每场 1 次。没有军师的对局（快速开战 / 联机）里不出现
	adv_btn = UiTheme.button("军师技", false)
	adv_btn.position = Vector2(RIGHT_EDGE - 176.0 * 3.0 - 40.0, 828)
	adv_btn.size = Vector2(176, 52)
	adv_btn.add_theme_font_size_override("font_size", FS_TITLE)
	adv_btn.pressed.connect(_on_advisor_active)
	adv_btn.visible = false
	ui_layer.add_child(adv_btn)

	# 暂停：右上角小按钮（Esc 也行），里面能放弃本局
	pause_btn = UiTheme.button("暂 停", false)
	pause_btn.position = Vector2(RIGHT_EDGE - 76.0, MARGIN_TOP)
	pause_btn.size = Vector2(76, 40)
	pause_btn.pressed.connect(_open_pause)
	ui_layer.add_child(pause_btn)

	# PvP 快捷短语（对局中点一句，对方屏幕上飘出）
	phrase_btn = UiTheme.button("短 语", false)
	phrase_btn.position = Vector2(RIGHT_EDGE - 164.0, MARGIN_TOP)
	phrase_btn.size = Vector2(76, 40)
	phrase_btn.pressed.connect(_open_phrases)
	phrase_btn.visible = false
	ui_layer.add_child(phrase_btn)

	# 手牌区域（引导聚光灯要指这一带，手牌本身是散在 hand_layer 里的）
	hand_zone = Control.new()
	hand_zone.position = Vector2(HAND_X_MIN, HAND_Y - 26)
	hand_zone.size = Vector2(HAND_X_MAX - HAND_X_MIN, 900 - (HAND_Y - 26))
	hand_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hand_zone)

	card_tip = CardTip.create(ui_layer)

	# 悬停牌的规则文字：军阵框底（472）之下、悬停放大牌顶（500.2）之上的一行，
	# 居中横贯，不遮牌也不压战场。牌顶位置随 HAND_HOVER_SCALE 变，改倍率要回头看这里。
	hand_hint = UiTheme.label("", FS_SMALL, UiTheme.INK_SOFT)
	hand_hint.position = Vector2(HAND_X_MIN, 474.0)
	hand_hint.size = Vector2(HAND_X_MAX - HAND_X_MIN, 21)
	hand_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hand_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 悬停牌 z_index=100，会压过同层的一切；说明行必须比它更高才看得见
	hand_hint.z_index = 200
	ui_layer.add_child(hand_hint)

	# 战报面板（左栏 216 宽，高度随条目自适应：开局两三条就矮，打久了才长满）
	log_panel = Panel.new()
	log_panel.position = Vector2(MARGIN_X, 116)
	log_panel.size = Vector2(SIDE_COL_W, LOG_MIN_H)
	log_panel.add_theme_stylebox_override("panel",
		UiTheme.panel_style(Color(1, 1, 1, 0.42), Color(0.11, 0.10, 0.09, 0.18), 6, 1))
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(log_panel)
	var log_title := UiTheme.label("战 报", FS_SMALL, UiTheme.INK_SOFT)
	log_title.position = Vector2(12, 8)
	log_panel.add_child(log_title)
	# 裁剪层必须是个尺寸固定的空 Control：VBoxContainer 会被子节点撑高，
	# 直接给它 clip_contents 等于按「撑高后的尺寸」裁，等于没裁（战报溢出就是这个原因）
	log_clip = Control.new()
	log_clip.position = Vector2(12, LOG_PAD_TOP)
	log_clip.size = Vector2(LOG_BOX_W, LOG_MIN_H - LOG_PAD_TOP - LOG_PAD_BOTTOM)
	log_clip.clip_contents = true
	log_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.add_child(log_clip)
	log_box = VBoxContainer.new()
	log_box.position = Vector2.ZERO
	log_box.size = log_clip.size
	log_box.custom_minimum_size = Vector2(LOG_BOX_W, 0)
	log_box.add_theme_constant_override("separation", 4)
	log_clip.add_child(log_box)

	# 全屏红闪（主将受击）
	flash_rect = ColorRect.new()
	flash_rect.color = Color(0.7, 0.12, 0.1, 0)
	Widgets.fill_screen(flash_rect)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.z_index = 50
	add_child(flash_rect)

func _start_battle() -> void:
	var cfg: Dictionary = App.battle_config
	var hero_id := str(cfg.get("hero", "liubang"))
	var foe_hero := str(cfg.get("foe", "xiangyu"))
	var ai_level := str(cfg.get("aiLevel", "bijiang"))
	var rules: Dictionary = cfg.get("rules", {})
	var decks := {}
	if (cfg.get("deck", []) as Array).size() > 0:
		decks["p1"] = (cfg["deck"] as Array).duplicate()
	if (cfg.get("enemyDeck", []) as Array).size() > 0:
		decks["p2"] = (cfg["enemyDeck"] as Array).duplicate()
	var opts := {"rules": rules}
	var meta: Dictionary = cfg.get("foeMeta", {})
	if not meta.is_empty():
		opts["p2Meta"] = meta
	if pvp:
		# 锁步：两端注入同一 seed 的确定性 RNG，牌序/随机效果完全一致
		RulesEngine.rng = Rng.new(int(cfg.get("seed", 1)))
		hero_id = "liubang"
		foe_hero = "xiangyu"
		ai_level = ""
		decks = {}
		opts = {}
	else:
		RulesEngine.rng = null
	state = RulesEngine.new_game(hero_id, foe_hero, "p1", ai_level, decks, opts)
	if pvp:
		# 联机 v1 起手自动保留（两端同样操作，保持确定）
		RulesEngine.do_mulligan(state, "p1", [])
		RulesEngine.do_mulligan(state, "p2", [])
	else:
		RulesEngine.do_mulligan(state, "p1", [])
		RulesEngine.do_mulligan(state, "p2", Ai.mulligan_uids(state, "p2"))
	RulesEngine.begin_game(state)
	# 开局先对齐战报基线：begin_game 已经写了「先手」「起手」几条，若从 0 起算会把它们当新增，
	# 于是每次进战场都白闪一次死战专精 —— 而那时候根本还没打出任何牌。
	_last_log_total = int(state.get("logTotal", 0))
	if stage_label != null:
		var name_txt := str(cfg.get("stageName", ""))
		var goal_txt := str(cfg.get("goalText", ""))
		if name_txt != "":
			stage_label.text = I18n.T(("%s · %s" % [name_txt, goal_txt]) if goal_txt != "" else name_txt)
		else:
			stage_label.text = ""
	hero_bars["p1"] = _make_hero_bar("p1")
	hero_bars["p2"] = _make_hero_bar("p2")
	_sync_all()
	_center_board()
	Audio.music("battle")
	if pvp:
		# PvP：不弹新手引导；接上网络信号；补放进场景前已到达的动作
		phrase_btn.visible = true
		Pvp.action_in.connect(_on_pvp_action)
		Pvp.peer_left.connect(_on_peer_left)
		Pvp.peer_back.connect(_on_peer_back)
		Pvp.self_dropped.connect(_on_self_dropped)
		Pvp.resumed.connect(_on_resumed)
		Pvp.net_error.connect(func (msg: String): _toast(msg))
		while _applied < Pvp.action_log.size():
			_apply_remote(Pvp.action_log[_applied])
			_applied += 1
		_sync_all()
	else:
		_intro_soon()

func _make_hero_bar(pid: String) -> Dictionary:
	var p: Dictionary = state["players"][pid]
	var is_player := pid == my_pid
	var holder := Control.new()
	# 靠边角落，不占战场中线：敌将左上、我方左下（手牌现在从 x=496 起，横向已让开）
	holder.position = Vector2(MARGIN_X, 792.0 if is_player else MARGIN_TOP)
	holder.size = Vector2(460, 88)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(holder)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel",
		UiTheme.panel_style(Color(1, 1, 1, 0.55), UiTheme.INK, 6, 2))
	holder.add_child(frame)

	var avatar := TextureRect.new()
	avatar.position = Vector2(6, 6)
	avatar.size = Vector2(76, 76)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让点击落到主将卡上（点立绘也算点敌将）
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var art_id: String = str(p["art"]) if p["art"] != null else str(p["heroId"])
	var tex := UiTheme.art_texture(art_id)
	if tex != null:
		avatar.texture = tex
	holder.add_child(avatar)

	var name_label := UiTheme.label("%s · %s" % [p["name"], p["title"]], FS_TITLE, UiTheme.INK)
	name_label.position = Vector2(94, 6)
	name_label.size = Vector2(210, 26)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	holder.add_child(name_label)

	var hp_label := UiTheme.label("", FS_TITLE, UiTheme.SEAL)
	hp_label.position = Vector2(94, 42)
	hp_label.size = Vector2(180, 30)
	holder.add_child(hp_label)

	# 军粮圆点条：10 颗点＝上限 10。实心＝本回合还能用，空心＝已花掉，灰点＝尚未解锁
	# 放在右半边（x≥312，右缘 448 留 12px 内边距），与左侧的名字/血量分栏，避免长名字压到圆点上
	var pip_row := HBoxContainer.new()
	pip_row.position = Vector2(312, 24)
	pip_row.add_theme_constant_override("separation", 4)
	pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pip_row)
	var pips: Array = []
	for i in 10:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(10, 10)
		pip.size = Vector2(10, 10)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip_row.add_child(pip)
		pips.append(pip)

	# 三种点样式建一次复用（每帧同步时只换 stylebox，不新建资源）
	var sb_on := StyleBoxFlat.new()
	sb_on.bg_color = Color("#33555e")
	sb_on.set_corner_radius_all(5)
	var sb_spent := StyleBoxFlat.new()
	sb_spent.bg_color = Color(1, 1, 1, 0.5)
	sb_spent.border_color = Color("#33555e")
	sb_spent.set_border_width_all(1)
	sb_spent.set_corner_radius_all(5)
	var sb_off := StyleBoxFlat.new()
	sb_off.bg_color = Color(0.09, 0.08, 0.07, 0.13)
	sb_off.set_corner_radius_all(5)

	var mana_label := UiTheme.label("", FS_SMALL, Color("#33555e"))
	mana_label.position = Vector2(312, 46)
	mana_label.size = Vector2(136, 20)
	holder.add_child(mana_label)

	# 敌方主将可点（攻击目标）：提示放右栏顶部，与点阵、军粮数字分行
	if not is_player:
		# y=5 而不是 2：面板边框 2px + Label 行框上下各溢出 1~2px，
		# 贴到 2 时字顶正压在边框线上，看起来像被裁掉了半截
		var hint := UiTheme.label("点此直取敌将", FS_MICRO, UiTheme.INK_SOFT)
		hint.position = Vector2(312, 5)
		hint.size = Vector2(136, 15)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		holder.add_child(hint)
		holder.gui_input.connect(func (e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_on_enemy_hero_clicked())

	return {"holder": holder, "hp": hp_label, "mana": mana_label, "avatar": avatar,
		"name": name_label, "pips": pips,
		"sb_on": sb_on, "sb_spent": sb_spent, "sb_off": sb_off}

# ---------------- 状态同步 ----------------

func _sync_all() -> void:
	# 「谁还活着」要跨双方一起算：分开算会把对面刚下场的部队当阵亡清掉
	# （曾经每个 _sync_board 各带一个 alive，先刷敌方再刷我方，敌方的视图就被杀光了）
	var alive := {}
	_sync_board(foe_id, alive)
	_sync_board(my_pid, alive)
	for uid in unit_views.keys():
		if not alive.has(uid):
			var v2: UnitView = unit_views[uid]
			unit_views.erase(uid)
			if is_instance_valid(v2):
				_death_fx(v2)
				v2.die()
	_sync_hand()
	_sync_hero_bars()
	_sync_log()

## 死战专精生效的一记反馈：一道自下而上的淡金掠光 + 印章声。
## 不做单位高亮——引擎状态里没有"这个援军被加成过"的标记，为表现层改状态结构不值得。
func _flash_last_stand() -> void:
	Audio.sfx("seal")
	var glow := ColorRect.new()
	glow.color = Color(UiTheme.GOLD, 0.0)
	Widgets.fill_screen(glow)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.z_index = 30
	add_child(glow)
	var tw := glow.create_tween()
	tw.tween_property(glow, "color:a", 0.16, 0.10)
	tw.tween_property(glow, "color:a", 0.0, 0.38)
	tw.tween_callback(glow.queue_free)

	# 战场中线浮一行小字，说明"刚才那一下是什么"，否则玩家只看到光
	var tip := UiTheme.label("死战专精", 20, UiTheme.SEAL)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.size = Vector2(420, 30)
	tip.position = Vector2((size.x - 420) * 0.5, size.y * 0.44)
	tip.modulate.a = 0.0
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.z_index = 31
	add_child(tip)
	var tw2 := tip.create_tween()
	tw2.tween_property(tip, "modulate:a", 1.0, 0.12)
	tw2.tween_property(tip, "position:y", tip.position.y - 18, 0.5)
	tw2.parallel().tween_property(tip, "modulate:a", 0.0, 0.5).set_delay(0.22)
	tw2.tween_callback(tip.queue_free)


func _sync_board(pid: String, alive: Dictionary) -> void:
	var p: Dictionary = state["players"][pid]

	for ci in RulesEngine.RANKS.size():
		var rank: String = RulesEngine.RANKS[ci]
		var row: Array = p["board"][rank]
		var n: int = row.size()
		# 3 张是常规满编（278 < 288 可用宽）。万一一列超过 3 张（列上限被调大、
		# 或者异常状态灌进来），整列等比缩小塞进列框，绝不溢出到邻列。
		var s: float = _rank_scale(n)
		var uw: float = UNIT_SIZE.x * s
		var gap: float = UNIT_GAP * s
		var total_w: float = n * uw + maxf(0.0, n - 1) * gap
		var start_x: float = COL_X[ci] - total_w * 0.5
		var top_y: float = _rank_top_y(pid, s)
		# UnitView 的缩放轴在牌中心（pop_in 要用），所以左上角要按 pivot 反向补偿
		var pivot_fix: Vector2 = UNIT_SIZE * 0.5 * (1.0 - s)
		for i in n:
			var u: Dictionary = row[i]
			var uid := int(u["uid"])
			alive[uid] = true
			var v: UnitView = unit_views.get(uid, null)
			if v == null:
				v = UnitView.new()
				board_layer.add_child(v)
				v.setup(u)
				v.clicked.connect(_on_unit_clicked)
				v.set_base_scale(s)
				v.position = Vector2(start_x + i * (uw + gap), top_y) - pivot_fix
				v.pop_in()
				unit_views[uid] = v
			else:
				v.refresh(u)
				v.set_base_scale(s)
				if not v.lunging:
					v.position = Vector2(start_x + i * (uw + gap), top_y) - pivot_fix
			v.set_selected(uid == selected_uid)

## 一列的缩放系数：常规满编不动，超编才缩（4 张 0.79 / 5 张 0.64 / 6 张 0.54）
func _rank_scale(n: int) -> float:
	if n <= 0:
		return 1.0
	var want_w: float = float(n) * UNIT_SIZE.x + maxf(0.0, float(n - 1)) * UNIT_GAP
	return minf(1.0, RANK_AVAIL_W / want_w)

## 一列部队的顶边：按缩放后的高度在列框里重新垂直居中
func _rank_top_y(pid: String, s: float) -> float:
	var frame_y: float = PLAYER_FRAME_Y if pid == my_pid else ENEMY_FRAME_Y
	return frame_y + COL_LABEL_H + maxf(0.0, (COL_H - COL_LABEL_H - UNIT_SIZE.y * s) * 0.5)

func _sync_hand() -> void:
	var p: Dictionary = state["players"][my_pid]
	var hand: Array = p["hand"]
	var n := hand.size()
	# 手牌排在 [HAND_X_MIN, HAND_X_MAX] 里：先按屏幕中心排，被左下主将面板挡住才贴左界，
	# 挤到右边界再整体左收。牌少时看着是居中的，不会因为区间偏右而整排右飘。
	var lo: float = HAND_X_MIN + HAND_ROT_HALF
	var hi: float = HAND_X_MAX - HAND_ROT_HALF
	var usable: float = hi - lo
	var spacing: float = 136.0 if n <= 1 else minf(136.0, (usable - CARD_SIZE.x) / float(n - 1))
	var total_w: float = CARD_SIZE.x + spacing * float(maxi(0, n - 1))
	var start_x: float = clampf(720.0 - total_w * 0.5, lo, maxf(lo, hi - total_w))
	# 悬停让位：牌少时区间有富余，两侧邻牌推开；牌多时余量≈0，就只靠放大牌自己盖住
	var hover_i := _hand_index_of(hand, _hover_uid)
	var push: float = clampf(maxf(0.0, usable - total_w) * 0.5, 0.0, HAND_HOVER_PUSH) if hover_i >= 0 else 0.0

	var alive := {}
	for i in n:
		var c: Dictionary = hand[i]
		var uid := int(c["uid"])
		alive[uid] = true
		# d = -1（最左）~ +1（最右）：扇形角度与弧落都由它线性/平方映射
		var d: float = 0.0
		if n > 1:
			d = (float(i) - float(n - 1) * 0.5) / (float(n - 1) * 0.5)
		var rot: float = HAND_MAX_ROT * d
		var dy: float = HAND_ARC * d * d
		var x: float = start_x + i * spacing
		if push > 0.0 and i != hover_i:
			# 只推紧邻那一张（|Δi|=1 → 满推力，|Δi|≥2 → 0），越远越不该动
			var gap := float(i - hover_i)
			var near: float = maxf(0.0, 2.0 - absf(gap))
			x += signf(gap) * push * near

		var v: CardView = card_views.get(uid, null)
		if v == null:
			v = CardView.new()
			hand_layer.add_child(v)
			v.setup(c)
			v.clicked.connect(_on_card_clicked)
			# 抽牌：从牌底下方滑入
			v.position = Vector2(x, HAND_Y + 40 + dy)
			v.rotation_degrees = rot
			v.move_to(Vector2(x, HAND_Y + dy), rot, 1.0, 0.24)
			_bind_hover(v, uid)
			card_views[uid] = v
			Audio.sfx("draw")
		else:
			if uid == _hover_uid:
				# 悬停牌：旋转归零、放大、上浮、置顶——三件事一起做才有"抽出来看"的手感
				v.z_index = 100
				v.move_to(Vector2(x, HAND_Y - HAND_HOVER_LIFT), 0.0, HAND_HOVER_SCALE, 0.14)
			else:
				v.z_index = 0
				v.move_to(Vector2(x, HAND_Y + dy), rot, 1.0, 0.16)
		v.set_playable(_can_play_ui(c))

	for uid in card_views.keys():
		if not alive.has(uid):
			var old: CardView = card_views[uid]
			card_views.erase(uid)
			if _hover_uid == uid:
				_hover_uid = -1
				if card_tip != null:
					card_tip.hide_tip()
			if is_instance_valid(old):
				old.queue_free()

## 手牌里某张牌的索引；没有（-1）或已不在手上都返回 -1
func _hand_index_of(hand: Array, uid: int) -> int:
	if uid < 0:
		return -1
	for i in hand.size():
		if int(hand[i].get("uid", -1)) == uid:
			return i
	return -1

## 手牌「能不能出」的统一判据：动画播放中 / 不是我的回合 / 规则不允许 → 压暗
func _can_play_ui(c: Dictionary) -> bool:
	if busy or state.is_empty() or bool(state["over"]):
		return false
	if str(state["current"]) != my_pid:
		return false
	return RulesEngine.can_play(state, my_pid, c)

## 只刷手牌明暗，不动位置、不建节点——busy 放开后必须调一次，
## 否则每回合都在「动画中」那一刻同步，牌会一直保持压暗（看起来像不能出牌）
func _refresh_hand_playable() -> void:
	if state.is_empty():
		return
	for uid in card_views.keys():
		var v: CardView = card_views[uid]
		if is_instance_valid(v):
			v.set_playable(_can_play_ui(v.card))

## 悬停：卡牌抬起 + 弹出详情浮层。
## 只在卡片创建时连一次——早先每次同步都连，悬停位移会累积成一串，卡会往下漂。
func _bind_hover(v: CardView, uid: int) -> void:
	v.mouse_entered.connect(func () -> void:
		if not is_instance_valid(v):
			return
		_hover_uid = uid
		# 部队牌悬停时点亮它所属的列，让「这张牌落到哪」一目了然
		if str(v.card.get("type", "")) == "piece":
			_highlight_col(my_pid, str(v.card.get("col", "")))
		# 放大 / 旋转归零 / 上浮 / 置顶 全交给重排统一处理：
		# 以前这里单独 tween position.y，和 _sync_hand 的位置补间互相覆盖，会抖。
		_sync_hand()
		_show_card_hint(v.card))
	v.mouse_exited.connect(func () -> void:
		if not is_instance_valid(v):
			return
		if _hover_uid == uid:
			_hover_uid = -1
		_clear_col_highlight()
		_sync_hand()
		_hide_card_hint())

## 悬停牌放大到 1.4 倍后牌面已能读全，规则文字改挂在手牌上方一行——
## 那里是军阵框底（472）与手牌顶（570）之间的空档，不遮任何东西。
func _show_card_hint(c: Dictionary) -> void:
	if hand_hint == null:
		return
	var desc := str(c.get("desc", ""))
	var nm := str(c.get("name", ""))
	hand_hint.text = I18n.T("%s　%s" % [nm, desc]) if desc != "" else I18n.T(nm)

func _hide_card_hint() -> void:
	if hand_hint != null:
		hand_hint.text = ""

func _sync_hero_bars() -> void:
	for pid in ["p1", "p2"]:
		var p: Dictionary = state["players"][pid]
		var bar: Dictionary = hero_bars[pid]
		bar["hp"].text = I18n.T("血量 %d / %d" % [int(p["hp"]), int(p["maxHp"])])
		var mana_now := int(p["mana"])
		var mana_cap := int(p["maxMana"])
		bar["mana"].text = I18n.T("军粮 %d / %d" % [mana_now, mana_cap])
		# 圆点：实心＝可用，空心＝本回合已花，灰点＝尚未解锁
		var pips: Array = bar["pips"]
		for i in pips.size():
			var pip: Panel = pips[i]
			var sb: StyleBox = bar["sb_off"]
			if i < mana_now:
				sb = bar["sb_on"]
			elif i < mana_cap:
				sb = bar["sb_spent"]
			pip.add_theme_stylebox_override("panel", sb)
		if int(p["hp"]) <= int(p["maxHp"]) * 0.3:
			bar["hp"].add_theme_color_override("font_color", Color("#c0261c"))

	_sync_skill_btn()
	_sync_adv_btn()

	var label_text := ""
	if state["over"]:
		label_text = "战 事 已 定"
	else:
		label_text = "第 %d 回合 · %s" % [int(state["turnNo"]),
			"我方行动" if state["current"] == my_pid else "敌方行动"]
		if pvp and state["current"] == my_pid and turn_left >= 0.0:
			label_text += " · %d 秒" % int(ceilf(turn_left))
	turn_label.text = I18n.T(label_text)

## 技能按钮：显示技能名与费用，不能用时压暗（点了仍会给一句原因）
func _sync_skill_btn() -> void:
	if skill_btn == null or state.is_empty():
		return
	var me: Dictionary = state["players"][my_pid]
	var sk: Dictionary = me["skill"]
	skill_btn.text = I18n.T("%s %d" % [str(sk["name"]), int(sk["cost"])])
	skill_btn.tooltip_text = I18n.T("%s（%d 军粮）\n%s" % [str(sk["name"]), int(sk["cost"]), str(sk.get("desc", ""))])
	var usable: bool = RulesEngine.can_skill(state, my_pid) and str(state["current"]) == my_pid and not busy
	# 可用＝朱砂描边 + 朱砂字（与「结束回合」同一套语言）；不可用＝灰边灰字再压暗。
	# 以前只有 modulate 变化，白底黑边跟可用态几乎看不出区别，玩家以为按钮坏了。
	if _skill_styles.is_empty():
		for on in [true, false]:
			var sb := UiTheme.panel_style(UiTheme.PAPER,
				UiTheme.SEAL if on else Color(0.11, 0.10, 0.09, 0.22), 6, 2)
			sb.content_margin_left = 22
			sb.content_margin_right = 22
			sb.content_margin_top = 10
			sb.content_margin_bottom = 10
			_skill_styles[on] = sb
	skill_btn.add_theme_stylebox_override("normal", _skill_styles[usable])
	skill_btn.add_theme_stylebox_override("hover", _skill_styles[usable])
	var ink := UiTheme.SEAL if usable else Color(UiTheme.INK_SOFT.r, UiTheme.INK_SOFT.g, UiTheme.INK_SOFT.b, 0.5)
	skill_btn.add_theme_color_override("font_color", ink)
	skill_btn.add_theme_color_override("font_hover_color", ink)
	skill_btn.modulate.a = 1.0 if usable else 0.8

	# 结束回合同理：不是我的回合 / 动画中 / 已结算时压暗
	if end_btn != null:
		var my_turn: bool = str(state["current"]) == my_pid and not busy and not bool(state["over"])
		end_btn.modulate.a = 1.0 if my_turn else 0.6

func _sync_log() -> void:
	for child in log_box.get_children():
		# 必须立刻摘掉：queue_free 要等帧末才生效，留着会让下面的高度判断算进旧条目
		log_box.remove_child(child)
		child.queue_free()
	var log: Array = state["log"]
	# 死战专精生效时给一记反馈：这条机制改的是「数值」，画面上原本什么都不会发生，
	# 玩家只会觉得"这局莫名其妙赢了"。只在新增条目里找，避免每次重绘都闪。
	var total := int(state.get("logTotal", 0))
	if total > _last_log_total:
		var added: int = mini(total - _last_log_total, log.size())
		for i in range(log.size() - added, log.size()):
			if str(log[i].get("k", "")) == "summon_bonus":
				_flash_last_stand()
				break
		_last_log_total = total
	# 最新一条排最上面：战报看的是「刚刚发生了什么」，旧条目往下滚。
	# 以前是旧的在上、新的在下，超出可视区时被裁掉的正是最新那条 —— 等于把最该看的裁了。
	var start: int = maxi(0, log.size() - LOG_LIMIT)
	for i in range(log.size() - 1, start - 1, -1):
		var is_boon := str(log[i].get("k", "")) == "summon_bonus"
		var l := UiTheme.label("· " + LogText.render(log[i]), FS_SMALL,
			UiTheme.SEAL if is_boon else UiTheme.INK_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 2
		# 注意：不要设 clip_text —— 那会让 Label 的最小高度塌成 1px，整条战报直接看不见
		l.custom_minimum_size = Vector2(LOG_BOX_W, 0)
		l.add_theme_constant_override("line_spacing", 3)
		log_box.add_child(l)
	# 条数之外还要按高度裁，但一律从末尾（最旧）丢，最新一条永远在可视区顶部
	var view_h := LOG_MAX_H - LOG_PAD_TOP - LOG_PAD_BOTTOM
	while log_box.get_child_count() > 1 and log_box.get_combined_minimum_size().y > view_h:
		var last := log_box.get_child(log_box.get_child_count() - 1)
		log_box.remove_child(last)
		last.queue_free()
	# 面板高度跟着条目走：开局两三条就短，打久了才长满左栏
	var h: float = clampf(log_box.get_combined_minimum_size().y + LOG_PAD_TOP + LOG_PAD_BOTTOM,
		LOG_MIN_H, LOG_MAX_H)
	log_panel.size.y = h
	log_clip.size.y = h - LOG_PAD_TOP - LOG_PAD_BOTTOM
	log_box.size.y = log_clip.size.y

func _center_board() -> void:
	pass

# ---------------- 玩家操作 ----------------

func _on_card_clicked(uid: int) -> void:
	if busy or state["over"] or state["current"] != my_pid:
		return
	var card: Dictionary = {}
	for c in state["players"][my_pid]["hand"]:
		if int(c["uid"]) == uid:
			card = c
			break
	if card.is_empty():
		return
	if not RulesEngine.can_play(state, my_pid, card):
		var me: Dictionary = state["players"][my_pid]
		if int(me["mana"]) < int(card["cost"]):
			_toast_reason("军粮不足")
		else:
			_toast_reason("%s列已满（每列最多 %d 员）"
				% [GameData.rank_name(str(card["col"])), GameData.column_limit()])
		return

	# 出牌前先记下卡片位置，做「飞过去」的动画
	var view: CardView = card_views.get(uid, null)
	var from_pos := view.position if view != null else Vector2(720, HAND_Y)
	if view != null:
		card_views.erase(uid)
		hand_layer.remove_child(view)
		fx_layer.add_child(view)

	var before := _snapshot()
	var r := RulesEngine.play_card(state, my_pid, uid)
	if not r["ok"]:
		if view != null:
			view.queue_free()
		_sync_all()
		return
	_pvp_local({"a": "play", "uid": uid})
	if coach != null and is_instance_valid(coach):
		coach.notify("play")

	var col_idx: int = RulesEngine.RANKS.find(str(card["col"])) if card["type"] == "piece" else 1
	var to_pos := Vector2(COL_X[col_idx] - UNIT_SIZE.x * 0.5, PLAYER_Y)
	Audio.sfx("card" if str(card["type"]) == "piece" else "spell")

	busy = true
	if view != null:
		view.z_index = 10
		view.pivot_offset = CARD_SIZE * 0.5
		var tw := view.create_tween()
		tw.set_parallel(true)
		tw.tween_property(view, "position", to_pos, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(view, "scale", UNIT_SIZE / CARD_SIZE, 0.24)
		tw.tween_property(view, "modulate:a", 0.0, 0.24).set_delay(0.12)
		tw.chain().tween_callback(func ():
			if is_instance_valid(view):
				view.queue_free()
			busy = false
			_after_action(before))
	else:
		busy = false
		_after_action(before)

func _on_unit_clicked(uid: int) -> void:
	if busy or state["over"]:
		return
	var mine: Dictionary = state["players"][my_pid]
	var theirs: Dictionary = state["players"][foe_id]

	# 点自己的单位 → 选中 / 取消
	for r in RulesEngine.RANKS:
		for u in mine["board"][r]:
			if int(u["uid"]) == uid:
				if not bool(u["canAttack"]) or int(u["atk"]) <= 0:
					_toast_reason("该单位本回合不能攻击")
					return
				selected_uid = -1 if selected_uid == uid else uid
				_refresh_selection()
				return

	# 点敌方单位 → 攻击
	if selected_uid < 0:
		_toast("先点自己的部队，再点目标")
		return
	for r in RulesEngine.RANKS:
		for u in theirs["board"][r]:
			if int(u["uid"]) == uid:
				_do_attack(selected_uid, {"kind": "unit", "uid": uid})
				return

func _on_enemy_hero_clicked() -> void:
	if busy or state["over"]:
		return
	if selected_uid < 0:
		_toast("先点自己的部队，再点目标")
		return
	_do_attack(selected_uid, {"kind": "hero"})

func _do_attack(attacker_uid: int, target: Dictionary) -> void:
	var before := _snapshot()
	var r := RulesEngine.attack(state, my_pid, attacker_uid, target)
	if not r["ok"]:
		_toast_reason(str(r.get("reason", "不能攻击")))
		return
	_pvp_local({"a": "attack", "uid": attacker_uid,
		"kind": str(target.get("kind", "unit")), "tid": int(target.get("uid", -1))})
	if coach != null and is_instance_valid(coach):
		coach.notify("attack")
	selected_uid = -1
	_refresh_selection()
	busy = true
	# 冲刺 → 命中瞬间结算（飘字/震屏/特效）→ 收招回位
	Audio.sfx("attack")
	var on_hit: Callable = func () -> void: _after_action(before)
	await _play_attack_anim(attacker_uid, target, my_pid, on_hit)
	busy = false
	_refresh_hand_playable()
	_drain_pvp()

## 攻击目标的全局坐标（敌我主将卡或目标单位中心）
func _attack_target_pos(target: Dictionary, attacker_pid: String) -> Vector2:
	if str(target.get("kind", "")) == "hero":
		var def_pid := RulesEngine.other(attacker_pid)
		var holder: Control = hero_bars[def_pid]["holder"]
		return holder.get_global_rect().get_center()
	var tv: UnitView = unit_views.get(int(target.get("uid", -1)), null)
	if tv == null or not is_instance_valid(tv):
		return Vector2.INF
	return tv.get_global_rect().get_center()

## 冲刺动画：朝目标突进（近身封顶 90px），命中瞬间回调 on_hit，再收招回位
func _play_attack_anim(attacker_uid: int, target: Dictionary, attacker_pid: String,
		on_hit: Callable) -> void:
	var v: UnitView = unit_views.get(attacker_uid, null)
	var hit_pos := _attack_target_pos(target, attacker_pid)
	if v == null or not is_instance_valid(v) or hit_pos == Vector2.INF:
		on_hit.call()
		return
	var home := v.position
	var center := home + UNIT_SIZE * 0.5
	var dir := hit_pos - center
	var step := home + dir.normalized() * minf(dir.length() * 0.5, 90.0)
	v.lunging = true
	v.z_index = 20
	# 残影拖尾：冲刺全程每拍留一片淡金虚影
	_ghost_trail(v, 0.1)
	var tw := v.create_tween()
	tw.tween_property(v, "position", step, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func () -> void:
		_impact_burst(hit_pos)
		on_hit.call())
	tw.tween_property(v, "position", home, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	v.lunging = false
	v.z_index = 0

## 冲刺残影：按拍复制当前立绘，淡金虚影边淡出边微缩，形成拖尾
func _ghost_trail(v: UnitView, dur: float) -> void:
	var tex := v.art_texture()
	if tex == null:
		return
	var step := 0.028
	var t := 0.0
	while t < dur:
		await get_tree().create_timer(step).timeout
		t += step
		if not is_instance_valid(v) or not v.lunging:
			return
		# 残影必须跟本体一样大：直接 texture→size 会被纹理最小尺寸顶成 1024，
		# 冲刺时甩出一张巨大的半透明立绘（几乎看不出来，但确实错了）
		var g := UiTheme.texture_rect(tex, v.size)
		g.position = v.position
		g.pivot_offset = v.size * 0.5
		g.modulate = Color(1.0, 0.86, 0.55, 0.3)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.z_index = 16
		fx_layer.add_child(g)
		var tw := g.create_tween()
		tw.set_parallel(true)
		tw.tween_property(g, "modulate:a", 0.0, 0.26)
		tw.tween_property(g, "scale", Vector2(0.86, 0.86), 0.26)
		tw.chain().tween_callback(g.queue_free)

## 阵亡特效：立绘切成 3×3 碎片四散 + 两圈墨灰烟尘
func _death_fx(v: UnitView) -> void:
	var rect := v.get_global_rect()
	var center := rect.get_center()
	# 烟尘先起，慢扩散
	for cfg in [
		{"size": 64.0, "color": Color(0.56, 0.51, 0.45, 0.4), "grow": 2.1, "dur": 0.5},
		{"size": 104.0, "color": Color(0.4, 0.36, 0.31, 0.22), "grow": 1.8, "dur": 0.68},
	]:
		var dust := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = cfg["color"]
		var sz: float = cfg["size"]
		sb.set_corner_radius_all(int(sz * 0.5))
		dust.add_theme_stylebox_override("panel", sb)
		dust.size = Vector2(sz, sz)
		dust.pivot_offset = Vector2(sz, sz) * 0.5
		dust.position = center - Vector2(sz, sz) * 0.5 + Vector2(0, 10)
		dust.z_index = 17
		dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_layer.add_child(dust)
		var dtw := dust.create_tween()
		dtw.set_parallel(true)
		dtw.tween_property(dust, "scale", Vector2.ONE * float(cfg["grow"]), float(cfg["dur"]))\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dtw.tween_property(dust, "modulate:a", 0.0, float(cfg["dur"]))
		dtw.chain().tween_callback(dust.queue_free)

	# 碎片：把这张立绘按 3×3 切开，各片朝外抛散
	var tex := v.art_texture()
	if tex == null:
		return
	var tsize := tex.get_size()
	var cell_src := Vector2(tsize.x / 3.0, tsize.y / 3.0)
	var cell_dst := rect.size / 3.0
	for gy in 3:
		for gx in 3:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(Vector2(gx, gy) * cell_src, cell_src)
			# 碎片尺寸同理：AtlasTexture 的最小尺寸是切片本身（~341），不先用 expand_mode
			# 关掉，碎片就不是 30px 小片而是三条大块横飞
			var sh := UiTheme.texture_rect(at, cell_dst)
			sh.pivot_offset = cell_dst * 0.5
			sh.position = rect.position + Vector2(gx, gy) * cell_dst
			sh.z_index = 18
			fx_layer.add_child(sh)
			var dir := (Vector2(gx, gy) - Vector2.ONE).normalized()
			dir += Vector2(randf_range(-0.35, 0.35), randf_range(-0.15, 0.35))
			var dist := randf_range(22.0, 58.0)
			var stw := sh.create_tween()
			stw.set_parallel(true)
			stw.tween_property(sh, "position", sh.position + dir * dist + Vector2(0, 16), 0.44)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			stw.tween_property(sh, "rotation", randf_range(-1.3, 1.3), 0.44)
			stw.tween_property(sh, "scale", Vector2(0.66, 0.66), 0.44)
			stw.tween_property(sh, "modulate:a", 0.0, 0.32).set_delay(0.12)
			stw.chain().tween_callback(sh.queue_free)

## 命中特效：金色光核 + 暗红冲击环，扩散淡出
func _impact_burst(global_pos: Vector2) -> void:
	for cfg in [
		{"size": 84.0, "color": Color(1.0, 0.9, 0.62, 0.9), "scale": 1.5},
		{"size": 110.0, "color": Color(0.72, 0.2, 0.14, 0.0), "scale": 1.35},
	]:
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = cfg["color"]
		sb.set_corner_radius_all(int(cfg["size"]) / 2)
		sb.border_color = Color(0.72, 0.2, 0.14, 0.75)
		sb.set_border_width_all(3)
		p.add_theme_stylebox_override("panel", sb)
		var sz: float = cfg["size"]
		p.size = Vector2(sz, sz)
		p.pivot_offset = Vector2(sz, sz) * 0.5
		p.position = global_pos - Vector2(sz, sz) * 0.5
		p.z_index = 25
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_layer.add_child(p)
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "scale", Vector2.ONE * float(cfg["scale"]), 0.24)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.24)
		tw.chain().tween_callback(p.queue_free)

func _refresh_selection() -> void:
	for uid in unit_views.keys():
		var v: UnitView = unit_views[uid]
		if is_instance_valid(v):
			v.set_selected(uid == selected_uid)

func _on_skill() -> void:
	if busy or state["over"] or state["current"] != my_pid:
		return
	if not RulesEngine.can_skill(state, my_pid):
		var p: Dictionary = state["players"][my_pid]
		if bool(p["skillUsed"]):
			_toast("本回合已用过主将技能")
		elif int(p["mana"]) < int(p["skill"]["cost"]):
			_toast("军粮不足")
		else:
			_toast("现在没有可施技的目标")
		return
	var before := _snapshot()
	var r := RulesEngine.use_skill(state, my_pid)
	if not r["ok"]:
		_toast(str(r.get("reason", "技能现在用不了")))
		return
	_pvp_local({"a": "skill"})
	Audio.sfx("skill")
	_after_action(before)
	if coach != null and is_instance_valid(coach):
		coach.notify("skill")

## 军师主动技按钮：每场 1 次。用过之后按钮留在原地显示「已用」——
## 直接隐藏会让玩家以为界面坏了（同「军师卡缺立绘时整块空白」那类问题）
func _sync_adv_btn() -> void:
	if adv_btn == null or state.is_empty():
		return
	if my_pid != "p1":
		adv_btn.visible = false
		return
	var a: Dictionary = RulesEngine.advisor_active(state)
	if a.is_empty():
		adv_btn.visible = false
		return
	adv_btn.visible = true
	var nm := str(a.get("name", "军师技"))
	var cost := int(a.get("cost", 0))
	var used := bool(state["players"]["p1"].get("advUsed", false))
	adv_btn.text = I18n.T("%s %d" % [nm, cost]) if not used else I18n.T("%s · 已用" % nm)
	adv_btn.tooltip_text = I18n.T("%s（%d 军粮 · 每场一次）\n%s" % [nm, cost, str(a.get("desc", ""))])
	var usable: bool = RulesEngine.can_advisor_active(state, my_pid) \
		and str(state["current"]) == my_pid and not busy
	if _skill_styles.is_empty():
		for on in [true, false]:
			var sb := UiTheme.panel_style(UiTheme.PAPER,
				UiTheme.SEAL if on else Color(0.11, 0.10, 0.09, 0.22), 6, 2)
			sb.content_margin_left = 22
			sb.content_margin_right = 22
			sb.content_margin_top = 10
			sb.content_margin_bottom = 10
			_skill_styles[on] = sb
	adv_btn.add_theme_stylebox_override("normal", _skill_styles[usable])
	adv_btn.add_theme_stylebox_override("hover", _skill_styles[usable])
	var ink := UiTheme.SEAL if usable else Color(UiTheme.INK_SOFT.r, UiTheme.INK_SOFT.g, UiTheme.INK_SOFT.b, 0.5)
	adv_btn.add_theme_color_override("font_color", ink)
	adv_btn.add_theme_color_override("font_hover_color", ink)
	adv_btn.modulate.a = 1.0 if usable else 0.8

func _on_advisor_active() -> void:
	if busy or state["over"] or state["current"] != my_pid:
		return
	if not RulesEngine.can_advisor_active(state, my_pid):
		var p: Dictionary = state["players"][my_pid]
		if bool(p.get("advUsed", false)):
			_toast("军师技本场已用过")
		elif int(p["mana"]) < int(RulesEngine.advisor_active(state).get("cost", 0)):
			_toast("军粮不足")
		else:
			_toast("现在没有可施技的目标")
		return
	var before := _snapshot()
	var r := RulesEngine.use_advisor_active(state, my_pid)
	if not r["ok"]:
		_toast(str(r.get("reason", "军师技现在用不了")))
		return
	Audio.sfx("skill")
	_after_action(before)

func _on_end_turn() -> void:
	if busy or state["over"]:
		return
	busy = true
	selected_uid = -1
	_refresh_selection()
	Audio.sfx("turn")
	RulesEngine.end_turn(state)
	_pvp_local({"a": "end"})
	_after_action({})
	if pvp:
		_drain_pvp()
		busy = false
		_refresh_hand_playable()
		return
	await _run_ai()
	busy = false
	_sync_all()

func _run_ai() -> void:
	var guard := 0
	while not state["over"] and state["current"] == "p2" and guard < 60:
		guard += 1
		var act := Ai.next_action(state, "p2")
		var before := _snapshot()
		if str(act["type"]) == "attack":
			# AI 进攻也走冲刺→命中结算→收招，和玩家同一套表现
			Audio.sfx("attack")
			await _play_attack_anim(int(act["attacker"]), act["target"], "p2",
				func () -> void:
					Ai.apply_action(state, "p2", act)
					_after_action(before))
		else:
			Ai.apply_action(state, "p2", act)
			_after_action(before)
		await get_tree().create_timer(0.55).timeout
		if str(act["type"]) == "end":
			break

# ---------------- PvP：动作交换与限时 ----------------

## 本地玩家动作：广播给对端（单机模式为空操作）
func _pvp_local(a: Dictionary) -> void:
	_applied += 1
	turn_left = -1.0
	if pvp:
		Pvp.send_action(a)

## 远端动作到达：动画期间先排队，动画完再逐个应用
func _on_pvp_action(a: Dictionary) -> void:
	_pvp_queue.append(a)
	_drain_pvp()

func _drain_pvp() -> void:
	if _pvp_queue.is_empty() or busy or state.is_empty() or state["over"]:
		return
	var a: Dictionary = _pvp_queue.pop_front()
	busy = true
	turn_left = -1.0
	_apply_remote(a)
	if str(a.get("a", "")) == "attack":
		# 远端进攻也走冲刺→命中结算→收招，和本端同一套表现
		Audio.sfx("attack")
		var target := {"kind": str(a.get("kind", "unit")), "uid": int(a.get("tid", -1))}
		var before := _snapshot()
		await _play_attack_anim(int(a.get("uid", -1)), target, foe_id,
			func () -> void: _after_action(before))
	else:
		busy = false
		_refresh_hand_playable()
	_drain_pvp()

## 把远端动作在本端引擎上重放执行（两端代码路径一致 → 状态一致）
func _apply_remote(a: Dictionary) -> void:
	var before := _snapshot()
	_applied += 1
	match str(a.get("a", "")):
		"play":
			RulesEngine.play_card(state, foe_id, int(a.get("uid", -1)))
			Audio.sfx("card")
		"skill":
			RulesEngine.use_skill(state, foe_id)
			Audio.sfx("skill")
		"end":
			RulesEngine.end_turn(state)
			Audio.sfx("turn")
		"surrender":
			state["over"] = true
			state["winner"] = my_pid
			_log_surrender()
		"phrase":
			_show_phrase(int(a.get("i", 0)))
		_:
			pass
	if str(a.get("a", "")) != "attack":
		_after_action(before)
	else:
		# 攻击的结算在冲刺命中瞬间由 on_hit 回调做，这里只同步选中态
		_refresh_selection()

func _log_surrender() -> void:
	state["log"].append({"key": "surrender", "args": {}})

## 回合计时（仅 PvP）：只由当前行动方的客户端强制结束自己的回合
func _process(delta: float) -> void:
	if not pvp or state.is_empty() or state["over"]:
		return
	if Pvp.status == Pvp.WAITING:
		return  # 对端掉线，计时暂停
	if str(state["current"]) == my_pid and not busy:
		if turn_left < 0.0:
			turn_left = 60.0
		turn_left -= delta
		if int(turn_left * 2.0) % 4 == 0:
			_sync_hero_bars()  # 每半秒刷一次秒数显示
		if turn_left <= 0.0:
			turn_left = -1.0
			_on_end_turn()
	else:
		turn_left = -1.0

## 对端掉线：90 秒重连窗口，超时判我方胜；重连回来继续打
func _on_peer_left() -> void:
	if not pvp or state["over"]:
		return
	_show_wait_overlay(true)
func _on_peer_back() -> void:
	if not pvp:
		return
	_show_wait_overlay(false)
	_drain_pvp()

func _show_wait_overlay(show_it: bool) -> void:
	if show_it:
		if _phrase_layer != null and is_instance_valid(_phrase_layer):
			return
		var layer := Control.new()
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		layer.mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0.11, 0.09, 0.07, 0.45)
		Widgets.fill_screen(dim)
		layer.add_child(dim)
		var box := Panel.new()
		box.position = Vector2(720 - 240, 450 - 90)
		box.size = Vector2(480, 180)
		box.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.INK, 8, 2))
		layer.add_child(box)
		var t1 := UiTheme.label("对 手 掉 线", 26, UiTheme.SEAL)
		t1.position = Vector2(0, 28)
		t1.size = Vector2(480, 36)
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(t1)
		var t2 := UiTheme.label("等待重连（90 秒），超时判你获胜", 15, UiTheme.INK_SOFT)
		t2.position = Vector2(0, 78)
		t2.size = Vector2(480, 24)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(t2)
		var giveup := UiTheme.button("离 开 房 间")
		giveup.position = Vector2(160, 116)
		giveup.size = Vector2(160, 44)
		giveup.pressed.connect(func (): App.pvp_leave_early())
		box.add_child(giveup)
		add_child(layer)
		_phrase_layer = layer
		# 90 秒倒计时：到点还没回来就判胜
		var timer := get_tree().create_timer(90.0)
		timer.timeout.connect(func ():
			if _phrase_layer != null and is_instance_valid(_phrase_layer) \
					and Pvp.status == Pvp.WAITING and not state["over"]:
				state["over"] = true
				state["winner"] = my_pid
				_show_wait_overlay(false)
				_show_result())
	else:
		if _phrase_layer != null and is_instance_valid(_phrase_layer):
			_phrase_layer.queue_free()
		_phrase_layer = null

## 自己掉线：自动重连（战场状态还在内存里，补上错过的动作即可）
func _on_self_dropped() -> void:
	if not pvp or state["over"]:
		return
	_toast("连接中断，正在重连…")
	Pvp.resume()

func _on_resumed(info: Dictionary) -> void:
	if not pvp:
		return
	_toast("重连成功")
	# 补放错过的动作（静默应用，不播动画）
	var log: Array = info.get("log", [])
	while _applied < log.size():
		var a: Dictionary = log[_applied]
		_applied += 1
		match str(a.get("a", "")):
			"play":
				RulesEngine.play_card(state, foe_id, int(a.get("uid", -1)))
			"skill":
				RulesEngine.use_skill(state, foe_id)
			"end":
				RulesEngine.end_turn(state)
			"surrender":
				state["over"] = true
				state["winner"] = my_pid
			_: pass
	_sync_all()
	_drain_pvp()

# ---------------- PvP：快捷短语 ----------------

const PHRASES: Array = ["承让了", "打得好看", "快点出牌吧", "好险！", "这一局认输", "再来一局？"]

func _open_phrases() -> void:
	if _phrase_layer != null and is_instance_valid(_phrase_layer):
		return
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.12)
	Widgets.fill_screen(dim)
	dim.gui_input.connect(func (e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free()
			if _phrase_layer == layer:
				_phrase_layer = null)
	layer.add_child(dim)
	var box := Panel.new()
	box.position = Vector2(250, 640)
	box.size = Vector2(200, 44 + PHRASES.size() * 40)
	box.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.INK, 8, 2))
	layer.add_child(box)
	for i in PHRASES.size():
		var b := UiTheme.button(PHRASES[i], false)
		b.position = Vector2(12, 30 + i * 38)
		b.size = Vector2(176, 34)
		var idx := i
		b.pressed.connect(func ():
			Pvp.send_action({"a": "phrase", "i": idx})
			layer.queue_free()
			if _phrase_layer == layer:
				_phrase_layer = null)
		box.add_child(b)
	add_child(layer)
	_phrase_layer = layer

## 对端的短语飘在我方主将卡上方
func _show_phrase(i: int) -> void:
	if i < 0 or i >= PHRASES.size():
		return
	var bar: Dictionary = hero_bars.get(my_pid, {})
	var pos := Vector2(500, 780)
	if bar.has("holder") and is_instance_valid(bar["holder"]):
		pos = (bar["holder"] as Control).position + Vector2(120, -6)
	_float_number(I18n.T(PHRASES[i]), pos, Color("#33555e"), 22)

# ---------------- 动画与反馈 ----------------

func _snapshot() -> Dictionary:
	var snap := {"hero": {}, "units": {}}
	for pid in ["p1", "p2"]:
		snap["hero"][pid] = int(state["players"][pid]["hp"])
		for r in RulesEngine.RANKS:
			for u in state["players"][pid]["board"][r]:
				snap["units"][int(u["uid"])] = int(u["hp"])
	return snap

func _after_action(before: Dictionary) -> void:
	_sync_all()
	if not before.is_empty():
		_diff_effects(before)
	_update_tension()
	if state["over"]:
		_show_result()

## 残血时曲子略快一点（Web 版是鼓点加密，这里用播放速率近似紧张感）
func _update_tension() -> void:
	var p: Dictionary = state["players"][my_pid]
	var max_hp := maxf(1.0, float(p["maxHp"]))
	Audio.tension(clampf(1.0 - float(p["hp"]) / max_hp, 0.0, 1.0))

func _diff_effects(before: Dictionary) -> void:
	# 单位掉血 / 阵亡
	for uid in before["units"].keys():
		var old_hp: int = before["units"][uid]
		var v: UnitView = unit_views.get(uid, null)
		var new_hp := 0
		if v != null:
			new_hp = int(v.unit["hp"])
		var loss := old_hp - new_hp
		if loss > 0 and v != null:
			_float_number("-" + str(loss), v.position + UNIT_SIZE * 0.5, Color("#c0261c"))
			_shake(v)
			v.hit_flash()

	# 主将掉血
	for pid in ["p1", "p2"]:
		var old_hero: int = before["hero"][pid]
		var new_hero: int = int(state["players"][pid]["hp"])
		if new_hero < old_hero:
			var bar: Dictionary = hero_bars[pid]
			var holder: Control = bar["holder"]
			_float_number("-" + str(old_hero - new_hero), holder.position + Vector2(240, 10), Color("#c0261c"), 30)
			_shake(holder)
			_impact_burst(holder.get_global_rect().get_center())
			_flash()
			Audio.sfx("hurt")
		elif new_hero > old_hero:
			# 技能回血：给一条绿色 +N，别让「血变多了」悄无声息
			var bar2: Dictionary = hero_bars[pid]
			var holder2: Control = bar2["holder"]
			_float_number("+" + str(new_hero - old_hero), holder2.position + Vector2(240, 10), Color("#2f7d4f"), 28)
			Audio.sfx("skill")

func _float_number(text: String, global_pos: Vector2, color: Color, font_size: int = 22) -> void:
	var l := UiTheme.label(text, font_size, color)
	l.z_index = 30
	l.position = global_pos
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 54, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.75).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)

func _shake(node: Control) -> void:
	var home := node.position
	var tw := node.create_tween()
	for i in 3:
		tw.tween_property(node, "position", home + Vector2(5, 0), 0.045)
		tw.tween_property(node, "position", home - Vector2(5, 0), 0.045)
	tw.tween_property(node, "position", home, 0.04)

func _flash() -> void:
	flash_rect.color.a = 0.22
	var tw := flash_rect.create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.4)

func _toast(text: String) -> void:
	toast_label.text = I18n.T(text)
	toast_label.modulate.a = 1.0
	var tw := toast_label.create_tween()
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.9).set_delay(1.4)

## 规则类失败原因 → 首次给一句白话解释，之后只说原文
func _toast_reason(reason: String) -> void:
	if reason.contains("挡路"):
		_hint_once("blocked", "敌方最靠前的那一列还没清空，暂时打不到后面的部队。", reason)
	elif reason.contains("不能攻击"):
		_hint_once("sick", "它这一回合还不能攻击：刚登场，或者已经出手过了。", reason)
	elif reason.contains("已满"):
		_hint_once("full", "每列最多站 %d 员。先打完这一列，或把牌出到别的列。"
			% GameData.column_limit(), reason)
	elif reason.contains("军粮不足"):
		_hint_once("noMana", "军粮不够。每回合上限 +1，撑到下个回合就出得起了。", reason)
	else:
		_toast(reason)

func _hint_once(id: String, tip: String, fallback: String = "") -> void:
	if Tutorial.hint(id):
		# 前缀与正文分开翻译：正文里常带动态数字，整串拼好再查表必然查不到
		_toast(I18n.T("小提示") + "　" + I18n.T(tip))
		return
	_toast(fallback if fallback != "" else tip)

func _show_result() -> void:
	if not state["over"]:
		return
	if _result_shown:
		return
	_result_shown = true
	# 结算屏在引导层下面，引导不收走会挡住按钮
	if coach != null and is_instance_valid(coach) and coach.active:
		coach.skip()
	var win: bool = str(state["winner"]) == my_pid
	Audio.sfx("win" if win else "lose")
	Audio.tension(0.0)
	var campaign := str(App.battle_config.get("mode", "")) == "campaign"

	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 60
	add_child(layer)
	_result_layer = layer

	var dim := ColorRect.new()
	dim.color = Color(0.11, 0.10, 0.09, 0.55)
	Widgets.fill_screen(dim)
	layer.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(450, 250)
	panel.size = Vector2(540, 340)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PAPER, UiTheme.SEAL, 10, 3))
	layer.add_child(panel)

	var title := UiTheme.label("大 获 全 胜" if win else "兵 败 如 山 倒", 38,
		UiTheme.SEAL if win else UiTheme.INK)
	title.position = Vector2(0, 42)
	title.size = Vector2(540, 54)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var goal_txt := str(App.battle_config.get("goalText", ""))
	var sub_text := ""
	if campaign:
		if win:
			sub_text = "「%s」已破" % str(App.battle_config.get("stageName", ""))
		elif App.stage_retry_left() > 0:
			sub_text = "此战失利，尚可重整一次 · 目标：%s" % goal_txt
		else:
			sub_text = "重整机会已尽，大军溃散 · 目标：%s" % goal_txt
	if sub_text != "":
		var sub := UiTheme.label(sub_text, 15, UiTheme.INK_SOFT)
		sub.position = Vector2(0, 104)
		sub.size = Vector2(540, 24)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(sub)

	var st: Dictionary = state["stats"][my_pid]
	var info := UiTheme.label("造成伤害 %d　直击主将 %d　出兵 %d　用计 %d" % [
		int(st["dmg"]), int(st["heroDmg"]), int(st["units"]), int(st["spells"])],
		16, UiTheme.INK_SOFT)
	info.position = Vector2(0, 148)
	info.size = Vector2(540, 30)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(info)

	if pvp:
		App.record_pvp(win)
		var sub2 := UiTheme.label("PvP 切磋 · 楚汉对垒", 15, UiTheme.INK_SOFT)
		sub2.position = Vector2(0, 104)
		sub2.size = Vector2(540, 24)
		sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(sub2)
		var lobby := UiTheme.button("回 大 厅", true)
		lobby.position = Vector2(60, 220)
		lobby.size = Vector2(200, 54)
		lobby.pressed.connect(func (): App.pvp_back_to_lobby())
		panel.add_child(lobby)
		var menu := UiTheme.button("返 回 主 菜 单")
		menu.position = Vector2(280, 220)
		menu.size = Vector2(200, 54)
		menu.pressed.connect(func (): App.pvp_leave_to_menu())
		panel.add_child(menu)
	elif campaign:
		var out_of_retry := not win and App.stage_retry_left() <= 0
		var btn_text := "继 续 行 军" if win else ("收 兵 回 营" if out_of_retry else "重 整 再 战")
		var btn := UiTheme.button(btn_text, true)
		btn.position = Vector2(170, 220)
		btn.size = Vector2(200, 54)
		var did_win := win
		btn.pressed.connect(func (): _leave_battle(did_win))
		panel.add_child(btn)

		var back := UiTheme.button("回 地 图")
		back.position = Vector2(170, 220)
		back.visible = false
		panel.add_child(back)
	else:
		var again := UiTheme.button("再 战 一 局", true)
		again.position = Vector2(60, 220)
		again.size = Vector2(200, 54)
		again.pressed.connect(_restart_battle)
		panel.add_child(again)

		var menu := UiTheme.button("返 回 主 菜 单")
		menu.position = Vector2(280, 220)
		menu.size = Vector2(200, 54)
		menu.pressed.connect(func (): App.back_to_menu())
		panel.add_child(menu)

	Widgets.fade_in(panel, 0.05, 0.28)

func _leave_battle(win: bool) -> void:
	var st: Dictionary = state["stats"][my_pid]
	var p1: Dictionary = state["players"][my_pid]
	App.finish_battle(win, {
		"turns": int(state["turnNo"]),
		"stats": st.duplicate(),
		"stage": str(App.battle_config.get("stageName", "")),
		"hp": int(p1["hp"]),
		"maxHp": int(p1["maxHp"]),
	})

func _restart_battle() -> void:
	if _result_layer != null and is_instance_valid(_result_layer):
		_result_layer.queue_free()
	if coach != null and is_instance_valid(coach):
		coach.queue_free()
	coach = null
	_hover_uid = -1
	if card_tip != null:
		card_tip.hide_tip()
	for v in unit_views.values():
		if is_instance_valid(v):
			v.queue_free()
	for c in card_views.values():
		if is_instance_valid(c):
			c.queue_free()
	unit_views.clear()
	card_views.clear()
	for pid in ["p1", "p2"]:
		if hero_bars.has(pid) and is_instance_valid(hero_bars[pid]["holder"]):
			(hero_bars[pid]["holder"] as Control).queue_free()
	hero_bars.clear()
	selected_uid = -1
	busy = false
	_result_shown = false
	_start_battle()

# ---------------- 暂停菜单 ----------------

## 战斗里 Esc 呼出/收起暂停菜单（战斗场景先于全局收到输入，拦掉设置面板）
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _result_layer != null and is_instance_valid(_result_layer):
		return
	if _pause_layer != null and is_instance_valid(_pause_layer):
		_close_pause()
	else:
		_open_pause()
	get_viewport().set_input_as_handled()

func _open_pause() -> void:
	if _pause_layer != null and is_instance_valid(_pause_layer) or _result_shown:
		return
	Audio.sfx("click")
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 树暂停时浮层还要能收点击（关闭/按钮），其余战斗逻辑照常冻结
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.11, 0.09, 0.07, 0.45)
	Widgets.fill_screen(dim)
	dim.gui_input.connect(func (e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_pause())
	layer.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(720 - 220, 450 - 185)
	panel.size = Vector2(440, 370)
	panel.add_theme_stylebox_override("panel",
		UiTheme.panel_style(UiTheme.PAPER, UiTheme.INK, 8, 2))
	layer.add_child(panel)

	var title := UiTheme.label("暂 停", 32, UiTheme.SEAL)
	title.position = Vector2(0, 34)
	title.size = Vector2(440, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var resume := UiTheme.button("继 续", true)
	resume.position = Vector2(120, 106)
	resume.size = Vector2(200, 54)
	resume.pressed.connect(_close_pause)
	panel.add_child(resume)

	var settings_btn := UiTheme.button("设 置")
	settings_btn.position = Vector2(120, 172)
	settings_btn.size = Vector2(200, 54)
	settings_btn.pressed.connect(func ():
		_close_pause()
		App.toggle_settings())
	panel.add_child(settings_btn)

	var is_campaign := str(App.battle_config.get("mode", "")) == "campaign"
	var quit_text := "返回主菜单"
	var note_text := ""
	if is_campaign:
		quit_text = "放弃本局"
		note_text = "放弃本局视为战败，同样消耗一次重整机会"
	elif pvp:
		quit_text = "认输离场"
		note_text = "认输视为本局战败，生涯只记 PvP 负场"
	var quit := UiTheme.button(quit_text)
	quit.position = Vector2(120, 238)
	quit.size = Vector2(200, 54)
	quit.pressed.connect(_abandon_battle)
	panel.add_child(quit)

	var note := UiTheme.label(note_text,
		13, UiTheme.INK_SOFT)
	note.position = Vector2(0, 316)
	note.size = Vector2(440, 22)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(note)

	add_child(layer)
	_pause_layer = layer
	get_tree().paused = true

func _close_pause() -> void:
	if _pause_layer != null and is_instance_valid(_pause_layer):
		_pause_layer.queue_free()
	_pause_layer = null
	get_tree().paused = false

## 放弃本局：按战败处理（记一笔战绩），战役回地图、单局回主菜单、PvP 认输
func _abandon_battle() -> void:
	_close_pause()
	if pvp:
		if not state["over"] and Pvp.is_in_room():
			Pvp.send_action({"a": "surrender"})
			state["over"] = true
			state["winner"] = foe_id
			_log_surrender()
			_show_result()
		else:
			App.pvp_leave_to_menu()
		return
	if str(App.battle_config.get("mode", "")) == "campaign":
		_leave_battle(false)
	else:
		App.back_to_menu()

# ---------------- 新手引导 ----------------

## 首局走一遍完整循环：认识对手 → 军粮 → 出牌 → 军阵 → 技能 → 结束回合
func _intro_steps() -> Array:
	var enemy_bar: Dictionary = hero_bars.get("p2", {})
	var my_bar: Dictionary = hero_bars.get("p1", {})
	var front_rect := Rect2(Vector2(COL_X[0] - 168.0, PLAYER_Y - 10.0),
		Vector2(336, UNIT_SIZE.y + 26))
	return [
		{"title": "这就是你的对手",
			"text": "把敌方主将的血量打到 0 就赢了。反过来，你的主将一死，仗就打输了。",
			"node": enemy_bar.get("holder", null)},
		{"title": "军粮就是出牌的费用",
			"text": "第 1 回合 1 点，第 2 回合 2 点……每回合上限加 1（最多 10），开局回满。这里的「当前 / 上限」就是你眼下有多少粮。",
			"node": my_bar.get("mana", null), "pad": 10.0},
		{"title": "点一张牌，它就下场",
			"text": "亮着的牌现在就能出；灰掉的是军粮不够，或者那一列已经站满 3 员。点一张试试。",
			"node": hand_zone, "tag": "play"},
		{"title": "兵种下场要等一回合",
			"text": "刚登场的兵种当回合不能攻击（带「冲锋」的除外）。到你的下一回合它会亮起来——点它，再点敌人，就是一次进攻。",
			"rect": front_rect},
		{"title": "别忘了主将技能",
			"text": "每回合能用一次。刘邦「约法三章」回血续航，项羽「破釜沉舟」横扫敌方前锋——关键时刻能翻盘。",
			"node": skill_btn, "tag": "skill"},
		{"title": "打完就交给对面",
			"text": "手里还有能出的牌、或还有能攻击的部队时，会先提醒你一次，再点才真的结束回合。",
			"node": end_btn},
	]

## 开战后稍等一拍再弹（等抽牌动画落定，视线不会被抢）
func _intro_soon() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--tour") or args.has("--shot") or args.has("--flow"):
		return
	await get_tree().create_timer(0.85).timeout
	_maybe_intro()

func _maybe_intro(force: bool = false) -> void:
	if state.is_empty() or bool(state["over"]) or str(state["current"]) != "p1":
		return
	if coach != null and is_instance_valid(coach) and coach.active:
		return
	if not force and Tutorial.done(Tutorial.BATTLE_INTRO):
		return
	coach = Coach.start(self, _intro_steps(), Tutorial.BATTLE_INTRO)

## 调试/巡览用：强制弹引导、以及收掉它
func _force_intro() -> void:
	_maybe_intro(true)

func _close_coach() -> void:
	if coach != null and is_instance_valid(coach):
		coach.skip()

## 切语言后原地重画文字（对局不中断，不重建 state）
func relang() -> void:
	I18n.localize_state(state)
	# 战役敌将身份是 stage.enemy.meta 的副本，按当前语言的关卡数据重新取词
	var sid := str(App.stage.get("id", ""))
	if sid != "":
		var st := GameData.stage_by_id(sid)
		var meta_src: Dictionary = (st.get("enemy", {}) as Dictionary).get("meta", {}) if st.get("enemy") is Dictionary else {}
		var p2: Dictionary = state["players"]["p2"]
		if p2.get("meta") is Dictionary and not meta_src.is_empty():
			var pm: Dictionary = p2["meta"]
			pm["name"] = str(meta_src.get("name", pm.get("name", "")))
			pm["title"] = str(meta_src.get("title", pm.get("title", "")))
	for v in card_views.values():
		if is_instance_valid(v):
			v.refresh_text()
	for pid in ["p1", "p2"]:
		var p: Dictionary = state["players"][pid]
		var bar: Dictionary = hero_bars.get(pid, {})
		if bar.has("name") and is_instance_valid(bar["name"]):
			(bar["name"] as Label).text = I18n.T("%s · %s" % [str(p["name"]), str(p["title"])])
	if card_tip != null:
		card_tip.hide_tip()
	end_btn.text = I18n.T("结束回合")
	pause_btn.text = I18n.T("暂 停")
	phrase_btn.text = I18n.T("短 语")
	# 军阵列名跟着换语言
	for key in col_frames:
		var f: Panel = col_frames[key]
		if f.get_child_count() > 0 and f.get_child(0) is Label:
			(f.get_child(0) as Label).text = I18n.T(GameData.rank_name(str(key).get_slice("_", 1)))
	_sync_all()

# ---------------- 调试截图 ----------------

func _maybe_shot() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--shot") or args.has("--tour"):
		return
	await get_tree().create_timer(1.0).timeout
	# 自动打 6 个回合，让战场有来有回
	for round_i in 6:
		if state["over"]:
			break
		for c in state["players"]["p1"]["hand"]:
			if RulesEngine.can_play(state, "p1", c):
				var before := _snapshot()
				RulesEngine.play_card(state, "p1", int(c["uid"]))
				_after_action(before)
				break
		await get_tree().create_timer(0.35).timeout
		if state["over"]:
			break
		RulesEngine.end_turn(state)
		_after_action({})
		await _run_ai()
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/_gd-battle.png")
	print("截图已保存 res://tests/_gd-battle.png  size=", img.get_size())
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
