extends SpawnGroup
class_name FormationData

@export_group("阵型")
@export var shape: FormationShape
@export var count: int = 5
@export var spacing := Vector2(60, 50)

@export_group("节奏")
@export var delay: float = 0.0
@export var interval: float = 0.0

func spawn(spawner) -> void:
	if shape == null:
		push_warning("FormationData 缺 shape")
		return

	var center := ScreenUtil.from_anchor(anchor) + offset_px * ScreenUtil.scale_factor()
	var scale := ScreenUtil.scale_factor()
	var offsets := shape.build_offsets(count, spacing)

	if offsets.is_empty():
		push_warning("阵型算不出点位")
		return

	for i in range(offsets.size()):
		var enemy = spawner.create_enemy(enemy_data)
		if enemy == null:
			return

		enemy.start_position = center
		enemy.offset = offsets[i] * scale
		enemy.direction = direction
		enemy.movement = movement
		spawner.schedule(enemy, delay + i * interval)