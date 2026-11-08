extends RefCounted
class_name WandInstance

## 一把法杖的实例：杖身 + 宝石 + 卡槽。
## 宝石只提供槽位数量，卡槽里的法术卡不可堆叠。

var instance_id := 0
var body: ItemInstance
var gem: ItemInstance
var cards: Array[ItemDefinition] = []
## 每次施法消耗一张，按数组顺序循环
var cast_index := 0

static var _next_id := 0

static func create(p_body: ItemInstance = null, p_gem: ItemInstance = null) -> WandInstance:
	_next_id += 1
	var wand := WandInstance.new()
	wand.instance_id = _next_id
	wand.body = p_body
	wand.gem = p_gem
	wand.ensure_slots()
	return wand

func max_cards() -> int:
	if gem == null or gem.definition == null:
		return 0
	return maxi(gem.definition.gem_slots, 0)

## 卡槽是关键：数组长度等于宝石槽位，空槽为 null。
func ensure_slots() -> void:
	var count := max_cards()
	while cards.size() < count:
		cards.append(null)

func can_add_card() -> bool:
	ensure_slots()
	for card in cards:
		if card == null:
			return true
	return false

func can_install(definition: ItemDefinition, ignore: ItemDefinition = null, at_index: int = -1) -> bool:
	if definition == null or not definition.is_card():
		return false
	if definition.is_attack() and definition.trigger_type != ItemDefinition.TriggerType.NONE and definition.projectile_count > 1:
		return false
	var candidate := cards.duplicate()
	var target_index := at_index
	if target_index < 0 and ignore != null:
		target_index = cards.find(ignore)
	if target_index < 0:
		for i in range(candidate.size()):
			if candidate[i] == null:
				target_index = i
				break
	if target_index < 0 or target_index >= candidate.size():
		return false
	for i in range(candidate.size()):
		if candidate[i] == ignore and i != target_index:
			candidate[i] = null
	candidate[target_index] = definition
	return _candidate_valid(candidate)

func _candidate_valid(candidate: Array) -> bool:
	var definition_count := {}
	for card in candidate:
		if card == null:
			continue
		definition_count[card.id] = int(definition_count.get(card.id, 0)) + 1
		if card.stack_limit > 0 and int(definition_count[card.id]) > card.stack_limit:
			return false
		if card.is_attack() and card.trigger_type != ItemDefinition.TriggerType.NONE and card.projectile_count > 1:
			return false

	var blocks := CastSimulator.build_blocks(candidate)
	for block in blocks:
		var mode_kind := {}
		for card in block:
			if card == null or not card.is_module():
				continue
			if card.compatibility_group == &"":
				continue
			if mode_kind.has(card.compatibility_group) and int(mode_kind[card.compatibility_group]) != card.effect_type:
				return false
			mode_kind[card.compatibility_group] = card.effect_type
	return true

func add_card(definition: ItemDefinition) -> bool:
	if definition == null or not definition.is_card():
		return false
	ensure_slots()
	for i in range(cards.size()):
		if cards[i] == null:
			if not can_install(definition, null, i):
				return false
			cards[i] = definition
			return true
	return false

## 放到指定槽位；目标槽已有卡时返回 false（由界面决定替换）。
func insert_card(index: int, definition: ItemDefinition) -> bool:
	if definition == null or not definition.is_card():
		return false
	ensure_slots()
	if index < 0 or index >= cards.size():
		return false
	if cards[index] != null:
		return false
	if not can_install(definition, null, index):
		return false
	cards[index] = definition
	return true

func move_card(from_index: int, to_index: int) -> bool:
	ensure_slots()
	if from_index < 0 or from_index >= cards.size():
		return false
	if to_index < 0 or to_index >= cards.size():
		return false
	if from_index == to_index or cards[from_index] == null:
		return false
	var candidate := cards.duplicate()
	candidate[from_index] = cards[to_index]
	candidate[to_index] = cards[from_index]
	if not _candidate_valid(candidate):
		return false
	cards[from_index] = candidate[from_index]
	cards[to_index] = candidate[to_index]
	return true

func remove_card(index: int) -> ItemDefinition:
	ensure_slots()
	if index < 0 or index >= cards.size():
		return null
	var card := cards[index]
	cards[index] = null
	return card

func card_count() -> int:
	var total := 0
	for card in cards:
		if card != null:
			total += 1
	return total

func compact_cards() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for card in cards:
		if card != null:
			result.append(card)
	return result

func next_card() -> ItemDefinition:
	ensure_slots()
	if cards.is_empty():
		cast_index = 0
		return null
	cast_index = clampi(cast_index, 0, cards.size() - 1)
	for i in range(cards.size()):
		var index := (cast_index + i) % cards.size()
		var card := cards[index]
		if card != null:
			cast_index = (index + 1) % cards.size()
			return card
	return null

## 卸下宝石：宝石回背包，卡牌按规则回背包/溢出。
## 返回 { ok, reason, cards, overflowed }
func unequip_gem(inventory: GridInventory) -> Dictionary:
	if gem == null:
		return {"ok": false, "reason": "没有宝石", "cards": 0, "overflowed": 0}

	if inventory.free_cells() < 1:
		return {"ok": false, "reason": "背包已满，无法卸下宝石", "cards": 0, "overflowed": 0}

	var gem_item := gem
	var returned_cards: Array[ItemDefinition] = []
	for card in cards:
		if card != null:
			returned_cards.append(card)
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
