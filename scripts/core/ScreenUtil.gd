extends RefCounted
class_name ScreenUtil

## 画面尺寸与坐标换算。
## 设计基准为横版 2560×1440；世界高度额外多出 50%（上下各 25%）。
## 尺寸来自 project.godot，运行时是常量，缓存一次即可。

const BASE_WIDTH := 2560.0
const BASE_HEIGHT := 1440.0
const WORLD_HEIGHT_FACTOR := 1.5

static var _cached_size := Vector2.ZERO
static var _cached_scale := 0.0

static func size() -> Vector2:
	if _cached_size == Vector2.ZERO:
		_cached_size = Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", BASE_WIDTH)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", BASE_HEIGHT))
		)
	return _cached_size

static func scale_factor() -> float:
	if _cached_scale == 0.0:
		_cached_scale = size().x / BASE_WIDTH
	return _cached_scale

## 世界尺寸：宽度固定，高度为屏幕的 1.5 倍
static func world_size() -> Vector2:
	return Vector2(size().x, size().y * WORLD_HEIGHT_FACTOR)

## 归一化锚点(-1~1) → 屏幕像素坐标
static func from_anchor(anchor: Vector2) -> Vector2:
	var s := size()
	return Vector2((anchor.x + 1.0) * 0.5 * s.x, (anchor.y + 1.0) * 0.5 * s.y)

## 归一化锚点(-1~1) → 世界像素坐标（含上下额外空间）
static func world_from_anchor(anchor: Vector2) -> Vector2:
	var s := world_size()
	return Vector2((anchor.x + 1.0) * 0.5 * s.x, (anchor.y + 1.0) * 0.5 * s.y)

## 归一化锚点(-1~1) → 当前摄像机视野外侧的世界坐标。
## 没有摄像机时回退到整张地图的锚点。
static func world_from_view_anchor(anchor: Vector2) -> Vector2:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return world_from_anchor(anchor)

	var viewport := tree.root.get_viewport()
	if viewport == null:
		return world_from_anchor(anchor)

	var camera := viewport.get_camera_2d()
	if camera == null:
		return world_from_anchor(anchor)

	var view_size := viewport.get_visible_rect().size
	var center := camera.get_screen_center_position()
	return center + Vector2(
		anchor.x * view_size.x * 0.5,
		anchor.y * view_size.y * 0.5
	)

## 摄像机 y 的可移动范围（保持视口不出世界）
static func camera_y_range() -> Vector2:
	var half := size().y * 0.5
	return Vector2(half, world_size().y - half)

static func refresh() -> void:
	_cached_size = Vector2.ZERO
	_cached_scale = 0.0
