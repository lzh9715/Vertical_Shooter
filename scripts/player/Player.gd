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
	EventBus.wand_switched.emit(GameFlow.get_equipment().active_wand_index)


func _physics_process(delta):
	_tick_steal(delta)

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	var world := ScreenUtil.world_size()
	position.x = clamp(position.x, 40, world.x - 40)
	position.y = clamp(position.y, 40, world.y - 40)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		var eq := GameFlow.get_equipment()
		var next_index := 1 - eq.active_wand_index
		if eq.switch_wand(next_index):
			EventBus.wand_switched.emit(next_index)
			get_viewport().set_input_as_handled()

# 当计时器倒计时结束时，自动调用这个函数
func _on_shoot_timer_timeout():
	var wand := GameFlow.get_equipment().active_wand()
	if wand != null:
		_shoot_wand(wand)
		return

	# 没有装配法杖时，保留旧 SpellData 作为过渡
	if current_spell == null or bullet_scene == null:
		return
	_shoot_legacy_spell(current_spell)

func _shoot_wand(wand: WandInstance) -> void:
	if wand.body == null or wand.cards.is_empty() or bullet_scene == null:
		return

	var card := wand.next_card()
	if card == null:
		return

	var effect := _card_effect(card)
	var body_bonus: int = wand.body.definition.damage_bonus
	_fire_volley(effect, body_bonus)

func _shoot_legacy_spell(spell: SpellData) -> void:
	var effect := {
		"count": spell.bullet_count,
		"spread": spell.spread_angle,
		"speed": spell.bullet_speed,
		"homing": spell.is_homing,
		"piercing": spell.is_piercing,
		"pierce": spell.pierce_amount,
		"explosive": spell.is_explosive,
		"radius": spell.explosion_radius,
		"explosion_damage": spell.explosion_damage,
	}
	_fire_volley(effect, 0)

func _card_effect(card: ItemDefinition) -> Dictionary:
	var effect := {
		"count": 1,
		"spread": 0.0,
		"speed": 800.0,
		"homing": false,
		"piercing": false,
		"pierce": 1,
		"explosive": false,
		"radius": 0.0,
		"explosion_damage": 0,
	}

	match card.id:
		&"card_spread":
			effect.count = 3
			effect.spread = 15.0
		&"card_homing":
			effect.homing = true
		&"card_pierce":
			effect.piercing = true
			effect.pierce = 3
		&"card_boom":
			effect.explosive = true
			effect.radius = 100.0
			effect.explosion_damage = 3

	return effect

func _fire_volley(effect: Dictionary, body_bonus: int) -> void:
	var count: int = effect.count
	for i in range(count):
		var bullet = bullet_scene.instantiate()
		bullet.speed = effect.speed
		bullet.damage = 1 + body_bonus
		bullet.is_homing = effect.homing
		bullet.is_piercing = effect.piercing
		bullet.pierce_amount = effect.pierce
		bullet.is_explosive = effect.explosive
		bullet.explosion_radius = effect.radius
		bullet.explosion_damage = int(effect.explosion_damage) + body_bonus

		get_parent().add_child(bullet)
		bullet.global_position = global_position + Vector2(40, 0)

		var angle_offset := 0.0
		if count > 1:
			var total_spread: float = effect.spread * (count - 1)
			angle_offset = deg_to_rad(-total_spread / 2.0 + effect.spread * i)

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