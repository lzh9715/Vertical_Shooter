extends Resource
class_name EventData

## 事件基类：进入节点时随机抽一个。
## 子类可以重写 on_enter() / build_options() / get_body() 做动态事件。

@export var title := "事件"
@export_multiline var body := ""
@export var options: Array[EventOption] = []

@export var max_choices := 1       # 本次事件最多选几个（当前都是 1）
@export var weight := 1.0
@export var min_layer := 1
@export var once_per_run := true

func on_enter() -> void:
	pass

func build_options() -> Array[EventOption]:
	return options.duplicate()

func get_body() -> String:
	return body
