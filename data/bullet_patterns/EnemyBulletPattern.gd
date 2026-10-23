extends Resource
class_name EnemyBulletPattern

## 敌人弹幕模式基类。
## 子类只实现 build_directions()，新增弹型不需要改敌人或生成器。

@export var speed := 220.0            # 弹速（720 基准像素/秒）
@export var interval := 1.8           # 连发间隔（秒）
@export var first_delay := 0.8        # 出场后第一发延迟（秒）
@export var damage := 1
@export var bullet_scene: PackedScene # 留空 = 使用默认 enemy_bullet.tscn

@export_group("外观（预留给贴图）")
@export var texture: Texture2D
@export var tint := Color(1, 0.85, 0.3, 1)
@export var radius := 7.0

## 返回这一轮要发射的方向（单位向量）
func build_directions(_aim: Vector2) -> Array[Vector2]:
	return []
