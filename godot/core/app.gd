## 全局单例（autoload）：场景路由 + 一局战役的临时状态
##
## 设计取舍：不用 Godot 的 change_scene 之后到处传参，而是把「当前这局战役」
## 放在单例里。战斗/奖励/事件各自从 App 读需要的字段，结束时把结果写回来，
## 再由 App 决定下一屏是谁。这样每个界面都能独立调试（--shot 直接进）。
extends Node

const SCENE_MENU := "res://scenes/menu.tscn"
const SCENE_SLOTS := "res://scenes/slots.tscn"
const SCENE_MAP := "res://scenes/campaign_map.tscn"
const SCENE_INTRO := "res://scenes/stage_intro.tscn"
const SCENE_BATTLE := "res://scenes/battle.tscn"
const SCENE_REWARD := "res://scenes/reward.tscn"
const SCENE_ADVISOR := "res://scenes/advisor.tscn"
const SCENE_EVENT := "res://scenes/event.tscn"
const SCENE_CODEX := "res://scenes/codex.tscn"
const SCENE_ENDING := "res://scenes/ending.tscn"
const SCENE_LOBBY := "res://scenes/lobby.tscn"
const SCENE_OMEN := "res://scenes/omen.tscn"

## 当前战役进度（空字典 = 没在战役中）
var progress: Dictionary = {}
## 这一局正在打/刚打完的关卡
var stage: Dictionary = {}
## 战斗配置，由 launch_stage 写，battle.gd 读
var battle_config: Dictionary = {}
## 最近一次战斗结果 {win, turns, stats}
var last_battle: Dictionary = {}
## 三选一候选 / 待定事件 / 军师候选
var reward_cards: Array = []
var pending_event: Dictionary = {}
var advisor_choices: Array = []
## 新战役待定的难度档位：空存档位点「初阵/常规」时暂存，拜军师（begin_run）时落进进度
var pending_mode: String = "regular"
## 本局终结的提示（清档回存档位时显示一次，读完即清）
var run_end_notice: String = ""
## 从战役里「看牌组」后返回用的标记
var return_to := SCENE_MAP
## 被仪式页压住的成就横幅（天时揭晓结束后补播）
var _deferred_announce: Array = []

var _fade: ColorRect
var _busy := false
var _flow_checks := 0
var _flow_fails := 0
var _settings: SettingsPanel
var _relang_pending := false
## 巡览开始前的设置文件原文（结束时写回，避免 --lang / 调试开关污染玩家设置）
var _settings_backup := ""

func _fok(cond: bool, label: String) -> void:
	_flow_checks += 1
	if not cond:
		_flow_fails += 1
		print("  ✗ " + label)

func _ready() -> void:
	Settings.ensure_loaded()
	Settings.apply_fullscreen()
	I18n.init_from_settings()
	# 舞台对齐：宽屏（16:9/21:9）下画布比 1440 版心宽，把整屏内容右移对半分。
	# 放在 root 的子节点入树事件上，这样 go()、联机大厅直接 change_scene、启动主场景
	# 三条路径都覆盖到，不必每个场景各写一遍。
	get_tree().root.child_entered_tree.connect(_on_root_child)
	get_viewport().size_changed.connect(_refit_stage)
	# 巡览（以及命令行 --lang）会改语言，先把设置文件原文留一份，结束时写回
	_settings_backup = _read_file(Settings.PATH)
	# 命令行强制语言：--lang en（英文验收与截图用）。只改运行期，不落盘
	var cargs := OS.get_cmdline_user_args()
	var li := cargs.find("--lang")
	if li >= 0 and li + 1 < cargs.size():
		I18n.set_lang_soft(cargs[li + 1])
	# 命令行指定联机中继：--relay ws://...（测试用，只改运行期）
	var ri := cargs.find("--relay")
	if ri >= 0 and ri + 1 < cargs.size():
		Settings.pvp_relay = cargs[ri + 1]
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.972, 0.961, 0.922, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	if OS.get_cmdline_user_args().has("--tour"):
		_tour()
	elif OS.get_cmdline_user_args().has("--shot"):
		# 快速开战一局（battle.gd 会自动打 6 回合存 _gd-battle.png）
		quick_battle()
	elif OS.get_cmdline_user_args().has("--flow"):
		_flow_test()

## 每个场景配哪首曲子（集中管理，场景脚本不必各自声明）
const BGM_FOR := {
	SCENE_MENU: "title",
	SCENE_SLOTS: "map",
	SCENE_MAP: "map",
	SCENE_INTRO: "map",
	SCENE_BATTLE: "battle",
	SCENE_REWARD: "map",
	SCENE_ADVISOR: "map",
	SCENE_EVENT: "map",
	SCENE_CODEX: "map",
	SCENE_ENDING: "title",
	SCENE_LOBBY: "title",
	SCENE_OMEN: "map",
}

## 场景入树：只认「root 的直接子节点」里 scenes/ 下的界面（内部节点、浮层都不参与）
func _on_root_child(n: Node) -> void:
	if not (n is Control) or n.get_parent() != get_tree().root:
		return
	if not str(n.scene_file_path).begins_with("res://scenes/"):
		return
	_fit_stage(n)

func _fit_stage(scene: Node) -> void:
	if not (scene is Control):
		return
	var c := scene as Control
	c.position = Vector2(Widgets.stage_offset(), 0.0)
	Widgets.refit(c)

func _refit_stage() -> void:
	var sc := get_tree().current_scene
	if sc != null:
		_fit_stage(sc)

## 切换场景（带一层宣纸色淡入淡出，避免生硬跳屏）
func go(path: String, delay: float = 0.0) -> void:
	if _busy:
		return
	_busy = true
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.16)
	await tw.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	Audio.music(str(BGM_FOR.get(path, "")))
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.2)
	await tw2.finished
	_busy = false

# ---------------- 设置面板（Esc 随时呼出） ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_settings()
		get_viewport().set_input_as_handled()

func toggle_settings() -> void:
	if _settings != null and is_instance_valid(_settings):
		_settings.close_panel()
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	Audio.sfx("click")
	_settings = SettingsPanel.open_on(scene)
	_settings.closed.connect(_on_settings_closed)
	_settings.lang_changed.connect(_on_settings_lang)
	# 打开设置即暂停，免得对面 AI 继续出牌
	get_tree().paused = true

func _on_settings_lang(l: String) -> void:
	Settings.set_lang(l)
	I18n.apply_data()
	_relang_pending = true
	if _settings != null and is_instance_valid(_settings):
		_settings.close_panel()

func _on_settings_closed() -> void:
	_settings = null
	get_tree().paused = false
	if _relang_pending:
		_relang_pending = false
		relang()

## 切语言：数据层已换好，这里让当前界面跟着换
## 战斗界面自己实现 relang（对局不能中断），其余界面重载一次即可——
## 它们的运行状态都放在 App 里，重载不丢东西。
func relang() -> void:
	I18n.apply_data()
	if not pending_event.is_empty():
		pending_event = GameData.event_by_id(str(pending_event.get("id", "")))
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_method("relang"):
		scene.call("relang")
		return
	var path := scene.scene_file_path
	if path != "":
		go(path)

## 开发用：设置面板是否开着（--flow 会断言）
func settings_open() -> bool:
	return _settings != null and is_instance_valid(_settings)

# ---------------- 战役流程 ----------------

## 进入某个存档位：有进度就回地图，空位就开新战役（先选难度档，再选军师）
func enter_slot(index: int, mode: String = "regular") -> void:
	Campaign.use_slot(index)
	progress = Campaign.load_slot(index)
	if progress.is_empty():
		pending_mode = "chuben" if mode == "chuben" else "regular"
		advisor_choices = Campaign.roll_advisors(3)
		go(SCENE_ADVISOR)
		return
	stage = Campaign.next_stage(progress)
	go(SCENE_MAP)

## 选定军师 → 正式开新战役（ascension = 心魔等级，0 为常规）
## 天时在这里才落定（roll_tian_shi），所以「揭晓」必须在拜师之后：先选人，再看天。
## 新局多一屏仪式，成就横幅让位给它，等仪式结束时补播。
func begin_run(advisor_id: String, ascension_level: int = 0, mode: String = "") -> void:
	var hero := "liubang"
	var deck: Array = (GameData.decks.get("han", []) as Array).duplicate()
	if mode == "":
		mode = pending_mode
	pending_mode = "regular"
	progress = Campaign.start_run(hero, deck, advisor_id, ascension_level, mode)
	stage = Campaign.next_stage(progress)
	var ach := Codex.record_advisor(advisor_id)
	if str(progress.get("tianShi", "")) != "":
		_deferred_announce = ach
		go(SCENE_OMEN)
		return
	announce(ach)
	go(SCENE_MAP)

## 本关还剩几次重整（结算面板与过场页都要用；返回 0 表示再败即终局）
func stage_retry_left() -> int:
	return Campaign.retry_left(progress, str(stage.get("id", "")))

## 点关卡 → 过场
func open_stage(stage_id: String) -> void:
	if Campaign.status_of(progress, stage_id) != "open":
		return
	stage = Campaign.stage_by_id(stage_id)
	go(SCENE_INTRO)

## 过场页点「出阵」
func launch_stage() -> void:
	if stage.is_empty():
		go(SCENE_MAP)
		return
	var hero_id := str(progress.get("hero", "liubang"))
	var hero := GameData.hero(hero_id)
	var rules := Campaign.engine_rules(stage, progress)
	Campaign.consume_boosts(progress)
	var enemy: Dictionary = stage.get("enemy", {})
	var meta: Dictionary = enemy.get("meta", {})
	battle_config = {
		"hero": hero_id,
		"foe": str(enemy.get("heroId", "xiangyu")),
		"foeMeta": meta,
		"rules": rules,
		"deck": (progress.get("deck", []) as Array).duplicate(),
		"enemyDeck": (rules.get("enemyDeck", []) as Array).duplicate(),
		"aiLevel": str(stage.get("aiLevel", "bijiang")),
		"stageName": str(stage.get("name", "")),
		"goalText": str(stage.get("goalText", "")),
		"mode": "campaign",
		"heroName": str(hero.get("name", "")),
	}
	go(SCENE_BATTLE)

## 战斗结算（battle.gd 调）
func finish_battle(win: bool, info: Dictionary = {}) -> void:
	last_battle = info
	last_battle["win"] = win
	last_battle["heroId"] = str(battle_config.get("hero", "liubang"))
	last_battle["level"] = str(battle_config.get("aiLevel", "bijiang"))
	# 战绩与成就：字段摊平，方便 Codex 的判定条件直接取
	var st: Dictionary = last_battle.get("stats", {})
	for k in ["dmg", "heroDmg", "units", "spells"]:
		last_battle[k] = int(st.get(k, 0))
	announce(Codex.record_battle(last_battle))
	if str(battle_config.get("mode", "")) != "campaign":
		go(SCENE_MENU, 0.1)
		return
	if not win:
		# 败仗不推进进度。每关只有 RETRY_PER_STAGE 次重整机会：
		# 用完还败 → 本局终结，清档回存档位（成就与生涯是独立存档，不受影响）
		var sid := str(stage.get("id", ""))
		if Campaign.take_retry(progress, sid):
			go(SCENE_MAP, 0.1)
			return
		Campaign.end_run()
		run_end_notice = "重整机会已尽，大军溃散 · 本局终结"
		progress = {}
		stage = {}
		pending_event = {}
		reward_cards = []
		go(SCENE_SLOTS, 0.1)
		return
	go(SCENE_REWARD, 0.1)

## 奖励页数据准备（reward.gd 在 _ready 里调）
func prepare_rewards() -> void:
	var hero_id := str(progress.get("hero", "liubang"))
	var hero := GameData.hero(hero_id)
	reward_cards = Campaign.roll_rewards(stage, str(hero.get("faction", "han")), 3,
		progress.get("deck", []))

## 选完奖励 → 结算通关 → 事件或回地图
func take_reward(card_id: String) -> void:
	if not stage.is_empty():
		Campaign.clear_stage(progress, str(stage["id"]), card_id)
	progress = Campaign.load_slot(Campaign.active_slot())
	_after_reward()

## 奖励页的次要选项：不取牌，改为从牌组删掉一张。
## 定价依据（test/_tune-skip2.js，120 局/格）：删掉 1~2 张「兵·新卒」这类废牌
## 比多拿一张奖励牌更强（第 4 关 +7pp、第 8 关 +26pp vs 单张 3~6pp），
## 但删到 4 张开始回落（低费填线被删空）——所以它是一个真实的构筑决策，不是白给。
func take_reward_skip(card_id: String) -> void:
	if stage.is_empty():
		return
	Campaign.clear_stage(progress, str(stage["id"]), "")
	if card_id != "":
		Campaign.remove_card(progress, card_id)
	progress = Campaign.load_slot(Campaign.active_slot())
	_after_reward()

## 奖励结算之后的公共尾巴：生涯记录 → 结局 / 事件 / 下一关
func _after_reward() -> void:
	# 生涯通关记录：只有首次通关才会计入成就，重打不重复
	if not stage.is_empty():
		var all := Campaign.stages()
		var idx := 0
		for i in all.size():
			if str(all[i]["id"]) == str(stage["id"]):
				idx = i
		announce(Codex.record_clear(str(stage["id"]), idx,
			(progress.get("deck", []) as Array).size(), all.size(),
			int(progress.get("ascension", 0)), str(progress.get("mode", "regular"))))
	if Campaign.is_finished(progress):
		# 八关全破 → 结局画面收束（不再有事件/地图）
		pending_event = {}
		stage = {}
		go(SCENE_ENDING)
		return
	if Campaign.needs_event(progress, stage):
		pending_event = Campaign.pick_event(progress)
		go(SCENE_EVENT)
		return
	pending_event = {}
	stage = Campaign.next_stage(progress)
	go(SCENE_MAP)

func finish_event() -> void:
	if not pending_event.is_empty():
		announce(Codex.record_event(str(pending_event.get("id", ""))))
	pending_event = {}
	stage = Campaign.next_stage(progress)
	go(SCENE_MAP)

## 快速开战：不进战役，纯单局
func quick_battle() -> void:
	progress = {}
	stage = {}
	battle_config = {
		"hero": "liubang",
		"foe": "xiangyu",
		"foeMeta": {},
		"rules": {},
		"deck": [],
		"enemyDeck": [],
		"aiLevel": "bijiang",
		"stageName": "快速开战",
		"goalText": "",
		"mode": "quick",
	}
	go(SCENE_BATTLE)

# ---------------- PvP ----------------

func open_lobby() -> void:
	progress = {}
	stage = {}
	battle_config = {}
	go(SCENE_LOBBY)

## PvP 结算记账（battle 结算面板调用）
func record_pvp(win: bool) -> void:
	Codex.record_pvp(win)

## 对局结束回大厅（重开一局走这里）
func pvp_back_to_lobby() -> void:
	Pvp.leave()
	open_lobby()

func pvp_leave_to_menu() -> void:
	Pvp.leave()
	back_to_menu()

## 等待对手重连时主动离开
func pvp_leave_early() -> void:
	Pvp.leave()
	open_lobby()

func back_to_menu() -> void:
	progress = {}
	stage = {}
	battle_config = {}
	go(SCENE_MENU)


# ---------------- 成就解锁提示 ----------------

## 把压在仪式页后面的成就横幅放出来（omen 页收尾时调）
func flush_announce() -> void:
	if _deferred_announce.is_empty():
		return
	var list := _deferred_announce
	_deferred_announce = []
	announce(list)

## 弹一条横幅播报新解锁的成就（任意场景通用，2.8 秒后自动收走）
func announce(list: Array) -> void:
	if list.is_empty():
		return
	var shown: Array = list.slice(0, 3)
	var h := 58.0 + 30.0 * float(shown.size())
	var w := 460.0
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SEAL, UiTheme.INK, 10, 3))
	# 公告条挂在 App 自己的 CanvasLayer 上，不跟场景位移走 → 按视口真宽居中
	box.position = Vector2((Widgets.viewport_size().x - w) * 0.5, -h - 20.0)
	box.size = Vector2(w, h)
	box.custom_minimum_size = Vector2(w, h)
	layer.add_child(box)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 22)
	pad.add_theme_constant_override("margin_right", 22)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	box.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	pad.add_child(col)
	var head := UiTheme.label("成 就 达 成", 15, UiTheme.PAPER)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	for a in shown:
		var line := UiTheme.label(I18n.T("「%s」%s" % [Codex.ach_name(a), Codex.ach_desc(a)]), 14, Color(1, 0.96, 0.9))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(line)

	var tw := create_tween()
	tw.tween_property(box, "position:y", 26.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(box, "position:y", -h - 20.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(layer.queue_free)
	Audio.sfx("win")

# ---------------- 开发用：全流程截图巡览 ----------------
## 用法：Godot --path godot -- --tour
## 依次走 主菜单 → 存档位 → 地图 → 过场 → 对战 → 奖励 → 事件，每屏存一张 png。

func _tour() -> void:
	await get_tree().create_timer(1.4).timeout
	# 引导存档也备份：巡览会强制弹一次引导，不能把玩家真实的首局引导吃掉
	var tut_backup := _read_file(Tutorial.PATH)
	# 造一份「打到一半」的存档，好看到已破/待战/未解锁三种节点
	Campaign.use_slot(0)
	var p := Campaign.start_run("liubang", (GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	# 三张奖励都挑死战牌：这样巡览里的地图能看到「死战专精」的常驻 chip
	Campaign.clear_stage(p, "peixian", "n_shi5")
	Campaign.clear_stage(p, "hongmen", "n_cheng2")
	Campaign.clear_stage(p, "pengcheng", "n_shi4")
	p["hpBonus"] = 3
	Campaign.save_slot(0, p)
	progress = Campaign.load_slot(0)
	_shot("_gd-menu.png")

	# 联机大厅（静态界面，不发网络请求）
	open_lobby()
	await get_tree().create_timer(0.8).timeout
	_shot("_gd-lobby.png")
	back_to_menu()
	await get_tree().create_timer(0.5).timeout

	# 设置面板（Esc 呼出，会暂停游戏树）
	toggle_settings()
	await get_tree().create_timer(0.9).timeout
	_shot("_gd-settings.png")
	toggle_settings()
	await get_tree().create_timer(0.5).timeout

	go(SCENE_SLOTS)
	await get_tree().create_timer(1.5).timeout
	_shot("_gd-slots.png")

	# 图鉴三屏
	go(SCENE_CODEX)
	await get_tree().create_timer(1.5).timeout
	var codex := get_tree().current_scene
	if codex != null and codex.has_method("_select_card"):
		# 选一张死战牌本身：巡览要能拍到「大图右上角的关键词印」，
		# 挑没有关键词的卡拍出来是空的，等于没验
		codex._select_card("n_shi5")
	await get_tree().create_timer(0.8).timeout
	_shot("_gd-codex-cards.png")
	if codex != null and codex.has_method("_switch_tab"):
		codex._switch_tab("stats")
		await get_tree().create_timer(0.9).timeout
		_shot("_gd-codex-stats.png")
		codex._switch_tab("ach")
		await get_tree().create_timer(0.9).timeout
		_shot("_gd-codex-ach.png")

	progress = Campaign.load_slot(0)
	go(SCENE_MAP)
	await get_tree().create_timer(1.6).timeout
	_shot("_gd-map.png")

	stage = Campaign.stage_by_id("xingyang")
	go(SCENE_INTRO)
	await get_tree().create_timer(1.4).timeout
	_shot("_gd-intro.png")

	launch_stage()
	await get_tree().create_timer(3.2).timeout
	_shot("_gd-battle-campaign.png")

	# 新手引导浮层（巡览里强制弹一次，截图后收掉）
	var bscene := get_tree().current_scene
	if bscene != null and bscene.has_method("_force_intro"):
		bscene._force_intro()
		await get_tree().create_timer(1.0).timeout
		_shot("_gd-coach.png")
		if bscene.has_method("_close_coach"):
			bscene._close_coach()
		await get_tree().create_timer(0.3).timeout

	# 卡牌悬停浮层（直接调接口模拟一次悬停，免得依赖鼠标；优先挑带关键词的牌，截图更有信息量）
	if bscene != null and bscene.get("card_tip") != null:
		var hand: Array = (bscene.state as Dictionary).get("players", {}).get("p1", {}).get("hand", [])
		var pick = null
		for hc in hand:
			if str(hc.get("desc", "")) != "" and Tutorial.keywords_in(str(hc["desc"])).size() > 0:
				pick = hc
				break
		if pick == null and hand.size() > 0:
			pick = hand[0]
		if pick != null:
			var v0 = bscene.card_views.get(int(pick["uid"]), null)
			if v0 != null:
				bscene.card_tip.show_card(v0.card)
				bscene.card_tip.place_near(v0.get_global_rect(),
					(bscene.hero_bars["p1"]["holder"] as Control).get_global_rect())
				# 部队牌顺带点亮目标列，截图能看到「悬停 → 落点」联动
				if str(v0.card.get("type", "")) == "piece":
					bscene._highlight_col("p1", str(v0.card.get("col", "")))
				await get_tree().create_timer(0.5).timeout
				_shot("_gd-cardtip.png")
				bscene.card_tip.hide_tip()
				bscene._clear_col_highlight()

	# 暂停菜单（呼出截图后收掉）
	if bscene != null and bscene.has_method("_open_pause"):
		bscene._open_pause()
		await get_tree().create_timer(0.5).timeout
		_shot("_gd-pause.png")
		bscene._close_pause()
		await get_tree().create_timer(0.3).timeout

	# 直接切奖励与事件屏（不真的打完一局，节省时间）
	prepare_rewards()
	var stage_name := str(stage.get("name", ""))
	go(SCENE_REWARD)
	await get_tree().create_timer(1.4).timeout
	_shot("_gd-reward.png")

	pending_event = Campaign.pick_event(progress)
	go(SCENE_EVENT)
	await get_tree().create_timer(1.4).timeout
	_shot("_gd-event.png")

	advisor_choices = Campaign.roll_advisors(3)
	go(SCENE_ADVISOR)
	await get_tree().create_timer(1.4).timeout
	_shot("_gd-advisor.png")

	# 心魔选中态（点一下 2 级：看得到盖章选中 + 四周暗角）
	var ascene := get_tree().current_scene
	if ascene != null and ascene.has_method("_force_asc"):
		ascene._force_asc(2)
		await get_tree().create_timer(0.9).timeout
		_shot("_gd-advisor-asc.png")

	# 天时揭晓仪式（真走一遍拜师，等签纸落地、按钮淡入后再截）
	begin_run("zhangliang", 2)
	await get_tree().create_timer(2.8).timeout
	_shot("_gd-omen.png")

	# 结局画面（伪造八关全破，只为截图；反正在 _wipe_all 之前）
	for s in Campaign.stages():
		if str(s["id"]) != "gading":
			Campaign.clear_stage(progress, str(s["id"]), "")
	progress = Campaign.load_slot(0)
	go(SCENE_ENDING)
	await get_tree().create_timer(1.6).timeout
	_shot("_gd-ending.png")

	print("[tour] 巡览完成，截图在 res://tests/ 下")
	# 清掉巡览造的假存档，避免污染真实游玩
	Campaign._wipe_all()
	_write_file(Tutorial.PATH, tut_backup)
	Tutorial._reload()
	# 设置文件原样写回（巡览期间可能被 --lang 改过语言），再重新读一遍
	_write_file(Settings.PATH, _settings_backup)
	Settings.reload()
	I18n.init_from_settings()
	progress = {}
	stage = {}
	battle_config = {}
	get_tree().quit()

func _shot(file_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/" + file_name)
	print("[tour] 截图 ", file_name, " ", img.get_size())

## 文本文件的读/写/删（巡览备份存档用）
func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s

func _write_file(path: String, text: String) -> void:
	if text == "":
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()


# ---------------- 开发用：战役闭环 E2E（无头） ----------------
## 用法：godot --headless --path godot -- --flow
## 不真打：直接伪造胜局，验证 战斗→奖励→事件→地图 的真实场景路由与进度落盘。

func _flow_test() -> void:
	_flow_checks = 0
	_flow_fails = 0
	# 跳过主菜单动画
	await get_tree().create_timer(0.4).timeout
	Campaign.use_slot(0)
	Campaign._wipe_all()
	# 拜师 → 天时揭晓 → 地图：新局多一屏仪式，不能把流程卡住
	begin_run("zhangliang", 0)
	await get_tree().create_timer(1.8).timeout
	var sc0 := get_tree().current_scene
	_fok(sc0 != null and sc0.scene_file_path == SCENE_OMEN, "择师后先过天时揭晓")
	_fok(str(progress.get("tianShi", "")) != "", "天时已落定")
	_fok(not Campaign.tian_shi_by_id(str(progress.get("tianShi", ""))).is_empty(), "天时能查到条目")
	if sc0 != null and sc0.has_method("_continue"):
		sc0._continue()
	await get_tree().create_timer(1.2).timeout
	sc0 = get_tree().current_scene
	_fok(sc0 != null and sc0.scene_file_path == SCENE_MAP, "揭晓后进入战役地图")
	# 重开一局，回到原本的流程主线
	Campaign._wipe_all()
	progress = Campaign.start_run("liubang", (GameData.decks.get("han", []) as Array).duplicate(), "zhangliang")
	_fok(progress["deck"].size() == 20, "开局牌组 20 张")
	stage = Campaign.stage_by_id("peixian")
	launch_stage()
	await get_tree().create_timer(1.2).timeout
	var sc := get_tree().current_scene
	_fok(sc != null and sc.scene_file_path == SCENE_BATTLE, "进入战斗场景")
	_fok(not battle_config.is_empty() and str(battle_config["mode"]) == "campaign", "战斗配置就位")
	# 伪造胜局
	finish_battle(true, {"turns": 9})
	await get_tree().create_timer(1.2).timeout
	sc = get_tree().current_scene
	_fok(sc.scene_file_path == SCENE_REWARD, "胜局进入奖励屏")
	_fok(reward_cards.size() == 3, "奖励候选 3 张")
	take_reward(str(reward_cards[0]))
	await get_tree().create_timer(1.2).timeout
	sc = get_tree().current_scene
	_fok(sc.scene_file_path == SCENE_EVENT, "奖励后进入行军事件")
	progress = Campaign.load_slot(0)
	_fok("peixian" in progress["cleared"], "通关已落盘")
	_fok(progress["deck"].size() == 21, "奖励牌已入组（21 张）")
	finish_event()
	await get_tree().create_timer(1.2).timeout
	sc = get_tree().current_scene
	_fok(sc.scene_file_path == SCENE_MAP, "事件后回到地图")
	_fok(str(stage.get("id", "")) == "hongmen", "当前关推进到鸿门宴")
	# 败仗路径
	open_stage("hongmen")
	await get_tree().create_timer(0.8).timeout
	launch_stage()
	await get_tree().create_timer(1.0).timeout
	finish_battle(false)
	await get_tree().create_timer(1.2).timeout
	sc = get_tree().current_scene
	_fok(sc.scene_file_path == SCENE_MAP, "败仗回地图不推进")
	progress = Campaign.load_slot(0)
	_fok(not ("hongmen" in progress["cleared"]), "败仗不计通关")
	var next := Campaign.next_stage(progress)
	_fok(str(next.get("id", "")) == "hongmen", "仍可重打鸿门宴")
	# 结局路由：八关全破后选完奖励 → 结局画面（而非地图/事件）
	for s in Campaign.stages():
		if str(s["id"]) != "gading":
			Campaign.clear_stage(progress, str(s["id"]), "")
	progress = Campaign.load_slot(0)
	stage = Campaign.stage_by_id("gading")
	finish_battle(true, {"turns": 12})
	await get_tree().create_timer(1.2).timeout
	take_reward("n_bing2")
	await get_tree().create_timer(1.2).timeout
	sc = get_tree().current_scene
	_fok(sc != null and sc.scene_file_path == SCENE_ENDING, "八关全破进入结局画面")
	_fok(Campaign.is_finished(Campaign.load_slot(0)), "全通进度已落盘")

	# 重整用尽 → 本局终结（P5）：同一关两连败，清档回存档位
	Campaign._wipe_all()
	progress = Campaign.start_run("liubang",
		(GameData.decks.get("han", []) as Array).duplicate(), "", 0, "regular")
	stage = Campaign.next_stage(progress)
	open_stage(str(stage.get("id", "")))
	await get_tree().create_timer(0.6).timeout
	launch_stage()
	await get_tree().create_timer(0.8).timeout
	finish_battle(false)
	await get_tree().create_timer(1.2).timeout
	_fok(get_tree().current_scene.scene_file_path == SCENE_MAP, "首败仍可重整（回地图，不终结）")
	_fok(int(Campaign.retry_left(Campaign.load_slot(0), str(stage.get("id", "")))) == 0,
		"首败已消耗本关重整机会")
	# 同一关再败一次 → 本局终结
	open_stage(str(stage.get("id", "")))
	await get_tree().create_timer(0.6).timeout
	launch_stage()
	await get_tree().create_timer(0.8).timeout
	finish_battle(false)
	await get_tree().create_timer(1.2).timeout
	_fok(get_tree().current_scene.scene_file_path == SCENE_SLOTS, "同一关二败 → 回存档位")
	_fok(bool(Campaign.slot_summary(0)["empty"]), "本局终结后存档位已清空")
	_fok(run_end_notice == "", "终局提示只在存档页显示一次")
	Campaign._wipe_all()
	progress = {}
	stage = {}
	battle_config = {}
	print("E2E：通过 %d 项，失败 %d 项" % [_flow_checks, _flow_fails])
	get_tree().quit(1 if _flow_fails > 0 else 0)
