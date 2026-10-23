extends Node
## 全局设置（Autoload）。负责读写 user://settings.cfg 并应用到引擎。

const PATH := "user://settings.cfg"

# 0.0 ~ 1.0 的线性音量
var master := 1.0
var music := 0.8
var sfx := 0.9
var fullscreen := false

func _ready() -> void:
	# 确保有独立的音乐/音效总线，方便以后分别调音量
	_ensure_bus("Music")
	_ensure_bus("SFX")

	load_settings()
	apply_all()

# ---------- 读写 ----------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return                     # 第一次运行没有文件，用默认值

	master = float(cfg.get_value("audio", "master", master))
	music = float(cfg.get_value("audio", "music", music))
	sfx = float(cfg.get_value("audio", "sfx", sfx))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(PATH)

# ---------- 对外接口（UI 只调这些） ----------

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

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_fullscreen()
	save_settings()

func apply_all() -> void:
	_apply_bus("Master", master)
	_apply_bus("Music", music)
	_apply_bus("SFX", sfx)
	apply_fullscreen()

func apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
		else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

# ---------- 内部工具 ----------

## 把 0~1 的音量应用到某条总线；0 直接静音，避免 -inf dB
func _apply_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return

	AudioServer.set_bus_mute(idx, value <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.001)))

## Godot 默认只有 Master；这里自动补出 Music / SFX，并送到 Master
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
	fullscreen = false
	apply_all()
	save_settings()