extends CanvasLayer

@onready var master_label: Label = $Center/Panel/Margin/VBox/MasterLabel
@onready var master_slider: HSlider = $Center/Panel/Margin/VBox/MasterSlider
@onready var music_label: Label = $Center/Panel/Margin/VBox/MusicLabel
@onready var music_slider: HSlider = $Center/Panel/Margin/VBox/MusicSlider
@onready var sfx_label: Label = $Center/Panel/Margin/VBox/SfxLabel
@onready var sfx_slider: HSlider = $Center/Panel/Margin/VBox/SfxSlider
@onready var fullscreen_check: CheckButton = $Center/Panel/Margin/VBox/FullscreenCheck
@onready var btn_reset: Button = $Center/Panel/Margin/VBox/Buttons/BtnReset
@onready var btn_back: Button = $Center/Panel/Margin/VBox/Buttons/BtnBack

func _ready() -> void:
	# 暂停时也要能操作
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	btn_reset.pressed.connect(_on_reset)
	btn_back.pressed.connect(close)

func open() -> void:
	_sync_from_settings()
	visible = true
	master_slider.grab_focus()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# ---------- 滑条 ----------

func _on_master_changed(value: float) -> void:
	Settings.set_master(value / 100.0)
	_update_labels()

func _on_music_changed(value: float) -> void:
	Settings.set_music(value / 100.0)
	_update_labels()

func _on_sfx_changed(value: float) -> void:
	Settings.set_sfx(value / 100.0)
	_update_labels()

func _on_fullscreen_toggled(on: bool) -> void:
	Settings.set_fullscreen(on)

func _on_reset() -> void:
	Settings.reset_defaults()
	_sync_from_settings()

# ---------- 同步 ----------

func _sync_from_settings() -> void:
	# 用 no_signal 避免同步时又触发一次保存
	master_slider.set_value_no_signal(Settings.master * 100.0)
	music_slider.set_value_no_signal(Settings.music * 100.0)
	sfx_slider.set_value_no_signal(Settings.sfx * 100.0)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	_update_labels()

func _update_labels() -> void:
	master_label.text = "主音量：%d%%" % roundi(master_slider.value)
	music_label.text = "音乐：%d%%" % roundi(music_slider.value)
	sfx_label.text = "音效：%d%%" % roundi(sfx_slider.value)