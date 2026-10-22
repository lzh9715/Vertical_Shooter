extends FormationShape
class_name ShapeGrid

@export var columns := 3

func build_offsets(count: int, spacing: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cols := maxi(columns, 1)
	var rows := int(ceil(float(count) / float(cols)))
	for i in range(count):
		var r := floori(float(i) / float(cols))
		var c := i % cols
		var x := (c - (cols - 1) * 0.5) * spacing.x
		var y := (r - (rows - 1) * 0.5) * spacing.y
		out.append(Vector2(x, y))
	return out