extends Node

## 用法杖卡组直接进入战斗：F6 运行。
## 法杖 1：单发/散射/追踪；法杖 2：穿透/爆裂。
## 战斗中按 Q 切换法杖。

func _ready() -> void:
	GameFlow.start_run(load("res://data/Level_01.tres"))

	var battle = load("res://scenes/battle/Battle.tscn").instantiate()
	var waves: Array[WaveData] = [load("res://data/waves/Test_Wave.tres")]
	battle.test_waves = waves
	add_child(battle)

	await get_tree().create_timer(0.2, false).timeout
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var hint := Label.new()
	hint.position = Vector2(30, 24)
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	hint.text = "法杖战斗测试：自动射击，Q 切换法杖；法杖 1 三卡，法杖 2 两卡"
	layer.add_child(hint)
