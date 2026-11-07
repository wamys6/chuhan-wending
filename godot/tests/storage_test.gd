extends SceneTree
## 存档鲁棒性测试 —— 原子写入 / 坏档恢复 / 类型校验
##
## 运行：godot --headless --path godot --script res://tests/storage_test.gd
##
## 为什么要有这个测试：写存档原来是「先截断再写」，断电/强退就留下半截 JSON；
## 读取端解析失败又静默回退空档 —— 玩家会看到图鉴清零、三个存档位全空。
## 这里验的不是「写得进去」，是「写坏了会怎样」。

const TP := "user://_st_test.json"

var checks := 0
var failures := 0
var failed_lines: Array = []
var backup := {}

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	var line := "  ✗ " + label + ("" if detail == "" else "  ← " + detail)
	failed_lines.append(line)
	print(line)

func _initialize() -> void:
	_run.call_deferred()

func _clean(p: String) -> void:
	for suffix in ["", ".tmp", ".corrupt"]:
		var path: String = p + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_raw(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()

## 本测试会反复破坏真实存档文件，跑之前必须整体备份、跑完原样放回
## （踩过坑：巡览把 settings 的 lang 改成 en 没还原，后续所有截图都是英文）
func _backup_all() -> void:
	for p in [Codex.PATH, Campaign.SAVE_PATH, Settings.PATH]:
		backup[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
		_clean(p)

func _restore_all() -> void:
	for p in backup.keys():
		_clean(p)
		if backup[p] == null:
			continue
		_write_raw(p, backup[p])
	Codex._loaded = false
	Settings._loaded = false

func _run() -> void:
	_backup_all()
	_clean(TP)
	print("· 原子写入")
	_test_write()
	print("· 临时文件回退")
	_test_tmp_fallback()
	print("· 坏档备份与自愈")
	_test_corrupt()
	print("· Codex 坏档")
	_test_codex()
	print("· Campaign 坏档")
	_test_campaign()
	print("· Settings 坏档")
	_test_settings()
	_clean(TP)
	_restore_all()
	print("通过 %d 项，失败 %d 项" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_write() -> void:
	ok(SafeFile.write(TP, "{\"a\":1}"), "写入成功")
	ok(FileAccess.get_file_as_string(TP) == "{\"a\":1}", "内容一致")
	ok(not FileAccess.file_exists(TP + ".tmp"), "写入后无 .tmp 残留")
	# 覆盖写
	ok(SafeFile.write(TP, "{\"a\":2}"), "覆盖写成功")
	ok(FileAccess.get_file_as_string(TP) == "{\"a\":2}", "覆盖后是新内容")
	ok(SafeFile.read_dict(TP).get("a") == 2, "读回字段正确")
	# 中文不被转义破坏
	ok(SafeFile.write(TP, "{\"名\":\"楚\"}"), "中文写入成功")
	ok(str(SafeFile.read_dict(TP).get("名")) == "楚", "中文读回正确")

	# 核心保证：写入失败时旧内容必须原样保留
	# 构造方式：把 .tmp 路径占成目录，临时文件创建必然失败
	_clean(TP)
	SafeFile.write(TP, "{\"k\":1}")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TP + ".tmp"))
	ok(not SafeFile.write(TP, "{\"k\":2}"), "临时文件写不进去时返回 false")
	ok(FileAccess.get_file_as_string(TP) == "{\"k\":1}", "失败时旧内容完好")
	ok(int(SafeFile.read_dict(TP).get("k")) == 1, "失败后仍能读出旧数据")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TP + ".tmp"))


func _test_tmp_fallback() -> void:
	_clean(TP)
	# 只有 .tmp（上次写入没来得及 rename）
	_write_raw(TP + ".tmp", "{\"b\":7}")
	ok(SafeFile.read_dict(TP).get("b") == 7, "主文件缺失时回退 .tmp")
	# 主文件空 + tmp 有内容（每步都重建，因为读成功会清掉 tmp）
	_write_raw(TP + ".tmp", "{\"b\":7}")
	_write_raw(TP, "")
	ok(SafeFile.read_dict(TP).get("b") == 7, "主文件为空时回退 .tmp")


func _test_corrupt() -> void:
	_clean(TP)
	_write_raw(TP, "{\"a\": 1, 半截")
	var d := SafeFile.read_dict(TP)
	ok(d.is_empty(), "坏档返回空字典（不崩）")
	ok(FileAccess.file_exists(TP + ".corrupt"), "坏档已备份")
	ok(FileAccess.get_file_as_string(TP + ".corrupt") == "{\"a\": 1, 半截", "备份内容原样")
	# 第二次读到坏档不该覆盖第一次的备份
	_write_raw(TP + ".corrupt", "FIRST")
	SafeFile.read_dict(TP)
	ok(FileAccess.get_file_as_string(TP + ".corrupt") == "FIRST", "已有备份不被覆盖")

	# 坏主文件 + 好 tmp → 自愈
	_clean(TP)
	_write_raw(TP, "{坏")
	_write_raw(TP + ".tmp", "{\"c\":9}")
	ok(SafeFile.read_dict(TP).get("c") == 9, "坏主文件时用 .tmp 救回")
	ok(not FileAccess.file_exists(TP + ".tmp"), "自愈后 .tmp 已提升")
	ok(SafeFile.read_dict(TP).get("c") == 9, "自愈后主文件可正常读")


func _test_codex() -> void:
	# 坏档：不能崩，且生涯结构完整
	Codex.reset()
	_write_raw(Codex.PATH, "{{{ 坏档")
	Codex._loaded = false
	Codex.ensure_loaded()
	ok(Codex.run_wins() == 0, "Codex 坏档回退 0 通关")
	ok(typeof(Codex.current().get("ach")) == TYPE_DICTIONARY, "ach 仍是字典")
	ok(Codex.unlock_state()["advisors"].size() == 4, "坏档时解锁仍在初始档")

	# 类型错：ach 写成数组，不能把 Array 塞进字典字段（后续 .has() 会运行时报错）
	Codex.reset()
	_write_raw(Codex.PATH, "{\"runWins\":3,\"ach\":[1,2,3],\"finished\":true}")
	Codex._loaded = false
	Codex.ensure_loaded()
	ok(typeof(Codex.current().get("ach")) == TYPE_DICTIONARY, "类型错的字段被丢弃")
	ok(Codex.run_wins() == 3, "同批正常字段仍生效")

	# 往返
	Codex.reset()
	Codex.current()["runWins"] = 2
	Codex.save()
	Codex._loaded = false
	Codex.ensure_loaded()
	ok(Codex.run_wins() == 2, "save/load 往返正确")
	ok(not FileAccess.file_exists(Codex.PATH + ".tmp"), "Codex 存档无 .tmp 残留")


func _test_campaign() -> void:
	Campaign._write_store(Campaign._empty_store())
	_write_raw(Campaign.SAVE_PATH, "不是 JSON")
	ok(Campaign.load_slot(0).is_empty(), "Campaign 坏档返回空档（不崩）")
	ok(Campaign.active_slot() == 0, "Campaign 坏档 active 归 0")
	ok(FileAccess.file_exists(Campaign.SAVE_PATH + ".corrupt"), "Campaign 坏档已备份")

	# 正常往返（用真实 progress 结构——normalize() 会丢掉不认识的键）
	Campaign._write_store(Campaign._empty_store())
	Campaign.use_slot(2)
	ok(Campaign.active_slot() == 2, "use_slot 生效")
	var prog := Campaign.empty_progress("liubang")
	prog["stage"] = 3
	Campaign.save_slot(2, prog)
	ok(int(Campaign.load_slot(2).get("stage", -1)) == 3, "save_slot/load_slot 往返")
	# 坏档后重写应恢复正常
	_write_raw(Campaign.SAVE_PATH, "坏")
	Campaign.use_slot(1)
	ok(Campaign.active_slot() == 1, "坏档后仍可正常写入")


func _test_settings() -> void:
	Settings.reload_from_disk()
	_write_raw(Settings.PATH, "[1,2,3]")
	Settings._loaded = false
	Settings.ensure_loaded()
	ok(Settings.bgm >= 0.0 and Settings.bgm <= 1.0, "Settings 坏档用默认值（不崩）")
	Settings.set_bgm(0.33)
	Settings.reload_from_disk()
	ok(absf(Settings.bgm - 0.33) < 0.001, "Settings 往返正确", "bgm=%.4f" % Settings.bgm)
