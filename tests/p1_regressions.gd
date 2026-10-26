extends SceneTree
## P1 回归：真实碰撞、单次奖励、节点结束与死亡结算。

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
	# --script 的入口先于 autoload 编译；等单例注册后再加载依赖它们的场景。
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
		"test_explosion_once",
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
		if enemy.hp == 90:
			hits += 1
	_expect(hits == expected_hits, "overlapping enemies: expected %d hits, got %d" % [expected_hits, hits])
	_expect(not is_instance_valid(bullet), "consumed bullet must be freed")
	return true

func test_nonpiercing_overlap() -> bool:
	return await _check_overlap(false, 1, 1)

func test_piercing_overlap_limit() -> bool:
	return await _check_overlap(true, 2, 2)

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
	# 同一物理帧可能排队送达多个 area_entered；queue_free 不能取消这些回调。
	bullet._on_area_entered(first)
	bullet._on_area_entered(second)
	var explosions := 0
	for child in current_scene.get_children():
		if child is Polygon2D:
			explosions += 1
	_expect(explosions == 1, "a consumed explosive bullet must explode once")
	_expect(first.hp == 90 and second.hp == 100, "a consumed bullet must ignore later collision callbacks")
	return true

func test_clear_then_death() -> bool:
	_select_battle_node()
	var player = _player_scene.instantiate()
	current_scene.add_child(player)
	player.current_hp = 1.0
	_flow.hp = 1.0
	_flow.finish_node()
	_expect(paused, "combat must pause as soon as node exit begins")
	# 模拟同帧已经送达的致死回调；它必须覆盖待执行的回地图跳转。
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
	# 没有战斗的节点也必须能连续完成，不能被上个节点的结束标记锁住。
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
	# 新场景已进入，但旧淡入仍在运行；这时的后续请求也不能被丢弃。
	_transition.change_scene(_flow.RESULT_SCENE)
	await _wait_transition()
	_expect(current_scene.scene_file_path == _flow.RESULT_SCENE, "scene request during fade-in must eventually execute")
	return true
