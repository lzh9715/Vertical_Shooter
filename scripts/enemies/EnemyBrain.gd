extends RefCounted
class_name EnemyBrain

## 极简状态机：持有状态表，负责 enter/update/exit。
## 复杂敌人的状态类可以注册到这里；状态本身不依赖具体场景。

var host: Node
var states: Dictionary = {}
var current_id: StringName = &""
var previous_id: StringName = &""
var current: EnemyState

func setup(p_host: Node, p_states: Dictionary, initial_id: StringName) -> void:
	host = p_host
	states = p_states
	for state in states.values():
		if state is EnemyState:
			state.setup(self, host)
	current = null
	current_id = &""
	previous_id = &""
	change(initial_id)

func change(next_id: StringName) -> void:
	if not states.has(next_id):
		push_warning("EnemyBrain: 未注册状态 %s" % String(next_id))
		return
	if current != null:
		current.exit()
	previous_id = current_id
	current_id = next_id
	current = states[next_id]
	current.enter()

func update(delta: float) -> void:
	if current != null:
		current.update(delta)

func has_state(state_id: StringName) -> bool:
	return states.has(state_id)
