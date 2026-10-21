extends FormationShape
class_name ShapeLine

func build_offsets(count: int, spacing: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var mid := (count - 1) * 0.5
	for i in range(count):
		out.append(Vector2((i - mid) * spacing.x, 0.0))
	return out