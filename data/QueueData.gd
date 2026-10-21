extends SpawnGroup
class_name QueueData

@export var count: int = 5
@export var spacing_time: float = 0.2

func spawn(spawner) -> void:
	var start := ScreenUtil.from_anchor(anchor) + offset_px * ScreenUtil.scale_factor()

	for i in range(count):
		var enemy = spawner.create_enemy(enemy_data)
		if enemy == null:
			return

		enemy.start_position = start
		enemy.offset = Vector2.ZERO
		enemy.movement = movement
		enemy.direction = direction

		spawner.schedule(enemy, i * spacing_time)