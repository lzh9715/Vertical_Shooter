extends Control

## 事件界面：展示标题/描述，按数据动态生成选项按钮。
## 不可行选项照常显示，但置灰禁用。当前所有事件均为单选。

@onready var title_label: Label = $VBox/Title
@onready var body_label: Label = $VBox/Body
@onready var options_box: VBoxContainer = $VBox/Options
@onready var result_label: Label = $VBox/Result
@onready var btn_continue: Button = $VBox/Continue

var _event: EventData
var _resolved := false

func _ready() -> void:
	get_tree().paused = false
	AudioManager.play_music(&"event")
	btn_continue.pressed.connect(_on_continue)
	result_label.visible = false
	btn_continue.visible = false

	_event = GameFlow.current_event
	if _event == null:
		title_label.text = "无事发生"
		body_label.text = ""
		_show_result("这里什么也没有。")
		return

	_event.on_enter()
	title_label.text = _event.title
	body_label.text = _event.get_body()

	for opt in _event.build_options():
		_add_option_button(opt)

func _add_option_button(opt: EventOption) -> void:
	var button := Button.new()
	var reason := opt.unavailable_reason()

	button.text = opt.label if reason == "" else "%s（%s）" % [opt.label, reason]
	button.disabled = reason != ""
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(_on_option_pressed.bind(opt))
	options_box.add_child(button)

func _on_option_pressed(opt: EventOption) -> void:
	if _resolved:
		return
	_resolved = true

	opt.apply_costs()

	var outcome := opt.outcome
	if outcome == null:
		_show_result("什么也没有发生。")
		return

	# 战斗事件：把上下文交给战斗场景
	if outcome.battle != null:
		GameFlow.event_context["battle"] = outcome.battle
		SceneTransition.change_scene(GameFlow.BATTLE_SCENE)
		return

	outcome.apply()
	_show_result(outcome.text)

func _show_result(text: String) -> void:
	for child in options_box.get_children():
		child.visible = false

	result_label.text = text
	result_label.visible = true
	btn_continue.visible = true
	btn_continue.text = "继续"

func _on_continue() -> void:
	GameFlow.finish_node()
