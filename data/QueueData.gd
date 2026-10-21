extends Resource
class_name QueueData

@export var enemy_data: EnemyData
@export var count: int = 5

@export_group("出场位置")
@export var anchor := Vector2(-1.15, 0.0)   # 归一化：-1 左/上边缘，1 右/下边缘
@export var offset_px := Vector2.ZERO       # 在锚点基础上的像素微调

@export_group("行为")
@export_enum("Top_To_Bottom", "Left_To_Right", "Right_To_Left") var direction: String = "Left_To_Right"
@export var movement: MovementPattern
@export var spacing_time: float = 0.2