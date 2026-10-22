extends Area2D

signal died(score: int, gold: int)

const DEFAULT_BULLET := preload("res://enemy_bullet.tscn")

@export var movement: MovementPattern
@export var speed := 200.0
@export var direction := "Top_To_Bottom"
@export var despawn_margin := 300.0

@export_group("数值")
@export var max_hp := 1
@export var score_reward := 10
@export var gold_reward := 5

@export_group("表现")
@export var texture: Texture2D

@export_group("攻击")
@export var attack: EnemyAttackPattern

var hp := 1
var start_position := Vector2.ZERO
var offset := Vector2.ZERO
var elapsed_time := 0.0

var _attack_running := false
var _step_index := 0
var _repeats_left := 0
var _timer := 0.0

@onready var polygon: Polygon2D = $Polygon2D
@onready var sprite: Sprite2D = $Body

func _ready() -> void:
	hp = max_hp

	if texture != null:
		sprite.texture = texture
		sprite.visible = true
		polygon.visible = false

	_apply_motion()
	_begin_attack()

func take_damage(amount: int) -> void:
	hp -= amount
	if hp > 0:
		return
	died.emit(score_reward, gold_reward)
	queue_free()

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	_apply_motion()
	_check_bounds()
	_tick_attack(delta)

# ---------- 移动 ----------

func _apply_motion() -> void:
	var dir := _direction_vector()
	var local: Vector2 = movement.sample(elapsed_time) * ScreenUtil.scale_factor() if movement else Vector2.ZERO
	global_position = (
		start_position
		+ dir * speed * elapsed_time
		+ dir.orthogonal() * local.x
		+ dir * local.y
		+ offset
	)

func _check_bounds() -> void:
	var bounds := Rect2(Vector2.ZERO, ScreenUtil.size()).grow(despawn_margin)
	if not bounds.has_point(global_position):
		queue_free()

func _direction_vector() -> Vector2:
	match direction:
		"Left_To_Right": return Vector2.RIGHT
		"Right_To_Left": return Vector2.LEFT
		_: return Vector2.DOWN

# ---------- 攻击序列 ----------

func _begin_attack() -> void:
	if attack == null or attack.steps.is_empty():
		return

	var first: AttackStep = attack.steps[0]
	if first == null or first.volley == null:
		return

	_attack_running = true
	_step_index = 0
	_repeats_left = maxi(first.repeat, 1)
	_timer = attack.start_delay

func _tick_attack(delta: float) -> void:
	if not _attack_running:
		return

	_timer -= delta
	if _timer > 0.0:
		return

	var step: AttackStep = attack.steps[_step_index]

	if _repeats_left > 0:
		if step != null and step.volley != null:
			_fire_volley(step.volley)
		_repeats_left -= 1

		if _repeats_left > 0:
			_timer = step.gap
		else:
			_timer = step.cooldown
		return

	_advance_step()

func _advance_step() -> void:
	var guard := 0
	while guard <= attack.steps.size():
		_step_index += 1
		if _step_index >= attack.steps.size():
			if not attack.loop:
				_attack_running = false
				return
			_step_index = 0

		var step: AttackStep = attack.steps[_step_index]
		if step != null and step.volley != null:
			_repeats_left = maxi(step.repeat, 1)
			_timer = 0.0
			return

		guard += 1

	_attack_running = false

func _fire_volley(volley: EnemyBulletPattern) -> void:
	var aim := Vector2.DOWN
	var target := get_tree().get_first_node_in_group("player")
	if target != null:
		aim = target.global_position - global_position
		if aim == Vector2.ZERO:
			aim = Vector2.DOWN

	var scene := volley.bullet_scene
	if scene == null:
		scene = DEFAULT_BULLET

	for dir in volley.build_directions(aim):
		var bullet = scene.instantiate()
		bullet.direction = dir
		bullet.speed = volley.speed * ScreenUtil.scale_factor()
		bullet.damage = volley.damage
		bullet.tint = volley.tint
		bullet.radius = volley.radius
		bullet.texture = volley.texture
		get_parent().add_child(bullet)
		bullet.global_position = global_position