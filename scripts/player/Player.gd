extends CharacterBody2D

signal hp_changed(current: float, max_hp: float)   # HUD 自己订阅，玩家不需要知道谁在显示血量

@export var speed := 400.0
@export var bullet_scene: PackedScene # 这个变量用来在编辑器里装子弹场景
@export var current_spell: SpellData # 玩家当前装备的法术

# 👇 新增血量相关变量
@export var max_hp := 100.0
var current_hp := 100.0
var is_invincible := false # 是否无敌

var _stolen_spell: SpellData
var _steal_left := 0.0
var _wand_runtimes: Dictionary = {}
var _legacy_cooldown := 0.0
var _iframe_generation := 0
var _stats: EquipmentStats = EquipmentStats.new()

@onready var shoot_timer: Timer = $ShootTimer
@onready var hurtbox: Area2D = $Hurtbox

func _ready():
	max_hp = GameFlow.max_hp
	current_hp = GameFlow.hp
	if GameFlow.spell != null:
		current_spell = GameFlow.spell

	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	shoot_timer.stop()
	EventBus.loadout_changed.connect(_rebuild_stats)
	_rebuild_stats()
	hp_changed.emit(current_hp, max_hp)

	EventBus.steal_spell_requested.connect(_on_steal_spell)
	EventBus.steal_cancelled.connect(_return_stolen_spell)
	EventBus.wand_switched.emit(GameFlow.get_equipment().active_wand_index)

func _rebuild_stats() -> void:
	_stats = EquipmentStats.compute(GameFlow.get_equipment())

	max_hp = _stats.max_hp()
	current_hp = minf(current_hp, max_hp)
	GameFlow.max_hp = max_hp
	GameFlow.hp = current_hp

	GameFlow.max_mana = _stats.max_mana()
	GameFlow.mana = minf(GameFlow.mana, GameFlow.max_mana)
	GameFlow.mana_regen = _stats.mana_regen()
	speed = _stats.move_speed()

	hp_changed.emit(current_hp, max_hp)


func _physics_process(delta):
	_tick_steal(delta)
	_regen_mana(delta)
	_regen_hp(delta)
	_tick_cast(delta)

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	var world := ScreenUtil.world_size()
	position.x = clamp(position.x, 40, world.x - 40)
	position.y = clamp(position.y, 40, world.y - 40)

func _regen_mana(delta: float) -> void:
	if GameFlow.mana < GameFlow.max_mana:
		GameFlow.mana = minf(GameFlow.max_mana, GameFlow.mana + GameFlow.mana_regen * delta)

func _regen_hp(delta: float) -> void:
	if current_hp >= max_hp:
		return
	current_hp = minf(max_hp, current_hp + _stats.hp_regen() * delta)
	GameFlow.hp = current_hp
	hp_changed.emit(current_hp, max_hp)

func _tick_cast(delta: float) -> void:
	var wand := GameFlow.get_equipment().active_wand()
	if wand == null or wand.body == null:
		_tick_legacy(delta)
		return

	var runtime := _runtime_for(wand)
	runtime.tick(delta)

	var plan := runtime.attempt(current_hp)
	if plan.status == "wait":
		return

	if plan.status == "skip":
		runtime.commit(plan)
		return

	if plan.hp_cost > 0.0:
		if not apply_overdraft(plan.hp_cost):
			return

	runtime.commit(plan)
	_fire_plan(plan)

func _runtime_for(wand: WandInstance) -> WandCastRuntime:
	if not _wand_runtimes.has(wand):
		_wand_runtimes[wand] = WandCastRuntime.new(wand)
	return _wand_runtimes[wand]

func _tick_legacy(delta: float) -> void:
	_legacy_cooldown = maxf(_legacy_cooldown - delta, 0.0)
	if _legacy_cooldown > 0.0 or current_spell == null:
		return
	_shoot_legacy_spell(current_spell)
	_legacy_cooldown = 0.2

func _fire_plan(plan: Dictionary) -> void:
	var body_bonus := 0
	var wand := GameFlow.get_equipment().active_wand()
	if wand != null and wand.body != null:
		body_bonus = wand.body.definition.damage_bonus

	var action_blocks: Array = plan.get("action_blocks", [])
	if action_blocks.is_empty():
		return

	var fired := false
	for block in action_blocks:
		var modifiers := _block_modifiers(block)
		for card in block:
			if card == null or not card.is_attack():
				continue
			var effect := _card_effect(card)
			_apply_module_effects(effect, modifiers)
			_fire_volley(effect, body_bonus)
			fired = true

	if not fired:
		# 全模块施法：法力已经提交，不生成弹体
		AudioManager.play_sfx(&"shoot", -12.0)

func _block_modifiers(block: Array) -> Dictionary:
	var modifiers := {
		"homing": false,
		"piercing": false,
		"pierce": 1,
		"explosive": false,
		"radius": 0.0,
		"explosion_damage": 0.0,
		"damage_bonus": 0.0,
	}

	for card in block:
		if card == null or not card.is_module():
			continue
		match card.effect_type:
			ItemDefinition.EffectType.HOMING:
				modifiers.homing = true
			ItemDefinition.EffectType.PIERCE:
				modifiers.piercing = true
				modifiers.pierce = maxi(int(card.effect_value), 1)
			ItemDefinition.EffectType.EXPLOSION:
				modifiers.explosive = true
				modifiers.radius = card.effect_radius
				modifiers.explosion_damage += card.effect_value
			ItemDefinition.EffectType.DAMAGE:
				modifiers.damage_bonus += card.effect_value

	return modifiers

func _apply_module_effects(effect: Dictionary, modifiers: Dictionary) -> void:
	effect.damage += modifiers.damage_bonus
	if modifiers.homing:
		effect.homing = true
	if modifiers.piercing:
		effect.piercing = true
		effect.pierce = modifiers.pierce
	if modifiers.explosive:
		effect.explosive = true
		effect.radius = modifiers.radius
		effect.explosion_damage = modifiers.explosion_damage

func apply_overdraft(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if current_hp - cost <= 0.0:
		return false

	current_hp -= cost
	GameFlow.hp = current_hp
	hp_changed.emit(current_hp, max_hp)
	_grant_invincibility()
	return true

func _grant_invincibility() -> void:
	_iframe_generation += 1
	var generation := _iframe_generation
	is_invincible = true
	var tween = create_tween()
	tween.set_loops(6)
	tween.tween_property(self, "modulate:a", 0.2, 0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(1.2, false).timeout
	if generation != _iframe_generation:
		return
	modulate.a = 1.0
	is_invincible = false

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
		"damage": 1,
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
		"count": card.projectile_count,
		"spread": card.spread_angle,
		"speed": card.projectile_speed,
		"damage": card.base_damage,
		"homing": false,
		"piercing": false,
		"pierce": 1,
		"explosive": false,
		"radius": 0.0,
		"explosion_damage": 0.0,
	}

	return effect

func _fire_volley(effect: Dictionary, body_bonus: int) -> void:
	var count: int = effect.count
	var base_damage: float = (
		float(effect.damage) + float(body_bonus) + _stats.damage_flat
	) * (1.0 + _stats.damage_pct)

	for i in range(count):
		var bullet = bullet_scene.instantiate()
		bullet.speed = effect.speed

		var crit := randf() < _stats.crit_chance()
		var final_damage := base_damage * (_stats.crit_damage() if crit else 1.0)
		bullet.damage = maxi(1, roundi(final_damage))

		var explosion_base: float = (
			float(effect.explosion_damage) + float(body_bonus) + _stats.damage_flat
		) * (1.0 + _stats.damage_pct)
		bullet.explosion_damage = maxi(0, roundi(explosion_base))

		bullet.is_homing = effect.homing
		bullet.is_piercing = effect.piercing
		bullet.pierce_amount = effect.pierce
		bullet.is_explosive = effect.explosive
		bullet.explosion_radius = effect.radius

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
		var dmg: float = 1.0
		if "damage" in area:
			dmg = float(area.damage)
		area.queue_free()
		if not is_invincible:
			take_damage(dmg)
		return

	# 撞到敌人本体
	if area.is_in_group("enemy") and not is_invincible:
		var contact_damage := 1.0
		if "attack_power" in area:
			contact_damage = float(area.attack_power)
		take_damage(contact_damage)


func take_damage(amount: float = 1.0):
	AudioManager.play_sfx(&"player_hit")

	var effective := amount
	if _stats != null:
		effective = maxf(amount - _stats.defense(), 1.0)
		effective *= (1.0 - _stats.damage_reduction())

	current_hp -= effective
	GameFlow.hp = current_hp
	hp_changed.emit(current_hp, max_hp)

	if current_hp <= 0.0:
		GameFlow.end_run()
		return

	_grant_invincibility()


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