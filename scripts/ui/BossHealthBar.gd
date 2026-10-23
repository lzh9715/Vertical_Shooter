extends CanvasLayer

@onready var bar: ProgressBar = $Bar
@onready var name_label: Label = $NameLabel
@onready var hp_label: Label = $HpLabel

var _base_title := "Boss"

func bind(boss: BaseBoss) -> void:
	_base_title = boss.display_name
	name_label.text = _base_title
	bar.max_value = boss.max_hp
	bar.value = boss.hp
	hp_label.text = "%d / %d" % [boss.hp, boss.max_hp]

	boss.hp_changed.connect(_on_hp_changed)
	boss.phase_changed.connect(_on_phase_changed)

func _on_hp_changed(current: int, max_hp: int) -> void:
	bar.max_value = max_hp
	bar.value = current
	hp_label.text = "%d / %d" % [current, max_hp]

func _on_phase_changed(index: int, total: int) -> void:
	name_label.text = "%s  阶段 %d/%d" % [_base_title, index + 1, total]
