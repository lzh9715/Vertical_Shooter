extends Node2D

@export var test_waves: Array[WaveData] = []   # 直接 F6 跑战斗场景时的调试波次

@onready var score_label: Label = $CanvasLayer/Label
@onready var gold_label: Label = $CanvasLayer/GoldLabel
@onready var hp_label: Label = $CanvasLayer/HpLabel

func _ready() -> void:
	get_tree().paused = false

	GameFlow.stats_changed.connect(_refresh_hud)
	_refresh_hud()
	update_hp_ui(GameFlow.hp, GameFlow.max_hp)

	var player := get_node_or_null("player")
	if player != null and player.has_signal("hp_changed"):
		player.hp_changed.connect(update_hp_ui)

	$Spawner.enemy_died.connect(_on_enemy_died)

	$BattleRunner.battle_finished.connect(_on_battle_finished)
	$BattleRunner.run(_resolve_waves())

func _refresh_hud() -> void:
	score_label.text = "Score: %d" % GameFlow.score
	gold_label.text = "金币: %d" % GameFlow.gold

func _on_enemy_died(score_gain: int, gold_gain: int) -> void:
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