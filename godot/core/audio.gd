## 音频总控：背景音乐（场景曲）+ 音效池 + 音量/静音/紧张度
##
## 素材由 tools/make-audio.js 离线渲染（与 Web 版同一套合成参数），
## 这里只负责播放。BGM 只有一个播放器，切场景时短淡出再淡入，避免"咔"声；
## 音效走 8 个播放器轮转，允许同帧多个音效叠加。
class_name Audio
extends RefCounted

const BGM_DIR := "res://assets/audio/"
const BGM_TRACKS := {
	"title": "bgm_title",
	"map": "bgm_map",
	"battle": "bgm_battle",
}
const SFX_NAMES := [
	"card", "spell", "attack", "hurt", "skill",
	"turn", "click", "tick", "draw", "win", "lose",
	# 表现层：心魔盖章 / 摇签 / 天时铜锣
	"seal", "lottery", "omen",
]
const POOL_SIZE := 8
## 音量为 0 时给一个足够低但不等于 -inf 的分贝，避免引擎告警
const SILENT_DB := -60.0

static var _bgm_player: AudioStreamPlayer
static var _pool: Array = []
static var _pool_idx := 0
static var _cache: Dictionary = {}
static var _scene := ""
static var _tension := 0.0
static var _tween: Tween

# ---------------- 初始化 ----------------

static func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root

static func _ensure() -> bool:
	if _bgm_player != null:
		return true
	var root := _host()
	if root == null:
		return false
	Settings.ensure_loaded()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	# 设置面板打开时会暂停游戏树，音频节点必须自持 ALWAYS，否则面板里点按钮没声
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_bgm_player)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(p)
		_pool.append(p)
	refresh_volume()
	return true

# ---------------- 音量 ----------------

static func _bgm_db() -> float:
	if Settings.muted or Settings.bgm <= 0.001:
		return SILENT_DB
	return linear_to_db(Settings.bgm)

static func _sfx_db() -> float:
	if Settings.muted or Settings.sfx <= 0.001:
		return SILENT_DB
	return linear_to_db(Settings.sfx)

## 设置面板改完音量后调用（淡变，避免音量突然跳变）
static func refresh_volume() -> void:
	if not _ensure():
		return
	for p in _pool:
		p.volume_db = _sfx_db()
	var target := _bgm_db()
	if _bgm_player.playing:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = _bgm_player.create_tween()
		_tween.tween_property(_bgm_player, "volume_db", target, 0.18)
	else:
		_bgm_player.volume_db = target

# ---------------- 背景音乐 ----------------

## 切场景曲：'title' | 'map' | 'battle' | ''（停止）
static func music(scene: String) -> void:
	if scene == _scene and _bgm_player != null and _bgm_player.playing:
		return
	_scene = scene
	if not _ensure():
		return
	if scene == "" or not BGM_TRACKS.has(scene):
		_stop_bgm()
		return
	var stream := _load_loop(BGM_DIR + str(BGM_TRACKS[scene]) + ".wav")
	if stream == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _bgm_player.playing:
		_tween = _bgm_player.create_tween()
		_tween.tween_property(_bgm_player, "volume_db", SILENT_DB, 0.22)
		_tween.tween_callback(_swap_track.bind(stream))
		_tween.tween_property(_bgm_player, "volume_db", _bgm_db(), 0.7)
	else:
		_swap_track(stream)
		_bgm_player.volume_db = SILENT_DB
		_tween = _bgm_player.create_tween()
		_tween.tween_property(_bgm_player, "volume_db", _bgm_db(), 0.9)

static func _swap_track(stream: AudioStream) -> void:
	if _bgm_player == null:
		return
	_bgm_player.stream = stream
	_bgm_player.pitch_scale = 1.0 + _tension * 0.05
	_bgm_player.play()

static func _stop_bgm() -> void:
	if _bgm_player == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = _bgm_player.create_tween()
	_tween.tween_property(_bgm_player, "volume_db", SILENT_DB, 0.3)
	_tween.tween_callback(_bgm_player.stop)

static func current_scene() -> String:
	return _scene

## 战斗紧张度 0-1：残血时曲子略快一点（Web 版是加速鼓点，这里用播放速率近似）
static func tension(v: float) -> void:
	var t := clampf(v, 0.0, 1.0)
	if absf(t - _tension) < 0.08:
		return
	_tension = t
	if _bgm_player != null and _bgm_player.playing:
		var tw := _bgm_player.create_tween()
		tw.tween_property(_bgm_player, "pitch_scale", 1.0 + _tension * 0.05, 1.2)

# ---------------- 音效 ----------------

static func sfx(name: String) -> void:
	if Settings.muted:
		return
	if not _ensure():
		return
	var stream := _load_loop("res://assets/audio/sfx_%s.wav" % name)
	if stream == null:
		return
	# 轮转取播放器：池子够用时不会打断正在响的那一个
	var p: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool.size()
	p.stream = stream
	p.volume_db = _sfx_db()
	p.play()

# ---------------- 资源加载 ----------------

static func _load_loop(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
		# WAV 导入默认不循环，这里给 BGM 打开前向循环；音效不循环
		if stream is AudioStreamWAV and path.get_file().begins_with("bgm_"):
			var wav := stream.duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			# 导入后数据可能被压成 QOA（每个 slice 20 样本），不能拿 data.size() 当帧数，
			# 按解码时长折算才是真实循环点，否则会播到中途就跳回开头。
			wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
			stream = wav
	_cache[path] = stream
	return stream

## 退出前收摊：停播、释放播放器、清缓存（否则退出时会报 RID 泄漏）
static func shutdown() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _bgm_player != null and is_instance_valid(_bgm_player):
		_bgm_player.stop()
		_bgm_player.queue_free()
	_bgm_player = null
	for p in _pool:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_pool.clear()
	_cache.clear()
	_scene = ""
