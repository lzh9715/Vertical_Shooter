extends CanvasLayer

func _process(_delta):
	# 只要按下 ESC，就通知主节点切换状态
	if Input.is_action_just_pressed("ui_cancel"):
		get_parent().toggle_rest_station()