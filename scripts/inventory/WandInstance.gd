extends RefCounted
class_name WandInstance

## 一把法杖的实例：杖身 + 宝石 + 卡槽。
## 宝石只提供槽位数量，卡槽里的法术卡不可堆叠。

var instance_id := 0
var body: ItemInstance
var gem: ItemInstance
var cards: Array[ItemDefinition] = []

static var _next_id := 0

static func create(p_body: ItemInstance = null, p_gem: ItemInstance = null) -> WandInstance:
	_next_id += 1
	var wand := WandInstance.new()
	wand.instance_id = _next_id
	wand.body = p_body
	wand.gem = p_gem
	return wand

func max_cards() -> int:
	if gem == null or gem.definition == null:
		return 0
	return maxi(gem.definition.gem_slots, 0)

func can_add_card() -> bool:
	return cards.size() < max_cards()

func add_card(definition: ItemDefinition) -> bool:
	if definition == null or not definition.is_card():
		return false
	if not can_add_card():
		return false
	cards.append(definition)
	return true

func remove_card(index: int) -> ItemDefinition:
	if index < 0 or index >= cards.size():
		return null
	return cards.pop_at(index)

## 卸下宝石：宝石回背包，卡牌按规则回背包/溢出。
## 返回 { ok, reason, cards, overflowed }
func unequip_gem(inventory: GridInventory) -> Dictionary:
	if gem == null:
		return {"ok": false, "reason": "没有宝石", "cards": 0, "overflowed": 0}

	if inventory.free_cells() < 1:
		return {"ok": false, "reason": "背包已满，无法卸下宝石", "cards": 0, "overflowed": 0}

	var gem_item := gem
	var returned_cards := cards.duplicate()
	var overflow_before := inventory.overflow_count()

	gem = null
	cards.clear()

	# 先把宝石放进普通格（前置检查已保证至少一格）
	inventory.add(gem_item)

	# 再把卡牌按“已有堆叠 → 空格 → 溢出堆叠 → 新溢出格”处理
	for card in returned_cards:
		inventory.add_card(card, 1)

	var overflowed := inventory.overflow_count() - overflow_before
	return {
		"ok": true,
		"reason": "",
		"cards": returned_cards.size(),
		"overflowed": overflowed,
	}
