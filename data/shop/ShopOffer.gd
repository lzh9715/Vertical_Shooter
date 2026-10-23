extends RefCounted
class_name ShopOffer

## 商店里的一次报价：某个商品 + 价格 + 是否售出。

var item: ShopItem
var price := 0
var sold := false

func _init(p_item: ShopItem = null, p_price := 0) -> void:
	item = p_item
	price = p_price
