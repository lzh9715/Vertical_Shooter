extends Resource
class_name FormationShape

## 是否让阵型随行进方向旋转（约定：本地 +X 为前方）
@export var rotate_to_direction := false

## 返回相对「阵型中心」的偏移数组（单位：720 基准下的像素）。
## count = 想摆几只，spacing = 间距参数（各形状用法不同）。
func build_offsets(_count: int, _spacing: Vector2) -> Array[Vector2]:
	return []
