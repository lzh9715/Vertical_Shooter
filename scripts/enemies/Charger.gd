extends "res://scripts/enemies/Enemy.gd"

## 冲锋兵：登场后停住瞄准 1 秒，锁定方向后冲锋到离场。
## 不发射子弹，整次冲锋只造成一次接触伤害。

enum State { PREPARE, AIM, CHARGE }

@export var prepare_time := 0.8
@export var aim_time := 1.0
@export var charge_width := 40.0
@export var charge_start_speed := 350.0
@export var charge_speed_step := 60.0
@export var charge_step_interval := 0.5
@export var charge_max_speed := 800.0

var _state := State.PREPARE
var _state_timer := 0.0
var _charge_speed := 0.0
var _speed_tick := 0.0
var _charge_direction := Vector2.LEFT
var _charge_damage := 1.0
var _did_hit := false
var _warning: Polygon2D

func _ready() -> void:
	_charge_damage = attack_power
	attack_power = 0.0
	super._ready()
	rotation = 0.0
	_state_timer = prepare_time
	_build_warning()

func _build_warning() -> void:
	_warning = Polygon2D.new()
	_warning.name = "ChargeWarning"
	_warning.color = Color(1.0, 0.1, 0.1, 0.28)
	_warning.z_index = -1
	_warning.visible = false
	add_child(_warning)

func _physics_process(delta: float) -> void:
	if _dead or is_queued_for_deletion():
		return

	match _state:
		State.PREPARE:
			global_position.x -= speed * delta
			_state_timer -= delta
			if _state_timer <= 0.0:
				_enter_aim()
		State.AIM:
			_update_aim()
			_state_timer -= delta
			if _state_timer <= 0.0:
				_start_charge()
		State.CHARGE:
			_tick_charge(delta)

func _enter_aim() -> void:
	_state = State.AIM
	_state_timer = aim_time
	if _warning != null:
		_warning.visible = true
	_update_aim()

func _update_aim() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var direction: Vector2 = player.global_position - global_position
		if direction.length_squared() > 0.001:
			_charge_direction = direction.normalized()
	rotation = _charge_direction.angle() - PI
	_update_warning_geometry()

func _update_warning_geometry() -> void:
	if _warning == null:
		return
	var length := ScreenUtil.world_size().length() * 2.0
	var half := charge_width * 0.5
	_warning.polygon = PackedVector2Array([
		Vector2(0, -half),
		Vector2(-length, -half),
		Vector2(-length, half),
		Vector2(0, half),
	])

func _start_charge() -> void:
	_state = State.CHARGE
	_state_timer = 0.0
	_charge_speed = charge_start_speed
	_speed_tick = 0.0
	_did_hit = false
	if _warning != null:
		_warning.visible = false

func _tick_charge(delta: float) -> void:
	_speed_tick += delta
	while _speed_tick >= charge_step_interval:
		_speed_tick -= charge_step_interval
		_charge_speed = minf(_charge_speed + charge_speed_step, charge_max_speed)

	global_position += _charge_direction * _charge_speed * delta
	_check_player_hit()

	var bounds := Rect2(Vector2.ZERO, ScreenUtil.world_size()).grow(400.0)
	if not bounds.has_point(global_position):
		queue_free()

func _check_player_hit() -> void:
	if _did_hit:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.is_invincible:
		return
	var forward := Vector2.LEFT.rotated(rotation)
	var to_player: Vector2 = player.global_position - global_position
	if to_player.dot(forward) < -10.0:
		return
	if absf(to_player.dot(forward.orthogonal())) > charge_width * 0.5:
		return
	_did_hit = true
	player.take_damage(_charge_damage)
