extends "res://scripts/enemies/Enemy.gd"

## 精英盾卫：登场 → 推进 → 驻守 → 破盾硬直 → 阻击。
## 普通弹被护盾吸收；穿透/爆炸绕过护盾。护盾只破一次。

const STATE_ENTER := &"ENTER"
const STATE_ADVANCE := &"ADVANCE"
const STATE_GUARD := &"GUARD"
const STATE_STUNNED := &"STUNNED"
const STATE_INTERCEPT := &"INTERCEPT"
const STATE_DEAD := &"DEAD"

const ENEMY_BULLET := preload("res://scenes/enemies/enemy_bullet.tscn")
const SPREAD_PATTERN := preload("res://data/bullet_templates/BulletSpread_Basic.tres")
const HEAVY_PATTERN := preload("res://data/bullet_templates/BulletHeavy_Basic.tres")

@export var stop_x := 1280.0
@export var enter_delay := 0.6
@export var advance_speed := 50.0
@export var intercept_x_speed := 40.0
@export var intercept_y_speed := 40.0
@export var stun_duration := 2.0
@export var shield_ratio := 0.5
@export var shield_visual_color := Color.WHITE

var _brain: EnemyBrain
var _state_time := 0.0
var _attack_cooldown := 0.0
var _shield_hp := 0
var _shield_max := 0
var _shield_line: Line2D
var _base_color := Color.WHITE

class EnterState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_enter()

	func update(delta: float) -> void:
		var g = host
		g._update_enter(delta)

class AdvanceState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_advance()

	func update(delta: float) -> void:
		var g = host
		g._update_advance(delta)

class GuardState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_guard()

	func update(delta: float) -> void:
		var g = host
		g._update_guard(delta)

class StunnedState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_stunned()

	func update(delta: float) -> void:
		var g = host
		g._update_stunned(delta)

class InterceptState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_intercept()

	func update(delta: float) -> void:
		var g = host
		g._update_intercept(delta)

class DeadState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_dead()

func _ready() -> void:
	super._ready()
	_base_color = polygon.color
	_shield_max = maxi(1, roundi(float(max_hp) * shield_ratio))
	_shield_hp = _shield_max
	_build_shield_visual()
	_brain = EnemyBrain.new()
	_brain.setup(self, {
		STATE_ENTER: EnterState.new(),
		STATE_ADVANCE: AdvanceState.new(),
		STATE_GUARD: GuardState.new(),
		STATE_STUNNED: StunnedState.new(),
		STATE_INTERCEPT: InterceptState.new(),
		STATE_DEAD: DeadState.new(),
	}, STATE_ENTER)
	died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_brain.update(delta)

func get_state_name() -> String:
	return String(_brain.current_id) if _brain != null else ""

func get_shield_ratio() -> float:
	return float(_shield_hp) / float(maxi(_shield_max, 1))

func get_shield_hp() -> int:
	return _shield_hp

func get_shield_max() -> int:
	return _shield_max

func has_active_shield() -> bool:
	return _shield_hp > 0

func absorb_shield_damage(amount: int) -> bool:
	if _shield_hp <= 0:
		return false
	_shield_hp = maxi(_shield_hp - amount, 0)
	_flash_shield()
	if _shield_hp <= 0:
		_break_shield()
	return true

func _break_shield() -> void:
	_shield_hp = 0
	if _shield_line != null:
		_shield_line.visible = false
	if _brain != null and _brain.current_id != STATE_DEAD:
		_brain.change(STATE_STUNNED)

func _enter_enter() -> void:
	_state_time = enter_delay
	_attack_cooldown = 0.0
	_set_body_color(_base_color)

func _update_enter(delta: float) -> void:
	_state_time -= delta
	if _state_time <= 0.0:
		_brain.change(STATE_ADVANCE)

func _enter_advance() -> void:
	_attack_cooldown = 1.2

func _update_advance(delta: float) -> void:
	var s := ScreenUtil.scale_factor()
	global_position.x = move_toward(global_position.x, stop_x, advance_speed * s * delta)
	_tick_pattern_attack(SPREAD_PATTERN, Vector2.LEFT)
	if absf(global_position.x - stop_x) <= 1.0:
		global_position.x = stop_x
		_brain.change(STATE_GUARD)

func _enter_guard() -> void:
	_attack_cooldown = 1.2

func _update_guard(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var aim := Vector2.LEFT
	if player != null:
		aim = (player.global_position - global_position).normalized()
	_tick_pattern_attack(SPREAD_PATTERN, aim)

func _enter_stunned() -> void:
	_state_time = stun_duration
	_attack_cooldown = 0.0
	if _shield_line != null:
		_shield_line.visible = false

func _update_stunned(delta: float) -> void:
	_state_time -= delta
	if _state_time <= 0.0:
		_brain.change(STATE_INTERCEPT)

func _enter_intercept() -> void:
	_attack_cooldown = 1.2

func _update_intercept(delta: float) -> void:
	var s := ScreenUtil.scale_factor()
	if global_position.x > stop_x:
		global_position.x = move_toward(global_position.x, stop_x, intercept_x_speed * s * delta)
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		global_position.y = move_toward(global_position.y, player.global_position.y, intercept_y_speed * s * delta)
	_tick_pattern_attack(HEAVY_PATTERN, _aim_at_player())

func _tick_pattern_attack(pattern: EnemyBulletPattern, aim: Vector2) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(_attack_cooldown - get_physics_process_delta_time(), 0.0)
		return
	if aim == Vector2.ZERO:
		aim = Vector2.LEFT
	_fire_pattern(pattern, aim)
	_attack_cooldown = pattern.interval

func _fire_pattern(pattern: EnemyBulletPattern, aim: Vector2) -> void:
	var directions := pattern.build_directions(aim)
	for dir in directions:
		var bullet = ENEMY_BULLET.instantiate()
		bullet.direction = dir
		bullet.speed = pattern.speed * ScreenUtil.scale_factor()
		bullet.damage = maxi(1, roundi(attack_power + pattern.damage))
		bullet.radius = pattern.radius
		bullet.tint = pattern.tint
		get_parent().add_child(bullet)
		if not ProjectileRegistry.register(bullet, &"enemy"):
			bullet.queue_free()
			continue
		bullet.global_position = global_position

func _aim_at_player() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return Vector2.LEFT
	return (player.global_position - global_position).normalized()

func _enter_dead() -> void:
	if _shield_line != null:
		_shield_line.visible = false
	_set_body_color(_base_color)

func _on_died(_score: int, _gold: int) -> void:
	if _brain != null:
		_brain.change(STATE_DEAD)

func _build_shield_visual() -> void:
	if polygon == null or polygon.polygon.is_empty():
		return
	_shield_line = Line2D.new()
	_shield_line.name = "ShieldOutline"
	_shield_line.points = polygon.polygon
	_shield_line.closed = true
	_shield_line.width = 6.0
	_shield_line.default_color = shield_visual_color
	_shield_line.antialiased = true
	_shield_line.z_index = 2
	add_child(_shield_line)

func _flash_shield() -> void:
	if _shield_line == null:
		return
	_shield_line.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var tween := create_tween()
	tween.tween_property(_shield_line, "modulate", Color.WHITE, 0.12)

func _set_body_color(color: Color) -> void:
	if polygon != null:
		polygon.color = color
