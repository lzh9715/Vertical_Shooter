extends Resource
class_name WaveData

@export var enemy_scene: PackedScene
@export var enemy_count: int = 5
# 👇 就是这一行！允许我们在检查器里下拉选择 Line 或 V_Shape
@export_enum("Line", "V_Shape") var formation: String = "Line" 
@export var spacing: float = 60.0
@export var speed: float = 150.0