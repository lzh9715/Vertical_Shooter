extends RefCounted
class_name SaveData

## 存档结构草案。只保存定义 ID、实例词条和装配关系，不保存 Resource 对象。
## 目前不接入实际存盘；先保证 capture -> restore 的往返结构稳定。

const VERSION := 1

static func capture() -> Dictionary:
	var inventory := GameFlow.get_inventory()
	var equipment := GameFlow.get_equipment()

	var cells: Array = []
	for i in range(inventory.cells.size()):
		if inventory.cells[i] != null:
			cells.append(_item_to_dict(inventory.cells[i], i))

	var overflow: Array = []
	for item in inventory.overflow:
		overflow.append(_item_to_dict(item, -1))

	return {
		"version": VERSION,
		"player": {
			"hp": GameFlow.hp,
			"max_hp": GameFlow.max_hp,
			"mana": GameFlow.mana,
			"max_mana": GameFlow.max_mana,
		},
		"inventory": {
			"cells": cells,
			"overflow": overflow,
			"trash": _item_to_dict(inventory.trash, -1),
		},
		"equipment": {
			"active_wand_index": equipment.active_wand_index,
			"wand_slots": [
				_wand_to_dict(equipment.wand_slots[0]),
				_wand_to_dict(equipment.wand_slots[1]),
			],
			"hat": _item_to_dict(equipment.hat, -1),
			"robe": _item_to_dict(equipment.robe, -1),
			"accessory": _item_to_dict(equipment.accessory, -1),
		},
	}

static func restore(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != VERSION:
		return false

	var player: Dictionary = data.get("player", {})
	GameFlow.hp = float(player.get("hp", 100.0))
	GameFlow.max_hp = float(player.get("max_hp", 100.0))
	GameFlow.mana = float(player.get("mana", 100.0))
	GameFlow.max_mana = float(player.get("max_mana", 100.0))

	var inventory := GridInventory.new()
	var inv_data: Dictionary = data.get("inventory", {})

	var cells: Array = inv_data.get("cells", [])
	for entry in cells:
		if not (entry is Dictionary):
			continue
		var slot := int(entry.get("slot", -1))
		if slot < 0 or slot >= inventory.cells.size():
			continue
		inventory.cells[slot] = _dict_to_item(entry)

	for entry in inv_data.get("overflow", []):
		if entry is Dictionary:
			var item = _dict_to_item(entry)
			if item != null:
				inventory.overflow.append(item)

	var trash_entry = inv_data.get("trash")
	if trash_entry is Dictionary:
		inventory.trash = _dict_to_item(trash_entry)

	var equipment := PlayerEquipment.new()
	var eq_data: Dictionary = data.get("equipment", {})
	var wand_slots: Array = eq_data.get("wand_slots", [])
	if wand_slots.size() > 0:
		equipment.wand_slots[0] = _dict_to_wand(wand_slots[0])
	if wand_slots.size() > 1:
		equipment.wand_slots[1] = _dict_to_wand(wand_slots[1])
	equipment.active_wand_index = clampi(int(eq_data.get("active_wand_index", 0)), 0, 1)
	equipment.hat = _dict_to_item(eq_data.get("hat", {}))
	equipment.robe = _dict_to_item(eq_data.get("robe", {}))
	equipment.accessory = _dict_to_item(eq_data.get("accessory", {}))

	GameFlow.inventory = inventory
	GameFlow.equipment = equipment
	return true

static func _item_to_dict(item, slot: int = -1) -> Dictionary:
	if item == null:
		return {}

	var result := {
		"slot": slot,
		"definition_id": String(item.definition.id) if item.definition != null else "",
	}

	if item is ItemStack:
		result["kind"] = "stack"
		result["count"] = item.count
		return result

	result["kind"] = "instance"
	result["instance_id"] = item.instance_id
	result["rarity"] = item.rarity
	var affixes: Array = []
	for affix in item.affixes:
		affixes.append({
			"id": String(affix.id),
			"display_name": affix.display_name,
			"stat": String(affix.stat),
			"amount": affix.amount,
			"value_bonus": affix.value_bonus,
		})
	result["affixes"] = affixes
	return result

static func _dict_to_item(data) -> Variant:
	if not (data is Dictionary) or data.is_empty():
		return null

	var definition := ItemCatalog.find_definition(StringName(String(data.get("definition_id", ""))))
	if definition == null:
		return null

	if String(data.get("kind", "")) == "stack":
		return ItemStack.new(definition, int(data.get("count", 1)))

	var affixes: Array[ItemAffix] = []
	for affix_data in data.get("affixes", []):
		if not (affix_data is Dictionary):
			continue
		var affix := ItemAffix.new()
		affix.id = StringName(String(affix_data.get("id", "")))
		affix.display_name = String(affix_data.get("display_name", ""))
		affix.stat = StringName(String(affix_data.get("stat", "")))
		affix.amount = float(affix_data.get("amount", 0.0))
		affix.value_bonus = int(affix_data.get("value_bonus", 0))
		affixes.append(affix)

	var instance := ItemInstance.create(definition, affixes)
	instance.rarity = int(data.get("rarity", definition.rarity))
	return instance

static func _wand_to_dict(wand: WandInstance) -> Dictionary:
	if wand == null:
		return {}

	var cards: Array = []
	for card in wand.cards:
		cards.append(String(card.id) if card != null else "")

	return {
		"body": _item_to_dict(wand.body),
		"gem": _item_to_dict(wand.gem),
		"cards": cards,
		"cast_index": wand.cast_index,
	}

static func _dict_to_wand(data) -> WandInstance:
	if not (data is Dictionary) or data.is_empty():
		return null

	var body = _dict_to_item(data.get("body", {}))
	var gem = _dict_to_item(data.get("gem", {}))
	var wand := WandInstance.create(body, gem)
	wand.ensure_slots()

	var card_ids: Array = data.get("cards", [])
	for i in range(mini(card_ids.size(), wand.cards.size())):
		var id := String(card_ids[i])
		if id != "":
			wand.cards[i] = ItemCatalog.find_card(StringName(id))
	wand.cast_index = int(data.get("cast_index", 0))
	return wand
