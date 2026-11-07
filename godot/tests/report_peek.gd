## 一次性验证：兵败战报抓拍（不进正式测试集）
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var app: Node = root.get_node_or_null("App")
	if app == null:
		print("没有 App autoload")
		quit(1)
		return
	var p: Dictionary = Campaign.empty_progress("liubang")
	p["cleared"] = ["peixian", "hongmen", "pengcheng", "xingyang", "jingxing", "weishui"]
	p["advisor"] = "zhangliang"
	app.progress = p
	app.pending_report = {
		"turns": 12, "stats": {"dmg": 21, "units": 8},
		"stage": "固陵之战", "stageId": "guling", "foeHp": 9, "retryLeft": 1,
	}
	app.go(app.SCENE_MAP)
	await create_timer(1.4).timeout
	_shot("_gd-report-zh.png")

	# 英文版：同一场面，只是语言不同
	Settings.set_lang("en")
	I18n.init_from_settings()
	app.progress = p
	app.pending_report = {
		"turns": 12, "stats": {"dmg": 21, "units": 8},
		"stage": "固陵之战", "stageId": "guling", "foeHp": 9, "retryLeft": 0,
	}
	app.go(app.SCENE_MAP)
	await create_timer(1.4).timeout
	_shot("_gd-report-en.png")
	Settings.set_lang("zh")
	I18n.init_from_settings()
	quit(0)

func _shot(fname: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/" + fname)
	print("已存 ", fname)
