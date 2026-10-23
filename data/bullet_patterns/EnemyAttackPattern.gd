extends Resource
class_name EnemyAttackPattern

## 一个完整的开火循环：按顺序执行 steps，loop 时打完后回到第一步。
@export var start_delay := 0.8           # 出场后第一次开火延迟
@export var loop := true                 # 是否循环
@export var steps: Array[AttackStep] = []