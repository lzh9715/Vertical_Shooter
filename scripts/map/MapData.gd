extends Resource
class_name MapData

@export var nodes: Array[MapNodeData] = []
@export var start_id: int = 0
@export var boss_id: int = 0
@export var map_seed: int = 0

func get_node_data(node_id: int) -> MapNodeData:
	if node_id < 0 or node_id >= nodes.size():
		return null
	return nodes[node_id]

func nodes_in_layer(layer: int) -> Array[MapNodeData]:
	var out: Array[MapNodeData] = []
	for n in nodes:
		if n.layer == layer:
			out.append(n)
	return out

func max_layer() -> int:
	var m := 0
	for n in nodes:
		m = maxi(m, n.layer)
	return m