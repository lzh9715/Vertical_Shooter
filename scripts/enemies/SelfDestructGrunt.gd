extends "res://scripts/enemies/Enemy.gd"

## 近程自爆兵：登场延迟→追踪玩家→近距离蓄力2秒→自爆。
## 被击杀时不会自爆；自爆不结算奖励。

const STATE_ENTER := &"ENTER"
const STATE_TRACK := &"TRACK"
const STATE_CHARGING := &"CHARGING"
const STATE_EXPLODE := &"EXPLODE"
const STATE_DEAD := &"DEAD"

@export var enter_delay := 0.6
@export var tracking_speed := 100.0
@export var trigger_distance := 100.0
@export var charge_time := 2.0
@export var explosion_radius := 200.0
@export var explosion_visual_duration := 0.25
@export var warning_start_color := Color(1.0, 1.0, 1.0, 0.18)
@export var warning_end_color := Color(1.0, 0.45, 0.05, 0.38)
@export var explosion_color := Color(1.0, 0.0, 0.0, 0.7)

var _brain: EnemyBrain
var _state_time := 0.0
var _charge_elapsed := 0.0
var _warning: Polygon2D
var _base_color := Color.WHITE
var _exploded := false

class EnterState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_enter()

	func update(delta: float) -> void:
		var g = host
		g._update_enter(delta)

class TrackState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_track()

	func update(delta: float) -> void:
		var g = host
		g._update_track(delta)

class ChargingState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_charging()

	func update(delta: float) -> void:
		var g = host
		g._update_charging(delta)

class ExplodeState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_explode()

class DeadState extends EnemyState:
	func enter() -> void:
		var g = host
		g._enter_dead()

func _ready() -> void:
	super._ready()
	_base_color = polygon.color
	_build_warning()
	_brain = EnemyBrain.new()
	_brain.setup(self, {
		STATE_ENTER: EnterState.new(),
		STATE_TRACK: TrackState.new(),
		STATE_CHARGING: ChargingState.new(),
		STATE_EXPLODE: ExplodeState.new(),
		STATE_DEAD: DeadState.new(),
	}, STATE_ENTER)
	died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_brain.update(delta)

func get_state_name() -> String:
	return String(_brain.current_id) if _brain != null else ""

func _enter_enter() -> void:
	_state_time = enter_delay
	_hide_warning()
	_set_body_color(_base_color)

func _update_enter(delta: float) -> void:
	_state_time -= delta
	if _state_time <= 0.0:
		_brain.change(STATE_TRACK)

func _enter_track() -> void:
	_hide_warning()
	_set_body_color(_base_color)

func _update_track(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() <= trigger_distance:
		_brain.change(STATE_CHARGING)
		return
	if to_player.length_squared() > 0.001:
		global_position += to_player.normalized() * tracking_speed * ScreenUtil.scale_factor() * speed_scale * delta

func _enter_charging() -> void:
	_state_time = charge_time
	_charge_elapsed = 0.0
	_show_warning()
	_set_body_color(Color(1.0, 0.25, 0.05, 1.0))

func _update_charging(delta: float) -> void:
	_state_time -= delta
	_charge_elapsed += delta
	var t := clampf(_charge_elapsed / maxf(charge_time, 0.001), 0.0, 1.0)
	if _warning != null:
		_warning.color = warning_start_color.lerp(warning_end_color, t)
	if _state_time <= 0.0:
		_brain.change(STATE_EXPLODE)

func _enter_explode() -> void:
	_exploded = true
	_hide_warning()
	if polygon != null:
		polygon.visible = false
	_explode_damage_and_visual()
	get_tree().create_timer(explosion_visual_duration, false).timeout.connect(queue_free)

func _enter_dead() -> void:
	_hide_warning()
	if polygon != null:
		polygon.visible = true
	_set_body_color(_base_color)

func _on_died(_score: int, _gold: int) -> void:
	if _brain != null:
		_brain.change(STATE_DEAD)

func _explode_damage_and_visual() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and not GameFlow.is_run_ended():
		if global_position.distance_to(player.global_position) <= explosion_radius:
			player.queue_explosion_damage(float(maxi(1, roundi(attack_power))))

	var visual := Polygon2D.new()
	visual.name = "SelfDestructExplosion"
	visual.top_level = true
	var points := PackedVector2Array()
	for i in range(48):
		var angle := TAU * float(i) / 48.0
		points.append(Vector2(cos(angle), sin(angle)) * explosion_radius)
	visual.polygon = points
	visual.color = explosion_color
	visual.z_index = 10
	visual.global_position = global_position
	get_parent().add_child(visual)
	var tween := visual.create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, explosion_visual_duration)
	tween.tween_callback(visual.queue_free)

func _build_warning() -> void:
	_warning = Polygon2D.new()
	_warning.name = "ChargeWarning"
	_warning.top_level = true
	var points := PackedVector2Array()
	for i in range(48):
		var angle := TAU * float(i) / 48.0
		points.append(Vector2(cos(angle), sin(angle)) * explosion_radius)
	_warning.polygon = points
	_warning.color = warning_start_color
	_warning.z_index = -1
	_warning.visible = false
	add_child(_warning)

func _show_warning() -> void:
	if _warning == null:
		return
	_warning.global_position = global_position
	_warning.color = warning_start_color
	_warning.visible = true

func _hide_warning() -> void:
	if _warning != null:
		_warning.visible = false

func _set_body_color(color: Color) -> void:
	if polygon != null:
		polygon.color = color
