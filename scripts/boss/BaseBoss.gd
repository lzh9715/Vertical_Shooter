extends Area2D
class_name BaseBoss

signal hp_changed(current: int, max_hp: int)
signal phase_changed(index: int, total: int)
signal boss_died

@export var data: BossData

@export_group("偷取机制")
@export var steal_duration := 5.0
@export var steal_cooldown := 25.0
@export_range(0.0, 1.0) var steal_chance := 0.3
@export var steal_thresholds: Array[float] = [0.75, 0.5, 0.25]

var display_name := "Boss"
var max_hp := 600
var hp := 0
var phases: Array[BossPhaseData] = []
var phase_index := -1
var invincible := false

var _state := "enter"
var _enter_t := 0.0
var _enter_duration := 1.5
var _from := Vector2.ZERO
var _hover := Vector2(1920, 720)
var _drift_t := 0.0

var _attack_timer := 0.0
var _step := 0
var _left := 0
var _transitioning := false

var _stealing := false
var _steal_timer := 0.0
var _steal_cd_left := 0.0
var _threshold_used: Array[bool] = []

@onready var polygon: Polygon2D = $Polygon2D
@onready var body: Sprite2D = $Body

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")

	if data != null:
		apply_data(data)
	else:
		hp = max_hp

	_from = global_position
	_hover = _hover * ScreenUtil.scale_factor()

	_threshold_used.resize(steal_thresholds.size())
	_threshold_used.fill(false)
	_steal_cd_left = steal_cooldown

	EventBus.spell_returned.connect(_on_spell_returned)
	hp_changed.emit(hp, max_hp)

## 深拷贝配置，保证分裂/运行时修改互不影响
func apply_data(d: BossData) -> void:
	data = d
	var copy: BossData = d.duplicate(true)
	display_name = copy.display_name
	max_hp = copy.max_hp
	hp = max_hp
	phases = copy.phases
	_enter_duration = copy.enter_duration
	_hover = copy.hover_position
	scale = Vector2.ONE * copy.visual_scale

	if copy.texture != null:
		body.texture = copy.texture
		body.visible = true
		polygon.visible = false

func _physics_process(delta: float) -> void:
	match _state:
		"enter": _tick_enter(delta)
		"fight": _tick_fight(delta)

func _tick_enter(delta: float) -> void:
	_enter_t += delta
	var t := clampf(_enter_t / maxf(_enter_duration, 0.1), 0.0, 1.0)
	global_position = _from.lerp(_hover, t)

	if t >= 1.0:
		_state = "fight"
		invincible = false
		_apply_phase()

func _tick_fight(delta: float) -> void:
	_update_phase()
	_tick_move(delta)
	_tick_attack(delta)
	_update_steal(delta)

func _update_phase() -> void:
	if _transitioning:
		return

	var ratio := float(hp) / float(max_hp)
	var target := -1
	for i in range(phases.size()):
		if ratio <= phases[i].hp_threshold:
			target = i

	if target == phase_index:
		return

	phase_index = target
	_apply_phase()
	phase_changed.emit(phase_index, phases.size())
	AudioManager.play_sfx(&"boss_phase")

	_transitioning = true
	invincible = true
	_phase_flash()          # ← 新增
	await get_tree().create_timer(0.6, false).timeout
	invincible = false
	_transitioning = false

func _apply_phase() -> void:
	if phase_index < 0:
		return

	_drift_t = 0.0
	_step = 0
	_left = 0
	var pattern: EnemyAttackPattern = phases[phase_index].attack
	_attack_timer = pattern.start_delay if pattern != null else 0.0

func _tick_move(delta: float) -> void:
	if phase_index < 0:
		return

	_drift_t += delta
	var off := Vector2.ZERO
	if phases[phase_index].movement != null:
		var raw := phases[phase_index].movement.offset_at(_drift_t)
		# 横版：Boss 落位后只做上下移动，把横向幅度映射到 y 轴
		off = Vector2(0.0, raw.x + raw.y) * ScreenUtil.scale_factor()

	global_position = _hover + off

func _tick_attack(delta: float) -> void:
	if phase_index < 0:
		return

	var pattern: EnemyAttackPattern = phases[phase_index].attack
	if pattern == null or pattern.steps.is_empty():
		return

	_attack_timer -= delta
	if _attack_timer > 0.0:
		return

	var step: AttackStep = pattern.steps[_step]
	if _left <= 0:
		_left = maxi(step.repeat, 1)

	_fire(step.volley)
	_left -= 1

	if _left > 0:
		_attack_timer = step.gap
	else:
		_attack_timer = step.cooldown
		_step = (_step + 1) % pattern.steps.size()

func _fire(volley: EnemyBulletPattern) -> void:
	if volley == null:
		return

	var aim := Vector2.LEFT
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		aim = player.global_position - global_position

	var scene := volley.bullet_scene
	if scene == null:
		scene = preload("res://scenes/enemies/enemy_bullet.tscn")

	for dir in volley.build_directions(aim):
		var b = scene.instantiate()
		b.direction = dir
		b.speed = volley.speed * ScreenUtil.scale_factor()
		b.damage = volley.damage
		b.tint = volley.tint
		b.radius = volley.radius
		get_parent().add_child(b)
		b.global_position = global_position

# ---------- 受伤 / 死亡 ----------

func take_damage(amount: int) -> void:
	if invincible or _state == "dead":
		return

	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	DamageNumbers.spawn(global_position, amount, Color(1.0, 0.85, 0.4))
	AudioManager.play_sfx(&"boss_hit", -5.0)
	_flash()

	if hp <= 0:
		_die()

func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2.2, 2.2, 2.2), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func _phase_flash() -> void:
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func _die() -> void:
	_state = "dead"
	invincible = true

	if _stealing:
		_stealing = false
		EventBus.steal_cancelled.emit()     # 立刻归还

	AudioManager.play_sfx(&"boss_die")
	boss_died.emit()
	queue_free()

# ---------- 偷取机制 ----------

func _update_steal(delta: float) -> void:
	if _stealing:
		_steal_timer -= delta
		if _steal_timer <= 0.0:
			_finish_steal()
		return

	if _try_threshold_steal():
		return

	_steal_cd_left -= delta
	if _steal_cd_left <= 0.0:
		_try_chance_steal()

func _try_threshold_steal() -> bool:
	if GameFlow.spell == null:
		return false

	var ratio := float(hp) / float(max_hp)
	for i in range(steal_thresholds.size()):
		if _threshold_used[i] or ratio > steal_thresholds[i]:
			continue

		_threshold_used[i] = true
		_begin_steal()
		return true

	return false

func _try_chance_steal() -> void:
	var ratio := float(hp) / float(max_hp)
	var ok := GameFlow.spell != null and ratio < steal_thresholds[0] and randf() < steal_chance

	if ok:
		_begin_steal()
	else:
		_steal_cd_left = steal_cooldown

func _begin_steal() -> void:
	if _stealing:
		return

	_stealing = true
	_steal_timer = steal_duration
	EventBus.steal_spell_requested.emit(steal_duration)

func _finish_steal() -> void:
	if not _stealing:
		return

	_stealing = false
	_steal_cd_left = steal_cooldown

func _on_spell_returned(_spell: SpellData) -> void:
	_finish_steal()