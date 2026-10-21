extends RefCounted
class_name ScreenUtil

## 所有数据里的像素值都按这个设计基准填写，运行时会自动按比例缩放
const BASE_WIDTH := 720.0

## 当前逻辑画面尺寸（跟 project.godot 的 viewport 设置走，与窗口大小无关）
static func size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", BASE_WIDTH)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1280))
	)

## 相对设计基准的缩放系数。换基准分辨率时，速度/间距/振幅都乘它
static func scale_factor() -> float:
	return size().x / BASE_WIDTH

## 锚点(-1~1) → 画面像素坐标。(0,0)=正中，(-1,-1)=左上角
static func from_anchor(anchor: Vector2) -> Vector2:
	var s := size()
	return Vector2((anchor.x + 1.0) * 0.5 * s.x, (anchor.y + 1.0) * 0.5 * s.y)