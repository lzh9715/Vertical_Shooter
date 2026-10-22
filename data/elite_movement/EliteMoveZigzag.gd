extends EliteMovement
class_name EliteMoveZigzag

## 左右折线巡逻，比正弦更“机械”。

@export var amplitude := 120.0
@export var frequency := 0.25

func offset_at(t: float) -> Vector2:
	var cycle := frequency * t + phase
	var tri := 1.0 - absf(fmod(cycle, 1.0) * 2.0 - 1.0)   # 0 → 1 → 0
	return Vector2((tri * 2.0 - 1.0) * amplitude, 0.0)
