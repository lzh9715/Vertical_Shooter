extends RefCounted
class_name MapGenerator

## 网格化地图生成
##   grid[layer][column]：layer 0 = 起点，layer N-1 = 首领；column 0~3
##   硬约束：
##     1. 只能连下一层（layer + 1）
##     2. 只能连相邻列（|Δcolumn| <= 1）
##     3. 每个非首领节点至少一条出边；每条路都必然走到首领（层数单调递增）
##     4. 单层最多 4 个节点，起点 / 首领固定单列

const GRID_WIDTH := 4
const MAX_ATTEMPTS := 100
const X_SPACING := 0.22          # UI 里相邻列的横向间距（归一化）
const POSITION_JITTER := Vector2(0.032, 0.012)   # 节点位置的轻微随机偏移

static func generate(config: LevelConfig, rng: RandomNumberGenerator) -> MapData:
	var total_layers := config.middle_layers + 2
	var center := rng.randi_range(1, GRID_WIDTH - 2)      # 4 列时中间是 1 或 2

	for _attempt in range(MAX_ATTEMPTS):
		var windows := _plan_windows(center, total_layers, config, rng)
		if windows.is_empty():
			continue
		var map := _build_map(windows, center, total_layers, config, rng)
		if map != null:
			map.seed = rng.seed
			return map

	# 兜底：一条中轴直链（正常不会走到这里）
	var straight: Array[Vector2i] = []
	for i in range(total_layers):
		straight.append(Vector2i(center, center))
	return _build_map(straight, center, total_layers, config, rng)

## 规划每层占用的「连续列窗口」：起点/首领是单列，中间层是 2~4 列的连续区间。
## 相邻两层的窗口必须满足 |Δ起始列| <= 1 且 |Δ结束列| <= 1，
## 这就是规则二的几何保证——只要窗口满足它，两层之间就一定能按相邻列连上。
static func _plan_windows(center: int, total_layers: int, config: LevelConfig, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var windows: Array[Vector2i] = []
	windows.append(Vector2i(center, center))

	var boss := Vector2i(center, center)
	var min_w := maxi(config.min_nodes_per_layer, 2)
	var max_w := mini(config.max_nodes_per_layer, GRID_WIDTH)

	for layer in range(1, total_layers - 1):
		var prev := windows[layer - 1]
		var is_last_middle := layer == total_layers - 2
		var candidates: Array[Vector2i] = []

		for w in range(min_w, max_w + 1):
			for a in range(0, GRID_WIDTH - w + 1):
				var win := Vector2i(a, a + w - 1)

				# 与上一层保持相邻（窗口两端都不许跳超过 1 列）
				if absi(win.x - prev.x) > 1 or absi(win.y - prev.y) > 1:
					continue

				# 最后一层中间层还要能直接连到首领
				if is_last_middle and (absi(win.x - boss.x) > 1 or absi(win.y - boss.x) > 1):
					continue

				candidates.append(win)

		if candidates.is_empty():
			return []

		windows.append(candidates[rng.randi_range(0, candidates.size() - 1)])

	windows.append(boss)
	return windows

static func _build_map(windows: Array[Vector2i], center: int, total_layers: int, config: LevelConfig, rng: RandomNumberGenerator) -> MapData:
	var map := MapData.new()
	var grid: Array = []

	# ① 建节点
	for layer in range(total_layers):
		var row: Array[MapNodeData] = []
		var win := windows[layer]
		for col in range(win.x, win.y + 1):
			var n := MapNodeData.new()
			n.id = map.nodes.size()
			n.layer = layer
			n.column = col
			var base := Vector2(
				0.5 + (col - center) * X_SPACING,
				float(layer) / float(total_layers - 1)
			)
			# 轻微抖动，避免地图看起来像死板的表格；不影响连通关系
			var jitter := Vector2(
				rng.randf_range(-POSITION_JITTER.x, POSITION_JITTER.x),
				rng.randf_range(-POSITION_JITTER.y, POSITION_JITTER.y)
			)
			n.position = (base + jitter).clamp(Vector2(0.03, 0.0), Vector2(0.97, 1.0))
			n.type = _roll_type(layer, total_layers, rng)
			n.display_name = "%s · 第%d层" % [MapNodeData.type_name(n.type), layer]
			if n.type == MapNodeData.NodeType.BATTLE or n.type == MapNodeData.NodeType.ELITE:
				n.wave_count = rng.randi_range(config.wave_min, config.wave_max)
			map.nodes.append(n)
			row.append(n)
		grid.append(row)

	# ② 连边：只在下一层的相邻列里挑 1~2 个
	for layer in range(total_layers - 1):
		var upper: Array = grid[layer]
		var lower: Array = grid[layer + 1]

		for a in upper:
			var targets: Array[MapNodeData] = []
			for b in lower:
				if absi(b.column - a.column) <= 1:
					targets.append(b)

			if targets.is_empty():
				return null        # 窗口规划出错，交给上层重试

			var want := 1 if targets.size() == 1 else rng.randi_range(1, mini(2, targets.size()))
			var chosen: Array[MapNodeData] = []
			while chosen.size() < want:
				var t: MapNodeData = targets[rng.randi_range(0, targets.size() - 1)]
				if not chosen.has(t):
					chosen.append(t)
			for c in chosen:
				a.next_ids.append(c.id)

		# ③ 补边：下一层每个节点至少一个入边（取相邻列里最近的）
		for b in lower:
			var has_in := false
			for a in upper:
				if b.id in a.next_ids:
					has_in = true
					break
			if has_in:
				continue

			var best: MapNodeData = null
			var best_dist := 99
			for a in upper:
				var d := absi(a.column - b.column)
				if d < best_dist:
					best_dist = d
					best = a

			if best == null or best_dist > 1:
				return null
			best.next_ids.append(b.id)

		# ④ 排序：补边会追加到末尾，这里按从左到右重排，画线不交叉
		for a in upper:
			var ordered := Array(a.next_ids)
			ordered.sort()
			a.next_ids = PackedInt32Array(ordered)

	map.start_id = grid[0][0].id
	map.boss_id = grid[total_layers - 1][0].id
	return map

static func _roll_type(layer: int, total_layers: int, rng: RandomNumberGenerator) -> int:
	if layer == 0:
		return MapNodeData.NodeType.START
	if layer == total_layers - 1:
		return MapNodeData.NodeType.BOSS

	var roll := rng.randf()
	if layer <= 3:
		if roll < 0.70: return MapNodeData.NodeType.BATTLE
		if roll < 0.90: return MapNodeData.NodeType.EVENT
		return MapNodeData.NodeType.SHOP
	else:
		if roll < 0.50: return MapNodeData.NodeType.BATTLE
		if roll < 0.70: return MapNodeData.NodeType.ELITE
		if roll < 0.90: return MapNodeData.NodeType.EVENT
		return MapNodeData.NodeType.SHOP
