extends "res://scripts/enemies/Enemy.gd"

## 自爆兵：慢速靠近玩家，进入引信后 1.5 秒爆炸；死亡也会启动同一个引信。

const EXPLOSION_SCENE := preload("res://scenes/enemies/self_destruct_explosion.tscn")

@export var trigger_distance := 70.0
@export var fuse_time := 1.5
@export var explosion_radius := 140.0
@export var explosion_damage := 28.0

var _fusing := false
var _hazard: Node2D

func _ready() -> void:
	super._ready()
	attack_power = 0.0
	global_position = start_position + offset

func _physics_process(delta: float) -> void:
	if _fusing or _dead or is_queued_for_deletion():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() <= trigger_distance:
		_start_fuse()
		return
	if to_player.length_squared() > 0.001:
		global_position += to_player.normalized() * speed * delta

func take_damage(amount: float) -> void:
	var already_fusing := _fusing
	super.take_damage(amount)
	if not already_fusing and hp <= 0:
		_start_fuse()

func _start_fuse() -> void:
	if _fusing:
		return
	_fusing = true
	_hazard = EXPLOSION_SCENE.instantiate()
	_hazard.setup(explosion_radius, explosion_damage, fuse_time, self)
	get_parent().add_child(_hazard)
	_hazard.global_position = global_position
