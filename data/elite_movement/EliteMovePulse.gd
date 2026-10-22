extends EliteMovement
class_name EliteMovePulse

## 周期性向下冲刺再回位，同时轻微左右摆动。
## depth 越大越有压迫感，frequency 控制节奏。

@export var depth := 120.0        # 向下冲刺的深度
@export var frequency := 0.25     # 每秒脉冲次数
@export var sway := 40.0          # 同时的左右摆动幅度

func offset_at(t: float) -> Vector2:
	var cycle := frequency * t + phase
	var pulse := 0.5 - 0.5 * cos(TAU * cycle)      # 0 → 1 → 0
	return Vector2(sin(TAU * cycle * 0.5) * sway, pulse * depth)
