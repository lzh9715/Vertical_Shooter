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