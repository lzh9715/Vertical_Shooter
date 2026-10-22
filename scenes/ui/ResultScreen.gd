extends Control

## 结算界面：通关与阵亡共用，根据 GameFlow.last_result 显示不同内容。

@onready var title_label: Label = $VBox/Title
@onready var stats_label: Label = $VBox/Stats
@onready var btn_restart: Button = $VBox/BtnRestart
@onready var btn_quit: Button = $VBox/BtnQuit

func _ready() -> void:
	get_tree().paused = false
	btn_restart.pressed.connect(_on_restart)
	btn_quit.pressed.connect(_on_quit)
	_apply(GameFlow.last_result)

func _apply(result: Dictionary) -> void:
	var victory: bool = result.get("victory", false)

	title_label.text = "通关！" if victory else "阵亡"
	title_label.modulate = Color(1.0, 0.85, 0.35) if victory else Color(1.0, 0.45, 0.45)

	var hp: int = int(result.get("hp", 0))
	var max_hp: int = int(result.get("max_hp", 0))
	var hp_text := "%d / %d" % [hp, max_hp] if max_hp > 0 else str(hp)

	stats_label.text = "得分：%d\n金币：%d\n到达节点：%d\n剩余血量：%s" % [
		int(result.get("score", 0)),
		int(result.get("gold", 0)),
		int(result.get("nodes", 0)),
		hp_text,
	]

func _on_restart() -> void:
	GameFlow.restart_after_result()

func _on_quit() -> void:
	get_tree().quit()
