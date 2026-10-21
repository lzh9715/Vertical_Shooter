extends MovementPattern
class_name MoveSine

@export var amplitude := 150.0   # 摆幅（像素）
@export var frequency := 0.48    # 每秒摆动多少轮（0.48 ≈ 原来的 sin(t*3.0)）
@export var phase := 0.0         # 起始相位，0~1，用来让同一编队的怪错开摆动

func sample(t: float) -> Vector2:
	return Vector2(sin(TAU * frequency * t + phase * TAU) * amplitude, 0.0)