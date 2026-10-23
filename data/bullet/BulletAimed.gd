extends EnemyBulletPattern
class_name BulletAimed

## 单发瞄准弹：朝玩家当前位置直线飞行。

func build_directions(aim: Vector2) -> Array[Vector2]:
	var dir := aim.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT
	var out: Array[Vector2] = [dir]
	return out
