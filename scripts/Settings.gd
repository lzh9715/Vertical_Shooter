extends Node
## 全局设置（Autoload）。负责读写 user://settings.cfg 并应用到引擎。

const PATH := "user://settings.cfg"

const DESIGN_SIZE := Vector2i(2560, 1440)

const WINDOW_PRESETS: Array[Vector2i] = [
	Vector2i(2560, 1440),
	Vector2i(1920, 1080),
	Vector2i(1280, 720),
]

enum WindowMode { WINDOWED, FULLSCREEN }

# 0.0 ~ 1.0 的线性音量
var master := 1.0
var music := 0.8
var sfx := 0.9

# 显示
var window_mode: int = WindowMode.WINDOWED
var resolution: Vector2i = Vector2i(2560, 1440)
var vsync := true

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")

	load_settings()
	apply_all()

# ---------- 读写 ----------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return

	master = float(cfg.get_value("audio", "master", master))
	music = float(cfg.get_value("audio", "music", music))
	sfx = float(cfg.get_value("audio", "sfx", sfx))

	# 旧版本只有 fullscreen 布尔值，做一次兼容
	var legacy_fullscreen := bool(cfg.get_value("display", "fullscreen", false))
	window_mode = int(cfg.get_value("display", "window_mode", 1 if legacy_fullscreen else 0))

	resolution = Vector2i(
		int(cfg.get_value("display", "resolution_x", resolution.x)),
		int(cfg.get_value("display", "resolution_y", resolution.y))
	)
	vsync = bool(cfg.get_value("display", "vsync", vsync))

	# 屏幕变小/换显示器时，旧尺寸可能放不下；旧竖版配置也一并迁移
	var usable := get_usable_screen_size()
	if resolution.x < resolution.y \
		or resolution.x > usable.x or resolution.y > usable.y \
		or resolution.x < 200 or resolution.y < 200:
		resolution = get_default_window_size()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)

	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "resolution_x", resolution.x)
	cfg.set_value("display", "resolution_y", resolution.y)
	cfg.set_value("display", "vsync", vsync)

	cfg.save(PATH)

# ---------- 对外接口 ----------

func set_master(value: float) -> void:
	master = clampf(value, 0.0, 1.0)
	_apply_bus("Master", master)
	save_settings()

func set_music(value: float) -> void:
	music = clampf(value, 0.0, 1.0)
	_apply_bus("Music", music)
	save_settings()

func set_sfx(value: float) -> void:
	sfx = clampf(value, 0.0, 1.0)
	_apply_bus("SFX", sfx)
	save_settings()

func set_window_mode(mode: int) -> void:
	window_mode = mode
	apply_display()
	save_settings()

func set_fullscreen(on: bool) -> void:
	set_window_mode(WindowMode.FULLSCREEN if on else WindowMode.WINDOWED)

func set_resolution(size: Vector2i) -> void:
	var usable := get_usable_screen_size()
	if size.x > usable.x or size.y > usable.y:
		size = get_fit_window_size()

	resolution = size
	if window_mode == WindowMode.WINDOWED:
		DisplayServer.window_set_size(resolution)
	save_settings()

func set_vsync(on: bool) -> void:
	vsync = on
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	save_settings()

func is_fullscreen() -> bool:
	return window_mode == WindowMode.FULLSCREEN

## 当前屏幕可用的像素区域（已排除任务栏）
func get_usable_screen_size() -> Vector2i:
	var screen := DisplayServer.window_get_current_screen()
	return DisplayServer.screen_get_usable_rect(screen).size

## 按 9:16 计算能放进屏幕的最大窗口尺寸
func get_fit_window_size() -> Vector2i:
	return compute_fit_size(get_usable_screen_size())

## 纯计算版本，方便测试不同屏幕尺寸
static func compute_fit_size(usable: Vector2i) -> Vector2i:
	if usable.x <= 0 or usable.y <= 0:
		return DESIGN_SIZE

	var scale := minf(
		float(usable.x) * 0.92 / DESIGN_SIZE.x,
		float(usable.y) * 0.92 / DESIGN_SIZE.y
	)
	scale = clampf(scale, 0.35, 2.0)

	return Vector2i(
		roundi(DESIGN_SIZE.x * scale),
		roundi(DESIGN_SIZE.y * scale)
	)

## 默认窗口：设计尺寸放得下就用它，否则用适应屏幕
func get_default_window_size() -> Vector2i:
	var usable := get_usable_screen_size()
	if DESIGN_SIZE.x <= usable.x and DESIGN_SIZE.y <= usable.y:
		return DESIGN_SIZE
	return get_fit_window_size()

## 只返回当前屏幕放得下的窗口尺寸，第一项固定为「适应屏幕」
func get_window_size_options() -> Array[Vector2i]:
	var usable := get_usable_screen_size()
	var options: Array[Vector2i] = []

	var fit := get_fit_window_size()
	options.append(fit)

	for preset in WINDOW_PRESETS:
		if preset.x <= usable.x and preset.y <= usable.y and not options.has(preset):
			options.append(preset)

	if not options.has(resolution) \
		and resolution.x <= usable.x and resolution.y <= usable.y:
		options.append(resolution)

	return options

func apply_all() -> void:
	_apply_bus("Master", master)
	_apply_bus("Music", music)
	_apply_bus("SFX", sfx)
	apply_display()

func apply_display() -> void:
	if window_mode == WindowMode.FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

# ---------- 内部工具 ----------

func _apply_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return

	AudioServer.set_bus_mute(idx, value <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.001)))

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func reset_defaults() -> void:
	master = 1.0
	music = 0.8
	sfx = 0.9

	window_mode = WindowMode.WINDOWED
	resolution = get_default_window_size()
	vsync = true

	apply_all()
	save_settings()
