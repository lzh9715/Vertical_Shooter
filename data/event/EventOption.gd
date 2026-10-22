extends Resource
class_name EventOption

## 事件的一个选项：条件、代价、结果。

@export var label := "离开"

@export_group("条件（不满足则禁用）")
@export var need_gold := 0
@export var need_hp := 0
@export var need_spell := false

@export_group("代价（选择时立刻扣除）")
@export var cost_gold := 0
@export var cost_hp := 0
@export var cost_max_hp := 0
@export var cost_spell := false

@export var outcome: EventOutcome

## 返回不可用原因；空字符串 = 可用
func unavailable_reason() -> String:
	if GameFlow.gold < need_gold + cost_gold:
		return "金币不足"
	if GameFlow.hp - cost_hp < maxi(need_hp, 1):
		return "生命不足"
	if cost_max_hp > 0 and GameFlow.max_hp - cost_max_hp < 1:
		return "最大生命不足"
	if (need_spell or cost_spell) and GameFlow.spell == null:
		return "没有法杖"
	return ""

func apply_costs() -> void:
	if cost_gold > 0:
		GameFlow.add_gold(-cost_gold)
	if cost_hp > 0:
		GameFlow.change_hp(-cost_hp)
	if cost_max_hp > 0:
		GameFlow.change_max_hp(-cost_max_hp)
	if cost_spell:
		GameFlow.spell = null
