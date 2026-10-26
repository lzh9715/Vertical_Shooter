extends RefCounted
class_name ShopSession

## 一次商店访问：5×3 货架、分类保底、购买进背包。
## 暂不提供刷新。

const ROW_SIZE := 5
const ROW_COUNT := 3

var pricing: ShopPricing
var offers: Array[ShopOffer] = []
var last_error := ""

func _init(p_pricing: ShopPricing = null) -> void:
	pricing = p_pricing if p_pricing != null else GameFlow.get_pricing()

func generate() -> void:
	offers.clear()
	last_error = ""

	var row1: Array[ShopOffer] = []
	var gem := _pick(ItemCatalog.gems())
	var body := _pick(ItemCatalog.bodies())
	if gem != null:
		row1.append(_make_offer(gem))
	if body != null:
		row1.append(_make_offer(body))

	var pool1: Array[ItemDefinition] = []
	pool1.append_array(ItemCatalog.gems())
	pool1.append_array(ItemCatalog.bodies())
	while row1.size() < ROW_SIZE and not pool1.is_empty():
		var def := _pick(pool1)
		if def != null:
			row1.append(_make_offer(def))
	row1.shuffle()

	var row2: Array[ShopOffer] = []
	var accessory := _pick(ItemCatalog.accessories())
	if accessory != null:
		row2.append(_make_offer(accessory))

	var head_pool: Array[ItemDefinition] = []
	head_pool.append_array(ItemCatalog.hats())
	head_pool.append_array(ItemCatalog.robes())
	var head := _pick(head_pool)
	if head != null:
		row2.append(_make_offer(head))

	var pool2: Array[ItemDefinition] = []
	pool2.append_array(ItemCatalog.hats())
	pool2.append_array(ItemCatalog.robes())
	pool2.append_array(ItemCatalog.accessories())
	while row2.size() < ROW_SIZE and not pool2.is_empty():
		var def := _pick(pool2)
		if def != null:
			row2.append(_make_offer(def))
	row2.shuffle()

	var row3: Array[ShopOffer] = []
	for i in range(ROW_SIZE):
		var card := _pick(ItemCatalog.cards())
		if card != null:
			row3.append(_make_offer(card))

	offers.append_array(row1)
	offers.append_array(row2)
	offers.append_array(row3)

func buy(index: int) -> bool:
	last_error = ""

	if index < 0 or index >= offers.size():
		last_error = "槽位无效"
		return false

	var offer := offers[index]
	if offer.sold:
		last_error = "已售出"
		return false
	if GameFlow.gold < offer.price:
		last_error = "金币不足"
		return false

	var inventory := GameFlow.get_inventory()
	if inventory.is_full():
		last_error = "背包已满，请先整理背包"
		return false

	if not GameFlow.spend_gold(offer.price):
		last_error = "金币不足"
		return false

	if offer.is_card():
		inventory.add_card(offer.definition, 1)
	else:
		inventory.add(offer.instance)

	offer.sold = true
	return true

func can_afford(offer: ShopOffer) -> bool:
	return offer != null and not offer.sold and GameFlow.gold >= offer.price

func row_start(row: int) -> int:
	return row * ROW_SIZE

func _make_offer(definition: ItemDefinition) -> ShopOffer:
	var instance: ItemInstance = null
	if not definition.is_card():
		var luck := GameFlow.get_player_stats().luck
		var rarity := ItemCatalog.roll_rarity(luck)
		instance = ItemCatalog.make_instance(definition, rarity)

	var base := instance.get_value() if instance != null else definition.base_price
	var layer := 1
	if GameFlow.current_node != null:
		layer = maxi(GameFlow.current_node.layer, 1)
	var difficulty_multiplier := 1.0 + float(layer - 1) * 0.1
	var price := maxi(1, roundi(base * pricing.total_multiplier() * difficulty_multiplier))
	return ShopOffer.new(definition, instance, price)

func _pick(pool: Array[ItemDefinition]) -> ItemDefinition:
	if pool.is_empty():
		return null
	return pool[randi_range(0, pool.size() - 1)]
