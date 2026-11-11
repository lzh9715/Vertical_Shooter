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
var _dead := false
var _pending_explosion_frame := -1
var _pending_explosion_damage := 0.0
var _explosion_queued := false

@onready var shoot_timer: Timer = $ShootTimer
@onready var hurtbox: Area2D = $Hurtbox

func _ready():
	add_to_group("player")
	max_hp = GameFlow.max_hp
	current_hp = GameFlow.hp
	if GameFlow.spell != null:
		current_spell = GameFlow.spell

	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	shoot_timer.stop()
	EventBus.loadout_changed.connect(_rebuild_stats)
	GameFlow.max_hp_changed.connect(_rebuild_stats)
	_rebuild_stats()
	hp_changed.emit(current_hp, max_hp)

	EventBus.steal_spell_requested.connect(_on_steal_spell)
	EventBus.steal_cancelled.connect(_return_stolen_spell)
	EventBus.wand_switched.emit(GameFlow.get_equipment().active_wand_index)

func _rebuild_stats() -> void:
	_stats = GameFlow.get_player_stats()

	max_hp = _stats.max_hp()
	current_hp = minf(GameFlow.hp, max_hp)
	GameFlow.max_hp = max_hp
	GameFlow.hp = current_hp

	GameFlow.max_mana = _stats.max_mana()
	GameFlow.mana = minf(GameFlow.mana, GameFlow.max_mana)
	GameFlow.mana_regen = _stats.mana_regen()
	speed = _stats.move_speed()

	hp_changed.emit(current_hp, max_hp)


func _physics_process(delta):
	if _dead or GameFlow.is_run_ended():
		return
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
	var trigger_blocks: Array = plan.get("trigger_blocks", [])
	for block in action_blocks:
		var modifiers := _block_modifiers(block)
		for card in block:
			if card == null or not card.is_attack():
				continue
			var effect := _card_effect(card)
			_apply_module_effects(effect, modifiers)
			effect["trigger_blocks"] = trigger_blocks
			_fire_volley(effect, body_bonus)
			fired = true

	if not fired:
		# 全模块施法：法力已经提交，不生成弹体
		AudioManager.play_sfx(&"shoot", -12.0)

## 触发链中的后续块：法力在发射时已预付，这里只负责执行弹体。
func fire_trigger_blocks(blocks: Array, origin: Vector2) -> void:
	if blocks.is_empty() or _dead or GameFlow.is_run_ended():
		return
	var block: Array = blocks[0]
	var remaining: Array = blocks.slice(1)
	var body_bonus := 0
	var wand := GameFlow.get_equipment().active_wand()
	if wand != null and wand.body != null:
		body_bonus = wand.body.definition.damage_bonus
	var modifiers := _block_modifiers(block)
	for card in block:
		if card == null or not card.is_attack():
			continue
		var effect := _card_effect(card)
		_apply_module_effects(effect, modifiers)
		effect["trigger_blocks"] = remaining
		_fire_volley(effect, body_bonus, origin)
	AudioManager.play_sfx(&"shoot", -9.0)

func _block_modifiers(block: Array) -> Dictionary:
	var modifiers := {
		"homing": false,
		"piercing": false,
		"pierce_bonus": 0,
		"explosive": false,
		"radius": 0.0,
		"damage_bonus": 0.0,
		"bounce": 0,
		"refract": 0,
		"return": 0,
		"speed_delta": 0.0,
		"lifetime_bonus": 0.0,
		"falloff": 0.8,
		"floor": 0.3,
	}

	for card in block:
		if card == null or not card.is_module():
			continue
		match card.effect_type:
			ItemDefinition.EffectType.HOMING:
				modifiers.homing = true
			ItemDefinition.EffectType.PIERCE:
				modifiers.piercing = true
				modifiers.pierce_bonus += maxi(int(card.effect_value), 1)
				modifiers.falloff = card.damage_falloff
				modifiers.floor = card.damage_floor
			ItemDefinition.EffectType.EXPLOSION:
				modifiers.explosive = true
				modifiers.radius = card.effect_radius
			ItemDefinition.EffectType.DAMAGE:
				modifiers.damage_bonus += card.effect_value
			ItemDefinition.EffectType.BOUNCE:
				modifiers.bounce += maxi(int(card.effect_value), 1)
				modifiers.falloff = card.damage_falloff
				modifiers.floor = card.damage_floor
			ItemDefinition.EffectType.REFRACT:
				modifiers.refract += maxi(int(card.effect_value), 1)
				modifiers.falloff = card.damage_falloff
				modifiers.floor = card.damage_floor
			ItemDefinition.EffectType.RETURN:
				modifiers.return += 1
			ItemDefinition.EffectType.ACCELERATE:
				modifiers.speed_delta += card.effect_value
			ItemDefinition.EffectType.DECELERATE:
				modifiers.speed_delta -= card.effect_value
			ItemDefinition.EffectType.LIFETIME:
				modifiers.lifetime_bonus += card.effect_value

	return modifiers

func _apply_module_effects(effect: Dictionary, modifiers: Dictionary) -> void:
	effect.damage += modifiers.damage_bonus
	effect.bounce = modifiers.bounce
	effect.refract = modifiers.refract
	effect.return_count = modifiers.return
	effect.speed_delta = modifiers.speed_delta
	effect.falloff = modifiers.falloff
	effect.floor = modifiers.floor
	effect.lifetime = maxf(0.1, effect.lifetime + modifiers.lifetime_bonus)
	effect.pierce = 1 + modifiers.pierce_bonus + modifiers.bounce + modifiers.refract
	if modifiers.homing:
		effect.homing = true
	if modifiers.piercing:
		effect.piercing = true
	if modifiers.explosive:
		effect.explosive = true
		effect.radius = modifiers.radius

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
		"bounce": 0,
		"refract": 0,
		"return_count": 0,
		"speed_delta": 0.0,
		"lifetime": card.lifetime,
		"falloff": 0.8,
		"floor": 0.3,
		"offset_type": card.offset_type,
		"offset_angle": card.offset_angle,
		"collision_shape": card.collision_shape,
		"collision_size": card.collision_size,
		"visual_scene": card.visual_scene,
		"crit_chance_bonus": card.crit_chance_bonus,
		"crit_damage_bonus": card.crit_damage_bonus,
		"trigger_type": card.trigger_type,
		"trigger_count": card.trigger_count,
		"copyable": card.copyable,
		"copy_inherits_trigger": card.copy_inherits_trigger,
		"trigger_blocks": [],
	}

	return effect

func _fire_volley(effect: Dictionary, body_bonus: int, origin = null) -> void:
	var count: int = effect.count
	var base_damage: float = (
		float(effect.damage) + float(body_bonus) + _stats.damage_flat
	) * (1.0 + _stats.damage_pct)
	var spawn_position: Vector2 = origin if origin != null else global_position + Vector2(40, 0)

	for i in range(count):
		var bullet = ProjectilePool.acquire(bullet_scene, get_parent())
		bullet.speed = effect.speed

		var crit_chance := clampf(
			_stats.crit_chance() + float(effect.crit_chance_bonus) / 100.0,
			0.0,
			1.0
		)
		var crit := randf() < crit_chance
		var crit_multiplier := _stats.crit_damage() + float(effect.crit_damage_bonus) / 100.0
		var final_damage := base_damage * (crit_multiplier if crit else 1.0)
		bullet.damage = maxi(1, roundi(final_damage))

		bullet.is_homing = effect.homing
		bullet.is_piercing = effect.piercing
		bullet.pierce_amount = effect.pierce
		bullet.is_explosive = effect.explosive
		bullet.explosion_radius = effect.radius
		bullet.damage_falloff = effect.falloff
		bullet.min_damage_ratio = effect.floor
		bullet.bounce_remaining = effect.bounce
		bullet.refract_remaining = effect.refract
		bullet.return_remaining = effect.return_count
		bullet.speed_delta = effect.speed_delta
		bullet.max_lifetime = effect.lifetime
		bullet.lifetime_bonus = 0.0
		bullet.visual_scene = effect.visual_scene
		bullet.use_data_shape = true
		bullet.collision_shape_type = effect.collision_shape
		bullet.collision_size = effect.collision_size
		bullet.trigger_type = effect.trigger_type
		bullet.trigger_remaining = effect.trigger_count
		bullet.trigger_initial_count = effect.trigger_count
		bullet.copyable = effect.copyable
		bullet.copy_inherits_trigger = effect.copy_inherits_trigger
		bullet.trigger_blocks = effect.trigger_blocks
		bullet.refresh_visuals()

		if not ProjectileRegistry.register(bullet, &"player"):
			bullet.queue_free()
			continue
		bullet.global_position = spawn_position

		var angle_offset := 0.0
		if count > 1:
			var total_spread: float = effect.spread * (count - 1)
			angle_offset = deg_to_rad(-total_spread / 2.0 + effect.spread * i)
		if effect.offset_type == ItemDefinition.OffsetType.RANDOM:
			angle_offset += deg_to_rad(randf_range(-effect.offset_angle, effect.offset_angle))
		elif effect.offset_type == ItemDefinition.OffsetType.FIXED:
			angle_offset += deg_to_rad(effect.offset_angle)

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
		if "contact_damage" in area and float(area.contact_damage) >= 0.0:
			contact_damage = float(area.contact_damage)
		elif "attack_power" in area:
			contact_damage = float(area.attack_power)
		if contact_damage > 0.0:
			take_damage(contact_damage)


## 同一物理帧内的多个自爆合并，取最高一次伤害。
func queue_explosion_damage(amount: float) -> void:
	if amount <= 0.0 or _dead or GameFlow.is_run_ended() or is_invincible:
		return

	var frame := Engine.get_physics_frames()
	if frame != _pending_explosion_frame:
		_pending_explosion_frame = frame
		_pending_explosion_damage = 0.0
		_explosion_queued = false

	_pending_explosion_damage = maxf(_pending_explosion_damage, amount)
	if not _explosion_queued:
		_explosion_queued = true
		_apply_pending_explosion.call_deferred()

func _apply_pending_explosion() -> void:
	_explosion_queued = false
	var damage := _pending_explosion_damage
	_pending_explosion_damage = 0.0
	if damage > 0.0 and not is_invincible and not _dead:
		take_damage(damage)


func take_damage(amount: float = 1.0):
	if _dead or GameFlow.is_run_ended():
		return
	AudioManager.play_sfx(&"player_hit")

	var effective := amount
	if _stats != null:
		effective = maxf(amount - _stats.defense(), 1.0)
		effective *= (1.0 - _stats.damage_reduction())

	current_hp = maxf(current_hp - effective, 0.0)
	_dead = current_hp <= 0.0
	GameFlow.hp = current_hp
	hp_changed.emit(current_hp, max_hp)

	if _dead:
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
