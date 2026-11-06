## 场景装配冒烟：每个 .tscn 都真的加载得起来、脚本都解析通过
##
## 为什么需要：2026-11-06 在 stage_intro.gd 里新加了一行，变量名与已有的 `rl` 重复，
## 整个脚本 Parse Error——**但 E2E 仍然全绿**，因为 E2E 只断言 `current_scene.scene_file_path`
## 是不是那个路径，脚本挂了路径照样对，画面是空的。这类「假绿」只有静态装配检查抓得到。
##
## 判据：load 得到 PackedScene、instantiate 出节点、节点上有脚本、脚本是有效 GDScript。
## 注意：**不加进场景树**（不进 tree 就不会跑 _ready），所以不依赖 App 的运行时状态。
extends SceneTree

var checks := 0
var failures := 0

func ok(cond: bool, label: String, detail: String = "") -> void:
	checks += 1
	if cond:
		return
	failures += 1
	print("  ✗ " + label + ("" if detail == "" else "  ← " + detail))

func _initialize() -> void:
	print("== 场景装配冒烟 ==")
	var dir := DirAccess.open("res://scenes")
	ok(dir != null, "scenes 目录可读")
	if dir == null:
		_finish()
		return
	var names: Array = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tscn"):
			names.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	names.sort()
	ok(names.size() >= 13, "场景数量对得上（%d 个）" % names.size())

	for name in names:
		var path := "res://scenes/" + str(name)
		var ps = load(path)
		ok(ps is PackedScene, "%s 能加载成 PackedScene" % path,
			"load 返回 " + str(typeof(ps)))
		if not (ps is PackedScene):
			continue
		var inst: Node = (ps as PackedScene).instantiate()
		ok(inst != null, "%s 能实例化" % path)
		if inst == null:
			continue
		# 脚本解析失败时 load 会失败、脚本为 null；这一条就是本次事故的判据
		var scr = inst.get_script()
		ok(scr != null, "%s 已挂脚本（解析失败会是 null）" % path)
		if scr != null:
			ok(scr is GDScript, "%s 脚本是有效 GDScript" % path, str(scr))
		inst.free()

	_finish()

func _finish() -> void:
	print("通过 %d 项，失败 %d 项" % [checks, failures])
	quit(1 if failures > 0 else 0)
