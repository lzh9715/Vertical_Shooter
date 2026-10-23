extends EnemyBulletPattern
class_name BulletSpread

## 扇形散射：以瞄准方向为中心，向两侧均匀展开 count 发。

@export var count := 5
@export var spread_degrees := 60.0

func build_directions(aim: Vector2) -> Array[Vector2]:
	var base := aim.normalized()
	if base == Vector2.ZERO:
		base = Vector2.LEFT

	var out: Array[Vector2] = []
	if count <= 1:
		out.append(base)
		return out

	var total := deg_to_rad(spread_degrees)
	var step := total / float(count - 1)
	var start := -total * 0.5
	for i in range(count):
		out.append(base.rotated(start + step * i))
	return out
