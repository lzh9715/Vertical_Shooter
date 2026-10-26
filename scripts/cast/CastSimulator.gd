extends RefCounted
class_name CastSimulator

## 纯逻辑施法模拟：不依赖场景、节点或 UI。
## 负责按顺序模拟法力账本、减耗池和施法块分组。

const MAX_ACTION_BLOCKS := 16
const CHAIN_OVERHEAD_PER_EXTRA := 0.03
const OVERDRAFT_HP_RATIO := 0.25

## 模拟一个施法块。
## cards 按实际读取顺序传入；攻击卡不要求放在最后，便于测试和未来扩展。
static func simulate_block(cards: Array, start_mana: float, max_mana: float) -> Dictionary:
	var discount_pool := 0.0
	for i in range(cards.size()):
		var card: ItemDefinition = cards[i]
		if card != null:
			discount_pool += float(card.mana_discount)

	var mana := start_mana
	var ledger: Array[Dictionary] = []
	var has_attack := false

	for i in range(cards.size()):
		var card: ItemDefinition = cards[i]
		if card == null:
			continue

		if card.is_attack():
			has_attack = true

		var used_discount := minf(discount_pool, float(card.mana_cost))
		var cost := maxf(float(card.mana_cost) - used_discount, 0.0)
		discount_pool -= used_discount

		if mana < cost:
			return {
				"ok": false,
				"mana": mana,
				"deficit": cost - mana,
				"has_attack": has_attack,
				"ledger": ledger,
				"error": "法力不足",
			}

		mana -= cost
		mana = minf(max_mana, mana + float(card.mana_restore))

		ledger.append({
			"id": card.id,
			"cost": cost,
			"restore": card.mana_restore,
			"mana_after": mana,
		})

	return {
		"ok": true,
		"mana": mana,
		"deficit": 0.0,
		"has_attack": has_attack,
		"ledger": ledger,
		"error": "",
	}

## 返回从多少起始法力可以完成该块；满蓝也无法完成时返回 -1。
static func minimum_start(cards: Array, max_mana: float) -> float:
	var max_result := simulate_block(cards, max_mana, max_mana)
	if not max_result.ok:
		return -1.0

	var low := 0.0
	var high := max_mana
	for i in range(32):
		var mid := (low + high) * 0.5
		var result := simulate_block(cards, mid, max_mana)
		if result.ok:
			high = mid
		else:
			low = mid
	return high

## 按施法块切分：每个攻击卡结束一个块；末尾只有模块时也形成一个无攻击块。
static func build_blocks(cards: Array) -> Array:
	var blocks: Array = []
	var current: Array = []

	for i in range(cards.size()):
		var card: ItemDefinition = cards[i]
		if card == null:
			continue
		current.append(card)
		if card.is_attack():
			blocks.append(current)
			current = []

	if not current.is_empty():
		blocks.append(current)
	return blocks

## 从 start_index 开始，计算本次联动动作覆盖哪些块。
## 显式三重/四重由 first_count 容纳，不产生链式额外块；
## 嵌套多重施法超出 first_count 的部分才形成 chain_extra。
static func action_indices(blocks: Array, start_index: int) -> Dictionary:
	if start_index < 0 or start_index >= blocks.size():
		return {"indices": [], "first_count": 0, "chain_extra": 0, "total_blocks": 0}

	var first_count := maxi(1, _max_multicast(blocks[start_index]))
	var end := mini(start_index + first_count - 1, blocks.size() - 1)
	var scan := start_index

	while scan <= end and scan < blocks.size():
		var count := maxi(1, _max_multicast(blocks[scan]))
		end = mini(maxi(end, scan + count - 1), blocks.size() - 1)
		end = mini(end, start_index + MAX_ACTION_BLOCKS - 1)
		scan += 1

	var indices: Array[int] = []
	for i in range(start_index, end + 1):
		indices.append(i)

	var total := indices.size()
	return {
		"indices": indices,
		"first_count": first_count,
		"chain_extra": maxi(0, total - first_count),
		"total_blocks": total,
	}

## 模拟一次完整联动动作。
## status:
##   ok        正常法力足够，立即释放
##   wait      当前法力不够，但满蓝可放，应等待
##   overdraft 满蓝也不够，但透支生命可以完成
##   degrade   无法安全完成，交给降级处理
static func simulate_action(
	blocks: Array,
	start_index: int,
	current_mana: float,
	max_mana: float,
	hp: float = 100.0,
	staff_interval: float = 0.0,
	allow_overdraft: bool = true
) -> Dictionary:
	var info := action_indices(blocks, start_index)
	var indices: Array[int] = info.indices
	if indices.is_empty():
		return {"status": "degrade", "indices": indices, "reason": "没有可施法块"}

	var normal_current := _simulate_indices(blocks, indices, current_mana, max_mana, false, hp, staff_interval)
	if normal_current.ok:
		normal_current.status = "ok"
		normal_current.indices = indices
		normal_current.info = info
		return normal_current

	# 当前蓝不够，但满蓝能放：等待，不允许透支
	var normal_max := _simulate_indices(blocks, indices, max_mana, max_mana, false, hp, staff_interval)
	if normal_max.ok:
		normal_max.status = "wait"
		normal_max.indices = indices
		normal_max.info = info
		normal_max.required_mana = minimum_action_start(blocks, indices, max_mana, staff_interval)
		return normal_max

	if not allow_overdraft:
		var degrade := normal_max.duplicate(true)
		degrade.status = "degrade"
		degrade.indices = indices
		degrade.info = info
		degrade.reason = "禁止透支"
		return degrade

	var overdraft := _simulate_indices(blocks, indices, max_mana, max_mana, true, hp, staff_interval)
	if overdraft.ok:
		overdraft.status = "overdraft"
		overdraft.indices = indices
		overdraft.info = info
		return overdraft

	overdraft.status = "degrade"
	overdraft.indices = indices
	overdraft.info = info
	overdraft.reason = "透支会致死或仍无法完成"
	return overdraft

## 当前动作从多少起始法力可以正常完成；无法完成时返回 -1。
static func minimum_action_start(blocks: Array, indices: Array[int], max_mana: float, staff_interval: float = 0.0) -> float:
	if _simulate_indices(blocks, indices, max_mana, max_mana, false, INF, staff_interval).ok == false:
		return -1.0

	var low := 0.0
	var high := max_mana
	for i in range(32):
		var mid := (low + high) * 0.5
		var result := _simulate_indices(blocks, indices, mid, max_mana, false, INF, staff_interval)
		if result.ok:
			high = mid
		else:
			low = mid
	return high

static func _simulate_indices(
	blocks: Array,
	indices: Array[int],
	start_mana: float,
	max_mana: float,
	allow_overdraft: bool,
	hp: float,
	staff_interval: float
) -> Dictionary:
	var mana := start_mana
	var hp_left := hp
	var hp_cost := 0.0
	var ledger: Array[Dictionary] = []
	var max_interval := 0.0
	var has_attack := false

	for block_index in indices:
		var block: Array = blocks[block_index]
		max_interval = maxf(max_interval, block_interval(block))

		var discount_pool := 0.0
		for i in range(block.size()):
			var card: ItemDefinition = block[i]
			if card != null:
				discount_pool += float(card.mana_discount)

		for i in range(block.size()):
			var card: ItemDefinition = block[i]
			if card == null:
				continue

			if card.is_attack():
				has_attack = true

			var used_discount := minf(discount_pool, float(card.mana_cost))
			var cost := maxf(float(card.mana_cost) - used_discount, 0.0)
			discount_pool -= used_discount

			if mana < cost:
				if not allow_overdraft:
					return {
						"ok": false,
						"status": "degrade",
						"mana": mana,
						"deficit": cost - mana,
						"hp_cost": hp_cost,
						"ledger": ledger,
						"has_attack": has_attack,
						"interval": max_interval + staff_interval,
						"max_interval": max_interval,
						"chain_extra": 0,
					}

				# 负余额是已支付过生命的债务，本张卡只为新借的法力扣血。
				var deficit := cost - maxf(mana, 0.0)
				var damage := deficit * OVERDRAFT_HP_RATIO
				if damage >= hp_left:
					return {
						"ok": false,
						"status": "degrade",
						"mana": mana,
						"deficit": deficit,
						"hp_cost": hp_cost + damage,
						"ledger": ledger,
						"has_attack": has_attack,
						"interval": max_interval + staff_interval,
						"max_interval": max_interval,
						"chain_extra": 0,
					}
				hp_left -= damage
				hp_cost += damage
				mana -= cost
			else:
				mana -= cost

			mana = minf(max_mana, mana + float(card.mana_restore))
			ledger.append({
				"id": card.id,
				"cost": cost,
				"restore": card.mana_restore,
				"mana_after": mana,
			})

	var info := action_indices(blocks, indices[0])
	var chain_extra: int = info.chain_extra
	var overhead := CHAIN_OVERHEAD_PER_EXTRA * float(chain_extra)

	return {
		"ok": true,
		"status": "ok",
		"mana": mana,
		"deficit": maxf(-mana, 0.0),
		"hp_cost": hp_cost,
		"ledger": ledger,
		"has_attack": has_attack,
		"interval": max_interval + staff_interval + overhead,
		"max_interval": max_interval,
		"chain_extra": chain_extra,
		"overhead": overhead,
	}

static func _max_multicast(block: Array) -> int:
	var result := 0
	for i in range(block.size()):
		var card: ItemDefinition = block[i]
		if card != null:
			result = maxi(result, card.multicast_count)
	return result

static func block_interval(cards: Array) -> float:
	var total := 0.0
	for i in range(cards.size()):
		var card: ItemDefinition = cards[i]
		if card != null:
			total += card.cast_interval
	return maxf(total, 0.0)

## 降级到最小块：只保留第一张攻击卡，丢弃本块的修饰符。
static func minimal_block(cards: Array) -> Array:
	for i in range(cards.size()):
		var card: ItemDefinition = cards[i]
		if card != null and card.is_attack():
			return [card]
	return []

static func total_mana_cost(cards: Array) -> float:
	var total := 0.0
	for i in range(cards.size()):
		var card: ItemDefinition = cards[i]
		if card != null:
			total += float(card.mana_cost)
	return total

static func total_discount(cards: Array) -> float:
	var total := 0.0
	for i in range(cards.size()):
		var card: ItemDefinition = cards[i]
		if card != null:
			total += float(card.mana_discount)
	return total
