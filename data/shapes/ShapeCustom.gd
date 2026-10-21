extends FormationShape
class_name ShapeCustom

@export var points: Array[Vector2] = []

func build_offsets(_count: int, _spacing: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.assign(points)
	return out