extends Node
## 全局射弹注册表：玩家与敌人共享 400 总上限。
## 强制回收走 evict()，绝不触发回旋/触发链/爆炸。

const MAX_PROJECTILES := 400

var _active: Array[Node] = []

func count() -> int:
	return _active.size()

func register(node: Node, kind: StringName = &"player") -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if _active.size() >= MAX_PROJECTILES:
		if not _evict_one():
			return false
	node.set_meta(&"projectile_kind", kind)
	_active.append(node)
	node.tree_exiting.connect(_on_tree_exiting.bind(node), CONNECT_ONE_SHOT)
	return true

func _on_tree_exiting(node: Node) -> void:
	_active.erase(node)

func _priority(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	if node.has_meta(&"projectile_kind") and node.get_meta(&"projectile_kind") == &"enemy":
		return 1
	if "trigger_remaining" in node and int(node.trigger_remaining) > 0:
		return 5
	if "return_remaining" in node and int(node.return_remaining) > 0:
		return 4
	if "is_copy" in node and bool(node.is_copy):
		return 3
	return 2

func _evict_one() -> bool:
	var victim: Node = null
	var victim_priority := 99
	for node in _active:
		if node == null or not is_instance_valid(node):
			continue
		var p := _priority(node)
		if p < victim_priority:
			victim_priority = p
			victim = node
	if victim == null or victim_priority >= 5:
		return false
	if victim.has_method("evict"):
		victim.evict()
	else:
		victim.queue_free()
	_active.erase(victim)
	return true

func clear() -> void:
	for node in _active:
		if node != null and is_instance_valid(node):
			if node.has_method("evict"):
				node.evict()
			else:
				node.queue_free()
	_active.clear()
