extends Node
## 全局 Run 状态（Autoload）。场景切换时不被销毁，负责记住“这局打到哪了”。

signal run_started
signal node_entered(node: MapNodeData)
signal node_finished(node: MapNodeData)
signal stats_changed


const MAP_SCENE := "res://scenes/map/MapView.tscn"
const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const SHOP_SCENE := "res://scenes/shop/ShopView.tscn"

var level: LevelConfig
var map: MapData
var current_node: MapNodeData
var cleared: Array[int] = []          # 已通关的节点 id
var frontier: Array[int] = []        # 当前层唯一可选的节点 id（只能选这一层）
var rng := RandomNumberGenerator.new()
# —— 一局冒险的运行状态（跨场景保留）——
var gold := 5000
var score := 0
var hp := 3
var max_hp := 3
var spell: SpellData
var pricing: ShopPricing

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
	reset_stats()
	run_started.emit()

## 点击地图节点
func enter_node(node: MapNodeData) -> void:
	if node == null:
		return
	current_node = node
	node_entered.emit(node)

	match node.type:
		MapNodeData.NodeType.BATTLE, MapNodeData.NodeType.ELITE, MapNodeData.NodeType.BOSS:
			get_tree().change_scene_to_file(BATTLE_SCENE)
		MapNodeData.NodeType.SHOP:
			get_tree().change_scene_to_file(SHOP_SCENE)
		_:
			# 事件节点还没有内容：先当作直接通过
			finish_node()

## 节点打完
func finish_node() -> void:
	get_tree().paused = false            # 从商店出来时可能还处于暂停

	if current_node == null:
		get_tree().change_scene_to_file(MAP_SCENE)
		return

	var finished := current_node
	cleared.append(finished.id)
	frontier = _next_ids_of(finished.id)
	node_finished.emit(finished)
	current_node = null

	if finished.type == MapNodeData.NodeType.BOSS:
		end_run()                        # 通关：暂时直接开新一局
	else:
		get_tree().change_scene_to_file(MAP_SCENE)

## 战斗场景调用：按节点类型和 wave_count，从池子里抽出一组波次
func build_waves(node: MapNodeData) -> Array[WaveData]:
	var out: Array[WaveData] = []
	if node == null or level == null:
		return out

	var pool: Array[WaveData] = level.mob_pool
	if node.type == MapNodeData.NodeType.ELITE and not level.elite_pool.is_empty():
		pool = level.elite_pool
	elif node.type == MapNodeData.NodeType.BOSS and not level.boss_pool.is_empty():
		pool = level.boss_pool

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
	max_hp = 3
	hp = max_hp
	spell = null
	stats_changed.emit()

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

## 结束一局（阵亡 / 通关）：清空地图，回地图界面重新开始
func end_run() -> void:
	get_tree().paused = false
	print("Run 结束")
	map = null
	current_node = null
	get_tree().change_scene_to_file(MAP_SCENE)
	frontier.clear()

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

func get_spell_pool() -> Array[SpellData]:
	if level == null:
		return []
	return level.spell_pool

## 商店定价：level 没配就用一份默认的（20~150，倍率 1.0）
func get_pricing() -> ShopPricing:
	if pricing == null:
		pricing = ShopPricing.new()
	return pricing