extends Node
class_name EnemySpawner

signal enemy_died(score: int, gold: int)

@export var difficulty: DifficultyProfile

var _alive: Array = []      # 已经进场的敌人
var _pending := 0           # 已排期、还没进场的敌人（延迟生成中的）

## 兼容旧入口
func trigger_spawn(data: Resource) -> void:
	spawn(data)

## 唯一入口：交给 SpawnGroup 自己生成
func spawn(group) -> void:
	if group == null:
		return
	if not (group is SpawnGroup):
		push_warning("不是 SpawnGroup：%s" % group)
		return
	group.spawn(self)

## 场上还剩多少敌人（含还没进场的）—— BattleRunner 用它判断“这波清空了吗”
func alive_count() -> int:
	_alive = _alive.filter(func(e): return is_instance_valid(e))
	return _alive.size() + _pending

func create_enemy(data: EnemyData):
	if data == null or data.scene == null:
		push_warning("EnemyData 没配好：缺 scene")
		return null

	var hp_mult := difficulty.value(&"hp") if difficulty else 1.0
	var speed_mult := difficulty.value(&"speed") if difficulty else 1.0
	var reward_mult := difficulty.value(&"reward") if difficulty else 1.0

	var enemy = data.scene.instantiate()
	enemy.max_hp = maxi(1, roundi(data.max_hp * hp_mult))
	enemy.attack_power = data.attack_power
	enemy.defense = data.defense
	enemy.damage_reduction = data.damage_reduction
	enemy.speed = data.speed * speed_mult * ScreenUtil.scale_factor()
	enemy.score_reward = roundi(data.score * reward_mult)
	enemy.gold_reward = roundi(data.gold * reward_mult)
	enemy.despawn_margin = data.despawn_margin * ScreenUtil.scale_factor()
	enemy.texture = data.texture
	enemy.attack = data.attack
	enemy.scale = Vector2.ONE * data.visual_scale
	if enemy.has_method("configure_elite"):
		enemy.configure_elite(data.elite_movement, data.elite_hover_height, data.elite_lane_offset)
	enemy.died.connect(_on_enemy_died)
	return enemy

## 延迟进场。用 await 而不是 create_timer + lambda：
## 节点被释放时协程会一起结束，不会像定时器那样在切场景后还来 add_child。
func schedule(enemy, delay: float) -> void:
	if delay <= 0.0:
		_attach(enemy)
		return

	_pending += 1
	await get_tree().create_timer(delay, false).timeout
	_pending = maxi(_pending - 1, 0)

	if is_inside_tree():
		_attach(enemy)

func _attach(enemy) -> void:
	if not is_instance_valid(enemy):
		return
	add_child(enemy)
	_alive.append(enemy)

func _on_enemy_died(score: int, gold: int) -> void:
	enemy_died.emit(score, gold)