extends Node
## 本地诊断信息：把版本、系统、设置和日志尾部拼成一段文本，供玩家复制后邮件反馈。

const LOG_PATH := "user://logs/godot.log"
const EMAIL := "support@example.com"   # 发布前替换成真实邮箱

func get_report() -> String:
	var lines: Array[String] = []

	lines.append("版本: %s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0")))
	lines.append("引擎: %s" % Engine.get_version_info().get("string", "unknown"))
	lines.append("系统: %s" % OS.get_name())
	lines.append("时间: %s" % Time.get_datetime_string_from_system())
	lines.append("窗口: %s  分辨率: %d×%d  垂直同步: %s" % [
		"全屏" if Settings.is_fullscreen() else "窗口",
		Settings.resolution.x, Settings.resolution.y,
		"开" if Settings.vsync else "关",
	])
	lines.append("--- 日志尾部 ---")
	lines.append(_read_tail(LOG_PATH, 12000))

	return "\n".join(lines)

func copy_report() -> void:
	DisplayServer.clipboard_set(get_report())

func _read_tail(path: String, max_chars: int) -> String:
	if not FileAccess.file_exists(path):
		return "(没有找到日志文件)"

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "(无法读取日志文件)"

	var size := file.get_length()
	var start := maxi(0, size - max_chars)
	file.seek(start)
	return file.get_buffer(size - start).get_string_from_utf8()
