extends Resource
class_name EventBattle

## 事件触发的限时战斗。

@export var boss: BossData
@export var time_limit := 40.0     # 秒；0 = 不限时
@export var win_gold := 0          # 胜利额外奖励
@export var refund_stolen := false # 是否返还事件里被扣掉的金币
