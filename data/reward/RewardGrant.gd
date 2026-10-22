extends RewardData
class_name RewardGrant

## 直接发放奖励：金币 / 回血 / 法杖。
## 金币走 GameFlow.get_reward_multiplier()，未来收益类 buff 只需要往那里叠倍率。

@export var base_gold := 150
@export var heal := 0
@export var spell: SpellData

func enter() -> void:
	GameFlow.add_gold(final_gold())
	if heal > 0:
		GameFlow.heal(heal)
	if spell != null:
		GameFlow.spell = spell

func final_gold() -> int:
	return maxi(1, roundi(base_gold * GameFlow.get_reward_multiplier()))

func describe() -> String:
	var lines: Array[String] = ["金币 +%d" % final_gold()]
	if heal > 0:
		lines.append("回复 %d 点血量" % heal)
	if spell != null:
		lines.append("获得法杖：%s" % spell.display_name)
	return "\n".join(lines)
