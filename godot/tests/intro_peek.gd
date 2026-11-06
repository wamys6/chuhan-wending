## 一次性截图脚本：关卡过场页（验证「本关重整」这一行不压到目标条）
## 用法：godot --path godot --resolution 1440x900 --script res://tests/intro_peek.gd
extends SceneTree

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	await process_frame
	var app: Node = root.get_node("App")
	app.progress = Campaign.empty_progress("liubang")
	app.progress["deck"] = (GameData.decks.get("han", []) as Array).duplicate()
	app.progress["retried"] = []                 # 还有一次重整
	app.stage = Campaign.stage_by_id("pengcheng")
	var scene: PackedScene = load("res://scenes/stage_intro.tscn")
	var inst: Control = scene.instantiate()
	root.add_child(inst)
	for i in 8:
		await process_frame
	await create_timer(0.6).timeout
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/_peek-intro.png")
	print("shot ok ", img.get_size())
	quit(0)
