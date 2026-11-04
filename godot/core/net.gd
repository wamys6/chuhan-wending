## PvP 网络层：确定性锁步的动作收发（autoload 单例 Pvp）
##
## 职责只有三件：①连中继（tools/relay.js）②建房/加入/重连的房间握手
## ③把「玩家动作」双向转发并镜像一份动作日志。规则引擎本地的执行不在这一层，
## 由 battle 场景收到 action_in 后自己重放——两端状态因此天然一致。
##
## 确定性约定：两端用同一个 seed 构造 Rng 注入 RulesEngine，之后网络上只传
## 动作（出牌 uid / 攻击目标 / 技能 / 结束回合），不传任何随机数。
extends Node

signal relay_connected
signal relay_failed(msg: String)
signal room_created(code: String)
signal room_joined(info: Dictionary)   # 加入方收到对局参数 {side, seed, ...}
signal peer_joined                      # 房主：对手入房，可以开局
signal peer_left                        # 对端掉线
signal peer_back                        # 对端重连回来了
signal resumed(info: Dictionary)        # 自己重连成功 {settings, log, as_host}
signal action_in(a: Dictionary)
signal net_error(msg: String)
signal self_dropped                     # 自己与中继的连接断了

enum { OFF, CONNECTING, LOBBY, IN_ROOM, WAITING }

const DEFAULT_RELAY := "ws://127.0.0.1:27775"

var ws: WebSocketPeer = null
var status := OFF
var role := ""                # "host" | "guest"
var code := ""                # 6 位房间码
var settings: Dictionary = {} # 对局参数（选边 / 种子 / 卡组名）
var action_log: Array = []    # 本端镜像的动作日志（重连恢复用）
var relay_url := DEFAULT_RELAY

var _intent := ""             # create | join | resume
var _pending_join := ""
var _closing := false         # 主动 leave 时不要触发 self_dropped

func _ready() -> void:
	# 暂停菜单冻结战场时，网络心跳与收包照常（断线检测不能停）
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.ensure_loaded()
	relay_url = Settings.pvp_relay

## ---------- 对外流程 ----------

## 房主：连中继并建房。settings 里至少要有 side("han"/"chu") 与 seed(int)
func host_create(game_settings: Dictionary, url: String = "") -> void:
	if url != "":
		relay_url = url
		Settings.pvp_relay = url
		Settings.save()
	_start(settings.duplicate(), "create", "")

## 加入方：连中继并按码入房
func guest_join(room_code: String, url: String = "") -> void:
	if url != "":
		relay_url = url
		Settings.pvp_relay = url
		Settings.save()
	_start({}, "join", room_code.to_upper().strip_edges())

## 掉线重连：按码回到原房间，服务端会补发完整动作日志
func resume(room_code: String = "") -> void:
	if code != "" and room_code == "":
		room_code = code
	_start({}, "resume", room_code)

func _start(s: Dictionary, intent: String, room: String) -> void:
	_close_socket()
	settings = s
	_intent = intent
	_pending_join = room
	_closing = false
	action_log.clear()
	ws = WebSocketPeer.new()
	ws.connect_to_url(relay_url)
	status = CONNECTING

## 主动离开（回主菜单时调用）：不触发 self_dropped
func leave() -> void:
	_closing = true
	if ws != null and status == IN_ROOM:
		_raw({"t": "leave"})
	_close_socket()
	status = OFF
	code = ""
	role = ""
	settings = {}
	action_log.clear()

## 出牌等玩家动作：镜像进本地日志再发出去
func send_action(a: Dictionary) -> void:
	if ws == null or status != IN_ROOM:
		return
	action_log.append(a)
	_raw({"t": "action", "a": a})

func is_in_room() -> bool:
	return status == IN_ROOM or status == WAITING

## ---------- 内部 ----------

func _process(_delta: float) -> void:
	if ws == null:
		return
	ws.poll()
	match ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if status == CONNECTING:
				status = LOBBY
				relay_connected.emit()
				match _intent:
					"create":
						_raw({"t": "create", "settings": settings})
					"join":
						_raw({"t": "join", "code": _pending_join})
					"resume":
						_raw({"t": "resume", "code": _pending_join})
			while ws.get_available_packet_count() > 0:
				var pkt := ws.get_packet()
				_handle(pkt.get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			if _closing:
				return
			var was_in := status == IN_ROOM or status == WAITING
			_close_socket()
			status = OFF
			if was_in:
				self_dropped.emit()
			else:
				relay_failed.emit("无法连接中继服务器")

func _handle(text: String) -> void:
	var m = JSON.parse_string(text)
	if typeof(m) != TYPE_DICTIONARY or not m.has("t"):
		return
	match str(m["t"]):
		"created":
			code = str(m["code"])
			role = "host"
			room_created.emit(code)
		"joined":
			role = "guest"
			code = _pending_join
			settings = m.get("settings", {}) if typeof(m.get("settings")) == TYPE_DICTIONARY else {}
			status = IN_ROOM
			room_joined.emit(settings.duplicate())
		"peer_joined":
			status = IN_ROOM
			peer_joined.emit()
		"peer_left":
			status = WAITING
			peer_left.emit()
		"peer_back":
			status = IN_ROOM
			peer_back.emit()
		"resumed":
			code = _pending_join
			var s = m.get("settings")
			if typeof(s) == TYPE_DICTIONARY:
				settings = s
			var lg = m.get("log")
			if typeof(lg) == TYPE_ARRAY:
				action_log = (lg as Array).duplicate()
			role = "host" if bool(m.get("asHost")) else "guest"
			status = IN_ROOM
			resumed.emit({"settings": settings.duplicate(), "log": action_log.duplicate()})
		"action":
			_on_remote_action(m)
		"error":
			net_error.emit(str(m.get("msg", "中继错误")))

func _on_remote_action(m: Dictionary) -> void:
	var a = m.get("a")
	if typeof(a) != TYPE_DICTIONARY:
		return
	var act: Dictionary = a
	# 顺序校验：seq 对不上说明有丢包或两端日志分叉，立即报告（锁步的生命线）
	var seq := int(m.get("seq", 0))
	if seq != action_log.size() + 1:
		net_error.emit("动作序列错位（本端 %d / 对端 %d）" % [action_log.size() + 1, seq])
	action_log.append(act)
	action_in.emit(act.duplicate())

func _raw(obj: Dictionary) -> void:
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(obj))

func _close_socket() -> void:
	if ws != null:
		ws.close()
	ws = null
