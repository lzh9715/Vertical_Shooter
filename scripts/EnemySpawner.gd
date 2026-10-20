extends Node


# 接收图纸，并开始生成
func trigger_spawn(data: Resource):
	print(">>> 生成器收到图纸：", data)
	if data == null: return # 如果图纸为空，直接停止
	if data is QueueData:
		_spawn_queue(data)
	elif data is FormationData:
		_spawn_formation(data)

# 处理队列生成
func _spawn_queue(data: QueueData):
	for i in range(data.count):
		var enemy = data.enemy_scene.instantiate()
		
		var base_pos = data.start_pos
		var offset = Vector2.ZERO
		var delay = i * data.spacing_time
		
		# 👇【修改点】直接删掉下面这两行，不要强制纵向排开！
		# if data.direction == "Left_To_Right" or data.direction == "Right_To_Left":
		# 	offset.y = i * 50.0 
		
		enemy.start_position = base_pos
		enemy.offset = offset # 这里保持在 (0, 0)
		enemy.path_type = data.path_type
		enemy.direction = data.direction
		enemy.speed = data.speed
		
		# 依然靠时间延迟拉开距离
		if delay > 0:
			get_tree().create_timer(delay).timeout.connect(func(): add_child(enemy))
		else:
			add_child(enemy)

# 处理阵型生成
func _spawn_formation(data: FormationData):
	# 阵型通常是同时出现
	var base_pos = Vector2(360, -100) # 默认屏幕顶部中间
	
	for point in data.points:
		var enemy = data.enemy_scene.instantiate()
		
		# 阵型偏移 = 点位 + 全局偏移
		var final_offset = point + Vector2(data.global_offset_x, 0)
		
		enemy.start_position = base_pos
		enemy.offset = final_offset
		enemy.path_type = "Straight" # 阵型默认直线下落
		enemy.direction = "Top_To_Bottom"
		enemy.speed = data.speed
		
		add_child(enemy)
