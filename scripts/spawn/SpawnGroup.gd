extends Resource
class_name SpawnGroup

## 所有“一次出怪方式”的基类。
## 子类只需实现 spawn()，新增出怪方式不用改 Spawner / WaveData / BattleRunner。

@export var enemy_data: EnemyData

@export_group("出场位置")
@export var anchor := Vector2(1.22, 0)      # 归一化坐标，-1~1；默认屏幕右侧外
@export var offset_px := Vector2.ZERO       # 锚点基础上的像素微调

@export_group("行为")
@export_enum("Right_To_Left", "Left_To_Right", "Top_To_Bottom") var direction := "Right_To_Left"
@export var movement: MovementPattern

## 由 EnemySpawner 调用：把这一组敌人实例化并放进场景
func spawn(_spawner) -> void:
	push_warning("%s 没有实现 spawn()" % get_script().resource_path)