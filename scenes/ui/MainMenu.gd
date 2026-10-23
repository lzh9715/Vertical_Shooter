extends Control

const LEVEL_SELECT_SCENE := "res://scenes/ui/LevelSelect.tscn"

@onready var btn_level: Button = $Menu/BtnLevel
@onready var btn_settings: Button = $Menu/BtnSettings
@onready var btn_exit: Button = $BtnExit
@onready var dialog: Control = $ConfirmDialog
@onready var settings_panel: CanvasLayer = $SettingsPanel

func _ready() -> void:
	get_tree().paused = false
	btn_level.pressed.connect(_on_level_pressed)
	btn_settings.pressed.connect(settings_panel.open)
	btn_exit.pressed.connect(_on_exit_pressed)
	dialog.confirmed.connect(_on_exit_confirmed)

func _on_level_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

func _on_exit_pressed() -> void:
	dialog.ask("确定退出游戏吗？")

func _on_exit_confirmed() -> void:
	get_tree().quit()
