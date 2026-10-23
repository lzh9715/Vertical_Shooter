extends CanvasLayer

@onready var master_label: Label = $Center/Panel/Margin/VBox/MasterLabel
@onready var master_slider: HSlider = $Center/Panel/Margin/VBox/MasterSlider
@onready var music_label: Label = $Center/Panel/Margin/VBox/MusicLabel
@onready var music_slider: HSlider = $Center/Panel/Margin/VBox/MusicSlider
@onready var sfx_label: Label = $Center/Panel/Margin/VBox/SfxLabel
@onready var sfx_slider: HSlider = $Center/Panel/Margin/VBox/SfxSlider
@onready var window_option: OptionButton = $Center/Panel/Margin/VBox/WindowModeOption
@onready var resolution_label: Label = $Center/Panel/Margin/VBox/ResolutionLabel
@onready var resolution_option: OptionButton = $Center/Panel/Margin/VBox/ResolutionOption
@onready var vsync_check: CheckButton = $Center/Panel/Margin/VBox/VsyncCheck
@onready var diag_label: Label = $Center/Panel/Margin/VBox/DiagLabel
@onready var diag_button: Button = $Center/Panel/Margin/VBox/DiagButton
@onready var btn_reset: Button = $Center/Panel/Margin/VBox/Buttons/BtnReset
@onready var btn_back: Button = $Center/Panel/Margin/VBox/Buttons/BtnBack

var _size_options: Array[Vector2i] = []

func _ready() -> void:
	# 暂停时也要能操作
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_fill_options()

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	window_option.item_selected.connect(_on_window_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)
	diag_button.pressed.connect(_on_copy_diagnostics)

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

# ---------- 初始化 / 同步 ----------

func _fill_options() -> void:
	window_option.clear()
	window_option.add_item("窗口", Settings.WindowMode.WINDOWED)
	window_option.add_item("全屏", Settings.WindowMode.FULLSCREEN)

	_refresh_size_options()

## 只列出当前屏幕放得下的窗口尺寸
func _refresh_size_options() -> void:
	_size_options = Settings.get_window_size_options()
	resolution_option.clear()

	for i in range(_size_options.size()):
		var size: Vector2i = _size_options[i]
		var label := "%d × %d" % [size.x, size.y]
		if i == 0:
			label += "（适应屏幕）"
		resolution_option.add_item(label, i)

func _sync_from_settings() -> void:
	master_slider.set_value_no_signal(Settings.master * 100.0)
	music_slider.set_value_no_signal(Settings.music * 100.0)
	sfx_slider.set_value_no_signal(Settings.sfx * 100.0)

	window_option.select(Settings.window_mode)

	_refresh_size_options()
	var size_index := _size_options.find(Settings.resolution)
	if size_index < 0 and not _size_options.is_empty():
		size_index = 0
		Settings.set_resolution(_size_options[0])
	resolution_option.select(maxi(size_index, 0))
	resolution_option.disabled = Settings.is_fullscreen()

	vsync_check.set_pressed_no_signal(Settings.vsync)

	_update_labels()

func _update_labels() -> void:
	master_label.text = "主音量：%d%%" % roundi(master_slider.value)
	music_label.text = "音乐：%d%%" % roundi(music_slider.value)
	sfx_label.text = "音效：%d%%" % roundi(sfx_slider.value)

	if Settings.is_fullscreen():
		var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
		resolution_label.text = "窗口大小：全屏使用显示器原生 %d×%d" % [screen.x, screen.y]
	else:
		resolution_label.text = "窗口大小"

	diag_label.text = "遇到问题时，复制诊断信息并发送至 %s" % Diagnostics.EMAIL

func _resolution_index() -> int:
	return maxi(_size_options.find(Settings.resolution), 0)

# ---------- 音频 ----------

func _on_master_changed(value: float) -> void:
	Settings.set_master(value / 100.0)
	_update_labels()

func _on_music_changed(value: float) -> void:
	Settings.set_music(value / 100.0)
	_update_labels()

func _on_sfx_changed(value: float) -> void:
	Settings.set_sfx(value / 100.0)
	_update_labels()

# ---------- 显示 ----------

func _on_window_selected(index: int) -> void:
	Settings.set_window_mode(index)
	resolution_option.disabled = index == Settings.WindowMode.FULLSCREEN
	_refresh_size_options()
	resolution_option.select(_resolution_index())
	_update_labels()

func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < _size_options.size():
		Settings.set_resolution(_size_options[index])
	_update_labels()

func _on_vsync_toggled(on: bool) -> void:
	Settings.set_vsync(on)

# ---------- 诊断 ----------

func _on_copy_diagnostics() -> void:
	Diagnostics.copy_report()
	diag_label.text = "已复制到剪贴板，请发送至 %s" % Diagnostics.EMAIL

func _on_reset() -> void:
	Settings.reset_defaults()
	_sync_from_settings()
