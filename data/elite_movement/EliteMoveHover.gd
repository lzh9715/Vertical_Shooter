extends EliteMovement
class_name EliteMoveHover

## 左右正弦漂移（原来的精英行为）。

@export var amplitude := 90.0     # 漂移幅度
@export var frequency := 0.35     # 每秒摆动次数

func offset_at(t: float) -> Vector2:
	return Vector2(sin(TAU * (frequency * t + phase)) * amplitude, 0.0)
