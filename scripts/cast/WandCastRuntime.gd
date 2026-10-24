extends RefCounted
class_name WandCastRuntime

## 一把法杖的战斗运行状态：牌组顺序、当前块、装填与冷却。
## 不直接操作 Player，只返回计划，由 Player 提交。

const RELOAD_TIME := 0.45
const SKIP_COOLDOWN := 0.08

var wand: WandInstance
var blocks: Array = []
var block_index := 0
var cooldown := 0.0
var reload_left := 0.0
var _overdraft_lock := false

func _init(p_wand: WandInstance) -> void:
	wand = p_wand
	rebuild()

func rebuild() -> void:
	if wand == null:
		blocks = []
		block_index = 0
		return

	var cards: Array = wand.cards.duplicate()
	if is_shuffled():
		cards.shuffle()

	blocks = CastSimulator.build_blocks(cards)
	block_index = 0
	reload_left = 0.0

func is_shuffled() -> bool:
	return (
		wand != null
		and wand.gem != null
		and wand.gem.definition != null
		and wand.gem.definition.cast_mode == ItemDefinition.CastMode.SHUFFLED
	)

func tick(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)

	if block_index >= blocks.size():
		if reload_left > 0.0:
			reload_left = maxf(reload_left - delta, 0.0)
			if reload_left <= 0.0:
				rebuild()
		else:
			rebuild()

func is_busy() -> bool:
	return cooldown > 0.0 or block_index >= blocks.size()

func attempt(player_hp: float) -> Dictionary:
	if wand == null or blocks.is_empty():
		return {"status": "wait", "reason": "没有法术卡"}
	if block_index >= blocks.size():
		return {"status": "wait", "reason": "装填中"}
	if cooldown > 0.0:
		return {"status": "wait", "reason": "冷却中"}

	if _overdraft_lock:
		if not _can_unlock_overdraft():
			return {"status": "wait", "reason": "透支后等待回蓝"}
		_overdraft_lock = false

	var staff_interval: float = 0.0
	if wand.body != null and wand.body.definition != null:
		staff_interval = wand.body.definition.cast_interval

	var result := CastSimulator.simulate_action(
		blocks,
		block_index,
		GameFlow.mana,
		GameFlow.max_mana,
		player_hp,
		staff_interval,
		not is_shuffled()
	)

	if result.status == "wait":
		return result

	if result.status == "overdraft":
		# 只有满蓝也放不出来时才允许透支；当前蓝不够时先等满
		if GameFlow.mana < GameFlow.max_mana:
			return {"status": "wait", "reason": "等待满蓝后透支"}
		return _make_plan(result, true)

	if result.status == "ok":
		return _make_plan(result, false)

	# degrade：先拆成当前普通块，再退到最小攻击块
	return _degrade_plan(staff_interval)

func _make_plan(result: Dictionary, is_overdraft: bool) -> Dictionary:
	var indices: Array = result.indices
	var cards: Array = []
	var action_blocks: Array = []
	for block_index_value in indices:
		var block: Array = blocks[block_index_value]
		action_blocks.append(block.duplicate())
		for card in block:
			cards.append(card)

	var advance: int = 0
	for index in indices:
		advance = maxi(advance, int(index) + 1)

	var interval: float = result.interval
	var plan := {
		"status": "overdraft" if is_overdraft else "ok",
		"cards": cards,
		"action_blocks": action_blocks,
		"mana_after": result.mana,
		"hp_cost": result.hp_cost,
		"interval": interval,
		"advance": advance,
		"chain_extra": result.chain_extra,
		"reason": "",
	}
	return plan

func _degrade_plan(staff_interval: float) -> Dictionary:
	var block: Array = blocks[block_index]

	# 第二层：当前普通块，不进行多重联动
	var normal := CastSimulator.simulate_block(block, GameFlow.mana, GameFlow.max_mana)
	var advance := block_index + 1
	if normal.ok:
		return {
			"status": "ok",
			"cards": block.duplicate(),
			"action_blocks": [block.duplicate()],
			"mana_after": normal.mana,
			"hp_cost": 0.0,
			"interval": CastSimulator.block_interval(block) + staff_interval,
			"advance": advance,
			"chain_extra": 0,
			"reason": "多重施法降级",
		}

	# 第三层：只保留攻击卡
	var minimal := CastSimulator.minimal_block(block)
	var minimal_result := CastSimulator.simulate_block(minimal, GameFlow.mana, GameFlow.max_mana)
	if minimal_result.ok:
		return {
			"status": "ok",
			"cards": minimal,
			"action_blocks": [minimal.duplicate()],
			"mana_after": minimal_result.mana,
			"hp_cost": 0.0,
			"interval": CastSimulator.block_interval(minimal) + staff_interval,
			"advance": advance,
			"chain_extra": 0,
			"reason": "最小施法块",
		}

	# 仍然不够：跳过该块，不扣蓝、不扣血
	return {
		"status": "skip",
		"cards": [],
		"action_blocks": [],
		"mana_after": GameFlow.mana,
		"hp_cost": 0.0,
		"interval": SKIP_COOLDOWN,
		"advance": advance,
		"chain_extra": 0,
		"reason": "无法支付，跳过",
	}

func commit(plan: Dictionary) -> void:
	GameFlow.mana = plan.mana_after
	block_index = plan.advance
	cooldown = plan.interval

	if plan.status == "overdraft":
		_overdraft_lock = true

	if block_index >= blocks.size():
		reload_left = RELOAD_TIME
		cooldown = maxf(cooldown, RELOAD_TIME)

func _can_unlock_overdraft() -> bool:
	if block_index >= blocks.size():
		return GameFlow.mana >= GameFlow.max_mana

	var info := CastSimulator.action_indices(blocks, block_index)
	if info.indices.is_empty():
		return GameFlow.mana >= GameFlow.max_mana

	var staff_interval: float = 0.0
	if wand.body != null and wand.body.definition != null:
		staff_interval = wand.body.definition.cast_interval

	var minimum := CastSimulator.minimum_action_start(blocks, info.indices, GameFlow.max_mana, staff_interval)
	if minimum < 0.0:
		return GameFlow.mana >= GameFlow.max_mana
	return GameFlow.mana >= minimum
