extends Area2D

@export var speed := 200.0

var start_position := Vector2.ZERO 
var offset := Vector2.ZERO         
var path_type := "Straight"        
var direction := "Top_To_Bottom"   
var elapsed_time := 0.0            

func _physics_process(delta):
	elapsed_time += delta
	
	# 1. 计算基础位移（根据方向决定主轴）
	var base_x = start_position.x
	var base_y = start_position.y
	
	if direction == "Top_To_Bottom":
		base_y += speed * elapsed_time
	elif direction == "Left_To_Right":
		base_x += speed * elapsed_time
	elif direction == "Right_To_Left":
		base_x -= speed * elapsed_time
	
	# 2. 计算副轴偏移（完全独立的函数计算）
	var wave_offset = 0.0
	if path_type == "Sine":
		wave_offset = 150.0 * sin(elapsed_time * 3.0)
	elif path_type == "Zigzag":
		var freq = 2.0
		var amp = 100.0
		var phase = fmod(elapsed_time * freq, 2.0)
		wave_offset = amp * (1.0 - abs(phase - 1.0)) * (1 if int(elapsed_time * freq) % 2 == 0 else -1)
	
	# 3. 将波浪偏移加到正确的轴上
	if direction == "Top_To_Bottom":
		base_x += wave_offset # 从上往下飞，波浪在 X 轴（左右扭动）
	else:
		base_y += wave_offset # 从左右飞，波浪在 Y 轴（上下扭动）
	
	# 4. 最终位置
	global_position = Vector2(base_x, base_y) + offset
	
	# 5. 越界销毁（全方位覆盖）
	if global_position.y > 1400 or global_position.y < -300 or global_position.x < -300 or global_position.x > 1000:
		queue_free()

