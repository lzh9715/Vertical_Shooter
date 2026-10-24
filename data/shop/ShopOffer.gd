extends RefCounted
class_name ShopOffer

## 一次商店报价：定义 + 可选的随机词条实例 + 价格。

var definition: ItemDefinition
var instance: ItemInstance
var price := 0
var sold := false

func _init(p_definition: ItemDefinition = null, p_instance: ItemInstance = null, p_price := 0) -> void:
	definition = p_definition
	instance = p_instance
	price = p_price

func is_card() -> bool:
	return definition != null and definition.is_card()

func display_name() -> String:
	return definition.display_name if definition != null else "未知商品"

func category_name() -> String:
	return ItemCatalog.category_name(definition.category) if definition != null else "物品"

func subtitle() -> String:
	if definition == null:
		return ""
	if is_card():
		return "法术 · 1 张"
	var parts: Array[String] = []
	if instance != null:
		parts.append(ItemCatalog.rarity_name(instance.rarity))
	if definition.category == ItemDefinition.Category.GEM:
		parts.append("%d 槽" % definition.gem_slots)
	elif definition.category == ItemDefinition.Category.STAFF_BODY:
		parts.append("+%d 伤害" % definition.damage_bonus)
	if instance != null and not instance.affixes.is_empty():
		parts.append(instance.describe_affixes())
	return " · ".join(parts)

func description() -> String:
	if definition == null:
		return ""
	var lines: Array[String] = [definition.description if definition.description != "" else category_name()]
	if instance != null:
		for affix in instance.affixes:
			var sign := "+" if affix.amount >= 0.0 else ""
			lines.append("%s %s%.2f" % [affix.display_name, sign, affix.amount])
	return "\n".join(lines)

func current_value() -> int:
	if instance != null:
		return instance.get_value()
	if definition != null:
		return definition.base_price
	return 1
