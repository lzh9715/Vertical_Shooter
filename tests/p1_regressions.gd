extends SceneTree
## P1 regressions: collisions, rewards, and clear/death races.
var _flow
var _transition
var _enemy_scene: PackedScene
var _bullet_scene: PackedScene
var _player_scene: PackedScene
var _passed := 0
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_flow = root.get_node("GameFlow")
	_transition = root.get_node("SceneTransition")
	# Load scenes after autoloads are registered.
	_enemy_scene = load("res://scenes/enemies/enemy.tscn")
	_bullet_scene = load("res://scenes/player/bullet.tscn")
	_player_scene = load("res://scenes/player/player.tscn")
	var watchdog := Timer.new()
	watchdog.one_shot = true
	watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(watchdog)
	watchdog.timeout.connect(func():
		push_error("P1 regression suite timed out")
		quit(1)
	)
	watchdog.start(20.0)

	for test_name in [
		"test_enemy_rewards_once",
		"test_nonpiercing_overlap",
		"test_piercing_overlap_limit",
		"test_pierce_damage_falloff",
		"test_homing_target_priority",
		"test_explosion_uses_projectile_damage",
		"test_explosion_once",
		"test_shield_blocks_ordinary_and_pierce_bypasses",
		"test_shield_explosion_bypasses",
		"test_enemy_damage_reduction_cap",
		"test_self_destruct_fuse_survives_death",
		"test_multiple_explosions_take_highest_once",
		"test_charger_damages_only_once",
		"test_clear_then_death",
		"test_death_then_clear",
		"test_normal_clear",
		"test_victory_and_restart",
		"test_request_during_fade_in",
	]:
		await _reset_scene()
		var failures_before := _failed
		if await call(test_name) != true:
			_expect(false, "%s did not finish (runtime error?)" % test_name)
		print("%s %s" % ["PASS" if failures_before == _failed else "FAIL", test_name])

	await _reset_scene()
	print("P1 regressions: %d assertions passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error(message)

func _reset_scene() -> void:
	await _wait_transition()
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	_flow.start_run(load("res://data/Level_01.tres"), 12345)

func _wait_transition() -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while _transition.get("_busy"):
		if Time.get_ticks_msec() >= deadline:
			_expect(false, "scene transition did not complete within 3 seconds")
			return
		await process_frame

func _enemy(at: Vector2, health: int = 100):
	var enemy = _enemy_scene.instantiate()
	enemy.start_position = at
	enemy.speed = 0.0
	enemy.max_hp = health
	current_scene.add_child(enemy)
	return enemy

func _select_battle_node() -> void:
	_flow.current_node = _flow.map.get_node_data(_flow.frontier[0])
	_flow.current_node.type = MapNodeData.NodeType.BATTLE

func test_enemy_rewards_once() -> bool:
	var spawner := EnemySpawner.new()
	current_scene.add_child(spawner)
	var enemy = _enemy(Vector2(1000, 1000), 1)
	enemy.died.connect(spawner._on_enemy_died)
	var battle = load("res://scripts/battle/BattleMain.gd").new()
	spawner.enemy_died.connect(battle._on_enemy_died)
	var gold_before: int = _flow.gold
	var score_before: int = _flow.score
	enemy.take_damage(10)
	enemy.take_damage(10)
	_expect(_flow.gold == gold_before + enemy.gold_reward, "enemy must award gold once per death")
	_expect(_flow.score == score_before + enemy.score_reward, "enemy must award score once per death")
	battle.free()
	return true

func _check_overlap(piercing: bool, limit: int, expected_hits: int) -> bool:
	var enemies: Array = []
	for i in range(3):
		enemies.append(_enemy(Vector2(1000, 1000)))
	var bullet = _bullet_scene.instantiate()
	bullet.position = Vector2(1000, 1000)
	bullet.speed = 0.0
	bullet.damage = 10
	bullet.is_piercing = piercing
	bullet.pierce_amount = limit
	current_scene.add_child(bullet)
	for i in range(4):
		await physics_frame
	await process_frame
	var hits := 0
	for enemy in enemies:
		if enemy.hp < enemy.max_hp:
			hits += 1
	_expect(hits == expected_hits, "overlapping enemies: expected %d hits, got %d" % [expected_hits, hits])
	_expect(not is_instance_valid(bullet), "consumed bullet must be freed")
	return true

func test_nonpiercing_overlap() -> bool:
	return await _check_overlap(false, 1, 1)

func test_piercing_overlap_limit() -> bool:
	return await _check_overlap(true, 2, 2)

func test_pierce_damage_falloff() -> bool:
	var enemies: Array = []
	for i in range(2):
		enemies.append(_enemy(Vector2(1000 + i * 50, 1000)))
	var bullet = _bullet_scene.instantiate()
	bullet.position = Vector2(1000, 1000)
	bullet.damage = 10
	bullet.is_piercing = true
	bullet.pierce_amount = 2
	current_scene.add_child(bullet)
	bullet._hit_target(enemies[0])
	bullet._hit_target(enemies[1])
	_expect(enemies[0].hp == 90, "first pierce hit must deal full damage")
	_expect(enemies[1].hp == 92, "second pierce hit must use 80% falloff")
	_expect(bullet.is_queued_for_deletion(), "bullet must be consumed after its hit budget")
	return true

func test_homing_target_priority() -> bool:
	var first = _enemy(Vector2(1000, 1000))
	var second = _enemy(Vector2(1200, 1000))
	var third = _enemy(Vector2(1400, 1000))
	var bullet = _bullet_scene.instantiate()
	bullet.position = Vector2(1000, 1000)
	bullet.is_homing = true
	bullet.is_piercing = true
	bullet.pierce_amount = 3
	current_scene.add_child(bullet)

	bullet._acquire_target()
	_expect(bullet._target == first, "homing must start with the nearest target")
	bullet._hit_target(first)
	bullet._acquire_target()
	_expect(bullet._target == second, "after a hit, homing must prefer an unvisited target")
	bullet._hit_target(second)
	bullet._visited[third] = true
	bullet._last_hit_target = second
	bullet._acquire_target()
	_expect(bullet._target == first, "after all targets are visited, homing must exclude the previous target")
	return true

func test_explosion_uses_projectile_damage() -> bool:
	var first = _enemy(Vector2(1000, 1000))
	var second = _enemy(Vector2(1030, 1000))
	var third = _enemy(Vector2(1100, 1000))
	var bullet = _bullet_scene.instantiate()
	bullet.position = Vector2(1000, 1000)
	bullet.speed = 0.0
	bullet.damage = 10
	bullet.is_explosive = true
	bullet.explosion_radius = 100.0
	bullet.is_piercing = true
	bullet.pierce_amount = 2
	current_scene.add_child(bullet)

	bullet._hit_target(first)
	_expect(first.hp == 90, "direct hit must use projectile damage")
	_expect(second.hp == 90, "inner explosion radius must use full projectile damage")
	_expect(third.hp == 94, "explosion edge must use 60% falloff")

	bullet._hit_target(first)
	_expect(first.hp == 82, "second direct hit must use 80% falloff")
	_expect(second.hp == 82, "inner explosion must also use fallen-off damage")
	_expect(third.hp == 89, "outer explosion must combine both falloffs")
	_expect(bullet.is_queued_for_deletion(), "bullet must be consumed after its hit budget")
	return true

func test_explosion_once() -> bool:
	var first = _enemy(Vector2(1000, 1000))
	var second = _enemy(Vector2(1400, 1000))
	var bullet = _bullet_scene.instantiate()
	bullet.position = first.position
	bullet.speed = 0.0
	bullet.damage = 10
	bullet.is_explosive = true
	bullet.explosion_radius = 50.0
	current_scene.add_child(bullet)
	# Queued overlap callbacks must not re-trigger a spent bullet.
	bullet._on_area_entered(first)
	bullet._on_area_entered(second)
	var explosions := 0
	for child in current_scene.get_children():
		if child is Polygon2D:
			explosions += 1
	_expect(explosions == 1, "a consumed explosive bullet must explode once")
	_expect(first.hp == 90 and second.hp == 100, "a consumed bullet must ignore later collision callbacks")
	return true

func test_shield_blocks_ordinary_and_pierce_bypasses() -> bool:
	var shield = load("res://scenes/enemies/shield_guard.tscn").instantiate()
	shield.start_position = Vector2(1000, 1000)
	shield.speed = 0.0
	shield.max_hp = 100
	current_scene.add_child(shield)

	var ordinary = _bullet_scene.instantiate()
	ordinary.damage = 10
	current_scene.add_child(ordinary)
	ordinary._hit_target(shield)
	_expect(shield.shield_hp == shield.shield_max - 10, "ordinary bullet must damage the shield")
	_expect(shield.hp == shield.max_hp, "ordinary bullet must not damage the shielded body")

	var piercing = _bullet_scene.instantiate()
	piercing.damage = 10
	piercing.is_piercing = true
	piercing.pierce_amount = 2
	current_scene.add_child(piercing)
	piercing._hit_target(shield)
	_expect(shield.hp == shield.max_hp - 10, "piercing bullet must bypass the shield")
	return true

func test_shield_explosion_bypasses() -> bool:
	var shield = load("res://scenes/enemies/shield_guard.tscn").instantiate()
	shield.start_position = Vector2(1000, 1000)
	shield.speed = 0.0
	shield.max_hp = 100
	current_scene.add_child(shield)

	var explosive = _bullet_scene.instantiate()
	explosive.position = shield.global_position
	explosive.damage = 10
	explosive.is_explosive = true
	explosive.explosion_radius = 100.0
	current_scene.add_child(explosive)
	explosive._hit_target(shield)
	_expect(shield.hp == shield.max_hp - 10, "explosion must bypass the shield and damage the body")
	return true

func test_enemy_damage_reduction_cap() -> bool:
	var enemy = _enemy(Vector2(1000, 1000), 100)
	enemy.defense = 0.0
	enemy.damage_reduction = 2.0
	enemy.take_damage(100)
	_expect(enemy.hp == 75, "enemy damage reduction must be capped at 75%")
	return true

func test_self_destruct_fuse_survives_death() -> bool:
	var self_destruct = load("res://scenes/enemies/self_destruct.tscn").instantiate()
	self_destruct.start_position = Vector2(1000, 1000)
	self_destruct.speed = 0.0
	self_destruct.max_hp = 10
	current_scene.add_child(self_destruct)
	self_destruct.take_damage(100)
	_expect(self_destruct.is_queued_for_deletion(), "killed self-destruct must leave the field")
	var hazards := 0
	var hazard_script = load("res://scripts/enemies/SelfDestructExplosion.gd")
	for child in current_scene.get_children():
		if child.get_script() == hazard_script:
			hazards += 1
	_expect(hazards == 1, "death must create an independent delayed explosion")
	await create_timer(1.7).timeout
	var hazards_after := 0
	for child in current_scene.get_children():
		if child.get_script() == hazard_script:
			hazards_after += 1
	_expect(hazards_after == 0, "self-destruct fuse must clean itself up after exploding")
	return true

func test_multiple_explosions_take_highest_once() -> bool:
	var player = _player_scene.instantiate()
	current_scene.add_child(player)
	player.set_physics_process(false)
	player._stats = EquipmentStats.new()
	var hp_before: float = player.current_hp
	player.queue_explosion_damage(10.0)
	player.queue_explosion_damage(20.0)
	await process_frame
	_expect(is_equal_approx(player.current_hp, hp_before - 20.0),
		"same-frame explosions must apply the highest damage only once")
	return true

func test_charger_damages_only_once() -> bool:
	var player = _player_scene.instantiate()
	current_scene.add_child(player)
	player.set_physics_process(false)
	player._stats = EquipmentStats.new()
	player.global_position = Vector2(1000, 1000)

	var charger = load("res://scenes/enemies/charger.tscn").instantiate()
	charger.start_position = Vector2(1100, 1000)
	charger.speed = 0.0
	charger.attack_power = 15.0
	charger.max_hp = 100
	current_scene.add_child(charger)
	charger._enter_aim()
	charger._physics_process(1.1)
	charger._physics_process(0.1)
	var hp_after_first: float = player.current_hp
	charger._physics_process(0.1)
	_expect(is_equal_approx(hp_after_first, 85.0), "charge must deal contact damage")
	_expect(is_equal_approx(player.current_hp, hp_after_first), "charge must damage the player only once")
	return true

func test_clear_then_death() -> bool:
	_select_battle_node()
	var player = _player_scene.instantiate()
	current_scene.add_child(player)
	player.current_hp = 1.0
	_flow.hp = 1.0
	_flow.finish_node()
	_expect(paused, "combat must pause as soon as node exit begins")
	# Simulate a lethal callback delivered during the clear fade.
	player.take_damage(1000)
	var result: Dictionary = _flow.last_result.duplicate(true)
	player.take_damage(1000)
	player._physics_process(1.0)
	_flow.end_run(true)
	_flow.finish_node()
	_expect(_flow.last_result == result, "repeated death/finish calls must not overwrite the result")
	_expect(player.current_hp == 0.0 and _flow.hp == 0.0, "dead player must not take more damage, regenerate or cast")
	await _wait_transition()
	_expect(current_scene.scene_file_path == _flow.RESULT_SCENE, "death during clear fade must reach ResultScreen")
	_expect(_flow.last_result.get("victory") == false, "death must remain a defeat")
	_expect(_flow.map == null, "death must not silently start a new run")
	_expect(not paused, "result scene must be interactive")
	return true

func test_death_then_clear() -> bool:
	_select_battle_node()
	_flow.hp = 0.0
	_flow.end_run(false)
	_flow.finish_node()
	_flow.end_run(true)
	await _wait_transition()
	_expect(current_scene.scene_file_path == _flow.RESULT_SCENE, "late clear callback must not replace the death destination")
	_expect(_flow.last_result.get("victory") == false, "late victory must not overwrite defeat")
	return true

func test_normal_clear() -> bool:
	_select_battle_node()
	var original_map = _flow.map
	var node_id: int = _flow.current_node.id
	var clear_count: int = _flow.cleared.size()
	var timer_fired := [false]
	var timer := Timer.new()
	timer.one_shot = true
	current_scene.add_child(timer)
	timer.timeout.connect(func(): timer_fired[0] = true)
	timer.start(0.03)
	_flow.finish_node()
	_flow.finish_node()
	await create_timer(0.06).timeout
	_expect(not timer_fired[0], "outgoing scene timers must stop during fade-out")
	await _wait_transition()
	_expect(current_scene.scene_file_path == _flow.MAP_SCENE, "normal clear must return to map")
	_expect(_flow.map == original_map, "normal clear must preserve the run")
	_expect(_flow.cleared.size() == clear_count + 1 and _flow.cleared.has(node_id), "node must be marked cleared exactly once")
	_expect(not paused, "map must be interactive after clear")
	# A request during fade-in must still execute.
	var next_node = _flow.map.get_node_data(_flow.frontier[0])
	next_node.type = MapNodeData.NodeType.START
	_flow.enter_node(next_node)
	await _wait_transition()
	_expect(_flow.cleared.size() == clear_count + 2, "entering the next node must reset the finish guard")
	_expect(_flow.map == original_map and not paused, "consecutive clears must preserve an interactive run")
	return true

func test_victory_and_restart() -> bool:
	_flow.current_node = _flow.map.get_node_data(_flow.map.boss_id)
	_flow.finish_node()
	_flow.finish_node()
	_flow.end_run(false)
	await _wait_transition()
	_expect(current_scene.scene_file_path == _flow.RESULT_SCENE, "boss clear must reach ResultScreen")
	_expect(_flow.last_result.get("victory") == true, "completed victory must not be overwritten by a late death")
	_flow.restart_after_result()
	await _wait_transition()
	_expect(current_scene.scene_file_path == _flow.MAP_SCENE, "restart must return to map")
	_expect(not _flow.is_run_ended() and _flow.current_node == null, "restart must reset terminal state")
	_expect(_flow.cleared.size() == 1 and not paused, "restart must create a fresh interactive run")
	return true

func test_request_during_fade_in() -> bool:
	_transition.change_scene(_flow.MAIN_MENU_SCENE)
	await scene_changed
	# The new scene is active but the previous fade-in is still running.
	_transition.change_scene(_flow.RESULT_SCENE)
	await _wait_transition()
	_expect(current_scene.scene_file_path == _flow.RESULT_SCENE, "scene request during fade-in must eventually execute")
	return true
