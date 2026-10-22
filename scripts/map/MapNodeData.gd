extends Resource
class_name MapNodeData

enum NodeType { START, BATTLE, ELITE, SHOP, EVENT, BOSS, REWARD }

@export var id: int = -1
@export var layer: int = 0
@export var column: int = 0                 # 网格列号（0 ~ GRID_WIDTH-1）
@export var type: int = NodeType.BATTLE

@export_group("地图表现")
@export var position := Vector2.ZERO        # 归一化 0~1，UI 自己换算像素
@export var display_name := ""              # 悬停浮窗显示的名称
@export var icon: Texture2D                 # 图例图标（预留，暂不使用）

@export_group("连接")
@export var next_ids: PackedInt32Array = [] # 出边，只指向更高层 → 天然无环

@export_group("战斗内容")
@export var wave_count: int = 0             # 5~7 波，5B 再挂具体 WaveData

@export var reward_gold: int = 0

static func type_name(t: int) -> String:
	return NodeType.keys()[t]