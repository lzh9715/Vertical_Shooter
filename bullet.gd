extends Area2D

@export var speed := 800.0
@export var is_homing := false
@export var turn_speed := 5.0

# 新增的属性
@export var is_piercing := false
@export var pierce_amount := 1
@export var is_explosive := false
@export var explosion_radius := 80.0

var pierced_enemies := [] # 记录已经打过的敌人，防止同一只怪被重复扣血

func _ready():
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	if is_homing:
		var target = _find_nearest_enemy()
		if target:
			var target_direction = (target.global_position - global_position).normalized()
			var target_angle = target_direction.angle() + PI / 2
			rotation = lerp_angle(rotation, target_angle, turn_speed * delta)

	position += Vector2.UP.rotated(rotation) * speed * delta
	
	if global_position.y < -200 or global_position.y > 1500 or global_position.x < -200 or global_position.x > 900:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("enemy") and not area in pierced_enemies:
		pierced_enemies.append(area)

		if is_explosive:
			explode()

		# ← 原来这里是 area.queue_free()
		if area.has_method("take_damage"):
			area.take_damage(1)

		if is_piercing and pierced_enemies.size() < pierce_amount:
			pass
		else:
			queue_free()

func explode():
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(9999)   # ← 原来是 enemy.queue_free()
	
	# 视觉反馈（可选）：在屏幕上画一个圈代表爆炸范围
	var explosion_visual = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(12):
		var angle = i * (TAU / 12)
		points.append(Vector2(cos(angle), sin(angle)) * explosion_radius)
	explosion_visual.polygon = points
	explosion_visual.color = Color(1, 0.5, 0, 0.5) # 半透明橙色
	explosion_visual.global_position = global_position
	get_parent().add_child(explosion_visual)
	
	# 0.1秒后销毁爆炸特效
	get_tree().create_timer(0.1).timeout.connect(explosion_visual.queue_free)

func _find_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty(): return null
	var nearest_enemy = null
	var min_distance = INF 
	for enemy in enemies:
		var distance = global_position.distance_squared_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_enemy = enemy
	return nearest_enemy