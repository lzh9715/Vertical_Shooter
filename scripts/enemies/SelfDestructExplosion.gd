extends Node2D

## 自爆兵的独立爆炸危险区：敌人本体消失后仍然继续倒计时。

var radius := 140.0
var damage := 28.0
var delay := 1.5
var _time_left := 1.5
var _source: Node
var _exploded := false
var _warning: Polygon2D

func setup(p_radius: float, p_damage: float, p_delay: float, source: Node = null) -> void:
	radius = p_radius
	damage = p_damage
	delay = p_delay
	_time_left = p_delay
	_source = source

func _ready() -> void:
	_build_warning()

func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left > 0.0:
		return
	_explode()

func _build_warning() -> void:
	_warning = Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	_warning.polygon = points
	_warning.color = Color(1.0, 0.45, 0.05, 0.28)
	_warning.z_index = -1
	add_child(_warning)

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var player := get_tree().get_first_node_in_group("player")
	if player != null and not GameFlow.is_run_ended():
		var distance := global_position.distance_to(player.global_position)
		if distance <= radius:
			var multiplier := ExplosionMath.falloff(distance, radius)
			player.queue_explosion_damage(maxf(1.0, damage * multiplier))
	if _warning != null:
		_warning.visible = false
	if is_instance_valid(_source):
		_source.queue_free()
	queue_free()
