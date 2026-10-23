extends Area2D

## 敌方子弹：只负责直线飞行、出屏回收，命中判定交给玩家 Hurtbox。

@export var speed := 220.0
@export var damage := 1
@export var direction := Vector2.LEFT
@export var tint := Color(1, 0.85, 0.3, 1)
@export var radius := 7.0
@export var texture: Texture2D

const BASE_RADIUS := 7.0

@onready var polygon: Polygon2D = $Polygon2D
@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	# 占位外观：圆形。半径由 radius 控制，颜色由 tint 控制。
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		points.append(Vector2(cos(a), sin(a)) * BASE_RADIUS)
	polygon.polygon = points
	polygon.color = tint

	if texture != null:
		sprite.texture = texture
		sprite.visible = true
		polygon.visible = false

	var s := maxf(radius / BASE_RADIUS, 0.1)
	scale = Vector2(s, s)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	var bounds := Rect2(Vector2.ZERO, ScreenUtil.world_size()).grow(160.0)
	if not bounds.has_point(global_position):
		queue_free()
