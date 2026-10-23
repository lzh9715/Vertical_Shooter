extends Node

func _ready() -> void:
	print("总线：Music=", AudioServer.get_bus_index("Music"),
		" SFX=", AudioServer.get_bus_index("SFX"))
	print("初始：master=%.2f music=%.2f sfx=%.2f fullscreen=%s" % [
		Settings.master, Settings.music, Settings.sfx, Settings.fullscreen])

	Settings.set_master(0.3)
	Settings.set_music(0.5)
	Settings.set_sfx(0.7)
	Settings.set_fullscreen(false)

	print("设置后：master=%.2f music=%.2f sfx=%.2f" % [
		Settings.master, Settings.music, Settings.sfx])

	var cfg := ConfigFile.new()
	print("读取文件 err=", cfg.load("user://settings.cfg"))
	print("文件内容：master=", cfg.get_value("audio", "master", -1.0),
		" music=", cfg.get_value("audio", "music", -1.0),
		" sfx=", cfg.get_value("audio", "sfx", -1.0))

	get_tree().quit()