extends MovementPattern
class_name MoveZigzag

@export var amplitude := 100.0
@export var frequency := 0.5     # 与原 fmod(t*2.0, 2.0) 一致
@export var phase := 0.0

func sample(t: float) -> Vector2:
	var cycle := frequency * t + phase
	var triangle := 1.0 - absf(fmod(cycle, 1.0) * 2.0 - 1.0)  # 0 → 1 → 0
	return Vector2((triangle * 2.0 - 1.0) * amplitude, 0.0)   # -amp → +amp → -amp