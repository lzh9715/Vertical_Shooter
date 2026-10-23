extends Node
## 全局伤害数字。敌人/Boss 受伤时调用 spawn()。

const MAX_NUMBERS := 60

func spawn(world_position: Vector2, amount: int, color := Color.WHITE) -> void:
	if amount <= 0:
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	if get_tree().get_nodes_in_group("damage_number").size() >= MAX_NUMBERS:
		return

	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 100

	scene.add_child(label)
	label.global_position = world_position + Vector2(randf_range(-14.0, 14.0), -28.0)
	label.add_to_group("damage_number")

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 42.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(label.queue_free)
