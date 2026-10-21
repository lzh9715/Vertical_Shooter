extends Resource
class_name LevelConfig

@export var display_name := "第一章"

@export_group("地图")
@export var fixed_map: MapData              # 手工设计的地图（关卡模式用）
@export var randomize_map := false          # true = 运行时生成
@export var middle_layers := 7              # 起点与首领之间的层数
@export var min_nodes_per_layer := 2
@export var max_nodes_per_layer := 4        # 上限 4 条路线

@export_group("战斗")
@export var wave_min := 5
@export var wave_max := 7

@export_group("难度")
@export var base_difficulty := 1.0
@export var difficulty_per_layer := 0.1

@export_group("波次池")
@export var mob_pool: Array[WaveData] = []
@export var elite_pool: Array[WaveData] = []
@export var boss_pool: Array[WaveData] = []

@export_group("商店")
@export var spell_pool: Array[SpellData] = []
@export var pricing: ShopPricing          # 留空则使用默认定价（20~150，倍率 1）