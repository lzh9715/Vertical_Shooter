extends Resource
class_name FormationData

@export var enemy_data: EnemyData

@export_group("阵型")
@export var shape: FormationShape              # 形状库
@export var count: int = 5                     # 出几只
@export var spacing := Vector2(60, 50)         # 720 基准下的间距

@export_group("出场位置")
@export var anchor := Vector2(0, -1.15)        # 阵型「中心」的归一化位置
@export var offset_px := Vector2.ZERO

@export_group("行为")
@export_enum("Top_To_Bottom", "Left_To_Right", "Right_To_Left") var direction: String = "Top_To_Bottom"
@export var movement: MovementPattern
@export var delay: float = 0.0                 # 整队延迟
@export var interval: float = 0.0              # 队内每只间隔