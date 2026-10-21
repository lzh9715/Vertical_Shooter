extends FormationShape
class_name ShapeCircle

func build_offsets(count: int, spacing: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(count):
		var a := TAU * float(i) / float(maxi(count, 1))
		out.append(Vector2(cos(a), sin(a)) * spacing.x)
	return out