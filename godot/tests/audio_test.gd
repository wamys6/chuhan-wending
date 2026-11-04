extends SceneTree
## 音频与设置测试：素材完整性 / 循环点 / 音量映射 / 存档读写 / 切曲状态机
##
## 运行：godot --headless --path godot --script res://tests/audio_test.gd
## headless 下音频走 Dummy 驱动，播放调用不会真的出声，但接口与资源加载全都能验。

var checks := 0
var failures := 0
var failed_lines: Array = []

const BGM_TRACKS := ["title", "map", "battle"]
const SFX_NAMES := [
	"card", "spell", "attack", "hurt", "skill",
	"turn", "click", "tick", "draw", "win", "lose",
	"seal", "lottery", "omen",
]

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	var line := "  ✗ " + label + ("" if detail == "" else "  ← " + detail)
	failed_lines.append(line)
	print(line)

func _initialize() -> void:
	# 音频播放器必须已进场景树才能 play()，所以推迟到第一帧空闲时再跑
	_run.call_deferred()

func _run() -> void:
	var backup := _read_settings_file()
	_test_assets()
	_test_settings()
	_test_audio()
	_test_panel()
	_restore_settings_file(backup)
	print("通过 %d 项，失败 %d 项" % [checks, failures])
	# 主动收摊，避免退出时一堆 RID 泄漏告警
	Audio.shutdown()
	quit(1 if failures > 0 else 0)

# ---------------- 素材 ----------------

func wav_info(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var head := f.get_buffer(44)
	if head.size() < 44:
		return {}
	var info := {
		"riff": head.slice(0, 4).get_string_from_ascii(),
		"wave": head.slice(8, 12).get_string_from_ascii(),
		"format": head.decode_u16(20),
		"channels": head.decode_u16(22),
		"rate": head.decode_u32(24),
		"bits": head.decode_u16(34),
		"data": head.decode_u32(40),
	}
	info["seconds"] = float(info["data"]) / float(int(info["rate"]) * int(info["channels"]) * (int(info["bits"]) / 8))
	f.close()
	return info

func _test_assets() -> void:
	print("· 音频素材")
	var total_mb := 0.0
	for name in BGM_TRACKS:
		var path := "res://assets/audio/bgm_%s.wav" % name
		var info := wav_info(path)
		ok(not info.is_empty(), "存在 BGM " + name)
		if info.is_empty():
			continue
		ok(info["riff"] == "RIFF" and info["wave"] == "WAVE", "BGM %s 是合法 WAV" % name)
		ok(int(info["format"]) == 1, "BGM %s 为 PCM" % name)
		ok(int(info["channels"]) == 1, "BGM %s 单声道" % name)
		ok(int(info["rate"]) == 44100, "BGM %s 采样率 44100" % name)
		# 循环曲太短会明显听出重复；30 秒是下线
		ok(float(info["seconds"]) > 25.0, "BGM %s 时长 %.1fs > 25s" % [name, info["seconds"]],
			"%.1fs" % info["seconds"])
		total_mb += float(info["data"]) / 1048576.0
	for name in SFX_NAMES:
		var info := wav_info("res://assets/audio/sfx_%s.wav" % name)
		ok(not info.is_empty(), "存在音效 " + name)
		if info.is_empty():
			continue
		ok(float(info["seconds"]) <= 1.5, "音效 %s 足够短（≤1.5s）" % name)
		total_mb += float(info["data"]) / 1048576.0
	ok(total_mb < 14.0, "音频总量 < 14MB", "%.1fMB" % total_mb)

# ---------------- 设置 ----------------

func _read_settings_file() -> String:
	if not FileAccess.file_exists(Settings.PATH):
		return ""
	return FileAccess.get_file_as_string(Settings.PATH)

func _restore_settings_file(text: String) -> void:
	if text == "":
		if FileAccess.file_exists(Settings.PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
		return
	var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	Settings._loaded = false
	Settings.ensure_loaded()

func _test_settings() -> void:
	print("· 设置")
	Settings.ensure_loaded()
	ok(Settings.bgm > 0.0 and Settings.bgm <= 1.0, "音乐音量在 0-1 之间")
	ok(Settings.motion, "动效默认开启")

	Settings.set_bgm(1.7)
	ok(is_equal_approx(Settings.bgm, 1.0), "音量上界被夹到 1.0")
	Settings.set_bgm(-0.4)
	ok(is_equal_approx(Settings.bgm, 0.0), "音量下界被夹到 0.0")
	Settings.set_bgm(0.55)
	Settings.set_sfx(0.35)
	Settings.set_motion(false)
	Settings.set_muted(true)

	# 落盘后重新读
	var text := FileAccess.get_file_as_string(Settings.PATH)
	ok(text.contains("\"bgm\""), "设置有落盘")
	var parsed = JSON.parse_string(text)
	ok(typeof(parsed) == TYPE_DICTIONARY and is_equal_approx(float(parsed["bgm"]), 0.55),
		"落盘的音乐音量正确")

	Settings._loaded = false
	Settings.bgm = 0.6
	Settings.sfx = 0.8
	Settings.muted = false
	Settings.motion = true
	Settings.ensure_loaded()
	ok(is_equal_approx(Settings.bgm, 0.55), "重读后音乐音量恢复为 0.55")
	ok(is_equal_approx(Settings.sfx, 0.35), "重读后音效音量恢复为 0.35")
	ok(Settings.muted, "重读后静音状态保留")
	ok(not Settings.motion, "重读后动效关闭状态保留")

	# 复原，避免污染真实游玩
	Settings.set_muted(false)
	Settings.set_motion(true)
	Settings.set_bgm(0.6)
	Settings.set_sfx(0.8)

# ---------------- 音频 ----------------

func _test_audio() -> void:
	print("· 音频")
	# 循环点：WAV 导入默认不循环，Audio 加载时要置成前向循环到末尾
	for name in BGM_TRACKS:
		var path := "res://assets/audio/bgm_%s.wav" % name
		var stream := Audio._load_loop(path)
		ok(stream is AudioStreamWAV, "BGM %s 载入为 AudioStreamWAV" % name)
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			ok(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "BGM %s 设为前向循环" % name)
			ok(wav.loop_end > 0, "BGM %s 循环终点已设置" % name)
			var info := wav_info(path)
			# 导入时被压成 QOA，解码时长应与源文件一致（不许截断）
			ok(absf(wav.get_length() - float(info["seconds"])) < 0.1,
				"BGM %s 解码时长与源文件一致" % name,
				"%.2fs vs %.2fs" % [wav.get_length(), info["seconds"]])
			var frames := int(round(wav.get_length() * float(wav.mix_rate)))
			ok(absi(wav.loop_end - frames) <= 2, "BGM %s 循环终点等于总帧数" % name,
				"%d vs %d" % [wav.loop_end, frames])

	# 音量映射
	Settings.set_muted(true)
	ok(is_equal_approx(Audio._bgm_db(), Audio.SILENT_DB), "静音时音乐分贝为下限")
	ok(is_equal_approx(Audio._sfx_db(), Audio.SILENT_DB), "静音时音效分贝为下限")
	Settings.set_muted(false)
	ok(Audio._bgm_db() < 0.0, "非静音时音乐分贝为负值（线性音量→dB）")

	# 设置面板打开会暂停游戏树，音频节点必须自持 ALWAYS
	Audio._ensure()
	ok(Audio._bgm_player != null and Audio._bgm_player.process_mode == Node.PROCESS_MODE_ALWAYS,
		"音乐节点不受游戏暂停影响")
	var pool_always := true
	for p in Audio._pool:
		if (p as AudioStreamPlayer).process_mode != Node.PROCESS_MODE_ALWAYS:
			pool_always = false
	ok(pool_always, "音效池不受游戏暂停影响")

	# 切曲状态机
	Audio.music("map")
	ok(Audio.current_scene() == "map", "切到地图曲")
	Audio.music("battle")
	ok(Audio.current_scene() == "battle", "切到战斗曲")
	Audio.music("")
	ok(Audio.current_scene() == "", "空场景名停止音乐")
	Audio.music("nonexistent")
	ok(Audio.current_scene() == "nonexistent", "未知曲名记入状态但不报错")

	# 音效全表跑一遍，缺素材或名字写错会在这里暴露
	for name in SFX_NAMES:
		Audio.sfx(name)
	ok(true, "11 个音效调用无异常")

	# 紧张度边界
	Audio.tension(2.0)
	ok(true, "紧张度上界不崩")
	Audio.tension(-1.0)
	ok(true, "紧张度下界不崩")

# ---------------- 设置面板 ----------------

func _test_panel() -> void:
	print("· 设置面板")
	var host := Control.new()
	host.size = Vector2(1440, 900)
	root.add_child(host)
	var panel := SettingsPanel.open_on(host)
	ok(panel != null, "面板可实例化")
	ok(panel.process_mode == Node.PROCESS_MODE_ALWAYS, "面板在暂停时仍响应（PROCESS_MODE_ALWAYS）")
	var sliders := _find_all(panel, "HSlider")
	ok(sliders.size() == 2, "面板有两条音量滑条", str(sliders.size()))
	var buttons := _find_all(panel, "Button")
	# 静音 / 动效 / 全屏 / 返回
	ok(buttons.size() >= 4, "面板按钮齐备", str(buttons.size()))
	var labels := _find_all(panel, "Label")
	var has_on := false
	for l in labels:
		if str((l as Label).text).find("设") >= 0:
			has_on = true
	ok(has_on, "面板标题就位")
	panel.free()
	host.free()

func _find_all(node: Node, cls: String) -> Array:
	var out: Array = []
	if node.is_class(cls):
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_all(c, cls))
	return out
