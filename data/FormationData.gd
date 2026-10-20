extends Resource
class_name FormationData

@export var enemy_scene: PackedScene
@export var points: Array[Vector2] = [Vector2(-50, 50), Vector2(0, 0), Vector2(50, 50)] # V字型默认点位
@export var global_offset_x: float = 0.0 # 整个阵型的左右偏移
@export var speed: float = 150.0