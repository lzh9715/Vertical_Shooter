extends Node

var _stolen: SpellData

func _ready() -> void:
	EventBus.spell_stolen.connect(func(s): _stolen = s)

	var player = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2(300, 1080)

	# 给玩家一把法杖（正常流程里由商店/关卡给）
	player.current_spell = load("res://data/spells/Spell_Single.tres")
	GameFlow.spell = player.current_spell

	await get_tree().process_frame
	print("初始法杖 = ", player.current_spell)

	# 偷装备
	EventBus.steal_spell_requested.emit(5.0)
	await get_tree().process_frame
	print("被偷后玩家法杖 = ", player.current_spell)
	print("Boss 收到 = ", _stolen)

	get_tree().quit()