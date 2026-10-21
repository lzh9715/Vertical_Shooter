extends Node

signal enemy_died(score: int, gold: int)

@export var difficulty: DifficultyProfile

func trigger_spawn(data: Resource):
	if data == null: return
	if data is QueueData:
		_spawn_queue(data)
	elif data is FormationData:
		_spawn_formation(data)

# —— 队列：同一个敌人按时间间隔依次出现
func _spawn_queue(data: QueueData):
	var start := ScreenUtil.from_anchor(data.anchor) + data.offset_px * ScreenUtil.scale_factor()

	for i in range(data.count):
		var enemy = _create_enemy(data.enemy_data)
		if enemy == null: return

		enemy.start_position = start
		enemy.offset = Vector2.ZERO
		enemy.movement = data.movement
		enemy.direction = data.direction
		_schedule(enemy, i * data.spacing_time)

# —— 阵型：同批敌人按形状排开
func _spawn_formation(data: FormationData):
	if data.shape == null:
		push_warning("FormationData 缺 shape")
		return

	var center := ScreenUtil.from_anchor(data.anchor) + data.offset_px * ScreenUtil.scale_factor()
	var scale := ScreenUtil.scale_factor()
	var offsets := data.shape.build_offsets(data.count, data.spacing)

	if offsets.is_empty():
		push_warning("阵型算不出点位，检查 shape / count")
		return

	for i in range(offsets.size()):
		var enemy = _create_enemy(data.enemy_data)
		if enemy == null: return

		enemy.start_position = center
		enemy.offset = offsets[i] * scale
		enemy.direction = data.direction
		enemy.movement = data.movement
		_schedule(enemy, data.delay + i * data.interval)

# —— 延迟生成，带实例有效性检查
func _schedule(enemy, delay: float) -> void:
	if delay <= 0.0:
		add_child(enemy)
		return
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		if is_instance_valid(enemy):
			add_child(enemy)
	)

# —— 唯一创建入口
func _create_enemy(data: EnemyData):
	if data == null or data.scene == null:
		push_warning("EnemyData 没配好：缺 scene")
		return null

	var hp_mult := difficulty.value(&"hp") if difficulty else 1.0
	var speed_mult := difficulty.value(&"speed") if difficulty else 1.0
	var reward_mult := difficulty.value(&"reward") if difficulty else 1.0

	var enemy = data.scene.instantiate()
	enemy.max_hp = maxi(1, roundi(data.max_hp * hp_mult))
	enemy.speed = data.speed * speed_mult * ScreenUtil.scale_factor()
	enemy.score_reward = roundi(data.score * reward_mult)
	enemy.gold_reward = roundi(data.gold * reward_mult)
	enemy.despawn_margin = data.despawn_margin * ScreenUtil.scale_factor()
	enemy.died.connect(_on_enemy_died)
	return enemy

func _on_enemy_died(score: int, gold: int) -> void:
	enemy_died.emit(score, gold)