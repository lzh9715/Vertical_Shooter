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

static func find_card(id: StringName) -> ItemDefinition:
	_ensure()
	for card in _cards:
		if card.id == id:
			return card
	return null

static func find_definition(id: StringName) -> ItemDefinition:
	_ensure()
	for pool in [_cards, _gems, _bodies, _hats, _robes, _accessories]:
		for definition in pool:
			if definition.id == id:
				return definition
	return null

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

static func make_instance(definition: ItemDefinition, rarity_override: int = -1) -> ItemInstance:
	if definition == null:
		return null
	var rarity := definition.rarity if rarity_override < 0 else rarity_override
	rarity = clampi(rarity, 0, 3)
	var instance := ItemInstance.create(definition, make_affixes(definition.category, rarity))
	instance.rarity = rarity
	return instance

## 按稀有度生成词条：普通 2±1、稀有 3±1、史诗 4±1、传说 5±1。
## 每条独立 25% 概率为负面；预算用于限制正面词条总量，允许超出 1 点。
static func make_affixes(category: int, rarity: int = 0) -> Array[ItemAffix]:
	var pool: Array[ItemAffix] = []
	match category:
		ItemDefinition.Category.GEM:
			pool = [
				_affix("增幅", &"spell_power", 0.08, 20),
				_affix("节能", &"mana_cost", 0.10, 25),
			]
		ItemDefinition.Category.STAFF_BODY:
			pool = [
				_affix("锋锐", &"damage", 1.0, 25),
				_affix("沉重", &"damage", 2.0, 40),
				_affix("锐利", &"crit_chance", 0.05, 20),
				_affix("致命", &"crit_damage", 0.15, 25),
			]
		ItemDefinition.Category.HAT:
			pool = [
				_affix("法力", &"max_mana", 10.0, 20),
				_affix("精准", &"crit_chance", 0.03, 15),
			]
		ItemDefinition.Category.ROBE:
			pool = [
				_affix("生命", &"max_hp", 1.0, 25),
				_affix("护盾", &"armor", 1.0, 20),
				_affix("坚韧", &"damage_reduction", 0.03, 20),
			]
		ItemDefinition.Category.ACCESSORY:
			pool = [
				_affix("拾取", &"pickup_radius", 0.15, 15),
				_affix("疾行", &"move_speed", 0.08, 15),
				_affix("幸运", &"luck", 1.0, 20),
			]

	var result: Array[ItemAffix] = []
	if pool.is_empty():
		return result

	rarity = clampi(rarity, 0, 3)
	var base_counts := [2, 3, 4, 5]
	var budgets := [80, 140, 220, 320]
	var target_count: int = clampi(base_counts[rarity] + randi_range(-1, 1), 1, 8)
	var budget: int = maxi(1, budgets[rarity] + randi_range(-1, 1))
	var spent := 0
	var has_positive := false

	for i in range(target_count):
		var template: ItemAffix = pool[randi_range(0, pool.size() - 1)]
		var negative := randf() < 0.25
		if not has_positive and i == target_count - 1:
			negative = false

		var cost := absi(template.value_bonus)
		if not negative and has_positive and spent + cost > budget + 1:
			negative = true

		var affix := _affix(
			template.display_name,
			template.stat,
			template.amount,
			template.value_bonus
		)
		if negative:
			affix.amount = -absf(affix.amount)
			affix.value_bonus = -absi(affix.value_bonus)
		else:
			affix.amount = absf(affix.amount)
			affix.value_bonus = absi(affix.value_bonus)
			spent += affix.value_bonus
			has_positive = true
		result.append(affix)

	if not has_positive and not result.is_empty():
		result[0].amount = absf(result[0].amount)
		result[0].value_bonus = absi(result[0].value_bonus)

	return result

static func rarity_name(rarity: int) -> String:
	match rarity:
		0: return "普通"
		1: return "稀有"
		2: return "史诗"
		3: return "传说"
	return "普通"

## 幸运只影响稀有度权重；有效幸运使用递减收益。
static func roll_rarity(luck: float) -> int:
	var effective_luck := maxf(luck, 0.0) * 50.0 / (maxf(luck, 0.0) + 50.0)
	var weights: Array[float] = [
		40.0,
		30.0 + effective_luck * 0.5,
		20.0 + effective_luck,
		10.0 + effective_luck * 1.5,
	]
	var total := 0.0
	for weight in weights:
		total += weight
	var roll := randf() * total
	var running := 0.0
	for i in range(weights.size()):
		running += weights[i]
		if roll <= running:
			return i
	return weights.size() - 1

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

	var single := _make_def(&"card_single", "单发卡", ItemDefinition.Category.SPELL_CARD, 3, 15)
	single.spell_kind = ItemDefinition.SpellKind.ATTACK
	single.mana_cost = 4
	single.base_damage = 10
	single.projectile_count = 1
	single.projectile_speed = 800.0
	single.cast_interval = 0.18
	single.base_value = 15

	var spread := _make_def(&"card_spread", "散射卡", ItemDefinition.Category.SPELL_CARD, 3, 25)
	spread.spell_kind = ItemDefinition.SpellKind.ATTACK
	spread.mana_cost = 8
	spread.base_damage = 6
	spread.projectile_count = 3
	spread.spread_angle = 15.0
	spread.projectile_speed = 700.0
	spread.cast_interval = 0.20
	spread.base_value = 25

	var homing := _make_def(&"card_homing", "追踪模块", ItemDefinition.Category.SPELL_CARD, 3, 40)
	homing.spell_kind = ItemDefinition.SpellKind.MODULE
	homing.effect_type = ItemDefinition.EffectType.HOMING
	homing.mana_cost = 6
	homing.cast_interval = 0.02
	homing.base_value = 40

	var pierce := _make_def(&"card_pierce", "穿透模块", ItemDefinition.Category.SPELL_CARD, 3, 35)
	pierce.spell_kind = ItemDefinition.SpellKind.MODULE
	pierce.effect_type = ItemDefinition.EffectType.PIERCE
	pierce.effect_value = 3.0
	pierce.mana_cost = 8
	pierce.cast_interval = 0.04
	pierce.base_value = 35

	var boom := _make_def(&"card_boom", "爆炸模块", ItemDefinition.Category.SPELL_CARD, 3, 50)
	boom.spell_kind = ItemDefinition.SpellKind.MODULE
	boom.effect_type = ItemDefinition.EffectType.EXPLOSION
	boom.effect_value = 32.0
	boom.effect_radius = 100.0
	boom.mana_cost = 18
	boom.cast_interval = 0.12
	boom.base_value = 50

	var damage := _make_def(&"module_damage", "增伤模块", ItemDefinition.Category.SPELL_CARD, 3, 30)
	damage.spell_kind = ItemDefinition.SpellKind.MODULE
	damage.effect_type = ItemDefinition.EffectType.DAMAGE
	damage.effect_value = 6.0
	damage.mana_cost = 8
	damage.cast_interval = 0.03
	damage.base_value = 30

	var double_cast := _make_def(&"module_double", "双重施法", ItemDefinition.Category.SPELL_CARD, 3, 40)
	double_cast.spell_kind = ItemDefinition.SpellKind.MODULE
	double_cast.effect_type = ItemDefinition.EffectType.MULTICAST
	double_cast.multicast_count = 2
	double_cast.mana_cost = 2
	double_cast.cast_interval = 0.02
	double_cast.base_value = 40

	var triple_cast := _make_def(&"module_triple", "三重施法", ItemDefinition.Category.SPELL_CARD, 3, 80)
	triple_cast.spell_kind = ItemDefinition.SpellKind.MODULE
	triple_cast.effect_type = ItemDefinition.EffectType.MULTICAST
	triple_cast.multicast_count = 3
	triple_cast.mana_cost = 4
	triple_cast.cast_interval = 0.04
	triple_cast.base_value = 80

	var quad_cast := _make_def(&"module_quad", "四重施法", ItemDefinition.Category.SPELL_CARD, 3, 120)
	quad_cast.spell_kind = ItemDefinition.SpellKind.MODULE
	quad_cast.effect_type = ItemDefinition.EffectType.MULTICAST
	quad_cast.multicast_count = 4
	quad_cast.mana_cost = 8
	quad_cast.cast_interval = 0.06
	quad_cast.base_value = 120

	var inject := _make_def(&"module_inject", "注能", ItemDefinition.Category.SPELL_CARD, 3, 20)
	inject.spell_kind = ItemDefinition.SpellKind.MODULE
	inject.effect_type = ItemDefinition.EffectType.NONE
	inject.mana_restore = 20
	inject.cast_interval = 0.10
	inject.base_value = 20

	var discount := _make_def(&"module_discount", "减耗", ItemDefinition.Category.SPELL_CARD, 3, 20)
	discount.spell_kind = ItemDefinition.SpellKind.MODULE
	discount.effect_type = ItemDefinition.EffectType.NONE
	discount.mana_discount = 2
	discount.cast_interval = 0.0
	discount.base_value = 20

	_cards = [single, spread, homing, pierce, boom, damage, double_cast, triple_cast, quad_cast, inject, discount]

	_gems = [
		_make_def(&"gem_a", "测试宝石 A", ItemDefinition.Category.GEM, 1, 80, 3),
		_make_def(&"gem_b", "测试宝石 B", ItemDefinition.Category.GEM, 1, 120, 5),
		_make_def(&"gem_c", "测试宝石 C", ItemDefinition.Category.GEM, 1, 160, 7),
	]
	_gems[0].rarity = 0
	_gems[1].rarity = 1
	_gems[2].rarity = 2
	_gems[2].cast_mode = ItemDefinition.CastMode.SHUFFLED

	_bodies = [
		_make_def(&"body_a", "测试杖身 A", ItemDefinition.Category.STAFF_BODY, 1, 90, 0, 3),
		_make_def(&"body_b", "测试杖身 B", ItemDefinition.Category.STAFF_BODY, 1, 120, 0, 5),
	]
	_bodies[0].rarity = 0
	_bodies[1].rarity = 1

	_hats = [
		_make_def(&"hat_apprentice", "学徒帽", ItemDefinition.Category.HAT, 1, 80),
		_make_def(&"hat_arcane", "秘法帽", ItemDefinition.Category.HAT, 1, 110),
	]
	_hats[0].rarity = 0
	_hats[1].rarity = 1

	_robes = [
		_make_def(&"robe_apprentice", "学徒袍", ItemDefinition.Category.ROBE, 1, 90),
		_make_def(&"robe_arcane", "秘法袍", ItemDefinition.Category.ROBE, 1, 120),
	]
	_robes[0].rarity = 0
	_robes[1].rarity = 1

	_accessories = [
		_make_def(&"acc_charm", "拾取护符", ItemDefinition.Category.ACCESSORY, 1, 70),
		_make_def(&"acc_swift", "疾行护符", ItemDefinition.Category.ACCESSORY, 1, 85),
	]
	_accessories[0].rarity = 0
	_accessories[1].rarity = 1

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
