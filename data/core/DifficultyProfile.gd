extends Resource
class_name DifficultyProfile

## 难度倍率。基础值给关卡用；运行时加成由装备/道具通过 source_id 叠加。
## 关键：敌人生成时「快照」一次，不会影响场上已有的敌人。

@export_group("基础倍率（关卡/无尽模式配置）")
@export_range(0.1, 10.0, 0.05) var hp := 1.0
@export_range(0.1, 10.0, 0.05) var speed := 1.0
@export_range(0.1, 10.0, 0.05) var bullet_damage := 1.0
@export_range(0.1, 10.0, 0.05) var reward := 1.0

# 运行时加成：来源ID -> { 属性名: 乘数 }，比如 { &"relic_sword": { &"hp": 1.2 } }
var _runtime: Dictionary = {}

## 未来装备/道具调用：add_modifier(&"relic_sword", &"hp", 1.2)
func add_modifier(source_id: StringName, key: StringName, multiplier: float) -> void:
	var entry: Dictionary = _runtime.get(source_id, {})
	entry[key] = multiplier
	_runtime[source_id] = entry

## 卸下装备时调用，一次性撤销这个来源的全部加成
func remove_modifier(source_id: StringName) -> void:
	_runtime.erase(source_id)

## 取某个属性的最终倍率
func value(key: StringName) -> float:
	var total := clampf(float(get(key)), 0.1, 20.0)
	for entry in _runtime.values():
		total *= float(entry.get(key, 1.0))
	return clampf(total, 0.1, 20.0)