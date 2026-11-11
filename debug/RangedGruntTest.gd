extends Node

var _state_label: Label
var _hint: Label
var _last_state := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameFlow.start_run(load("res://data/Level_01.tres"))

	var battle = load("res://scenes/battle/Battle.tscn").instantiate()
	var waves: Array[WaveData] = [load("res://data/waves/Test_RangedGrunt.tres")]
	battle.test_waves = waves
	add_child(battle)

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_hint = Label.new()
	_hint.position = Vector2(30, 24)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
	_hint.text = "远程游猎兵状态测试  |  S：施加1.5秒硬直"
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
			print("RANGED_STATE ", state_name, " pos=", enemy.global_position)
	elif _state_label != null:
		_state_label.text = "STATE: -"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S:
		var enemy = get_tree().get_first_node_in_group("enemy")
		if enemy != null and enemy.has_method("apply_stun"):
			enemy.apply_stun(1.5)
