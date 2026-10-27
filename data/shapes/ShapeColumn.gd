extends FormationShape
class_name ShapeColumn

## 纵向列阵：沿 y 轴排列，适合横版右侧入场。

func build_offsets(count: int, spacing: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var mid := (count - 1) * 0.5
	for i in range(count):
		out.append(Vector2(0.0, (i - mid) * spacing.y))
	return out
