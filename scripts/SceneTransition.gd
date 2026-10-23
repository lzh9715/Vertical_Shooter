extends CanvasLayer
## 全局场景切换：淡出 → 切场景 → 淡入。挂为 Autoload。

const FADE_TIME := 0.22

var _rect: ColorRect
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200

	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func change_scene(path: String) -> void:
	if _busy:
		return

	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	await _fade_to(1.0)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame

	await _fade_to(0.0)

	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_rect, "color:a", alpha, FADE_TIME)
	await tween.finished
