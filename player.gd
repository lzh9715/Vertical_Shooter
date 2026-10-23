extends CharacterBody2D

signal hp_changed(current: int, max_hp: int)   # HUD 自己订阅，玩家不需要知道谁在显示血量

@export var speed := 400.0
@export var bullet_scene: PackedScene # 这个变量用来在编辑器里装子弹场景
@export var current_spell: SpellData # 玩家当前装备的法术

# 👇 新增血量相关变量
@export var max_hp := 3
var current_hp := 3
var is_invincible := false # 是否无敌

var _stolen_spell: SpellData
var _steal_left := 0.0

@onready var shoot_timer: Timer = $ShootTimer
@onready var hurtbox: Area2D = $Hurtbox

func _ready():
	max_hp = GameFlow.max_hp
	current_hp = GameFlow.hp
	if GameFlow.spell != null:
		current_spell = GameFlow.spell

	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	hp_changed.emit(current_hp, max_hp)

	EventBus.steal_spell_requested.connect(_on_steal_spell)
	EventBus.steal_cancelled.connect(_return_stolen_spell)


func _physics_process(delta):
	_tick_steal(delta)

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	var world := ScreenUtil.world_size()
	position.x = clamp(position.x, 40, world.x - 40)
	position.y = clamp(position.y, 40, world.y - 40)

# 当计时器倒计时结束时，自动调用这个函数

func _on_shoot_timer_timeout():
	# 如果没装备法杖或者子弹场景没拖，就退出
	if current_spell == null or bullet_scene == null:
		return
	
	# 核心逻辑：根据当前法杖的 bullet_count，循环生成子弹
	for i in range(current_spell.bullet_count):
		var bullet = bullet_scene.instantiate()
		
		# 把法杖的速度赋给子弹（需要子弹脚本里也有 speed 变量，你之前写过）
		bullet.speed = current_spell.bullet_speed 

		# 【新增这行】把法杖里的追踪开关赋给子弹
		bullet.is_homing = current_spell.is_homing
		# 在 bullet.is_homing = current_spell.is_homing 下面加上这几行：
		bullet.is_piercing = current_spell.is_piercing
		bullet.pierce_amount = current_spell.pierce_amount
		bullet.is_explosive = current_spell.is_explosive
		bullet.explosion_radius = current_spell.explosion_radius 
		bullet.explosion_damage = current_spell.explosion_damage
		
		get_parent().add_child(bullet)
		bullet.global_position = global_position + Vector2(40, 0)
		
		# 处理散射角度
		# 计算角度偏移，让它是以正上方为中心扇形散开
		var angle_offset = 0.0
		if current_spell.bullet_count > 1:
			# 比如3发，角度偏移就是 -15, 0, 15
			var total_spread = current_spell.spread_angle * (current_spell.bullet_count - 1)
			angle_offset = deg_to_rad(-total_spread / 2.0 + current_spell.spread_angle * i)
		
		# 让子弹旋转
		bullet.rotation = angle_offset

	AudioManager.play_sfx(&"shoot", -6.0)

# 👇 新增受击逻辑
func _on_hurtbox_area_entered(area):
	# 敌方子弹：先销毁子弹，再按无敌状态决定是否扣血
	if area.is_in_group("enemy_bullet"):
		var dmg: int = 1
		if "damage" in area:
			dmg = int(area.damage)
		area.queue_free()
		if not is_invincible:
			take_damage(dmg)
		return

	# 撞到敌人本体
	if area.is_in_group("enemy") and not is_invincible:
		take_damage()


func take_damage(amount: int = 1):
	AudioManager.play_sfx(&"player_hit")
	current_hp -= amount
	GameFlow.hp = current_hp
	hp_changed.emit(current_hp, max_hp)

	if current_hp <= 0:
		GameFlow.end_run()
		return

	# 触发无敌闪烁
	is_invincible = true

	# 闪烁效果（用 Tween 改变透明度）
	var tween = create_tween()
	tween.set_loops(6) # 闪烁 6 次
	tween.tween_property(self, "modulate:a", 0.2, 0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)

	# 1.2 秒后解除无敌，恢复透明度
	await get_tree().create_timer(1.2, false).timeout
	modulate.a = 1.0
	is_invincible = false


func _on_steal_spell(duration: float) -> void:
	if current_spell == null or _stolen_spell != null:
		return

	_stolen_spell = current_spell
	current_spell = null
	GameFlow.spell = null
	_steal_left = maxf(duration, 1.0)
	EventBus.spell_stolen.emit(_stolen_spell)

func _tick_steal(delta: float) -> void:
	if _stolen_spell == null:
		return

	_steal_left -= delta
	if _steal_left <= 0.0:
		_return_stolen_spell()

func _return_stolen_spell() -> void:
	if _stolen_spell == null:
		return

	current_spell = _stolen_spell
	GameFlow.spell = _stolen_spell
	EventBus.spell_returned.emit(_stolen_spell)
	_stolen_spell = null
	_steal_left = 0.0