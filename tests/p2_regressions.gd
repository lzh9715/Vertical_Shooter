extends SceneTree
## P2 回归：宝石拖拽事务、事件生命修正、连续透支账本。

var _flow
var _bus
var _backpack_scene: PackedScene
var _player_scene: PackedScene
var _save_script
var _event_outcome_script
var _event_option_script
var _passed := 0
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_flow = root.get_node("GameFlow")
	_bus = root.get_node("EventBus")
	_backpack_scene = load("res://scenes/backpack/BackpackView.tscn")
	_player_scene = load("res://scenes/player/player.tscn")
	_save_script = load("res://scripts/save/SaveData.gd")
	_event_outcome_script = load("res://data/event/EventOutcome.gd")
	_event_option_script = load("res://data/event/EventOption.gd")
	var watchdog := Timer.new()
	watchdog.one_shot = true
	watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(watchdog)
	watchdog.timeout.connect(func():
		push_error("P2 regression suite timed out")
		quit(1)
	)
	watchdog.start(20.0)
	for test_name in [
		"test_gem_cancel",
		"test_gem_close_and_rejected_drop",
		"test_gem_remove_to_cell",
		"test_gem_remove_to_trash_with_full_bag",
		"test_gem_replace_with_full_bag",
		"test_body_drag_preserves_gem_program",
		"test_event_hp_survives_player_and_loadout",
		"test_event_hp_cost_and_floor",
		"test_event_hp_save_restore_and_reset",
		"test_overdraft_charges_new_debt_only",
		"test_overdraft_zero_cost_and_restore",
		"test_overdraft_survival_boundary",
		"test_overdraft_normal_wait_and_disabled",
		"test_overdraft_player_commit_once",
	]:
		await _reset_scene()
		var before := _failed
		if await call(test_name) != true:
			_expect(false, "%s did not finish (runtime error?)" % test_name)
		print("%s %s" % ["PASS" if _failed == before else "FAIL", test_name])
	await _reset_scene()
	print("P2 regressions: %d assertions passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error(message)

func _reset_scene() -> void:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	_flow.start_run(load("res://data/Level_01.tres"), 12345)
	_flow.inventory = GridInventory.new()
	_flow.equipment = PlayerEquipment.new()

func _wand() -> WandInstance:
	var wand := WandInstance.create(
		ItemInstance.create(ItemCatalog.bodies()[0]),
		ItemInstance.create(ItemCatalog.gems()[1])
	)
	wand.cards[0] = ItemCatalog.find_card(&"card_single")
	wand.cards[2] = ItemCatalog.find_card(&"card_spread")
	wand.cards[4] = ItemCatalog.find_card(&"card_single")
	wand.cast_index = 2
	_flow.get_equipment().equip_wand(0, wand)
	return wand

func _view():
	var view = _backpack_scene.instantiate()
	current_scene.add_child(view)
	view.open()
	return view

func _player():
	var player = _player_scene.instantiate()
	current_scene.add_child(player)
	player.set_physics_process(false)
	return player

func _bag_state() -> Array:
	var inventory: GridInventory = _flow.get_inventory()
	var state: Array = []
	for items in [inventory.cells, inventory.overflow]:
		var slots: Array = []
		for item in items:
			slots.append([item, item.count] if item is ItemStack else item)
		state.append(slots)
	state.append(inventory.trash)
	return state

func _fill_bag() -> void:
	var inventory: GridInventory = _flow.get_inventory()
	for i in range(inventory.capacity()):
		inventory.cells[i] = ItemInstance.create(ItemCatalog.bodies()[0])

func _card_total() -> int:
	var total := 0
	var inventory: GridInventory = _flow.get_inventory()
	for items in [inventory.cells, inventory.overflow]:
		for item in items:
			if item is ItemStack:
				total += item.count
	return total

func test_gem_cancel() -> bool:
	var wand := _wand()
	_fill_bag()
	_flow.get_inventory().overflow.append(ItemStack.new(ItemCatalog.find_card(&"card_single"), 2))
	var view = _view()
	var gem := wand.gem
	var cards := wand.cards.duplicate()
	var bag := _bag_state()
	view._start_drag(view.gem_slot, false)
	_expect(_bag_state() == bag, "starting a gem drag must not distribute cards into the bag")
	view._restore_drag()
	_expect(wand.gem == gem and wand.cards == cards, "cancel must restore exact gem, empty slots and card order")
	_expect(wand.cast_index == 2, "cancel must preserve cast position")
	_expect(_bag_state() == bag, "cancel with a full bag must preserve stacks and overflow exactly")
	return true

func test_gem_close_and_rejected_drop() -> bool:
	var wand := _wand()
	var view = _view()
	var cards := wand.cards.duplicate()
	var bag := _bag_state()
	view._start_drag(view.gem_slot, false)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	view._unhandled_input(cancel)
	_expect(not view.visible and wand.cards == cards, "Esc must close and restore the complete program")
	view.open()
	view._start_drag(view.gem_slot, false)
	view._drop_to_equipment(2)
	_expect(wand.cards == cards and _bag_state() == bag, "invalid equipment drop must leave the loadout and bag unchanged")
	view._start_drag(view.gem_slot, false)
	view._drop_to_assembly(1)
	_expect(wand.cards == cards and wand.cast_index == 2, "dropping back on the source gem slot must be a no-op")
	return true

func test_gem_remove_to_cell() -> bool:
	var wand := _wand()
	var gem := wand.gem
	var inventory: GridInventory = _flow.get_inventory()
	inventory.cells[1] = ItemStack.new(ItemCatalog.find_card(&"card_single"), 2)
	var view = _view()
	view._start_drag(view.gem_slot, false)
	view._drop_to_cell(0)
	_expect(inventory.cells[0] == gem, "accepted drop must place the gem in its target cell")
	_expect(wand.gem == null and wand.cards.is_empty(), "accepted removal must detach the gem and its program")
	_expect(_card_total() == 5, "returned cards must merge without loss or duplication")
	_expect(wand.cast_index == 0, "removing the program must reset cast position")
	return true

func test_gem_remove_to_trash_with_full_bag() -> bool:
	var wand := _wand()
	var gem := wand.gem
	_fill_bag()
	var view = _view()
	view._start_drag(view.gem_slot, false)
	view._drop_to_trash()
	var inventory: GridInventory = _flow.get_inventory()
	_expect(inventory.trash == gem and wand.gem == null, "discard must transfer gem ownership to trash")
	_expect(inventory.is_full() and _card_total() == 3, "full bag must retain every returned card in overflow")
	_expect(wand.cards.is_empty(), "successful discard must clear the old program")
	return true

func test_gem_replace_with_full_bag() -> bool:
	var wand := _wand()
	var old_gem := wand.gem
	_fill_bag()
	var inventory: GridInventory = _flow.get_inventory()
	var replacement := ItemInstance.create(ItemCatalog.gems()[0])
	inventory.cells[0] = replacement
	var view = _view()
	view._start_drag(view._grid_slots[0], false)
	view._drop_to_assembly(1)
	_expect(wand.gem == replacement, "replacement gem must be installed")
	_expect(inventory.cells[0] == old_gem, "old gem must have priority for the vacated source cell")
	_expect(_card_total() == 3, "replacement must return all non-null cards without errors or loss")
	_expect(wand.cards.size() == replacement.definition.gem_slots and wand.card_count() == 0, "new gem must expose exactly its empty slots")
	return true

func test_body_drag_preserves_gem_program() -> bool:
	var wand := _wand()
	var body := wand.body
	var gem := wand.gem
	var cards := wand.cards.duplicate()
	var view = _view()
	view._start_drag(view.body_slot, false)
	view._restore_drag()
	_expect(wand.body == body and wand.gem == gem and wand.cards == cards, "body drag cancellation must preserve the entire wand")
	view._start_drag(view.body_slot, false)
	view._drop_to_cell(0)
	_expect(_flow.get_inventory().cells[0] == body and wand.body == null, "body removal must still commit to its target cell")
	_expect(wand.gem == gem and wand.cards == cards and wand.cast_index == 2, "body removal must not unpack the gem program")
	return true

func test_event_hp_survives_player_and_loadout() -> bool:
	var reward = _event_outcome_script.new()
	reward.max_hp = 10
	reward.apply()
	var player = _player()
	_expect(player.max_hp == 110.0 and _flow.max_hp == 110.0, "event +10 maximum health must survive entering battle")
	var affix := ItemAffix.new()
	affix.stat = &"max_hp"
	affix.amount = 20.0
	_flow.get_equipment().robe = ItemInstance.create(ItemCatalog.robes()[0], [affix])
	_bus.loadout_changed.emit()
	_expect(player.max_hp == 130.0, "equipment and event maximum health must add without overwriting each other")
	_bus.loadout_changed.emit()
	_expect(player.max_hp == 130.0, "rebuilding stats repeatedly must not stack the event bonus twice")
	_flow.get_equipment().robe = null
	_bus.loadout_changed.emit()
	_expect(player.max_hp == 110.0, "removing equipment must preserve the event bonus")
	_expect(player.current_hp == 100.0, "raising maximum health must not grant free healing")
	return true

func test_event_hp_cost_and_floor() -> bool:
	var cost = _event_option_script.new()
	cost.cost_max_hp = 25
	cost.apply_costs()
	var player = _player()
	_expect(player.max_hp == 75.0 and player.current_hp == 75.0, "event maximum health cost must persist and clamp current health")
	_flow.change_max_hp(-1000)
	player._rebuild_stats()
	_expect(player.max_hp == 1.0 and player.current_hp == 1.0, "maximum health must have a persistent floor of one")
	_flow.change_max_hp(1)
	player._rebuild_stats()
	_expect(player.max_hp == 2.0, "clamping must not leave hidden negative maximum-health debt")
	var affix := ItemAffix.new()
	affix.stat = &"max_hp"
	affix.amount = 20.0
	_flow.get_equipment().robe = ItemInstance.create(ItemCatalog.robes()[0], [affix])
	_bus.loadout_changed.emit()
	_flow.change_max_hp(-1000)
	_flow.get_equipment().robe = null
	_bus.loadout_changed.emit()
	_flow.change_max_hp(1)
	_expect(player.max_hp == 2.0, "a new event must apply to the visible health floor even after removing equipment")
	return true

func test_event_hp_save_restore_and_reset() -> bool:
	_flow.change_max_hp(15)
	var saved: Dictionary = _save_script.capture()
	_flow.start_run(load("res://data/Level_01.tres"), 12345)
	_expect(_save_script.restore(saved), "save restore must accept a captured state")
	var player = _player()
	_expect(player.max_hp == 115.0, "save roundtrip must preserve the event maximum-health modifier")
	player.free()
	# 旧的 version 1 数据没有独立修正字段，仍需恢复当时的最终上限。
	saved.player.erase("max_hp_bonus")
	_flow.start_run(load("res://data/Level_01.tres"), 12345)
	_expect(_save_script.restore(saved), "legacy save without the modifier field must still load")
	player = _player()
	_expect(player.max_hp == 115.0, "legacy save must infer its event modifier from restored equipment")
	player.free()
	_flow.start_run(load("res://data/Level_01.tres"), 12345)
	_flow.equipment = PlayerEquipment.new()
	player = _player()
	_expect(player.max_hp == 100.0, "starting another run must clear event maximum-health modifiers")
	return true

func _attack(cost: int) -> ItemDefinition:
	var card := ItemDefinition.new()
	card.category = ItemDefinition.Category.SPELL_CARD
	card.spell_kind = ItemDefinition.SpellKind.ATTACK
	card.mana_cost = cost
	return card

func _module(restore: int = 0) -> ItemDefinition:
	var card := ItemDefinition.new()
	card.category = ItemDefinition.Category.SPELL_CARD
	card.spell_kind = ItemDefinition.SpellKind.MODULE
	card.mana_restore = restore
	return card

func _blocks(cards: Array) -> Array:
	var multi := _module()
	multi.multicast_count = 16
	var program: Array = [multi]
	program.append_array(cards)
	return CastSimulator.build_blocks(program)

func test_overdraft_charges_new_debt_only() -> bool:
	var result := CastSimulator.simulate_action(_blocks([_attack(60), _attack(60), _attack(10)]), 0, 100, 100, 100)
	_expect(result.status == "overdraft", "130-mana action must be available with health overdraft")
	_expect(is_equal_approx(result.hp_cost, 7.5), "30 newly borrowed mana must cost 7.5 health, not 12.5")
	_expect(result.mana == -30.0, "health payment must preserve the existing mana-debt model")
	return true

func test_overdraft_zero_cost_and_restore() -> bool:
	var zero := CastSimulator.simulate_action(_blocks([_attack(120), _module(), _attack(0)]), 0, 100, 100, 100)
	_expect(is_equal_approx(zero.hp_cost, 5.0), "zero-cost cards must not charge existing mana debt again")
	var restored := CastSimulator.simulate_action(_blocks([_attack(120), _module(30), _attack(40)]), 0, 100, 100, 100)
	_expect(is_equal_approx(restored.hp_cost, 12.5), "restoration must repay debt before financing the next attack")
	_expect(restored.mana == -30.0, "restoration must follow the same mana ledger")
	return true

func test_overdraft_survival_boundary() -> bool:
	var blocks := _blocks([_attack(60), _attack(60), _attack(10)])
	var survives := CastSimulator.simulate_action(blocks, 0, 100, 100, 8)
	_expect(survives.status == "overdraft" and is_equal_approx(survives.hp_cost, 7.5), "8 health must be sufficient for a 7.5-health overdraft")
	var lethal := CastSimulator.simulate_action(blocks, 0, 100, 100, 7.5)
	_expect(lethal.status == "degrade", "overdraft must never consume the last health point")
	return true

func test_overdraft_normal_wait_and_disabled() -> bool:
	var normal := CastSimulator.simulate_action(_blocks([_attack(60)]), 0, 100, 100, 100)
	_expect(normal.status == "ok" and normal.hp_cost == 0.0 and normal.mana == 40.0, "normal casting must remain health-free")
	var waiting := CastSimulator.simulate_action(_blocks([_attack(60)]), 0, 40, 100, 100)
	_expect(waiting.status == "wait" and waiting.hp_cost == 0.0, "an affordable-at-full action must wait instead of borrowing health")
	var disabled := CastSimulator.simulate_action(_blocks([_attack(120)]), 0, 100, 100, 100, 0, false)
	_expect(disabled.status == "degrade", "disabling overdraft must still degrade unaffordable actions")
	return true

func test_overdraft_player_commit_once() -> bool:
	var wand := _wand()
	var multi := _module()
	multi.multicast_count = 3
	wand.cards.assign([multi, _attack(60), _attack(60), _attack(10)])
	_flow.hp = 8.0
	var player = _player()
	player._tick_cast(0.0)
	_expect(is_equal_approx(player.current_hp, 0.5), "actual player must pay the corrected health cost")
	_expect(_flow.mana == -30.0, "actual player must commit the corrected plan")
	player._tick_cast(0.0)
	_expect(is_equal_approx(player.current_hp, 0.5), "retry during cooldown must not pay health twice")
	return true
