extends Resource
class_name EliteMovement

## 精英在「战斗阶段」相对悬停点的偏移（单位：720 基准像素）。
## t = 进入战斗阶段后的秒数。
##
## phase 统一放在基类：精英生成时会复制一份资源并把 phase 随机化，
## 所以同类精英同时出场也不会走出完全相同的轨迹。
## 子类只实现 offset_at()，新增移动方式不需要改 elite.gd。

@export var phase := 0.0     # 起始相位 0~1（生成时由 精英 随机覆盖）

func offset_at(_t: float) -> Vector2:
	return Vector2.ZERO
