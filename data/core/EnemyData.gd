extends Resource
class_name EnemyData

@export_group("身份")
@export_enum("小怪", "精英", "Boss") var tier: int = 0
@export var scene: PackedScene

@export_group("数值")
@export var max_hp: int = 1
@export var speed: float = 200.0
@export var score: int = 10      # 击杀得分
@export var gold: int = 5        # 掉落金币
@export var despawn_margin: float = 300.0

@export_group("表现")
@export var texture: Texture2D   # 留空 = 红色方块占位；以后直接拖贴图
@export var visual_scale := 1.0  # 整体缩放：小怪 1.0、精英 1.6~2.0、Boss 2.5~3.0

@export_group("攻击")
@export var attack: EnemyAttackPattern   # 留空 = 不开火

@export_group("精英")
@export var elite_movement: EliteMovement   # 战斗阶段的移动方式（留空 = 停在悬停点）
@export var elite_hover_height := 1920.0    # 横版：悬停点的 x 坐标
@export var elite_lane_offset := 0.0        # 固定的纵向车道偏移（不同精英可以上下分开）