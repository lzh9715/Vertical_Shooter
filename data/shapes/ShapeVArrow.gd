extends FormationShape
class_name ShapeVArrow

## 箭头形 V 字：尖端指向行进方向。
## 本地坐标 +X = 前方，尖端在原点，两翼向后展开。
## 配合 rotate_to_direction，从左往右移动时呈 ">"，从上往下呈 "v"。

func _init() -> void:
	rotate_to_direction = true

func build_offsets(count: int, spacing: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count <= 0:
		return out

	out.append(Vector2.ZERO)          # 尖端

	var k := 1
	while out.size() < count:
		var back := -k * spacing.x
		var side := k * spacing.y
		out.append(Vector2(back, -side))
		if out.size() < count:
			out.append(Vector2(back, side))
		k += 1

	return out
