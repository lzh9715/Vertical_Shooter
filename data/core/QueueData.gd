extends SpawnGroup
class_name QueueData

@export var count: int = 5
@export var spacing_time: float = 0.2

func spawn(spawner) -> void:
	var start := ScreenUtil.world_from_view_anchor(anchor) + offset_px * ScreenUtil.scale_factor()

	for i in range(count):
		var enemy = spawner.create_enemy(enemy_data)
		if enemy == null:
			return

		enemy.start_position = start
		enemy.offset = Vector2.ZERO
		enemy.movement = movement
		enemy.direction = direction

		# 精英需要知道自己是这一队里的第几只，用来分配互不重叠的悬停车道
		if enemy.has_method("configure_lane"):
			enemy.configure_lane(i, count)

		spawner.schedule(enemy, i * spacing_time)