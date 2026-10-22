extends Resource
class_name RewardData

## 奖励关基类：进入节点时随机抽一个，由 GameFlow 路由。
## 子类实现 enter()（真正结算）与 describe()（展示文本）。

@export var display_name := "奖励关"

func enter() -> void:
	pass

func describe() -> String:
	return ""
