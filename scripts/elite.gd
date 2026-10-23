extends "res://enemy.gd"

## 精英行为模板：飞入 → 悬停 → 按 EliteMovement 库摆位，同时按攻击序列开火。
## 继承小怪的数值 / 受伤 / 死亡 / 弹幕逻辑，只重写“怎么移动”。
##
## 战斗阶段的移动方式由 EnemyData.elite_movement 决定：
##   EliteMoveHover / EliteMoveZigzag / EliteMovePulse / EliteMoveStill
## 新增移动方式只需要新建一个 EliteMovement 子类。

@export var hover_height := 1920.0     # 横版：悬停点的 x 坐标（原竖版为 y）
@export var enter_speed_mult := 2.0    # 入场速度倍数
@export var elite_movement: EliteMovement
@export var randomize_phase := true   # 同类精英同时出场时错开轨迹
@export var hover_x_jitter := 15.0    # 悬停点的小幅随机抖动（现在作用于 y）
@export var lane_spacing := 300.0     # 同一队精英之间的纵向间距

var _entering := true
var _hover_point := Vector2.ZERO
var _drift_time := 0.0
var _lane_index := 0
var _lane_count := 1
var _base_lane_offset := 0.0

func _ready() -> void:
	super._ready()
	_rebuild_hover_point()
	global_position = start_position + offset

## 由 QueueData 在生成时调用：第 index 只 / 共 total 只
func configure_lane(index: int, total: int) -> void:
	_lane_index = index
	_lane_count = maxi(total, 1)
	if is_node_ready():
		_rebuild_hover_point()

## 由 EnemySpawner 在生成时调用
func configure_elite(movement: EliteMovement, height: float, lane_offset: float = 0.0) -> void:
	# 每只精英复制一份移动配置，避免共享资源被同时修改，
	# 也保证同类精英可以各自随机相位。
	if movement != null:
		elite_movement = movement.duplicate()
		if randomize_phase:
			elite_movement.phase = randf()
	else:
		elite_movement = null

	_base_lane_offset = lane_offset

	if height > 0.0:
		hover_height = height
	if is_node_ready():
		_rebuild_hover_point()

func _rebuild_hover_point() -> void:
	var s := ScreenUtil.scale_factor()

	# 同一队里有多只时按序号分车道（居中对齐）；
	# 单独一只时用 EnemyData 里配置的固定偏移。
	# 横版：车道沿 y 轴分布。
	var lane_offset := 0.0
	if _lane_count > 1:
		lane_offset = (float(_lane_index) - float(_lane_count - 1) * 0.5) * lane_spacing
	else:
		lane_offset = _base_lane_offset

	var jitter := randf_range(-hover_x_jitter, hover_x_jitter) * s
	_hover_point = Vector2(hover_height * s, start_position.y + lane_offset * s + jitter) + offset

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	_update_elite_motion(delta)

	# 入场期间不开火，落位后才开始攻击，节奏更清晰
	if not _entering:
		_tick_attack(delta)

func _update_elite_motion(delta: float) -> void:
	var s := ScreenUtil.scale_factor()

	if _entering:
		global_position = global_position.move_toward(_hover_point, speed * enter_speed_mult * delta)
		if global_position.distance_to(_hover_point) < 2.0:
			_entering = false
		return

	_drift_time += delta

	var off := Vector2.ZERO
	if elite_movement != null:
		off = elite_movement.offset_at(_drift_time) * s

	global_position = _hover_point + off
