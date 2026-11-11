extends Node

var _state_label: Label
var _hint: Label
var _last_states := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameFlow.start_run(load("res://data/Level_01.tres"))

	var battle = load("res://scenes/battle/Battle.tscn").instantiate()
	var waves: Array[WaveData] = [load("res://data/waves/Test_MeleeCharger.tres")]
	battle.test_waves = waves
	add_child(battle)

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_hint = Label.new()
	_hint.position = Vector2(30, 24)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
	_hint.text = "近程冲锋兵状态测试  |  S：尝试对最近敌人施加1.5秒硬直（CHARGE免疫）"
	layer.add_child(_hint)

	_state_label = Label.new()
	_state_label.position = Vector2(30, 64)
	_state_label.add_theme_font_size_override("font_size", 26)
	_state_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_state_label.text = "STATE: -"
	layer.add_child(_state_label)

func _process(_delta: float) -> void:
	var lines: Array[String] = []
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy.has_method("get_state_name"):
			var state_name: String = enemy.get_state_name()
			lines.append("%s  %s  x=%.0f" % [enemy.name, state_name, enemy.global_position.x])
			if _last_states.get(enemy.name, "") != state_name:
				_last_states[enemy.name] = state_name
				print("CHARGER_STATE ", enemy.name, " ", state_name, " x=", enemy.global_position.x)
	_state_label.text = "\n".join(lines) if not lines.is_empty() else "STATE: -"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S:
		var enemies := get_tree().get_nodes_in_group("enemy")
		if not enemies.is_empty():
			var enemy = enemies[0]
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(1.5)
