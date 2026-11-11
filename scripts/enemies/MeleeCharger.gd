extends "res://scripts/enemies/Enemy.gd"

## 近程冲锋兵：入场→蓄力预警→固定方向冲锋，直到死亡或冲出左边缘。
## 冲锋阶段不可被外部硬直打断；接触伤害由本体碰撞框负责。

const STATE_ENTER := &"ENTER"
const STATE_PREPARE := &"PREPARE"
const STATE_CHARGE := &"CHARGE"
const STATE_STUNNED := &"STUNNED"
const STATE_DEAD := &"DEAD"
const STATE_DESPAWN := &"DESPAWN"

@export var stop_line_ratio := 0.60
@export var entry_speed := 160.0
@export var prepare_time := 0.5
@export var stun_duration := 1.5
@export var charge_start_speed := 350.0
@export var charge_speed_gain := 60.0
@export var charge_max_speed := 800.0
@export var warning_length_scale := 2.0
@export var warning_color := Color(1.0, 0.22, 0.08, 0.28)

var _brain: EnemyBrain
var _stop_x := 0.0
var _prepare_left := 0.0
var _charge_time := 0.0
var _charge_speed := 0.0
var _charge_direction := Vector2.LEFT
var _return_state: StringName = STATE_PREPARE
var _stun_left := 0.0
var _warning: Polygon2D
var _base_color := Color.WHITE

class EnterState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_enter()

	func update(delta: float) -> void:
		var g = host
		g._update_enter(delta)

class PrepareState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_prepare()

	func update(delta: float) -> void:
		var g = host
		g._update_prepare(delta)

class ChargeState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_charge()

	func update(delta: float) -> void:
		var g = host
		g._update_charge(delta)

class StunnedState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_stunned()

	func update(delta: float) -> void:
		var g = host
		g._update_stunned(delta)

class DeadState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_dead()

class DespawnState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_despawn()

func _ready() -> void:
	super._ready()
	_base_color = polygon.color
	_stop_x = ScreenUtil.world_size().x * stop_line_ratio
	_build_warning()
	_brain = EnemyBrain.new()
	_brain.setup(self, {
		STATE_ENTER: EnterState.new(),
		STATE_PREPARE: PrepareState.new(),
		STATE_CHARGE: ChargeState.new(),
		STATE_STUNNED: StunnedState.new(),
		STATE_DEAD: DeadState.new(),
		STATE_DESPAWN: DespawnState.new(),
	}, STATE_ENTER)
	died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_brain.update(delta)

func get_state_name() -> String:
	return String(_brain.current_id) if _brain != null else ""

func apply_stun(duration: float = -1.0) -> void:
	if _dead or _brain == null:
		return
	var current := _brain.current_id
	if current == STATE_CHARGE or current == STATE_DEAD or current == STATE_DESPAWN or current == STATE_STUNNED:
		return
	_return_state = current
	_brain.change(STATE_STUNNED)
	_stun_left = stun_duration if duration < 0.0 else maxf(duration, 0.0)

func _enter_enter() -> void:
	_prepare_left = 0.0
	_hide_warning()
	_set_body_color(_base_color)

func _update_enter(delta: float) -> void:
	var s := ScreenUtil.scale_factor()
	global_position.x = move_toward(global_position.x, _stop_x, entry_speed * s * speed_scale * delta)
	if absf(global_position.x - _stop_x) <= 1.0:
		global_position.x = _stop_x
		_brain.change(STATE_PREPARE)

func _enter_prepare() -> void:
	if _prepare_left <= 0.0:
		_prepare_left = prepare_time
		_lock_charge_direction()
	_set_body_color(Color(1.0, 0.38, 0.12, 1.0))
	_show_warning()

func _update_prepare(delta: float) -> void:
	_prepare_left -= delta
	_update_warning_geometry()
	if _prepare_left <= 0.0:
		_hide_warning()
		_brain.change(STATE_CHARGE)

func _enter_charge() -> void:
	_hide_warning()
	_set_body_color(_base_color)
	_charge_time = 0.0
	_charge_speed = charge_start_speed * speed_scale

func _update_charge(delta: float) -> void:
	var s := ScreenUtil.scale_factor()
	_charge_time += delta
	_charge_speed = minf(charge_start_speed + charge_speed_gain * _charge_time, charge_max_speed) * speed_scale
	global_position += _charge_direction * _charge_speed * s * delta
	if global_position.x < -despawn_margin:
		_brain.change(STATE_DESPAWN)

func _enter_stunned() -> void:
	_hide_warning()
	_set_body_color(_base_color)

func _update_stunned(delta: float) -> void:
	_stun_left -= delta
	if _stun_left <= 0.0:
		_brain.change(_return_state)

func _enter_dead() -> void:
	_hide_warning()
	_set_body_color(_base_color)

func _enter_despawn() -> void:
	_hide_warning()
	queue_free()

func _on_died(_score: int, _gold: int) -> void:
	if _brain != null:
		_brain.change(STATE_DEAD)

func _lock_charge_direction() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_charge_direction = (player.global_position - global_position).normalized()
	if _charge_direction == Vector2.ZERO:
		_charge_direction = Vector2.LEFT

func _build_warning() -> void:
	_warning = Polygon2D.new()
	_warning.name = "ChargeWarning"
	_warning.top_level = true
	_warning.color = warning_color
	_warning.z_index = -1
	_warning.visible = false
	add_child(_warning)

func _show_warning() -> void:
	if _warning != null:
		_warning.visible = true
		_update_warning_geometry()

func _hide_warning() -> void:
	if _warning != null:
		_warning.visible = false

func _update_warning_geometry() -> void:
	if _warning == null:
		return
	var width := 30.0
	var length := ScreenUtil.world_size().length() * warning_length_scale
	var forward := _charge_direction
	var side := forward.orthogonal() * width * 0.5
	var start := global_position
	var end := start + forward * length
	_warning.polygon = PackedVector2Array([
		start + side,
		end + side,
		end - side,
		start - side,
	])

func _set_body_color(color: Color) -> void:
	if polygon != null:
		polygon.color = color
