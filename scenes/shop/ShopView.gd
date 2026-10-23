extends Control

@onready var rest_station: RestStation = $RestStation

func _ready() -> void:
	get_tree().paused = false
	AudioManager.play_music(&"shop")
	rest_station.close_button_text = "离开商店"
	rest_station.closed.connect(_on_closed)
	rest_station.open()

func _on_closed() -> void:
	GameFlow.finish_node()