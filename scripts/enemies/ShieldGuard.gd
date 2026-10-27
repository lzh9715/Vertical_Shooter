extends "res://scripts/enemies/Enemy.gd"

## 盾卫：全身普通护盾，普通射弹被挡下；穿透和爆炸绕过护盾。
## 破盾后 2 秒硬直，不移动不攻击。

@export var shield_ratio := 0.5
@export var stop_line_ratio := 0.5
@export var stun_duration := 2.0

var shield_hp := 0
var shield_max := 0
var _stop_x := 0.0
var _stun_left := 0.0
var _shield_line: Line2D

func _ready() -> void:
	_stop_x = ScreenUtil.world_size().x * stop_line_ratio
	super._ready()
	shield_max = maxi(1, roundi(float(max_hp) * shield_ratio))
	shield_hp = shield_max
	_build_shield_visual()

func has_active_shield() -> bool:
	return shield_hp > 0

func absorb_shield_damage(amount: int) -> bool:
	if shield_hp <= 0:
		return false
	shield_hp = maxi(shield_hp - amount, 0)
	_flash_shield()
	if shield_hp <= 0:
		_break_shield()
	return true

func _break_shield() -> void:
	shield_hp = 0
	_stun_left = stun_duration
	_attack_running = false
	if _shield_line != null:
		_shield_line.visible = false

func _build_shield_visual() -> void:
	if polygon == null or polygon.polygon.is_empty():
		return
	_shield_line = Line2D.new()
	_shield_line.name = "ShieldOutline"
	_shield_line.points = polygon.polygon
	_shield_line.closed = true
	_shield_line.width = 6.0
	_shield_line.default_color = Color.WHITE
	_shield_line.antialiased = true
	_shield_line.z_index = 2
	add_child(_shield_line)

func _flash_shield() -> void:
	if _shield_line == null:
		return
	_shield_line.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var tween := create_tween()
	tween.tween_property(_shield_line, "modulate", Color.WHITE, 0.12)

func _apply_motion() -> void:
	super._apply_motion()
	if global_position.x < _stop_x:
		global_position.x = _stop_x

func _physics_process(delta: float) -> void:
	if _stun_left > 0.0:
		_stun_left = maxf(_stun_left - delta, 0.0)
		if _stun_left <= 0.0:
			_resume_after_stun()
		return
	super._physics_process(delta)

func _resume_after_stun() -> void:
	start_position = global_position
	elapsed_time = 0.0
	_begin_attack()

## 盾卫只向左侧发射水平弹，不追踪玩家。
func _fire_volley(volley: EnemyBulletPattern) -> void:
	if volley == null:
		return
	var scene := volley.bullet_scene
	if scene == null:
		scene = preload("res://scenes/enemies/enemy_bullet.tscn")
	for dir in volley.build_directions(Vector2.LEFT):
		var bullet = scene.instantiate()
		bullet.direction = dir
		bullet.speed = volley.speed * ScreenUtil.scale_factor()
		bullet.damage = attack_power + volley.damage
		bullet.tint = volley.tint
		bullet.radius = volley.radius
		bullet.texture = volley.texture
		get_parent().add_child(bullet)
		bullet.global_position = global_position
