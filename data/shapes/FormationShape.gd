extends Resource
class_name FormationShape

## 返回相对「阵型中心」的偏移数组（单位：720 基准下的像素）。
## count = 想摆几只，spacing = 间距参数（各形状用法不同）。
func build_offsets(_count: int, _spacing: Vector2) -> Array[Vector2]:
	return []