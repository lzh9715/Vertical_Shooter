extends Node
## 全局 Run 状态（Autoload）。场景切换时不被销毁，负责记住“这局打到哪了”。

signal run_started
signal node_entered(node: MapNodeData)
signal node_finished(node: MapNodeData)
signal stats_changed


const MAP_SCENE := "res://scenes/map/MapView.tscn"
const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const SHOP_SCENE := "res://scenes/shop/ShopView.tscn"
const RESULT_SCENE := "res://scenes/ui/ResultScreen.tscn"
const REWARD_SCENE := "res://scenes/ui/RewardView.tscn"
const EVENT_SCENE := "res://scenes/ui/EventView.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

var level: LevelConfig
var map: MapData
var current_node: MapNodeData
var cleared: Array[int] = []          # 已通关的节点 id
var frontier: Array[int] = []        # 当前层唯一可选的节点 id（只能选这一层）
var rng := RandomNumberGenerator.new()
# —— 一局冒险的运行状态（跨场景保留）——
var gold := 5000
var score := 0
var hp := 100.0
var max_hp := 100.0
var mana := 100.0
var max_mana := 100.0
var mana_regen := 35.0
var spell: SpellData
var inventory: GridInventory
var equipment: PlayerEquipment
var pricing: ShopPricing
var last_result: Dictionary = {}       # 结算界面读取的上一局数据
var current_reward: RewardData         # 当前奖励关
var current_event: EventData           # 当前事件
var event_context: Dictionary = {}     # 事件战斗上下文（Boss / 限时 / 被偷金额）
var _used_events: Array[String] = []   # 本局已出现过的事件
var _reward_modifiers: Dictionary = {} # 收益类 buff：来源 ID -> 倍率

## 开一局：生成/读取地图，起点自动算作已通过
func start_run(config: LevelConfig, seed_value: int = 0) -> void:
	level = config
	pricing = config.pricing
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	map = config.fixed_map
	if map == null or config.randomize_map:
		map = MapGenerator.generate(config, rng)

	current_node = null
	cleared.clear()
	cleared.append(map.start_id)      # 起点默认通过
	frontier = _next_ids_of(map.start_id)
	current_reward = null
	current_event = null
	event_context.clear()
	_used_events.clear()
	_reward_modifiers.clear()
	reset_stats()
	_seed_starter_inventory()
	run_started.emit()

## 点击地图节点
func enter_node(node: MapNodeData) -> void:
	if node == null:
		return
	current_node = node
	node_entered.emit(node)

	match node.type:
		MapNodeData.NodeType.BATTLE, MapNodeData.NodeType.ELITE, MapNodeData.NodeType.BOSS:
			SceneTransition.change_scene(BATTLE_SCENE)
		MapNodeData.NodeType.SHOP:
			SceneTransition.change_scene(SHOP_SCENE)
		MapNodeData.NodeType.REWARD:
			current_reward = _pick_reward()
			if current_reward is RewardBattle:
				SceneTransition.change_scene(BATTLE_SCENE)
			else:
				SceneTransition.change_scene(REWARD_SCENE)
		MapNodeData.NodeType.EVENT:
			current_event = _pick_event()
			if current_event == null:
				finish_node()
			else:
				SceneTransition.change_scene(EVENT_SCENE)
		_:
			# 未实现的节点类型：直接通过
			finish_node()

## 节点打完
func finish_node() -> void:
	get_tree().paused = false            # 确保离开战斗/商店时不会停留在暂停状态

	if current_node == null:
		SceneTransition.change_scene(MAP_SCENE)
		return

	var finished := current_node
	cleared.append(finished.id)
	frontier = _next_ids_of(finished.id)
	node_finished.emit(finished)
	current_node = null
	current_reward = null
	current_event = null
	event_context.clear()

	if finished.type == MapNodeData.NodeType.BOSS:
		end_run(true)                    # 通关
	else:
		SceneTransition.change_scene(MAP_SCENE)

## 战斗场景调用：按节点类型和 wave_count，从池子里抽出一组波次
func build_waves(node: MapNodeData) -> Array[WaveData]:
	var out: Array[WaveData] = []
	if node == null or level == null:
		return out

	var pool: Array[WaveData] = level.mob_pool
	if node.type == MapNodeData.NodeType.ELITE and not level.elite_pool.is_empty():
		pool = level.elite_pool

	if pool.is_empty():
		push_warning("波次池是空的：%s" % node.display_name)
		return out

	for i in range(maxi(node.wave_count, 1)):
		out.append(pool[rng.randi_range(0, pool.size() - 1)])
	return out

## 地图界面用：这个节点现在能不能点
func is_node_available(node: MapNodeData) -> bool:
	if node == null or map == null:
		return false
	return frontier.has(node.id)

func reset_stats() -> void:
	gold = 5000
	score = 0
	max_hp = 100.0
	hp = max_hp
	mana = 100.0
	max_mana = 100.0
	spell = null
	stats_changed.emit()

## 返回主菜单时立即清空本局运行状态（保留 last_result 供展示）
func reset_run() -> void:
	get_tree().paused = false

	map = null
	current_node = null
	current_reward = null
	current_event = null
	event_context.clear()
	_used_events.clear()
	_reward_modifiers.clear()
	inventory = null
	equipment = null
	cleared.clear()
	frontier.clear()

	reset_stats()

func go_main_menu() -> void:
	reset_run()
	SceneTransition.change_scene(MAIN_MENU_SCENE)

func add_gold(amount: int) -> void:
	gold = maxi(gold + amount, 0)
	stats_changed.emit()

func add_score(amount: int) -> void:
	score += amount
	stats_changed.emit()

## 够钱就扣，返回是否成功
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	stats_changed.emit()
	return true

## 结束一局（阵亡 / 通关）：记录结果并进入结算界面
func end_run(victory: bool = false) -> void:
	get_tree().paused = false

	last_result = {
		"victory": victory,
		"score": score,
		"gold": gold,
		"hp": hp,
		"max_hp": max_hp,
		"mana": mana,
		"max_mana": max_mana,
		"nodes": cleared.size(),
	}

	print("Run 结束：", "通关" if victory else "阵亡")

	map = null
	current_node = null
	current_reward = null
	current_event = null
	event_context.clear()
	frontier.clear()

	# 淡出需要时间，不会在物理回调里立刻移除碰撞体
	SceneTransition.change_scene(RESULT_SCENE)

## 结算界面点“再来一局”
func restart_after_result() -> void:
	if level == null:
		SceneTransition.change_scene(MAP_SCENE)
		return

	start_run(level)
	SceneTransition.change_scene(MAP_SCENE)

func _next_ids_of(node_id: int) -> Array[int]:
	var out: Array[int] = []
	if map == null:
		return out
	var n := map.get_node_data(node_id)
	if n == null:
		return out
	for id in n.next_ids:
		out.append(id)
	return out

## 商店定价：level 没配就用一份默认的（20~150，倍率 1.0）
func get_pricing() -> ShopPricing:
	if pricing == null:
		pricing = ShopPricing.new()
	return pricing

func get_boss() -> BossData:
	if level == null:
		return null
	return level.boss

# ---------- 奖励关 ----------

func _pick_reward() -> RewardData:
	if level == null or level.reward_pool.is_empty():
		push_warning("奖励池是空的")
		return null
	return level.reward_pool[rng.randi_range(0, level.reward_pool.size() - 1)]

## 收益倍率接口：未来的金币 buff / 道具往这里叠
func add_reward_modifier(source_id: StringName, multiplier: float) -> void:
	_reward_modifiers[source_id] = multiplier

func remove_reward_modifier(source_id: StringName) -> void:
	_reward_modifiers.erase(source_id)

func get_reward_multiplier() -> float:
	var total := 1.0
	for m in _reward_modifiers.values():
		total *= float(m)
	return clampf(total, 0.1, 10.0)

func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)
	stats_changed.emit()

## 事件用：改变当前血量（最低保留 1，避免事件直接致死）
func change_hp(delta: float) -> void:
	hp = clampf(hp + delta, 1.0, max_hp)
	stats_changed.emit()

## 事件用：改变最大生命（最低 1，当前血量跟随上限）
func change_max_hp(delta: float) -> void:
	max_hp = maxf(1.0, max_hp + delta)
	hp = minf(hp, max_hp)
	stats_changed.emit()

func spend_mana(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if mana < amount:
		return false
	mana -= amount
	stats_changed.emit()
	return true

func restore_mana(amount: float) -> void:
	mana = minf(max_mana, mana + maxf(amount, 0.0))
	stats_changed.emit()

# ---------- 事件 ----------

func _pick_event() -> EventData:
	if level == null or level.event_pool.is_empty():
		return null

	var candidates: Array[EventData] = []
	for e in level.event_pool:
		if e == null:
			continue
		if e.once_per_run and _used_events.has(e.resource_path):
			continue
		if current_node != null and current_node.layer < e.min_layer:
			continue
		candidates.append(e)

	if candidates.is_empty():
		return null

	var picked := candidates[rng.randi_range(0, candidates.size() - 1)]
	_used_events.append(picked.resource_path)
	return picked

# ---------- 背包 / 装备 ----------

func get_inventory() -> GridInventory:
	if inventory == null:
		inventory = GridInventory.new()
	return inventory

func get_equipment() -> PlayerEquipment:
	if equipment == null:
		equipment = PlayerEquipment.new()
	return equipment

## 临时起始物资：接入掉落/商店后删除
func _seed_starter_inventory() -> void:
	inventory = GridInventory.new()
	equipment = PlayerEquipment.new()

	var gems := ItemCatalog.gems()
	var bodies := ItemCatalog.bodies()
	var hats := ItemCatalog.hats()
	var robes := ItemCatalog.robes()
	var accessories := ItemCatalog.accessories()

	# 备用宝石 / 装备
	inventory.add(ItemInstance.create(gems[2]))
	inventory.add(ItemCatalog.make_instance(hats[0]))
	inventory.add(ItemCatalog.make_instance(robes[0]))
	inventory.add(ItemCatalog.make_instance(accessories[0]))

	# 两把已装备法杖：默认各装一组卡，保证开局可以射击
	var wand0 := WandInstance.create(
		ItemInstance.create(bodies[0]),
		ItemInstance.create(gems[0])
	)
	wand0.add_card(ItemCatalog.find_card(&"card_homing"))
	wand0.add_card(ItemCatalog.find_card(&"card_pierce"))
	wand0.add_card(ItemCatalog.find_card(&"card_single"))
	equipment.equip_wand(0, wand0)

	var wand1 := WandInstance.create(
		ItemInstance.create(bodies[1]),
		ItemInstance.create(gems[1])
	)
	wand1.add_card(ItemCatalog.find_card(&"module_damage"))
	wand1.add_card(ItemCatalog.find_card(&"card_boom"))
	wand1.add_card(ItemCatalog.find_card(&"card_single"))
	wand1.add_card(ItemCatalog.find_card(&"card_spread"))
	wand1.add_card(ItemCatalog.find_card(&"card_single"))
	equipment.equip_wand(1, wand1)

	equipment.equip_item(ItemCatalog.make_instance(hats[0]))
	equipment.equip_item(ItemCatalog.make_instance(robes[0]))
	equipment.equip_item(ItemCatalog.make_instance(accessories[0]))