extends "res://scripts/enemies/Enemy.gd"

## 远程游猎兵：固定循环状态机示例。
## 行为规格见 data/design/enemy-behavior-spec.xlsx。

const STATE_ENTER := &"ENTER"
const STATE_COMBAT := &"COMBAT"
const STATE_ADVANCE := &"ADVANCE"
const STATE_STUNNED := &"STUNNED"
const STATE_DEAD := &"DEAD"
const STATE_DESPAWN := &"DESPAWN"

const ENEMY_BULLET := preload("res://scenes/enemies/enemy_bullet.tscn")

@export var stop_line_ratio := 0.75
@export var entry_speed := 160.0
@export var advance_speed := 90.0
@export var hold_time := 6.0
@export var stun_duration := 1.5
@export var first_shot_delay := 0.5
@export var shot_interval := 1.5
@export var telegraph_time := 0.35
@export var bullet_speed := 350.0
@export var bullet_damage := 6
@export var bullet_radius := 7.0
@export var bullet_tint := Color(1.0, 0.65, 0.3, 1.0)
@export var telegraph_color := Color(1.0, 0.78, 0.25, 1.0)

var _brain: EnemyBrain
var _stop_x := 0.0
var _combat_time := 0.0
var _return_state: StringName = STATE_COMBAT
var _stun_left := 0.0
var _attack_cooldown := 0.0
var _telegraph_left := 0.0
var _aiming := false
var _aim_dir := Vector2.LEFT
var _base_color := Color.WHITE
var _telegraph_line: Line2D

class EnterState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_enter()

	func update(delta: float) -> void:
		var g = host
		g._update_enter(delta)

class CombatState extends EnemyState:
	func update(delta: float) -> void:
		var g = host
		g._update_combat(delta)

class AdvanceState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_advance()

	func update(delta: float) -> void:
		var g = host
		g._update_advance(delta)

class StunnedState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_stunned()

	func update(delta: float) -> void:
		var g = host
		g._update_stunned(delta)

	func exit() -> void:
		var g = host
		g._exit_stunned()

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
	_build_telegraph_line()
	_brain = EnemyBrain.new()
	_brain.setup(self, {
		STATE_ENTER: EnterState.new(),
		STATE_COMBAT: CombatState.new(),
		STATE_ADVANCE: AdvanceState.new(),
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
	if _brain.current_id == STATE_DEAD or _brain.current_id == STATE_DESPAWN or _brain.current_id == STATE_STUNNED:
		return
	_return_state = _brain.current_id
	_brain.change(STATE_STUNNED)
	_stun_left = stun_duration if duration < 0.0 else maxf(duration, 0.0)

func _enter_enter() -> void:
	_combat_time = 0.0
	_attack_cooldown = 0.0
	_cancel_attack()

func _update_enter(delta: float) -> void:
	var s := ScreenUtil.scale_factor()
	global_position.x = move_toward(global_position.x, _stop_x, entry_speed * s * delta)
	if absf(global_position.x - _stop_x) <= 1.0:
		global_position.x = _stop_x
		_combat_time = 0.0
		_attack_cooldown = first_shot_delay
		_brain.change(STATE_COMBAT)

func _update_combat(delta: float) -> void:
	_combat_time += delta
	_tick_attack(delta)
	if _combat_time >= hold_time:
		_brain.change(STATE_ADVANCE)

func _enter_advance() -> void:
	# 从 COMBAT 进入时保留剩余攻击冷却，不重置攻击循环。
	pass

func _update_advance(delta: float) -> void:
	var s := ScreenUtil.scale_factor()
	global_position.x -= advance_speed * s * delta
	_tick_attack(delta)
	if global_position.x < -despawn_margin:
		_brain.change(STATE_DESPAWN)

func _enter_stunned() -> void:
	_cancel_attack()
	_attack_cooldown = first_shot_delay
	_set_body_color(_base_color)

func _update_stunned(delta: float) -> void:
	_stun_left -= delta
	if _stun_left <= 0.0:
		_brain.change(_return_state)

func _exit_stunned() -> void:
	_attack_cooldown = first_shot_delay
	_aiming = false
	_telegraph_left = 0.0
	_set_body_color(_base_color)

func _enter_dead() -> void:
	_cancel_attack()
	_set_body_color(_base_color)

func _enter_despawn() -> void:
	_cancel_attack()
	queue_free()

func _on_died(_score: int, _gold: int) -> void:
	if _brain != null:
		_brain.change(STATE_DEAD)

# ---------- 攻击 ----------

func _tick_attack(delta: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
		return

	if not _aiming:
		_begin_telegraph()
		return

	_telegraph_left -= delta
	_update_telegraph_line()
	if _telegraph_left <= 0.0:
		_fire_aimed_bullet()

func _begin_telegraph() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_aim_dir = (player.global_position - global_position).normalized()
	else:
		_aim_dir = Vector2.LEFT
	if _aim_dir == Vector2.ZERO:
		_aim_dir = Vector2.LEFT
	_aiming = true
	_telegraph_left = telegraph_time
	_set_body_color(telegraph_color)
	if _telegraph_line != null:
		_telegraph_line.visible = true
		_update_telegraph_line()

func _fire_aimed_bullet() -> void:
	_aiming = false
	_telegraph_left = 0.0
	if _telegraph_line != null:
		_telegraph_line.visible = false
	_set_body_color(_base_color)
	_attack_cooldown = shot_interval

	var bullet = ENEMY_BULLET.instantiate()
	bullet.direction = _aim_dir
	bullet.speed = bullet_speed * ScreenUtil.scale_factor()
	bullet.damage = bullet_damage
	bullet.radius = bullet_radius
	bullet.tint = bullet_tint
	get_parent().add_child(bullet)
	if not ProjectileRegistry.register(bullet, &"enemy"):
		bullet.queue_free()
		return
	bullet.global_position = global_position

func _build_telegraph_line() -> void:
	_telegraph_line = Line2D.new()
	_telegraph_line.name = "TelegraphLine"
	_telegraph_line.top_level = true
	_telegraph_line.width = 2.0
	_telegraph_line.default_color = Color(1.0, 0.35, 0.2, 0.7)
	_telegraph_line.z_index = 9
	_telegraph_line.visible = false
	add_child(_telegraph_line)

func _update_telegraph_line() -> void:
	if _telegraph_line == null:
		return
	var length := ScreenUtil.world_size().length() * 1.5
	_telegraph_line.points = PackedVector2Array([
		global_position,
		global_position + _aim_dir * length,
	])

func _cancel_attack() -> void:
	_aiming = false
	_telegraph_left = 0.0
	if _telegraph_line != null:
		_telegraph_line.visible = false
	if polygon != null:
		_set_body_color(_base_color)

func _set_body_color(color: Color) -> void:
	if polygon != null:
		polygon.color = color
