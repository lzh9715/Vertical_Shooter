extends Node

var _stolen: SpellData

func _ready() -> void:
	EventBus.spell_stolen.connect(func(s): _stolen = s)

	var player = load("res://player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2(360, 1000)

	# 给玩家一把法杖（正常流程里由商店/关卡给）
	player.current_spell = load("res://data/Spell_Single.tres")
	GameFlow.spell = player.current_spell

	await get_tree().process_frame
	print("初始法杖 = ", player.current_spell)
	print("初始速度倍率 = ", player._speed_mult)

	# 减速 0.3 秒，半速
	EventBus.debuff_requested.emit(&"slow", 0.3, 0.5)
	await get_tree().process_frame
	print("减速中 = ", player._speed_mult)

	await get_tree().create_timer(0.5, false).timeout
	print("减速结束 = ", player._speed_mult)

	# 偷装备
	EventBus.steal_spell_requested.emit()
	await get_tree().process_frame
	print("被偷后玩家法杖 = ", player.current_spell)
	print("Boss 收到 = ", _stolen)

	get_tree().quit()