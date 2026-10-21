extends RefCounted
class_name ScreenUtil

## 逻辑画面尺寸与坐标换算。
##
## 尺寸来自 project.godot 的 viewport 设置，运行期是常量，
## 所以缓存一次即可：敌人每帧要调用 scale_factor() / size()，
## 原实现每次都查 ProjectSettings（字符串 → 字典 → Variant），
## 数量一多就是可测量的开销。

const BASE_WIDTH := 720.0
const BASE_HEIGHT := 1280.0

static var _cached_size := Vector2.ZERO
static var _cached_scale := 0.0

## 当前逻辑画面尺寸（缓存后不再查询 ProjectSettings）
static func size() -> Vector2:
	if _cached_size == Vector2.ZERO:
		_cached_size = Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", BASE_WIDTH)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", BASE_HEIGHT))
		)
	return _cached_size

## 相对设计基准的缩放系数（缓存）
static func scale_factor() -> float:
	if _cached_scale == 0.0:
		_cached_scale = size().x / BASE_WIDTH
	return _cached_scale

## 锚点(-1~1) → 画面像素坐标。(0,0)=正中，(-1,-1)=左上角
static func from_anchor(anchor: Vector2) -> Vector2:
	var s := size()
	return Vector2((anchor.x + 1.0) * 0.5 * s.x, (anchor.y + 1.0) * 0.5 * s.y)

## 清空缓存。正常运行时不需要；只有运行期改变分辨率/热重载时才需要手动调用。
static func refresh() -> void:
	_cached_size = Vector2.ZERO
	_cached_scale = 0.0
