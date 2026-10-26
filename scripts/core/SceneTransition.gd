extends CanvasLayer
## 全局场景切换：淡出 → 切场景 → 淡入。挂为 Autoload。

const FADE_TIME := 0.22

var _rect: ColorRect
var _busy := false
var _pending_path := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200

	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func change_scene(path: String) -> void:
	# 淡出时用最新目标替换旧目标；淡入时保留请求，待本次完成后继续切换。
	_pending_path = path
	if _busy:
		return

	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	while not _pending_path.is_empty():
		await _fade_to(1.0)
		var target := _pending_path
		_pending_path = ""
		var error := get_tree().change_scene_to_file(target)
		if error == OK:
			await get_tree().scene_changed
		else:
			push_error("场景切换失败：%s（错误 %d）" % [target, error])
		get_tree().paused = false
		if _pending_path.is_empty():
			await _fade_to(0.0)

	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_rect, "color:a", alpha, FADE_TIME)
	await tween.finished
