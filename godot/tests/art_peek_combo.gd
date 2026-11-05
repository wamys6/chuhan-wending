## 一次性验证：连击 8 张新立绘在真实 CardView 里的显示效果（不进正式测试集）
##
## 运行：godot --path godot --resolution 1280x820 --script res://tests/art_peek_combo.gd
## 产出：godot/tests/_peek-combo.png（再手动拷进 docs/）
extends SceneTree

const IDS := ["h_zhiji", "s_liannu", "s_lianhuan", "h_qimen",
	"h_diezhen", "h_jiewu", "h_xiandeng", "s_lianying"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	GameData.ensure_loaded()
	I18n.set_lang_soft(I18n.ZH)

	var bg := ColorRect.new()
	bg.color = UiTheme.PAPER
	bg.size = Vector2(1280, 820)
	root.add_child(bg)

	# 两排 4 列：卡面放大到 1.6 倍，看清水印字/名字条/关键词印的位置关系
	var scale_up := 1.0
	var cell := Vector2(CardView.SIZE.x * scale_up + 30, CardView.SIZE.y * scale_up + 40)
	var origin := Vector2(50, 120)

	for i in IDS.size():
		var id: String = IDS[i]
		var c: Dictionary = GameData.card(id).duplicate()
		c["uid"] = i + 1
		c["baseId"] = id
		var holder := Control.new()
		var v := CardView.new()
		v.setup(c)
		v.scale = Vector2(scale_up, scale_up)
		v.position = origin + Vector2(i * cell.x, 0)
		holder.add_child(v)
		root.add_child(holder)

		# 牌 id 与中文名，方便核对「图文对得上」
		var cap := UiTheme.label("%s  %s" % [id, str(c.get("name", ""))], 17, UiTheme.INK)
		cap.position = Vector2(v.position.x, v.position.y + CardView.SIZE.y + 12)
		root.add_child(cap)

	await process_frame
	await create_timer(1.2).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/_peek-combo.png")
	print("[peek] 截图 ", img.get_size())
	quit(0)
