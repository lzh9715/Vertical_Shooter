extends RefCounted
class_name ItemCatalog

## 测试用物品目录。商店和起始物资共用同一批定义。
## 后续接入正式装备系统时，这里可以替换成 .tres 目录。

static var _cards: Array[ItemDefinition] = []
static var _gems: Array[ItemDefinition] = []
static var _bodies: Array[ItemDefinition] = []
static var _hats: Array[ItemDefinition] = []
static var _robes: Array[ItemDefinition] = []
static var _accessories: Array[ItemDefinition] = []

static func cards() -> Array[ItemDefinition]:
	_ensure()
	return _cards

static func gems() -> Array[ItemDefinition]:
	_ensure()
	return _gems

static func bodies() -> Array[ItemDefinition]:
	_ensure()
	return _bodies

static func hats() -> Array[ItemDefinition]:
	_ensure()
	return _hats

static func robes() -> Array[ItemDefinition]:
	_ensure()
	return _robes

static func accessories() -> Array[ItemDefinition]:
	_ensure()
	return _accessories

static func make_instance(definition: ItemDefinition) -> ItemInstance:
	return ItemInstance.create(definition, make_affixes(definition.category))

static func make_affixes(category: int) -> Array[ItemAffix]:
	var pool: Array[ItemAffix] = []
	match category:
		ItemDefinition.Category.GEM:
			pool = [
				_affix("增幅", &"spell_power", 0.08, 20),
				_affix("节能", &"mana_cost", 0.10, 25),
				_affix("迅捷", &"cast_speed", 0.10, 15),
			]
		ItemDefinition.Category.STAFF_BODY:
			pool = [
				_affix("锋锐", &"damage", 1.0, 25),
				_affix("沉重", &"damage", 2.0, 40),
				_affix("轻快", &"cast_speed", 0.05, 15),
			]
		ItemDefinition.Category.HAT:
			pool = [
				_affix("法力", &"max_mana", 10.0, 20),
				_affix("专注", &"cooldown", 0.05, 20),
			]
		ItemDefinition.Category.ROBE:
			pool = [
				_affix("生命", &"max_hp", 1.0, 25),
				_affix("护盾", &"armor", 1.0, 20),
			]
		ItemDefinition.Category.ACCESSORY:
			pool = [
				_affix("拾取", &"pickup_radius", 0.15, 15),
				_affix("疾行", &"move_speed", 0.08, 15),
			]

	var result: Array[ItemAffix] = []
	if pool.is_empty():
		return result
	pool.shuffle()
	var count := 1 + randi_range(0, 1)
	for i in range(mini(count, pool.size())):
		result.append(pool[i])
	return result

static func category_name(category: int) -> String:
	match category:
		ItemDefinition.Category.SPELL_CARD:
			return "法术"
		ItemDefinition.Category.GEM:
			return "宝石"
		ItemDefinition.Category.STAFF_BODY:
			return "杖身"
		ItemDefinition.Category.HAT:
			return "巫师帽"
		ItemDefinition.Category.ROBE:
			return "巫师袍"
		ItemDefinition.Category.ACCESSORY:
			return "配饰"
	return "物品"

static func _ensure() -> void:
	if not _cards.is_empty():
		return

	_cards = [
		_make_def(&"card_single", "单发卡", ItemDefinition.Category.SPELL_CARD, 3, 15),
		_make_def(&"card_spread", "散射卡", ItemDefinition.Category.SPELL_CARD, 3, 25),
		_make_def(&"card_homing", "追踪卡", ItemDefinition.Category.SPELL_CARD, 3, 40),
		_make_def(&"card_pierce", "穿透卡", ItemDefinition.Category.SPELL_CARD, 3, 35),
		_make_def(&"card_boom", "爆裂卡", ItemDefinition.Category.SPELL_CARD, 3, 50),
	]

	_gems = [
		_make_def(&"gem_a", "测试宝石 A", ItemDefinition.Category.GEM, 1, 80, 3),
		_make_def(&"gem_b", "测试宝石 B", ItemDefinition.Category.GEM, 1, 120, 5),
		_make_def(&"gem_c", "测试宝石 C", ItemDefinition.Category.GEM, 1, 160, 7),
	]

	_bodies = [
		_make_def(&"body_a", "测试杖身 A", ItemDefinition.Category.STAFF_BODY, 1, 90, 0, 3),
		_make_def(&"body_b", "测试杖身 B", ItemDefinition.Category.STAFF_BODY, 1, 120, 0, 5),
	]

	_hats = [
		_make_def(&"hat_apprentice", "学徒帽", ItemDefinition.Category.HAT, 1, 80),
		_make_def(&"hat_arcane", "秘法帽", ItemDefinition.Category.HAT, 1, 110),
	]

	_robes = [
		_make_def(&"robe_apprentice", "学徒袍", ItemDefinition.Category.ROBE, 1, 90),
		_make_def(&"robe_arcane", "秘法袍", ItemDefinition.Category.ROBE, 1, 120),
	]

	_accessories = [
		_make_def(&"acc_charm", "拾取护符", ItemDefinition.Category.ACCESSORY, 1, 70),
		_make_def(&"acc_swift", "疾行护符", ItemDefinition.Category.ACCESSORY, 1, 85),
	]

static func _make_def(id: StringName, name: String, category: int, stack_limit: int, price: int, gem_slots := 0, damage := 0) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.display_name = name
	def.category = category
	def.stack_limit = stack_limit
	def.base_price = price
	def.gem_slots = gem_slots
	def.damage_bonus = damage
	return def

static func _affix(name: String, stat: StringName, amount: float, bonus: int) -> ItemAffix:
	var affix := ItemAffix.new()
	affix.display_name = name
	affix.stat = stat
	affix.amount = amount
	affix.value_bonus = bonus
	return affix
