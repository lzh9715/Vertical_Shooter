extends Resource
class_name ShopPricing

## 商店定价：基础价格区间 + 倍率。
## 价格不写进 SpellData 资源，只存在「本次商店的报价」里，
## 所以同一把法杖在不同商店、不同局里价格互不影响。
##
## 倍率接口与 DifficultyProfile 同构：
##   base_multiplier 是关卡基数；
##   运行时来源（无尽进度、道具、诅咒）用 add_modifier 叠加，可随时撤销。

@export var min_price := 20
@export var max_price := 150
@export_range(0.1, 10.0, 0.05) var base_multiplier := 1.0

# 运行时加成：来源ID -> 乘数
var _runtime: Dictionary = {}

func add_modifier(source_id: StringName, multiplier: float) -> void:
	_runtime[source_id] = multiplier

func remove_modifier(source_id: StringName) -> void:
	_runtime.erase(source_id)

func total_multiplier() -> float:
	var total := base_multiplier
	for m in _runtime.values():
		total *= float(m)
	return clampf(total, 0.1, 20.0)

## 抽一个报价（整数金币）
func roll_price() -> int:
	var low := mini(min_price, max_price)
	var high := maxi(min_price, max_price)
	var raw := float(randi_range(low, high)) * total_multiplier()
	return maxi(1, roundi(raw))
