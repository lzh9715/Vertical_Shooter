extends ShopItem
class_name ShopItemSpell

## 法杖商品（当前占位商品类型）。

@export var spell: SpellData

static func from_spell(s: SpellData) -> ShopItemSpell:
	var item := ShopItemSpell.new()
	item.spell = s
	item.category = &"spell"

	var spell_name := s.display_name
	if spell_name == "" or spell_name == "未命名法杖":
		spell_name = "神秘法杖"

	item.display_name = spell_name
	item.description = s.description
	return item

func apply() -> bool:
	if spell == null:
		return false

	GameFlow.spell = spell
	return true
