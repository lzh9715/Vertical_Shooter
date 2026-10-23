extends Resource
class_name ShopItem

## 商店商品的基类。
## 子类负责具体效果（给法杖、回血、升级、散件……），商店逻辑只认 ShopItem。

@export var display_name := "商品"
@export_multiline var description := ""
@export var category: StringName = &"misc"

## 0 表示使用 ShopPricing 的全局区间；大于 0 时作为该商品的基础价
@export var base_price := 0

func get_price(pricing: ShopPricing) -> int:
	if base_price > 0:
		return maxi(1, roundi(base_price * pricing.total_multiplier()))
	return pricing.roll_price()

## 购买成功后应用效果；返回 false 表示没有生效（例如数据缺失）
func apply() -> bool:
	return true
