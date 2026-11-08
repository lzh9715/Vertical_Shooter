extends Area2D

const REASON_HIT := 0
const REASON_EXPIRED := 1
const REASON_OFFSCREEN := 2
const REASON_EVICTED := 3

const SHAPE_CIRCLE := 0
const SHAPE_RECTANGLE := 1
const SHAPE_CAPSULE := 2

const TRIGGER_NONE := 0
const TRIGGER_ON_HIT := 1
const TRIGGER_ON_EXPIRE := 2
const TRIGGER_ON_HIT_OR_EXPIRE := 3

@export var speed := 800.0
@export var damage := 1
@export var is_homing := false
@export var turn_speed := 5.0

# 穿透表示“这发子弹最多命中多少次”，不是“命中多少个不同目标”。
@export var is_piercing := false
@export var pierce_amount := 1
@export var damage_falloff := 0.8
@export var min_damage_ratio := 0.3
@export var hit_cooldown := 0.08
@export var target_retry_interval := 0.15

@export var is_explosive := false
@export var explosion_radius := 80.0

# 弹射、折射、回旋、加速/减速、寿命
@export var bounce_remaining := 0
@export var refract_remaining := 0
@export var return_remaining := 0
@export var speed_delta := 0.0
@export var lifetime_bonus := 0.0

# 触发链
@export var trigger_type := TRIGGER_NONE
@export var trigger_remaining := 0
@export var trigger_initial_count := 0
@export var copyable := true
@export var copy_inherits_trigger := true
@export var is_copy := false
var trigger_blocks: Array = []

# 视觉与碰撞数据
@export var visual_scene: PackedScene
@export var use_data_shape := false
@export var collision_shape_type := SHAPE_CIRCLE
@export var collision_size := Vector2(5.0, 5.0)

## 离开视野后的宽限时间（追踪弹可以在这段时间内折返）
@export var offscreen_grace := 0.5
## 硬寿命，防止追踪弹长期绕场
@export var max_lifetime := 5.0
@export var view_margin := 120.0

var _lifetime := 0.0
var _offscreen_time := 0.0
var _spent := false
var _expiring := false
var _base_damage := 1
var _max_hits := 1
var _hit_count := 0
var _start_speed := 800.0

var _target: Node2D = null
var _last_hit_target: Node2D = null
var _visited: Dictionary = {}
var _hit_times: Dictionary = {}
var _next_target_search := 0.0

func _ready():
	add_to_group("player_bullet")
	_start_speed = speed
	_base_damage = maxi(damage, 1)
	_max_hits = maxi(pierce_amount, 1)
	if use_data_shape:
		_apply_collision_shape()
	_apply_visual()
	area_entered.connect(_on_area_entered)

func _apply_visual() -> void:
	var old_visual := get_node_or_null("Polygon2D")
	if old_visual != null and visual_scene != null:
		old_visual.visible = false
	if visual_scene != null:
		var visual := visual_scene.instantiate()
		visual.name = "ProjectileVisual"
		if visual is Node2D:
			visual.rotation = PI / 2.0
		add_child(visual)

func refresh_visuals() -> void:
	_base_damage = maxi(damage, 1)
	_max_hits = maxi(pierce_amount, 1)
	_start_speed = speed
	for child in get_children():
		if child.name == "ProjectileVisual":
			remove_child(child)
			child.queue_free()
	var old_visual := get_node_or_null("Polygon2D")
	if old_visual != null:
		old_visual.visible = visual_scene == null
	if use_data_shape:
		_apply_collision_shape()
	_apply_visual()

func reset_for_reuse() -> void:
	_lifetime = 0.0
	_offscreen_time = 0.0
	_spent = false
	_expiring = false
	_hit_count = 0
	_target = null
	_last_hit_target = null
	_visited = {}
	_hit_times = {}
	_next_target_search = 0.0
	trigger_remaining = 0
	trigger_initial_count = 0
	trigger_blocks = []
	copyable = true
	copy_inherits_trigger = true
	is_copy = false
	bounce_remaining = 0
	refract_remaining = 0
	return_remaining = 0
	speed_delta = 0.0
	lifetime_bonus = 0.0
	visible = true
	set_physics_process(true)
	set_process(true)

func _apply_collision_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	shape_node.rotation = 0.0
	match collision_shape_type:
		SHAPE_RECTANGLE:
			var rect := RectangleShape2D.new()
			rect.size = collision_size
			shape_node.shape = rect
		SHAPE_CAPSULE:
			var capsule := CapsuleShape2D.new()
			capsule.radius = maxf(collision_size.x * 0.5, 0.5)
			capsule.height = maxf(collision_size.y, capsule.radius * 2.0)
			shape_node.shape = capsule
			shape_node.rotation = PI / 2.0
		_:
			var circle := CircleShape2D.new()
			circle.radius = maxf(collision_size.x, 0.5)
			shape_node.shape = circle

func _physics_process(delta):
	_lifetime += delta
	if _lifetime >= max_lifetime + lifetime_bonus:
		_expire(REASON_EXPIRED)
		return

	if speed_delta != 0.0:
		speed = maxf(0.0, speed + speed_delta * delta)

	if is_homing:
		if not _is_valid_target(_target):
			_target = null
		if _target == null and _lifetime >= _next_target_search:
			_acquire_target()
			if _target == null:
				_next_target_search = _lifetime + target_retry_interval
		if _target != null:
			var target_direction = (_target.global_position - global_position).normalized()
			var target_angle = target_direction.angle()
			rotation = lerp_angle(rotation, target_angle, turn_speed * delta)

	position += Vector2.RIGHT.rotated(rotation) * speed * delta

	var bounds := Rect2(Vector2.ZERO, ScreenUtil.world_size()).grow(300.0)
	if not bounds.has_point(global_position):
		_expire(REASON_OFFSCREEN)
		return

	_update_view_lifetime(delta)

func _update_view_lifetime(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	var inside := false

	if camera != null:
		var size := get_viewport().get_visible_rect().size
		var center := camera.get_screen_center_position()
		var view_rect := Rect2(center - size * 0.5, size).grow(view_margin)
		inside = view_rect.has_point(global_position)
	else:
		inside = Rect2(Vector2.ZERO, ScreenUtil.world_size()).grow(view_margin).has_point(global_position)

	if inside:
		_offscreen_time = 0.0
		return

	_offscreen_time += delta
	if _offscreen_time >= offscreen_grace:
		_expire(REASON_OFFSCREEN)

func _is_valid_target(candidate) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and candidate.is_in_group("enemy")
	)

## 优先选择本发子弹没命中过的目标；全部命中过后，再选择除上一目标外的最近目标。
func _acquire_target() -> void:
	_target = null
	var enemies := get_tree().get_nodes_in_group("enemy")
	var nearest_unvisited: Node2D = null
	var nearest_unvisited_distance := INF
	var nearest_other: Node2D = null
	var nearest_other_distance := INF

	for candidate in enemies:
		if not _is_valid_target(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if not _visited.has(candidate):
			if distance < nearest_unvisited_distance:
				nearest_unvisited_distance = distance
				nearest_unvisited = candidate
		elif candidate != _last_hit_target:
			if distance < nearest_other_distance:
				nearest_other_distance = distance
				nearest_other = candidate

	if nearest_unvisited != null:
		_target = nearest_unvisited
	elif nearest_other != null:
		_target = nearest_other

func _find_refract_target() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var nearest_unvisited: Node2D = null
	var nearest_unvisited_distance := INF
	var nearest_other: Node2D = null
	var nearest_other_distance := INF
	for candidate in enemies:
		if not _is_valid_target(candidate) or candidate == _last_hit_target:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if not _visited.has(candidate):
			if distance < nearest_unvisited_distance:
				nearest_unvisited_distance = distance
				nearest_unvisited = candidate
		elif distance < nearest_other_distance:
			nearest_other_distance = distance
			nearest_other = candidate
	return nearest_unvisited if nearest_unvisited != null else nearest_other

func _on_area_entered(area):
	if _spent or is_queued_for_deletion():
		return

	if area.is_in_group("enemy"):
		if _hit_times.has(area) and _lifetime - float(_hit_times[area]) < hit_cooldown:
			return
		_hit_target(area)

func _hit_target(area) -> void:
	if _hit_count >= _max_hits:
		return

	var multiplier := maxf(pow(damage_falloff, _hit_count), min_damage_ratio)
	var hit_damage := maxi(1, roundi(float(_base_damage) * multiplier))

	_hit_count += 1
	_visited[area] = true
	_last_hit_target = area
	_hit_times[area] = _lifetime
	# 下一次物理帧会重新选目标：优先未命中过的，全部命中后排除当前目标。
	_target = null
	_next_target_search = _lifetime

	# 普通射弹先被护盾吸收；穿透弹直接绕过护盾打本体。
	var shield_stopped := false
	if (
		area.has_method("has_active_shield")
		and area.has_active_shield()
		and not is_piercing
	):
		if area.has_method("absorb_shield_damage"):
			area.absorb_shield_damage(hit_damage)
		shield_stopped = true

	if is_explosive:
		# 盾卫直击被护盾吸收时，爆炸仍然要能伤害本体；
		# 普通直击目标则跳过，避免和直击伤害重复。
		explode(hit_damage, shield_stopped)
	if not shield_stopped and area.has_method("take_damage"):
		area.take_damage(hit_damage)

	# 触发弹只在第一次有效命中时触发；后续命中不再触发。
	if trigger_remaining > 0 and (trigger_type == TRIGGER_ON_HIT or trigger_type == TRIGGER_ON_HIT_OR_EXPIRE):
		_trigger_next_block()

	# 弹射优先，其次折射。两者都在命中后立刻固定新方向。
	if bounce_remaining > 0:
		bounce_remaining -= 1
		rotation = randf_range(-PI, PI)
		return
	if refract_remaining > 0:
		var target := _find_refract_target()
		if target == null:
			_expire(REASON_HIT)
			return
		refract_remaining -= 1
		rotation = (target.global_position - global_position).angle()
		return

	if _hit_count >= _max_hits:
		_expire(REASON_HIT)

func _trigger_next_block() -> void:
	if trigger_remaining <= 0:
		return
	trigger_remaining -= 1
	if trigger_blocks.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("fire_trigger_blocks"):
		player.call_deferred("fire_trigger_blocks", trigger_blocks, global_position)

func _expire(reason: int) -> void:
	if _expiring:
		return
	_expiring = true
	_spent = true

	if reason != REASON_EVICTED:
		if trigger_remaining > 0 and (trigger_type == TRIGGER_ON_EXPIRE or trigger_type == TRIGGER_ON_HIT_OR_EXPIRE):
			_trigger_next_block()
		if return_remaining > 0 and not is_copy:
			call_deferred("_spawn_copy")

	if has_meta(&"pooled") and ProjectilePool != null:
		ProjectilePool.release(self)
	else:
		queue_free()

## 因 400 总上限被回收：绝不触发回旋、触发链或爆炸等“消失”逻辑。
func evict() -> void:
	_expire(REASON_EVICTED)

func _spawn_copy() -> void:
	if not copyable or is_copy or return_remaining <= 0:
		return
	var parent := get_parent()
	if parent == null:
		return
	var copy := duplicate()
	if not copy is Area2D:
		return
	for connection in copy.area_entered.get_connections():
		copy.area_entered.disconnect(connection.callable)
	copy.visual_scene = null
	copy.is_copy = true
	copy.return_remaining = 0
	copy.speed = _start_speed
	copy._start_speed = _start_speed
	copy.rotation = PI
	copy.position = position
	copy._lifetime = 0.0
	copy._offscreen_time = 0.0
	copy._spent = false
	copy._expiring = false
	copy._hit_count = 0
	copy._target = null
	copy._last_hit_target = null
	copy._visited = {}
	copy._hit_times = {}
	copy._next_target_search = 0.0
	copy.trigger_remaining = trigger_initial_count if copy_inherits_trigger else 0
	copy.trigger_initial_count = copy.trigger_remaining
	copy.trigger_blocks = trigger_blocks.duplicate(true)
	copy.remove_meta(&"pooled")
	parent.add_child(copy)
	if not ProjectileRegistry.register(copy, &"player"):
		copy.queue_free()

func explode(explosion_damage: int, include_direct: bool = false):
	AudioManager.play_sfx(&"explosion")
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if _visited.has(enemy):
			# 普通直击已经结算；只有“直击被护盾吸收”时才补一次爆炸本体伤害
			if not (include_direct and enemy == _last_hit_target):
				continue
		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			if enemy.has_method("take_damage"):
				var multiplier := ExplosionMath.falloff(
					global_position.distance_to(enemy.global_position),
					explosion_radius
				)
				enemy.take_damage(maxi(1, roundi(float(explosion_damage) * multiplier)))

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

	# 0.1秒后销毁爆炸特效（跟随暂停）
	get_tree().create_timer(0.1, false).timeout.connect(explosion_visual.queue_free)
