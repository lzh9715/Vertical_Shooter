extends FormationShape
class_name ShapeV

func build_offsets(count: int, spacing: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var mid := (count - 1) * 0.5
	for i in range(count):
		var dx := (i - mid) * spacing.x
		var dy := absf(i - mid) * spacing.y
		out.append(Vector2(dx, dy))
	return out