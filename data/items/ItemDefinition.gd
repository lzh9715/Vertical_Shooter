extends Resource
class_name ItemDefinition

## 物品静态定义（只读模板）。具体拥有物由 ItemStack / ItemInstance 表示。

enum Category {
	SPELL_CARD,
	GEM,
	STAFF_BODY,
	HAT,
	ROBE,
	ACCESSORY,
}

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var category: Category = Category.SPELL_CARD
@export var stack_limit := 1
@export var base_price := 10
@export var rarity := 0
@export var icon: Texture2D
@export var tags: Array[StringName] = []
@export var gem_slots := 0        # 仅宝石使用：提供多少个法术卡槽
@export var damage_bonus := 0     # 仅杖身使用：占位伤害加成

func is_card() -> bool:
	return category == Category.SPELL_CARD

func is_equipment() -> bool:
	return category != Category.SPELL_CARD

func is_stackable() -> bool:
	return stack_limit > 1
