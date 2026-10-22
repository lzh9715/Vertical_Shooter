extends Resource
class_name AttackStep

## 攻击序列中的一步：
## 连续打 repeat 轮，每轮之间隔 gap，打完后等 cooldown 再进下一步。
@export var volley: EnemyBulletPattern   # 打什么（瞄准/扇形/重弹）
@export var repeat := 1                  # 连打几轮
@export var gap := 0.12                  # 连发之间的间隔（秒）
@export var cooldown := 1.8              # 本步结束后的等待（秒）