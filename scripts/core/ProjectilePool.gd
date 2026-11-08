extends Node
## 单逻辑池：复用基础 Bullet，视觉/碰撞/属性由每次发射的数据重新配置。

var _inactive: Array[Area2D] = []

func acquire(scene: PackedScene, parent: Node) -> Area2D:
	var bullet: Area2D = null
	while bullet == null and not _inactive.is_empty():
		var candidate = _inactive.pop_back()
		if is_instance_valid(candidate):
			bullet = candidate
	if bullet == null:
		bullet = scene.instantiate()
	else:
		bullet.reset_for_reuse()
	if bullet.get_parent() != null:
		bullet.get_parent().remove_child(bullet)
	bullet.remove_from_group("player_bullet")
	bullet.set_meta(&"pooled", true)
	parent.add_child(bullet)
	bullet.add_to_group("player_bullet")
	return bullet

func release(bullet: Area2D) -> void:
	if bullet == null or not is_instance_valid(bullet):
		return
	call_deferred("_release_to_pool", bullet)

func _release_to_pool(bullet: Area2D) -> void:
	if bullet == null or not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
		return
	bullet.visible = false
	bullet.remove_from_group("player_bullet")
	bullet.set_physics_process(false)
	bullet.set_process(false)
	var parent := bullet.get_parent()
	if parent != null:
		parent.remove_child(bullet)
	add_child(bullet)
	_inactive.append(bullet)

func clear() -> void:
	for bullet in _inactive:
		if bullet != null and is_instance_valid(bullet):
			bullet.queue_free()
	_inactive.clear()
