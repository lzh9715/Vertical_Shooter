extends Node

const BOSS_DATA := "res://data/boss/Boss_Test.tres"
const BAR_SCENE := preload("res://scenes/ui/BossHealthBar.tscn")

func _ready() -> void:
	var data: BossData = load(BOSS_DATA)

	# 给玩家一把法杖，方便观察“被偷/归还”
	GameFlow.spell = load("res://data/Spell_Single.tres")

	var player = load("res://player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2(360, 1100)
	player.current_spell = GameFlow.spell

	# 生成 Boss（先赋 data，再入树，_ready 会 apply_data）
	var boss = data.scene.instantiate()
	boss.data = data
	boss.position = Vector2(360, -100)
	add_child(boss)
	# 仅测试用：缩短冷却、概率拉满
	boss.steal_cooldown = 4.0
	boss.steal_chance = 1.0

	var bar = BAR_SCENE.instantiate()
	add_child(bar)
	bar.bind(boss)

	boss.phase_changed.connect(func(i, total): print("阶段切换 → ", i + 1, "/", total))
	EventBus.spell_stolen.connect(func(s): print("法杖被偷：", s))
	EventBus.spell_returned.connect(func(s): print("法杖归还：", s))

	# 等入场结束，然后自动扣血，观察阶段与偷取
	await get_tree().create_timer(2.0, false).timeout

	# 打到 70% 左右（会触发 75% 阈值偷取），然后停手观察概率偷取
	while is_instance_valid(boss) and boss.hp > int(boss.max_hp * 0.7):
		boss.take_damage(40)
		await get_tree().create_timer(0.4, false).timeout

	print("--- 停手 14 秒，观察概率偷取 ---")
	await get_tree().create_timer(14.0, false).timeout
	print("--- 恢复输出 ---")

	while is_instance_valid(boss) and boss.hp > 0:
		boss.take_damage(40)
		await get_tree().create_timer(0.4, false).timeout

	print("Boss 已死亡，玩家法杖 = ", player.current_spell)

	while is_instance_valid(boss) and boss.hp > 0:
		boss.take_damage(40)
		await get_tree().create_timer(0.4, false).timeout

	print("Boss 已死亡")