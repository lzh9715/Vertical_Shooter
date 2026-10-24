extends Node

func _ready() -> void:
	var magic := _attack(&"magic", 4, 10)
	var heavy := _attack(&"heavy", 12, 22)
	var inject := _module(&"inject", 0, 20, 0)
	var discount2 := _module(&"discount2", 0, 0, 2)
	var discount4 := _module(&"discount4", 0, 0, 4)
	var discount20 := _module(&"discount20", 0, 0, 20)

	_check("注能→魔弹", [inject, magic], 0.0, 100.0, true, 16.0)
	_check("魔弹→注能", [magic, inject], 0.0, 100.0, false, 0.0)
	print("魔弹→注能 最低启动=", CastSimulator.minimum_start([magic, inject], 100.0))

	_check("减耗2→魔弹", [discount2, magic], 2.0, 100.0, true, 0.0)
	_check("减耗2→魔弹（只有1蓝）", [discount2, magic], 1.0, 100.0, false, 0.0)
	_check("减耗4→魔弹2", [discount4, magic], 0.0, 100.0, true, 0.0)

	_check("注能+魔弹120（上限100）", [inject, _attack(&"big", 120, 10)], 100.0, 100.0, false, 0.0)
	_check("减耗20+魔弹120（上限100）", [discount20, _attack(&"big2", 120, 10)], 100.0, 100.0, true, 0.0)

	var first := _attack(&"first60", 60, 10)
	var second := _attack(&"second60", 60, 10)
	_check("60→注能→60", [first, inject, second], 100.0, 100.0, true, 0.0)

	var blocks := CastSimulator.build_blocks([inject, discount2, magic, heavy])
	print("分块数量=", blocks.size(), " 块1卡数=", blocks[0].size(), " 块2卡数=", blocks[1].size())
	print("块1间隔=", CastSimulator.block_interval(blocks[0]))

	var double_card := _multi(&"double", 2)
	var triple_card := _multi(&"triple", 3)

	var double_blocks := CastSimulator.build_blocks([
		double_card, _attack(&"a60", 60, 10),
		_attack(&"b60", 60, 10),
	])
	_print_action("双重 60+60", CastSimulator.simulate_action(double_blocks, 0, 100.0, 100.0, 100.0, 0.0, true))

	var triple_blocks := CastSimulator.build_blocks([
		triple_card, _attack(&"t1", 10, 10),
		_attack(&"t2", 10, 10),
		_attack(&"t3", 10, 10),
	])
	_print_action("三重 3×10", CastSimulator.simulate_action(triple_blocks, 0, 100.0, 100.0, 100.0, 0.0, true))

	var nested_blocks := CastSimulator.build_blocks([
		double_card, _attack(&"n1", 10, 10),
		double_card, _attack(&"n2", 10, 10),
		_attack(&"n3", 10, 10),
	])
	_print_action("双重链式", CastSimulator.simulate_action(nested_blocks, 0, 100.0, 100.0, 100.0, 0.0, true))

	var low_hp := CastSimulator.simulate_action(double_blocks, 0, 100.0, 100.0, 3.0, 0.0, true)
	print(low_hp.status, " 低血量透支：hp_cost=", low_hp.hp_cost, " reason=", low_hp.get("reason", ""))

	var wait_blocks := CastSimulator.build_blocks([_attack(&"wait60", 60, 10)])
	_print_action("当前40/上限100，60消耗", CastSimulator.simulate_action(wait_blocks, 0, 40.0, 100.0, 100.0, 0.0, true))

	get_tree().quit()

func _print_action(label: String, result: Dictionary) -> void:
	print(
		label,
		" → ", result.status,
		" hp_cost=", result.get("hp_cost", 0.0),
		" chain_extra=", result.get("chain_extra", 0),
		" interval=", result.get("interval", 0.0),
		" required=", result.get("required_mana", -1.0)
	)

func _check(label: String, cards: Array, start: float, max_mana: float, expected_ok: bool, expected_mana: float) -> void:
	var result := CastSimulator.simulate_block(cards, start, max_mana)
	var ok: bool = result.ok
	var mana: float = result.mana
	var status := "✅" if ok == expected_ok and (not expected_ok or is_equal_approx(mana, expected_mana)) else "❌"
	print(status, " ", label, " ok=", ok, " mana=", mana, " deficit=", result.deficit)

func _attack(id: StringName, cost: int, damage: int) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.display_name = str(id)
	def.category = ItemDefinition.Category.SPELL_CARD
	def.spell_kind = ItemDefinition.SpellKind.ATTACK
	def.mana_cost = cost
	def.base_damage = damage
	return def

func _module(id: StringName, cost: int, restore: int, discount: int) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.display_name = str(id)
	def.category = ItemDefinition.Category.SPELL_CARD
	def.spell_kind = ItemDefinition.SpellKind.MODULE
	def.mana_cost = cost
	def.mana_restore = restore
	def.mana_discount = discount
	return def

func _multi(id: StringName, count: int) -> ItemDefinition:
	var def := _module(id, 2, 0, 0)
	def.multicast_count = count
	return def
