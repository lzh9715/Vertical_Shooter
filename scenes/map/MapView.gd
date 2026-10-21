extends Control

const LEVEL_PATH := "res://data/Level_01.tres"
const NODE_RADIUS := 22.0
const MARGIN := Vector2(70, 110)

# 连线样式：二次贝塞尔弧线 + 虚线
const CURVE_SAMPLES := 20
const CURVE_BOW := 0.10          # 弯曲程度（相对两点距离）
const DASH_LENGTH := 9.0
const GAP_LENGTH := 7.0

const TYPE_LABEL := {
	MapNodeData.NodeType.START: "起",
	MapNodeData.NodeType.BATTLE: "战",
	MapNodeData.NodeType.ELITE: "精",
	MapNodeData.NodeType.SHOP: "商",
	MapNodeData.NodeType.EVENT: "事",
	MapNodeData.NodeType.BOSS: "首",
}

const TYPE_COLOR := {
	MapNodeData.NodeType.START: Color(0.65, 0.65, 0.65),
	MapNodeData.NodeType.BATTLE: Color(0.92, 0.92, 0.92),
	MapNodeData.NodeType.ELITE: Color(1.0, 0.62, 0.25),
	MapNodeData.NodeType.SHOP: Color(0.35, 0.9, 0.45),
	MapNodeData.NodeType.EVENT: Color(0.45, 0.72, 1.0),
	MapNodeData.NodeType.BOSS: Color(1.0, 0.32, 0.32),
}

@onready var tooltip: Panel = $Tooltip
@onready var tooltip_label: Label = $Tooltip/Label

func _ready() -> void:
	get_tree().paused = false
	if GameFlow.map == null:
		var level: LevelConfig = load(LEVEL_PATH)
		GameFlow.start_run(level)
	_build()
	resized.connect(_relayout)

func _build() -> void:
	for child in get_children():
		if child is Button:
			child.queue_free()

	tooltip.visible = false

	for n in GameFlow.map.nodes:
		var b := Button.new()
		b.text = TYPE_LABEL.get(n.type, "?")
		b.custom_minimum_size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
		b.size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
		b.position = _screen_pos(n) - Vector2(NODE_RADIUS, NODE_RADIUS)
		b.disabled = not GameFlow.is_node_available(n)
		b.add_theme_color_override("font_color", TYPE_COLOR.get(n.type, Color.WHITE))

		if GameFlow.cleared.has(n.id):
			b.modulate = Color(1, 1, 1, 0.35)

		b.pressed.connect(_on_node_pressed.bind(n))
		b.mouse_entered.connect(_show_tooltip.bind(n))
		b.mouse_exited.connect(_hide_tooltip)
		b.set_meta("node_id", n.id)
		add_child(b)

	tooltip.move_to_front()
	queue_redraw()

## 窗口尺寸变化时只重排按钮，并重绘连线（否则线和按钮会对不上）
func _relayout() -> void:
	if GameFlow.map == null:
		return
	for child in get_children():
		if child is Button and child.has_meta("node_id"):
			var n := GameFlow.map.get_node_data(child.get_meta("node_id"))
			if n != null:
				child.position = _screen_pos(n) - Vector2(NODE_RADIUS, NODE_RADIUS)
	queue_redraw()

func _process(_delta: float) -> void:
	if not tooltip.visible:
		return
	var pos := get_global_mouse_position() + Vector2(18, 18)
	pos.x = minf(pos.x, size.x - tooltip.size.x - 8)
	pos.y = minf(pos.y, size.y - tooltip.size.y - 8)
	tooltip.position = pos

func _draw() -> void:
	if GameFlow.map == null:
		return

	for n in GameFlow.map.nodes:
		var from := _screen_pos(n)
		for nid in n.next_ids:
			var target := GameFlow.map.get_node_data(nid)
			if target == null:
				continue
			var color := Color(0.95, 0.82, 0.4, 0.95) if GameFlow.cleared.has(n.id) else Color(0.45, 0.47, 0.58, 0.95)
			_draw_dashed_curve(from, _screen_pos(target), color, 2.5, n.id * 73856093 + nid * 19349663)

## 画一条「轻微弯曲的虚线」：二次贝塞尔 + 沿弧长切出的虚线段
## edge_seed 用来决定每条边自己的弯曲方向/幅度/前后偏移，保证重绘时稳定（不会闪烁）
func _draw_dashed_curve(a: Vector2, b: Vector2, color: Color, width: float, edge_seed: int) -> void:
	var span := a.distance_to(b)
	if span < 2.0:
		return

	var dir := (b - a) / span
	var normal := Vector2(-dir.y, dir.x)

	var h := absi(edge_seed)
	var side := 1.0 if (h % 2) == 0 else -1.0                                  # 随机左/右弯
	var bow := CURVE_BOW * (0.55 + 0.9 * float((h / 2) % 100) / 100.0)         # 弯曲幅度 0.55~1.45 倍
	var along := (float((h / 200) % 100) / 100.0 - 0.5) * 0.3                  # 控制点沿行进方向前后 ±15%

	var ctrl := (a + b) * 0.5 + normal * span * bow * side + dir * span * along

	# 采样成折线
	var pts := PackedVector2Array()
	for i in range(CURVE_SAMPLES + 1):
		var t := float(i) / float(CURVE_SAMPLES)
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))

	# 累积弧长
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))

	# 按弧长交替画实线段与空白
	var total := cum[cum.size() - 1]
	var d := 0.0
	while d < total:
		var d2 := minf(d + DASH_LENGTH, total)
		draw_line(_point_on(pts, cum, d), _point_on(pts, cum, d2), color, width)
		d += DASH_LENGTH + GAP_LENGTH

## 弧长 → 折线上的点
func _point_on(pts: PackedVector2Array, cum: PackedFloat32Array, dist: float) -> Vector2:
	for i in range(1, pts.size()):
		if dist <= cum[i]:
			var seg := cum[i] - cum[i - 1]
			var t := 0.0 if seg <= 0.0001 else (dist - cum[i - 1]) / seg
			return pts[i - 1].lerp(pts[i], t)
	return pts[pts.size() - 1]

func _screen_pos(n: MapNodeData) -> Vector2:
	var usable := size - MARGIN * 2.0
	return MARGIN + Vector2(n.position.x, n.position.y) * usable

func _on_node_pressed(n: MapNodeData) -> void:
	GameFlow.enter_node(n)

func _show_tooltip(n: MapNodeData) -> void:
	tooltip_label.text = "%s\n%s" % [n.display_name, _type_desc(n.type)]
	tooltip.visible = true

func _hide_tooltip() -> void:
	tooltip.visible = false

func _type_desc(t: int) -> String:
	match t:
		MapNodeData.NodeType.START: return "起点"
		MapNodeData.NodeType.BATTLE: return "小怪战斗"
		MapNodeData.NodeType.ELITE: return "精英战斗"
		MapNodeData.NodeType.SHOP: return "商店"
		MapNodeData.NodeType.EVENT: return "事件"
		MapNodeData.NodeType.BOSS: return "首领"
	return "未知"