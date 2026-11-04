## 玩家设置：音量 / 静音 / 动效 / 全屏 / 语言
##
## 用 static 变量 + 静态方法（与 GameData、Campaign 一致），任何地方都能
## 直接 `Settings.bgm` 读、`Settings.set_bgm(v)` 写，不必在场景之间传引用。
## 落盘到 user://chuhan_settings.json —— Windows 下即 %APPDATA%\Godot\app_userdata\...
class_name Settings
extends RefCounted

const PATH := "user://chuhan_settings.json"

## 音乐/音效默认值沿用 Web 版（0.6 / 0.8）
static var bgm: float = 0.6
static var sfx: float = 0.8
static var muted: bool = false
## 动效开关：关掉后所有入场淡入/位移立即到位（晕动症友好，也方便截屏比对）
static var motion: bool = true
static var fullscreen: bool = false
## 界面语言：zh | en（英文数据由后续 i18n 阶段接入）
static var lang: String = "zh"
## 联机中继地址（PvP 动作转发服务器）
static var pvp_relay: String = "ws://101.200.235.68:27775"

static var _loaded := false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	bgm = clampf(float(parsed.get("bgm", bgm)), 0.0, 1.0)
	sfx = clampf(float(parsed.get("sfx", sfx)), 0.0, 1.0)
	muted = bool(parsed.get("muted", muted))
	motion = bool(parsed.get("motion", motion))
	fullscreen = bool(parsed.get("fullscreen", fullscreen))
	lang = str(parsed.get("lang", lang))
	pvp_relay = str(parsed.get("pvpRelay", pvp_relay))

## 丢掉内存里的值，重新从磁盘读（巡览还原设置用）
static func reload() -> void:
	_loaded = false
	ensure_loaded()

static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"bgm": bgm, "sfx": sfx, "muted": muted,
		"motion": motion, "fullscreen": fullscreen, "lang": lang,
		"pvpRelay": pvp_relay,
	}, "\t"))
	f.close()

static func set_bgm(v: float) -> void:
	bgm = clampf(v, 0.0, 1.0)
	save()
	Audio.refresh_volume()

static func set_sfx(v: float) -> void:
	sfx = clampf(v, 0.0, 1.0)
	save()
	Audio.refresh_volume()

static func set_muted(v: bool) -> void:
	muted = v
	save()
	Audio.refresh_volume()
	if not v:
		Audio.sfx("click")

static func set_motion(v: bool) -> void:
	motion = v
	save()

static func set_lang(v: String) -> void:
	lang = v
	save()

## 全屏切换（窗口模式与无边框全屏之间；桌面端由 Godot 自己处理）
static func toggle_fullscreen() -> bool:
	fullscreen = not fullscreen
	_apply_fullscreen()
	save()
	return fullscreen

static func apply_fullscreen() -> void:
	_apply_fullscreen()

static func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
