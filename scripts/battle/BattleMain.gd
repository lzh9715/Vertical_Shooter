extends Node2D

const BOSS_BAR_SCENE := preload("res://scenes/ui/BossHealthBar.tscn")

@export var test_waves: Array[WaveData] = []   # 直接 F6 跑战斗场景时的调试波次

var _event_active := false
var _event_time_left := 0.0
var _event_timer_label: Label

@onready var score_label: Label = $CanvasLayer/Label
@onready var gold_label: Label = $CanvasLayer/GoldLabel
@onready var hp_label: Label = $CanvasLayer/HpLabel
@onready var wand_label: Label = $CanvasLayer/WandLabel
@onready var camera: Camera2D = $Camera2D
@onready var player_node: Node2D = $player

func _ready() -> void:
	get_tree().paused = false
	AudioManager.play_music(&"battle")

	GameFlow.stats_changed.connect(_refresh_hud)
	EventBus.wand_switched.connect(_on_wand_switched)
	_refresh_hud()
	update_hp_ui(GameFlow.hp, GameFlow.max_hp)
	_on_wand_switched(GameFlow.get_equipment().active_wand_index)

	var player := get_node_or_null("player")
	if player != null and player.has_signal("hp_changed"):
		player.hp_changed.connect(update_hp_ui)

	$Spawner.enemy_died.connect(_on_enemy_died)

	var event_battle := GameFlow.event_context.get("battle") as EventBattle
	if event_battle != null:
		_start_event_battle(event_battle)
		return

	var reward := GameFlow.current_reward as RewardBattle
	if reward != null:
		# 奖励战：小怪不吃难度倍率，打完给金币不给分
		$Spawner.difficulty = null
		$BattleRunner.battle_finished.connect(_on_battle_finished)
		$BattleRunner.run(reward.waves)
		return

	if _is_boss_node():
		_start_boss_fight()
	else:
		$BattleRunner.battle_finished.connect(_on_battle_finished)
		$BattleRunner.run(_resolve_waves())

func _is_boss_node() -> bool:
	return GameFlow.current_node != null \
		and GameFlow.current_node.type == MapNodeData.NodeType.BOSS

func _start_boss_fight() -> void:
	var boss_data: BossData = GameFlow.get_boss()
	if boss_data == null or boss_data.scene == null:
		push_warning("当前关卡没有配置 Boss")
		GameFlow.finish_node()
		return

	var s := ScreenUtil.scale_factor()
	var boss = boss_data.scene.instantiate()
	boss.data = boss_data
	boss.position = Vector2(2800, 720) * s
	add_child(boss)

	var bar = BOSS_BAR_SCENE.instantiate()
	add_child(bar)
	bar.bind(boss)

	boss.boss_died.connect(_on_boss_died)

func _on_boss_died() -> void:
	GameFlow.finish_node()

func _refresh_hud() -> void:
	score_label.text = "分数：%d" % GameFlow.score
	gold_label.text = "金币：%d" % GameFlow.gold

func _on_wand_switched(index: int) -> void:
	wand_label.text = "法杖 %d/2  [Q]" % [index + 1]

func _on_enemy_died(score_gain: int, gold_gain: int) -> void:
	var reward := GameFlow.current_reward as RewardBattle
	if reward != null:
		# 奖励战：金币加成，不给分数
		GameFlow.add_gold(roundi(gold_gain * reward.gold_multiplier))
		return

	GameFlow.add_score(score_gain)
	GameFlow.add_gold(gold_gain)

func _resolve_waves() -> Array[WaveData]:
	if GameFlow.current_node != null:
		return GameFlow.build_waves(GameFlow.current_node)
	return test_waves

func _on_battle_finished() -> void:
	if GameFlow.current_node != null:
		GameFlow.finish_node()
	else:
		print("战斗结束：全部波次已清空（调试模式）")

func update_hp_ui(current: int, max_val: int) -> void:
	hp_label.text = "HP: %d/%d" % [current, max_val]

# ---------- 事件限时战斗 ----------

func _start_event_battle(battle: EventBattle) -> void:
	var boss_data := battle.boss
	if boss_data == null or boss_data.scene == null:
		push_warning("事件战斗缺少 Boss 配置")
		GameFlow.event_context.clear()
		GameFlow.finish_node()
		return

	var s := ScreenUtil.scale_factor()
	var boss = boss_data.scene.instantiate()
	boss.data = boss_data
	boss.position = Vector2(2800, 720) * s
	add_child(boss)

	var bar = BOSS_BAR_SCENE.instantiate()
	add_child(bar)
	bar.bind(boss)

	boss.boss_died.connect(_on_event_boss_died)

	_event_active = true
	_event_time_left = battle.time_limit

	_event_timer_label = Label.new()
	_event_timer_label.position = Vector2(20, 120) * s
	_event_timer_label.add_theme_font_size_override("font_size", int(26 * s))
	_event_timer_label.text = "剩余 %d 秒" % int(ceil(_event_time_left))
	$CanvasLayer.add_child(_event_timer_label)

func _update_camera() -> void:
	if camera == null or player_node == null:
		return

	var y_range := ScreenUtil.camera_y_range()
	camera.position = Vector2(
		ScreenUtil.size().x * 0.5,
		clampf(player_node.global_position.y, y_range.x, y_range.y)
	)

func _process(delta: float) -> void:
	_update_camera()

	if not _event_active:
		return

	if _event_time_left <= 0.0:
		return

	_event_time_left -= delta
	_event_timer_label.text = "剩余 %d 秒" % int(ceil(maxf(_event_time_left, 0.0)))

	if _event_time_left <= 0.0:
		_event_timeout()

func _event_timeout() -> void:
	if not _event_active:
		return

	_event_active = false
	GameFlow.event_context.clear()
	GameFlow.finish_node()

func _on_event_boss_died() -> void:
	if not _event_active:
		return

	_event_active = false

	var battle: EventBattle = GameFlow.event_context.get("battle")
	if battle != null:
		if battle.refund_stolen:
			GameFlow.add_gold(int(GameFlow.event_context.get("stolen", 0)))
		if battle.win_gold > 0:
			GameFlow.add_gold(battle.win_gold)

	GameFlow.event_context.clear()
	GameFlow.finish_node()