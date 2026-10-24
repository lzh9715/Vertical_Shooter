extends RefCounted
class_name PlayerEquipment

## 玩家装备槽：两把法杖 + 巫师帽 + 巫师袍 + 一个配饰。

var wand_slots: Array[WandInstance] = [null, null]
var active_wand_index := 0

var hat: ItemInstance
var robe: ItemInstance
var accessory: ItemInstance

func active_wand() -> WandInstance:
	return wand_slots[active_wand_index]

func switch_wand(index: int) -> bool:
	if index < 0 or index >= wand_slots.size():
		return false
	if wand_slots[index] == null:
		return false
	active_wand_index = index
	return true

func equip_wand(index: int, wand: WandInstance) -> WandInstance:
	if index < 0 or index >= wand_slots.size():
		return null
	var previous := wand_slots[index]
	wand_slots[index] = wand
	return previous

func unequip_wand(index: int) -> WandInstance:
	if index < 0 or index >= wand_slots.size():
		return null
	var wand := wand_slots[index]
	wand_slots[index] = null
	return wand

func equip_item(item: ItemInstance) -> ItemInstance:
	if item == null or item.definition == null:
		return null

	match item.definition.category:
		ItemDefinition.Category.HAT:
			var old := hat
			hat = item
			return old
		ItemDefinition.Category.ROBE:
			var old := robe
			robe = item
			return old
		ItemDefinition.Category.ACCESSORY:
			var old := accessory
			accessory = item
			return old
	return null

func equipment_item_at(index: int) -> ItemInstance:
	match index:
		2:
			return hat
		3:
			return robe
		4:
			return accessory
	return null

func clear_equipment(index: int) -> ItemInstance:
	var item := equipment_item_at(index)
	match index:
		2:
			hat = null
		3:
			robe = null
		4:
			accessory = null
	return item

func accepts(index: int, item: ItemInstance) -> bool:
	if item == null or item.definition == null:
		return false
	match index:
		2:
			return item.definition.category == ItemDefinition.Category.HAT
		3:
			return item.definition.category == ItemDefinition.Category.ROBE
		4:
			return item.definition.category == ItemDefinition.Category.ACCESSORY
	return false
