extends RefCounted
class_name ExplosionMath

## 爆炸距离衰减：内圈 40% 满伤，外圈线性降到 60%。
const FULL_RATIO := 0.4
const EDGE_RATIO := 0.6

static func falloff(distance: float, radius: float) -> float:
	if radius <= 0.0:
		return 1.0
	var inner := radius * FULL_RATIO
	if distance <= inner:
		return 1.0
	var t := clampf((distance - inner) / (radius - inner), 0.0, 1.0)
	return lerpf(1.0, EDGE_RATIO, t)
