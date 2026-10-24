extends Control

## 通用二次确认弹窗。默认隐藏，调用 ask() 显示。
## 确认/取消只发信号，具体行为由使用方决定。

signal confirmed
signal cancelled
signal dismissed

@onready var message_label: Label = $Center/Panel/Margin/VBox/Message
@onready var btn_yes: Button = $Center/Panel/Margin/VBox/Buttons/BtnYes
@onready var btn_no: Button = $Center/Panel/Margin/VBox/Buttons/BtnNo

func _ready() -> void:
	visible = false
	btn_yes.pressed.connect(_on_yes)
	btn_no.pressed.connect(_on_no)

func ask(text: String) -> void:
	message_label.text = text
	visible = true
	if btn_no.visible:
		btn_no.grab_focus()
	else:
		btn_yes.grab_focus()

func ask_single(text: String, yes_text: String) -> void:
	btn_yes.text = yes_text
	btn_no.visible = false
	ask(text)

func ask_choice(text: String, yes_text: String, no_text: String) -> void:
	btn_yes.text = yes_text
	btn_no.text = no_text
	btn_no.visible = true
	ask(text)

func _on_yes() -> void:
	visible = false
	confirmed.emit()

func _on_no() -> void:
	visible = false
	cancelled.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		visible = false
		dismissed.emit()
		get_viewport().set_input_as_handled()
