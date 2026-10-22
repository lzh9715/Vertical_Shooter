extends Resource
class_name BossPhaseData

## Boss 的一个阶段：血量阈值 + 移动方式 + 攻击序列
@export var hp_threshold := 1.0          # 血量比例 <= 此值时进入该阶段
@export var movement: EliteMovement      # 复用精英移动库
@export var attack: EnemyAttackPattern   # 复用攻击序列库
@export var display_name := ""