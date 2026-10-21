extends Node

const STRESS_SEEDS := 200

func _ready() -> void:
	var config := _make_config()

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345                    # 想换一张图就改这个数字

	var map := MapGenerator.generate(config, rng)
	_print_map(map)
	_show_result(_check(map))

	print("")
	print("========== 压力测试 %d 个种子 ==========" % STRESS_SEEDS)
	_stress(config)

func _make_config() -> LevelConfig:
	var config := LevelConfig.new()
	config.middle_layers = 7
	config.min_nodes_per_layer = 2
	config.max_nodes_per_layer = 4
	config.wave_min = 5
	config.wave_max = 7
	return config

func _print_map(map: MapData) -> void:
	print("========== 地图  seed=%d  层数=%d  节点数=%d ==========" % [map.seed, map.max_layer() + 1, map.nodes.size()])
	for layer in range(map.max_layer() + 1):
		var row := map.nodes_in_layer(layer)
		var line := "L%d (%d只)：" % [layer, row.size()]
		for n in row:
			var outs := ""
			for nid in n.next_ids:
				outs += str(nid) + " "
			var extra := ""
			if n.wave_count > 0:
				extra = " 波%d" % n.wave_count
			line += "  #%d 列%d %s%s→[%s]" % [n.id, n.column, MapNodeData.type_name(n.type), extra, outs.strip_edges()]
		print(line)

## 逐条检查四条硬约束，返回错误列表（空 = 通过）
func _check(map: MapData) -> Array[String]:
	var errors: Array[String] = []
	var by_id := {}
	for n in map.nodes:
		by_id[n.id] = n

	# 层数 / 宽度
	if map.max_layer() + 1 != 9:
		errors.append("层数不是 9（实际 %d）" % (map.max_layer() + 1))
	for layer in range(map.max_layer() + 1):
		var w := map.nodes_in_layer(layer).size()
		if w > 4:
			errors.append("第 %d 层有 %d 个节点，超过 4" % [layer, w])

	# 规则一、二：只连下一层，只连相邻列
	for n in map.nodes:
		for nid in n.next_ids:
			var t = by_id.get(nid)
			if t == null:
				errors.append("#%d 指向不存在的节点 %d" % [n.id, nid])
				continue
			if t.layer != n.layer + 1:
				errors.append("#%d → #%d 跨层连接（L%d → L%d）" % [n.id, t.id, n.layer, t.layer])
			if absi(t.column - n.column) > 1:
				errors.append("#%d → #%d 跨列连接（列 %d → 列 %d）" % [n.id, t.id, n.column, t.column])

	# 规则三：起点可达 / 首领可达
	var forward := _reachable(map, true)
	for n in map.nodes:
		if not forward.has(n.id):
			errors.append("#%d 从起点不可达" % n.id)

	var backward := _reachable(map, false)
	for n in map.nodes:
		if not backward.has(n.id):
			errors.append("#%d 走不到首领（死胡同）" % n.id)

	# 起点 / 首领各只有一个，且居中
	if map.nodes_in_layer(0).size() != 1:
		errors.append("起点层不是单节点")
	if map.nodes_in_layer(map.max_layer()).size() != 1:
		errors.append("首领层不是单节点")
	if map.get_node_data(map.start_id) == null or map.get_node_data(map.boss_id) == null:
		errors.append("start_id / boss_id 无效")

	return errors

## forward = true：从起点顺着出边能到哪些节点
## forward = false：从首领逆着入边能回到哪些节点（= 能走到首领的节点）
func _reachable(map: MapData, forward: bool) -> Dictionary:
	var incoming := {}
	for n in map.nodes:
		for nid in n.next_ids:
			if not incoming.has(nid):
				incoming[nid] = []
			incoming[nid].append(n.id)

	var seen := {}
	var stack: Array[int] = [map.start_id if forward else map.boss_id]

	while not stack.is_empty():
		var cur: int = stack.pop_back()
		if seen.has(cur):
			continue
		seen[cur] = true

		if forward:
			var node := map.get_node_data(cur)
			if node == null:
				continue
			for nid in node.next_ids:
				stack.append(nid)
		else:
			for pid in incoming.get(cur, []):
				stack.append(pid)

	return seen

func _show_result(errors: Array[String]) -> void:
	if errors.is_empty():
		print("校验：通过 ✅")
		return
	print("校验：失败 ❌")
	for e in errors:
		print("   - ", e)

func _stress(config: LevelConfig) -> void:
	var fails := 0
	var widest := 0
	var widest_seed := -1
	for s in range(STRESS_SEEDS):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var map := MapGenerator.generate(config, rng)
		var errors := _check(map)
		if not errors.is_empty():
			fails += 1
			print("  seed=%d 失败：" % s, errors)
		for layer in range(map.max_layer() + 1):
			var w := map.nodes_in_layer(layer).size()
			if w > widest:
				widest = w
				widest_seed = s
	print("结果：", "全部通过 ✅" if fails == 0 else "%d / %d 失败 ❌" % [fails, STRESS_SEEDS])
	print("最宽层：%d 个节点（seed=%d）" % [widest, widest_seed])
