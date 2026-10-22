extends RewardData
class_name RewardBattle

## 刷怪奖励关：打完给大量金币，不给分数，小怪不吃难度倍率。

@export var waves: Array[WaveData] = []
@export var gold_multiplier := 2.0

func describe() -> String:
	return "消灭全部小怪，金币 ×%.1f" % gold_multiplier
