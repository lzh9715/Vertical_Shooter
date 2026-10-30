extends Area2D

@export var speed := 800.0
@export var damage := 1
@export var is_homing := false
@export var turn_speed := 5.0

# 穿透现在表示“这发子弹最多命中多少次”，不是“命中多少个不同目标”。
@export var is_piercing := false
@export var pierce_amount := 1
@export var damage_falloff := 0.8
@export var min_damage_ratio := 0.3
@export var hit_cooldown := 0.08
@export var target_retry_interval := 0.15

@export var is_explosive := false
@export var explosion_radius := 80.0

## 离开视野后的宽限时间（追踪弹可以在这段时间内折返）
@export var offscreen_grace := 0.5
## 硬寿命，防止追踪弹长期绕场
@export var max_lifetime := 5.0
@export var view_margin := 120.0

var _lifetime := 0.0
var _offscreen_time := 0.0
var _spent := false
var _base_damage := 1
var _max_hits := 1
var _hit_count := 0

var _target: Node2D = null
var _last_hit_target: Node2D = null
var _visited: Dictionary = {}
var _hit_times: Dictionary = {}
var _next_target_search := 0.0

func _ready():
	add_to_group("player_bullet")
	_base_damage = maxi(damage, 1)
	_max_hits = maxi(pierce_amount, 1) if is_piercing else 1
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	_lifetime += delta
	if _lifetime >= max_lifetime:
		queue_free()
		return

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
		queue_free()
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
		queue_free()

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

	if not is_piercing or _hit_count >= _max_hits:
		_spent = true
		queue_free()

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
