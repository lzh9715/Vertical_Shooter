extends Area2D

signal died(score: int, gold: int)

@export var movement: MovementPattern
@export var speed := 200.0
@export var direction := "Top_To_Bottom"
@export var despawn_margin := 300.0

@export var max_hp := 1
@export var score_reward := 10
@export var gold_reward := 5

var hp := 1
var start_position := Vector2.ZERO
var offset := Vector2.ZERO
var elapsed_time := 0.0

func _ready() -> void:
	hp = max_hp
	_apply_motion()        # ← 关键：进场立刻定位，避免左上角闪一帧

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