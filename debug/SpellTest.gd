extends Node2D

## 法术测试场：自动射击木桩，可打开背包自由改装配装。
## B 打开背包 / R 重置木桩 / Q 切换法杖

@onready var stats_label: Label = $HUD/Stats
@onready var backpack: CanvasLayer = $BackpackView
@onready var btn_backpack: Button = $HUD/BtnBackpack
@onready var btn_reset: Button = $HUD/BtnReset

var _player: Node2D
var _dummy: Node2D
var _peak_damage := 0

func _ready() -> void:
	GameFlow.start_run(load("res://data/Level_01.tres"))

	# 测试背包：每种法术卡给 3 张，方便反复装配
	var inventory := GameFlow.get_inventory()
	for card in ItemCatalog.cards():
		inventory.add_card(card, 3)

	_player = load("res://scenes/player/player.tscn").instantiate()
	add_child(_player)
	_player.global_position = Vector2(300, 1080)

	_dummy = load("res://scenes/enemies/elite.tscn").instantiate()
	_dummy.max_hp = 1_000_000
	_dummy.start_position = Vector2(2842, 1080)
	_dummy.hover_height = 1920.0
	_dummy.hover_x_jitter = 0.0
	_dummy.speed = 600.0
	_dummy.scale = Vector2(3.0, 3.0)
	_dummy.attack = null
	_dummy.elite_movement = load("res://data/elite_movement/EliteMove_Hover_Gunner.tres").duplicate()
	if _dummy.elite_movement != null:
		_dummy.elite_movement.phase = 0.0
	add_child(_dummy)
	_peak_damage = 0

	btn_backpack.pressed.connect(_toggle_backpack)
	btn_reset.pressed.connect(_reset_dummy)
	stats_label.text = _stats_text()

func _process(_delta: float) -> void:
	stats_label.text = _stats_text()

func _stats_text() -> String:
	if _dummy == null:
		return ""
	var damage: int = maxi(_dummy.max_hp - _dummy.hp, 0)
	_peak_damage = maxi(_peak_damage, damage)
	var wand_index: int = GameFlow.get_equipment().active_wand_index
	return "HP：%d/%d    法力：%d/%d    法杖：%d/2    木桩总伤害：%d    最高：%d" % [
		ceili(GameFlow.hp), ceili(GameFlow.max_hp),
		ceili(GameFlow.mana), ceili(GameFlow.max_mana),
		wand_index + 1, damage, _peak_damage,
	]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_B:
			_toggle_backpack()
			get_viewport().set_input_as_handled()
		KEY_R:
			_reset_dummy()
			get_viewport().set_input_as_handled()

func _toggle_backpack() -> void:
	if backpack.visible:
		backpack.close()
	else:
		backpack.open()

func _reset_dummy() -> void:
	if _dummy == null:
		return
	_dummy.hp = _dummy.max_hp
	_peak_damage = 0
	stats_label.text = _stats_text()
