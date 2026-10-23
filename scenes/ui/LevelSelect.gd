extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

@export var levels: Array[LevelConfig] = []

@onready var cards: VBoxContainer = $Center/VBox/Cards
@onready var btn_back: Button = $BtnBack

func _ready() -> void:
	get_tree().paused = false
	btn_back.pressed.connect(_on_back)

	if levels.is_empty():
		var empty := Label.new()
		empty.text = "暂无关卡"
		empty.add_theme_font_size_override("font_size", 28)
		cards.add_child(empty)
		return

	for level in levels:
		_add_card(level)

func _add_card(level: LevelConfig) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1200, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var title := Label.new()
	title.text = level.display_name
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	var info := Label.new()
	info.text = "难度：普通（占位） · %d 层" % level.middle_layers
	info.add_theme_font_size_override("font_size", 32)
	info.modulate = Color(0.75, 0.75, 0.8)
	box.add_child(info)

	var enter := Button.new()
	enter.text = "进入"
	enter.custom_minimum_size = Vector2(0, 80)
	enter.add_theme_font_size_override("font_size", 36)
	enter.pressed.connect(_on_enter.bind(level))
	box.add_child(enter)

	cards.add_child(panel)

func _on_enter(level: LevelConfig) -> void:
	GameFlow.start_run(level)
	SceneTransition.change_scene(GameFlow.MAP_SCENE)

func _on_back() -> void:
	SceneTransition.change_scene(MAIN_MENU_SCENE)
