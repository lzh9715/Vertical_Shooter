extends CanvasLayer

## 通用暂停菜单：挂在 Battle / MapView 下。
## Esc 打开/关闭；暂停时本节点通过 PROCESS_MODE_ALWAYS 保持可交互。

@onready var btn_resume: Button = $Center/Panel/Margin/VBox/BtnResume
@onready var btn_settings: Button = $Center/Panel/Margin/VBox/BtnSettings
@onready var btn_menu: Button = $Center/Panel/Margin/VBox/BtnMenu
@onready var btn_quit: Button = $Center/Panel/Margin/VBox/BtnQuit
@onready var dialog: Control = $ConfirmDialog
@onready var settings_panel: CanvasLayer = $SettingsPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	btn_resume.pressed.connect(close)
	btn_settings.pressed.connect(settings_panel.open)
	btn_menu.pressed.connect(_on_main_menu)
	btn_quit.pressed.connect(_on_quit)
	dialog.confirmed.connect(_on_quit_confirmed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	# 设置面板开着时，Esc 交给它自己关闭
	if settings_panel.visible:
		return

	# 二次确认开着时，Esc 交给 ConfirmDialog 自己处理
	if dialog.visible:
		return

	if visible:
		close()
	else:
		open()

	get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	get_tree().paused = true
	btn_resume.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func _on_main_menu() -> void:
	close()
	GameFlow.go_main_menu()

func _on_quit() -> void:
	dialog.ask("确定退出游戏吗？")

func _on_quit_confirmed() -> void:
	get_tree().quit()
