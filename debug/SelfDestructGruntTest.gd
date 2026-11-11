extends Node

var _state_label: Label
var _hint: Label
var _last_state := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameFlow.start_run(load("res://data/Level_01.tres"))

	var battle = load("res://scenes/battle/Battle.tscn").instantiate()
	var waves: Array[WaveData] = [load("res://data/waves/Test_SelfDestructGrunt.tres")]
	battle.test_waves = waves
	add_child(battle)

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_hint = Label.new()
	_hint.position = Vector2(30, 24)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	_hint.text = "近程自爆兵状态测试  |  追踪 → 2秒蓄力 → 自爆"
	layer.add_child(_hint)

	_state_label = Label.new()
	_state_label.position = Vector2(30, 64)
	_state_label.add_theme_font_size_override("font_size", 30)
	_state_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_state_label.text = "STATE: -"
	layer.add_child(_state_label)

func _process(_delta: float) -> void:
	var enemy = get_tree().get_first_node_in_group("enemy")
	if enemy != null and enemy.has_method("get_state_name"):
		var state_name: String = enemy.get_state_name()
		_state_label.text = "STATE: %s" % state_name
		if state_name != _last_state:
			_last_state = state_name
			print("SELF_DESTRUCT_STATE ", state_name, " pos=", enemy.global_position)
	elif _state_label != null:
		_state_label.text = "STATE: -"
