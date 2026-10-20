extends Resource
class_name QueueData

@export var enemy_scene: PackedScene
@export var count: int = 5
@export var start_pos: Vector2 = Vector2(360, -100) # 起点
@export_enum("Top_To_Bottom", "Left_To_Right", "Right_To_Left") var direction: String = "Top_To_Bottom"
@export_enum("Straight", "Sine", "Zigzag") var path_type: String = "Straight"
@export var speed: float = 150.0
@export var spacing_time: float = 0.2 # 敌人出现的时间间隔