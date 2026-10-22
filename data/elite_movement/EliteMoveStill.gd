extends EliteMovement
class_name EliteMoveStill

## 完全静止，停在悬停点。

func offset_at(_t: float) -> Vector2:
	return Vector2.ZERO
