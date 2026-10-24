extends RefCounted
class_name ItemStack

## 可堆叠物品：法术卡（上限 3）。没有随机词条，所以只存定义 + 数量。

var definition: ItemDefinition
var count := 1

func _init(def: ItemDefinition = null, p_count := 1) -> void:
	definition = def
	count = maxi(p_count, 0)

func max_count() -> int:
	return definition.stack_limit if definition != null else 1

func room() -> int:
	return maxi(max_count() - count, 0)

func can_merge_with(other: ItemStack) -> bool:
	return (
		other != null
		and definition == other.definition
		and count < max_count()
	)

func get_value() -> int:
	return definition.base_price * count if definition != null else 0
