extends Control
## 启动场景：目前只做数据自检，随后会换成主菜单（见 scenes/main_menu.gd）

func _ready() -> void:
	GameData.ensure_loaded()
	var n: int = GameData.cards.size()
	print("[楚汉·问鼎] Godot 版启动 — 卡牌 %d 张 / 关卡 %d 关" % [n, GameData.stages.size()])
	if n == 0:
		push_error("数据未加载：请先运行 node tools/export-data.js")
