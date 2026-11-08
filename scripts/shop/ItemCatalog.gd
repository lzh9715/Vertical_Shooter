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

	var magic_bolt := _make_def(&"projectile_magic_bolt_1", "魔法弹1级", ItemDefinition.Category.SPELL_CARD, 3, 20)
	magic_bolt.sort_order = 100
	magic_bolt.spell_kind = ItemDefinition.SpellKind.ATTACK
	magic_bolt.mana_cost = 5
	magic_bolt.base_damage = 5
	magic_bolt.projectile_count = 1
	magic_bolt.projectile_speed = 300.0
	magic_bolt.cast_interval = 0.20
	magic_bolt.offset_type = ItemDefinition.OffsetType.RANDOM
	magic_bolt.offset_angle = 0.0
	magic_bolt.lifetime = 5.0
	magic_bolt.collision_shape = ItemDefinition.CollisionShape.CIRCLE
	magic_bolt.collision_size = Vector2(5.0, 5.0)
	magic_bolt.visual_scene = load("res://scenes/projectiles/projectile_magic_bolt_1.tscn")
	magic_bolt.behavior_tag = &"normal"
	magic_bolt.base_value = 20

	var magic_bolt_trigger := _make_def(&"projectile_magic_bolt_trigger", "魔法弹1级（触发）", ItemDefinition.Category.SPELL_CARD, 3, 28)
	magic_bolt_trigger.sort_order = 110
	magic_bolt_trigger.spell_kind = ItemDefinition.SpellKind.ATTACK
	magic_bolt_trigger.mana_cost = 5
	magic_bolt_trigger.base_damage = 5
	magic_bolt_trigger.projectile_count = 1
	magic_bolt_trigger.projectile_speed = 300.0
	magic_bolt_trigger.cast_interval = 0.20
	magic_bolt_trigger.offset_type = ItemDefinition.OffsetType.RANDOM
	magic_bolt_trigger.offset_angle = 0.0
	magic_bolt_trigger.lifetime = 5.0
	magic_bolt_trigger.collision_shape = ItemDefinition.CollisionShape.CIRCLE
	magic_bolt_trigger.collision_size = Vector2(5.0, 5.0)
	magic_bolt_trigger.visual_scene = load("res://scenes/projectiles/projectile_magic_bolt_trigger.tscn")
	magic_bolt_trigger.behavior_tag = &"trigger"
	magic_bolt_trigger.trigger_type = ItemDefinition.TriggerType.ON_HIT
	magic_bolt_trigger.trigger_target = &"next_block"
	magic_bolt_trigger.trigger_count = 1
	magic_bolt_trigger.base_value = 28

	var magic_bolt_delayed := _make_def(&"projectile_magic_bolt_delayed", "魔法弹1级（延时）", ItemDefinition.Category.SPELL_CARD, 3, 28)
	magic_bolt_delayed.sort_order = 120
	magic_bolt_delayed.spell_kind = ItemDefinition.SpellKind.ATTACK
	magic_bolt_delayed.mana_cost = 5
	magic_bolt_delayed.base_damage = 5
	magic_bolt_delayed.projectile_count = 1
	magic_bolt_delayed.projectile_speed = 300.0
	magic_bolt_delayed.cast_interval = 0.20
	magic_bolt_delayed.offset_type = ItemDefinition.OffsetType.RANDOM
	magic_bolt_delayed.offset_angle = 0.0
	magic_bolt_delayed.lifetime = 1.0
	magic_bolt_delayed.collision_shape = ItemDefinition.CollisionShape.CIRCLE
	magic_bolt_delayed.collision_size = Vector2(5.0, 5.0)
	magic_bolt_delayed.visual_scene = load("res://scenes/projectiles/projectile_magic_bolt_delayed.tscn")
	magic_bolt_delayed.behavior_tag = &"delayed"
	magic_bolt_delayed.trigger_type = ItemDefinition.TriggerType.ON_HIT_OR_EXPIRE
	magic_bolt_delayed.trigger_target = &"next_block"
	magic_bolt_delayed.trigger_count = 1
	magic_bolt_delayed.base_value = 28

	var arrow := _make_def(&"projectile_arrow", "木箭", ItemDefinition.Category.SPELL_CARD, 3, 24)
	arrow.sort_order = 130
	arrow.spell_kind = ItemDefinition.SpellKind.ATTACK
	arrow.mana_cost = 5
	arrow.base_damage = 10
	arrow.projectile_count = 1
	arrow.projectile_speed = 400.0
	arrow.cast_interval = 0.20
	arrow.offset_type = ItemDefinition.OffsetType.RANDOM
	arrow.offset_angle = 5.0
	arrow.lifetime = 5.0
	arrow.collision_shape = ItemDefinition.CollisionShape.RECTANGLE
	arrow.collision_size = Vector2(10.0, 3.0)
	arrow.crit_chance_bonus = 10.0
	arrow.visual_scene = load("res://scenes/projectiles/projectile_arrow.tscn")
	arrow.base_value = 24

	var stone := _make_def(&"projectile_stone", "石块", ItemDefinition.Category.SPELL_CARD, 3, 8)
	stone.sort_order = 140
	stone.spell_kind = ItemDefinition.SpellKind.ATTACK
	stone.mana_cost = 1
	stone.base_damage = 10
	stone.projectile_count = 1
	stone.projectile_speed = 150.0
	stone.cast_interval = 0.20
	stone.offset_type = ItemDefinition.OffsetType.RANDOM
	stone.offset_angle = 5.0
	stone.lifetime = 5.0
	stone.collision_shape = ItemDefinition.CollisionShape.CIRCLE
	stone.collision_size = Vector2(5.0, 5.0)
	stone.crit_chance_bonus = 5.0
	stone.visual_scene = load("res://scenes/projectiles/projectile_stone.tscn")
	stone.base_value = 8

	var dirt := _make_def(&"projectile_dirt", "土块", ItemDefinition.Category.SPELL_CARD, 3, 8)
	dirt.sort_order = 150
	dirt.spell_kind = ItemDefinition.SpellKind.ATTACK
	dirt.mana_cost = 1
	dirt.base_damage = 5
	dirt.projectile_count = 1
	dirt.projectile_speed = 200.0
	dirt.cast_interval = 0.20
	dirt.offset_type = ItemDefinition.OffsetType.RANDOM
	dirt.offset_angle = 5.0
	dirt.lifetime = 5.0
	dirt.collision_shape = ItemDefinition.CollisionShape.CIRCLE
	dirt.collision_size = Vector2(5.0, 5.0)
	dirt.crit_chance_bonus = 5.0
	dirt.visual_scene = load("res://scenes/projectiles/projectile_dirt.tscn")
	dirt.base_value = 8

	var fireball := _make_def(&"projectile_fireball", "单发火球", ItemDefinition.Category.SPELL_CARD, 3, 36)
	fireball.sort_order = 160
	fireball.spell_kind = ItemDefinition.SpellKind.ATTACK
	fireball.mana_cost = 10
	fireball.base_damage = 10
	fireball.projectile_count = 1
	fireball.projectile_speed = 500.0
	fireball.cast_interval = 0.30
	fireball.offset_type = ItemDefinition.OffsetType.RANDOM
	fireball.offset_angle = 0.0
	fireball.lifetime = 5.0
	fireball.collision_shape = ItemDefinition.CollisionShape.CIRCLE
	fireball.collision_size = Vector2(5.0, 5.0)
	fireball.crit_chance_bonus = 10.0
	fireball.visual_scene = load("res://scenes/projectiles/projectile_fireball.tscn")
	fireball.base_value = 36

	var fireball_double := _make_def(&"projectile_fireball_double", "双发散射火球", ItemDefinition.Category.SPELL_CARD, 3, 60)
	fireball_double.sort_order = 170
	fireball_double.spell_kind = ItemDefinition.SpellKind.ATTACK
	fireball_double.mana_cost = 20
	fireball_double.base_damage = 10
	fireball_double.projectile_count = 2
	fireball_double.projectile_speed = 500.0
	fireball_double.cast_interval = 0.30
	fireball_double.offset_type = ItemDefinition.OffsetType.MULTI
	fireball_double.spread_angle = 10.0
	fireball_double.lifetime = 5.0
	fireball_double.collision_shape = ItemDefinition.CollisionShape.CIRCLE
	fireball_double.collision_size = Vector2(5.0, 5.0)
	fireball_double.crit_chance_bonus = 10.0
	fireball_double.visual_scene = load("res://scenes/projectiles/projectile_fireball_double.tscn")
	fireball_double.base_value = 60

	var scatter_double := _make_def(&"projectile_scatter_double", "二重散射魔法弹", ItemDefinition.Category.SPELL_CARD, 3, 25)
	scatter_double.sort_order = 180
	scatter_double.spell_kind = ItemDefinition.SpellKind.ATTACK
	scatter_double.mana_cost = 10
	scatter_double.base_damage = 5
	scatter_double.projectile_count = 2
	scatter_double.spread_angle = 5.0
	scatter_double.projectile_speed = 300.0
	scatter_double.cast_interval = 0.20
	scatter_double.offset_type = ItemDefinition.OffsetType.MULTI
	scatter_double.lifetime = 5.0
	scatter_double.visual_scene = load("res://scenes/projectiles/projectile_scatter_double.tscn")
	scatter_double.base_value = 25

	var scatter_triple := _make_def(&"projectile_scatter_triple", "三重散射魔法弹", ItemDefinition.Category.SPELL_CARD, 3, 35)
	scatter_triple.sort_order = 190
	scatter_triple.spell_kind = ItemDefinition.SpellKind.ATTACK
	scatter_triple.mana_cost = 15
	scatter_triple.base_damage = 5
	scatter_triple.projectile_count = 3
	scatter_triple.spread_angle = 5.0
	scatter_triple.projectile_speed = 300.0
	scatter_triple.cast_interval = 0.30
	scatter_triple.offset_type = ItemDefinition.OffsetType.MULTI
	scatter_triple.lifetime = 5.0
	scatter_triple.visual_scene = load("res://scenes/projectiles/projectile_scatter_triple.tscn")
	scatter_triple.base_value = 35

	var homing := _make_def(&"module_homing", "追踪模块", ItemDefinition.Category.SPELL_CARD, 3, 40)
	homing.spell_kind = ItemDefinition.SpellKind.MODULE
	homing.effect_type = ItemDefinition.EffectType.HOMING
	homing.mana_cost = 10
	homing.cast_interval = 0.10
	homing.base_value = 40

	var pierce_1 := _make_def(&"module_pierce_1", "穿透模块1级", ItemDefinition.Category.SPELL_CARD, 3, 20)
	pierce_1.spell_kind = ItemDefinition.SpellKind.MODULE
	pierce_1.effect_type = ItemDefinition.EffectType.PIERCE
	pierce_1.effect_value = 1.0
	pierce_1.mana_cost = 5
	pierce_1.cast_interval = 0.0
	pierce_1.compatibility_group = &"PIERCE_MODE"
	pierce_1.damage_falloff = 0.7
	pierce_1.damage_floor = 0.3
	pierce_1.base_value = 20

	var pierce_2 := _make_def(&"module_pierce_2", "穿透模块2级", ItemDefinition.Category.SPELL_CARD, 3, 25)
	pierce_2.spell_kind = ItemDefinition.SpellKind.MODULE
	pierce_2.effect_type = ItemDefinition.EffectType.PIERCE
	pierce_2.effect_value = 2.0
	pierce_2.mana_cost = 5
	pierce_2.cast_interval = 0.0
	pierce_2.compatibility_group = &"PIERCE_MODE"
	pierce_2.damage_falloff = 0.7
	pierce_2.damage_floor = 0.3
	pierce_2.base_value = 25

	var pierce_3 := _make_def(&"module_pierce_3", "穿透模块3级", ItemDefinition.Category.SPELL_CARD, 3, 30)
	pierce_3.spell_kind = ItemDefinition.SpellKind.MODULE
	pierce_3.effect_type = ItemDefinition.EffectType.PIERCE
	pierce_3.effect_value = 3.0
	pierce_3.mana_cost = 5
	pierce_3.cast_interval = 0.0
	pierce_3.compatibility_group = &"PIERCE_MODE"
	pierce_3.damage_falloff = 0.7
	pierce_3.damage_floor = 0.3
	pierce_3.base_value = 30

	var boom := _make_def(&"module_explosion", "爆炸模块", ItemDefinition.Category.SPELL_CARD, 3, 50)
	boom.spell_kind = ItemDefinition.SpellKind.MODULE
	boom.effect_type = ItemDefinition.EffectType.EXPLOSION
	boom.effect_radius = 100.0
	boom.mana_cost = 15
	boom.cast_interval = 0.20
	boom.base_value = 50

	var damage := _make_def(&"module_damage", "增伤模块", ItemDefinition.Category.SPELL_CARD, 3, 30)
	damage.spell_kind = ItemDefinition.SpellKind.MODULE
	damage.effect_type = ItemDefinition.EffectType.DAMAGE
	damage.effect_value = 5.0
	damage.mana_cost = 5
	damage.cast_interval = 0.10
	damage.base_value = 30

	var double_cast := _make_def(&"module_multicast_double", "双重施法", ItemDefinition.Category.SPELL_CARD, 3, 40)
	double_cast.spell_kind = ItemDefinition.SpellKind.MODULE
	double_cast.effect_type = ItemDefinition.EffectType.MULTICAST
	double_cast.multicast_count = 2
	double_cast.mana_cost = 10
	double_cast.cast_interval = 0.10
	double_cast.base_value = 40

	var triple_cast := _make_def(&"module_multicast_triple", "三重施法", ItemDefinition.Category.SPELL_CARD, 3, 80)
	triple_cast.spell_kind = ItemDefinition.SpellKind.MODULE
	triple_cast.effect_type = ItemDefinition.EffectType.MULTICAST
	triple_cast.multicast_count = 3
	triple_cast.mana_cost = 20
	triple_cast.cast_interval = 0.20
	triple_cast.base_value = 80

	var quad_cast := _make_def(&"module_multicast_quad", "四重施法", ItemDefinition.Category.SPELL_CARD, 3, 120)
	quad_cast.spell_kind = ItemDefinition.SpellKind.MODULE
	quad_cast.effect_type = ItemDefinition.EffectType.MULTICAST
	quad_cast.multicast_count = 4
	quad_cast.mana_cost = 30
	quad_cast.cast_interval = 0.30
	quad_cast.base_value = 120

	var inject := _make_def(&"module_inject", "注能", ItemDefinition.Category.SPELL_CARD, 3, 20)
	inject.spell_kind = ItemDefinition.SpellKind.MODULE
	inject.effect_type = ItemDefinition.EffectType.NONE
	inject.mana_restore = 20
	inject.cast_interval = 0.0
	inject.base_value = 20

	var discount := _make_def(&"module_discount", "减耗", ItemDefinition.Category.SPELL_CARD, 3, 20)
	discount.spell_kind = ItemDefinition.SpellKind.MODULE
	discount.effect_type = ItemDefinition.EffectType.NONE
	discount.mana_discount = 20
	discount.cast_interval = 0.0
	discount.base_value = 20

	var bounce := _make_def(&"module_bounce", "弹射模块", ItemDefinition.Category.SPELL_CARD, 3, 30)
	bounce.spell_kind = ItemDefinition.SpellKind.MODULE
	bounce.effect_type = ItemDefinition.EffectType.BOUNCE
	bounce.effect_value = 1.0
	bounce.mana_cost = 5
	bounce.cast_interval = 0.0
	bounce.damage_falloff = 0.7
	bounce.damage_floor = 0.3
	bounce.compatibility_group = &"PIERCE_MODE"
	bounce.base_value = 30

	var refract := _make_def(&"module_refract", "折射模块", ItemDefinition.Category.SPELL_CARD, 3, 30)
	refract.spell_kind = ItemDefinition.SpellKind.MODULE
	refract.effect_type = ItemDefinition.EffectType.REFRACT
	refract.effect_value = 1.0
	refract.mana_cost = 5
	refract.cast_interval = 0.0
	refract.damage_falloff = 0.7
	refract.damage_floor = 0.3
	refract.compatibility_group = &"PIERCE_MODE"
	refract.target_rule = &"unvisited"
	refract.base_value = 30

	var return_module := _make_def(&"module_return", "回旋模块", ItemDefinition.Category.SPELL_CARD, 1, 90)
	return_module.spell_kind = ItemDefinition.SpellKind.MODULE
	return_module.effect_type = ItemDefinition.EffectType.RETURN
	return_module.effect_value = 1.0
	return_module.mana_cost = 50
	return_module.cast_interval = 0.0
	return_module.is_copy_module = true
	return_module.inherit_to_copy = false
	return_module.base_value = 90

	var accelerate := _make_def(&"module_accelerate", "加速模块", ItemDefinition.Category.SPELL_CARD, 3, 20)
	accelerate.spell_kind = ItemDefinition.SpellKind.MODULE
	accelerate.effect_type = ItemDefinition.EffectType.ACCELERATE
	accelerate.effect_value = 50.0
	accelerate.mana_cost = 10
	accelerate.cast_interval = 0.0
	accelerate.base_value = 20

	var decelerate := _make_def(&"module_decelerate", "减速模块", ItemDefinition.Category.SPELL_CARD, 3, 20)
	decelerate.spell_kind = ItemDefinition.SpellKind.MODULE
	decelerate.effect_type = ItemDefinition.EffectType.DECELERATE
	decelerate.effect_value = 50.0
	decelerate.mana_cost = 10
	decelerate.cast_interval = 0.0
	decelerate.base_value = 20

	var lifetime_up := _make_def(&"module_lifetime_up", "持久模块", ItemDefinition.Category.SPELL_CARD, 3, 20)
	lifetime_up.spell_kind = ItemDefinition.SpellKind.MODULE
	lifetime_up.effect_type = ItemDefinition.EffectType.LIFETIME
	lifetime_up.effect_value = 2.0
	lifetime_up.mana_cost = 10
	lifetime_up.cast_interval = 0.0
	lifetime_up.base_value = 20

	var lifetime_down := _make_def(&"module_lifetime_down", "消逝模块", ItemDefinition.Category.SPELL_CARD, 3, 20)
	lifetime_down.spell_kind = ItemDefinition.SpellKind.MODULE
	lifetime_down.effect_type = ItemDefinition.EffectType.LIFETIME
	lifetime_down.effect_value = -2.0
	lifetime_down.mana_cost = 10
	lifetime_down.cast_interval = 0.0
	lifetime_down.base_value = 20

	_cards = [single]
	_cards.append_array(_load_projectile_resources())
	_cards.append_array(_load_module_resources())

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

static func _load_projectile_resources() -> Array:
	var result: Array = []
	var dir := DirAccess.open("res://data/projectiles")
	if dir == null:
		return result
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var resource = load("res://data/projectiles/%s" % file)
		if resource is ItemDefinition and resource.is_attack():
			result.append(resource)
	result.sort_custom(func(a, b): return a.sort_order < b.sort_order)
	return result

static func _load_module_resources() -> Array:
	var result: Array = []
	var dir := DirAccess.open("res://data/spell_modules")
	if dir == null:
		return result
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var resource = load("res://data/spell_modules/%s" % file)
		if resource is ItemDefinition and resource.is_module():
			result.append(resource)
	result.sort_custom(func(a, b): return a.sort_order < b.sort_order)
	return result

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
