extends BulletAimed
class_name BulletHeavy

## 重弹：更大、更慢、伤害更高的橙色圆形弹。
## 外观仍可替换：改 texture 即可，留空就用橙色圆形占位。

func _init() -> void:
	speed = 120.0
	interval = 2.8
	first_delay = 1.2
	damage = 2
	radius = 18.0
	tint = Color(1.0, 0.55, 0.15, 1.0)
