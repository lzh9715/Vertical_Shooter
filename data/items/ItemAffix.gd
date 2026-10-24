extends Resource
class_name ItemAffix

## 装备随机词条。目前只做“属性 + 价值”两项，后续可以扩展条件效果。

@export var id: StringName = &""
@export var display_name := ""
@export var stat: StringName = &""
@export var amount := 0.0
@export var value_bonus := 0
