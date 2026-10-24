extends RefCounted
class_name ItemInstance

## 装备类物品的独立实例：同定义、同词条也不可堆叠。

var instance_id := 0
var definition: ItemDefinition
var affixes: Array[ItemAffix] = []

static var _next_id := 0

static func create(def: ItemDefinition, p_affixes: Array[ItemAffix] = []) -> ItemInstance:
	_next_id += 1
	var item := ItemInstance.new()
	item.instance_id = _next_id
	item.definition = def
	item.affixes = p_affixes
	return item

func get_value() -> int:
	var total := definition.base_price if definition != null else 0
	for affix in affixes:
		total += affix.value_bonus
	return maxi(total, 1)

func describe_affixes() -> String:
	var lines: Array[String] = []
	for affix in affixes:
		lines.append("%s +%.1f" % [affix.display_name, affix.amount])
	return " / ".join(lines)
