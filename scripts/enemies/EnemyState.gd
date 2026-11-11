extends RefCounted
class_name EnemyState

## 敌人状态基类：状态只负责自己的进入、每帧更新和退出。
## 具体转换由状态内部通过 EnemyBrain.change() 发起。

var host: Node
var brain: EnemyBrain

func setup(p_brain: EnemyBrain, p_host: Node) -> void:
	brain = p_brain
	host = p_host

func enter() -> void:
	pass

func update(_delta: float) -> void:
	pass

func exit() -> void:
	pass
