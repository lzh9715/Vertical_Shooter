extends Resource
class_name MovementPattern

## 轨迹基类。返回「行进坐标系」下的偏移：
##   x = 横向（垂直于前进方向，用来左右摆）
##   y = 纵向（沿着前进方向，用来前后突进）
## t = 敌人存活秒数
## 子类只需要重写 sample()，调用方永远不用改。
func sample(_t: float) -> Vector2:
	return Vector2.ZERO