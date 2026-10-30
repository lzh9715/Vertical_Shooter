extends SpawnGroup
class_name FormationData

@export_group("阵型")
@export var shape: FormationShape
@export var count: int = 5
@export var spacing := Vector2(60, 50)

@export_group("节奏")
@export var delay: float = 0.0
@export var interval: float = 0.0
@export var repeat := 1                 # 同一阵型重复生成几组
@export var group_interval := 0.3       # 组与组之间的间隔

func spawn(spawner) -> void:
	if shape == null:
		push_warning("FormationData 缺 shape")
		return

	var center := ScreenUtil.world_from_view_anchor(anchor) + offset_px * ScreenUtil.scale_factor()
	var scale := ScreenUtil.scale_factor()
	var offsets := shape.build_offsets(count, spacing)

	if offsets.is_empty():
		push_warning("阵型算不出点位")
		return

	if shape.rotate_to_direction:
		var angle := _direction_angle()
		for i in range(offsets.size()):
			offsets[i] = offsets[i].rotated(angle)

	var groups := maxi(repeat, 1)
	for g in range(groups):
		var base_delay := delay + g * group_interval
		for i in range(offsets.size()):
			var enemy = spawner.create_enemy(enemy_data)
			if enemy == null:
				return

			enemy.start_position = center
			enemy.offset = offsets[i] * scale
			enemy.direction = direction
			enemy.movement = movement
			spawner.schedule(enemy, base_delay + i * interval)

func _direction_angle() -> float:
	match direction:
		"Right_To_Left": return PI
		"Left_To_Right": return 0.0
		"Top_To_Bottom": return PI * 0.5
		"Bottom_To_Top": return -PI * 0.5
		_: return PI      # 横版默认向左
