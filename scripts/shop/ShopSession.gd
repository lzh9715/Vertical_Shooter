extends RefCounted
class_name ShopSession

## 一次商店访问的逻辑：生成报价、购买、刷新。
## 不持有 UI，也不知道按钮长什么样。

const SLOT_COUNT := 3
const REFRESH_COST := 10

var pricing: ShopPricing
var offers: Array[ShopOffer] = []

func _init(p_pricing: ShopPricing = null) -> void:
	pricing = p_pricing if p_pricing != null else GameFlow.get_pricing()

## 当前版本从法杖池随机铺货；以后可以换成商品目录/分类池
func generate() -> void:
	offers.clear()

	var pool := GameFlow.get_spell_pool()
	if pool.is_empty():
		return

	for i in range(SLOT_COUNT):
		var spell: SpellData = pool[randi_range(0, pool.size() - 1)]
		var item := ShopItemSpell.from_spell(spell)
		offers.append(ShopOffer.new(item, item.get_price(pricing)))

## 购买成功返回 true；金币不足、已售出、效果失败都返回 false
func buy(index: int) -> bool:
	if index < 0 or index >= offers.size():
		return false

	var offer := offers[index]
	if offer.sold:
		return false

	if not GameFlow.spend_gold(offer.price):
		return false

	if not offer.item.apply():
		return false

	offer.sold = true
	return true

## 花 10 金币重新铺货
func refresh() -> bool:
	if GameFlow.get_spell_pool().is_empty():
		return false

	if not GameFlow.spend_gold(REFRESH_COST):
		return false

	generate()
	return true

func can_afford(offer: ShopOffer) -> bool:
	return offer != null and not offer.sold and GameFlow.gold >= offer.price
