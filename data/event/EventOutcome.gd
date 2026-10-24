extends Resource
class_name EventOutcome

## 一次选择的结果：直接作用于 GameFlow 的状态。

@export_multiline var text := ""

@export_group("即时效果")
@export var gold := 0
@export var hp := 0              # 正数回复，负数扣血
@export var max_hp := 0          # 正数提升上限，负数降低
@export var score := 0

@export_group("持续效果（本局）")
@export var reward_modifier_source: StringName = &""
@export var reward_multiplier := 1.0
@export var shop_modifier_source: StringName = &""
@export var shop_price_multiplier := 1.0

@export_group("战斗")
@export var battle: EventBattle

func apply() -> void:
	if gold != 0:
		GameFlow.add_gold(gold)
	if hp != 0:
		GameFlow.change_hp(hp)
	if max_hp != 0:
		GameFlow.change_max_hp(max_hp)
	if score != 0:
		GameFlow.add_score(score)

	if reward_multiplier != 1.0 and reward_modifier_source != &"":
		GameFlow.add_reward_modifier(reward_modifier_source, reward_multiplier)

	if shop_price_multiplier != 1.0 and shop_modifier_source != &"":
		GameFlow.get_pricing().add_modifier(shop_modifier_source, shop_price_multiplier)
