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

## 法术卡类型：攻击卡建立弹体，模块卡修改当前施法块
enum SpellKind {
	NONE,
	ATTACK,
	MODULE,
}

enum CastMode {
	ORDERED,
	SHUFFLED,
}

enum EffectType {
	NONE,
	HOMING,
	PIERCE,
	EXPLOSION,
	DAMAGE,
	MULTICAST,
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
@export var cast_mode: CastMode = CastMode.ORDERED
@export var damage_bonus := 0     # 仅杖身使用：占位伤害加成

@export_group("法术卡")
@export var spell_kind: SpellKind = SpellKind.NONE
@export var effect_type: EffectType = EffectType.NONE
@export var effect_value := 0.0
@export var effect_radius := 0.0
@export var mana_cost := 0
@export var mana_restore := 0
@export var mana_discount := 0
@export var cast_interval := 0.0
@export var multicast_count := 0
@export var base_value := 0
@export var visual_scene: PackedScene

@export_group("攻击卡基础")
@export var base_damage := 0
@export var projectile_count := 1
@export var projectile_speed := 800.0
@export var spread_angle := 0.0
@export var lifetime := 1.8

func is_card() -> bool:
	return category == Category.SPELL_CARD

func is_attack() -> bool:
	return is_card() and spell_kind == SpellKind.ATTACK

func is_module() -> bool:
	return is_card() and spell_kind == SpellKind.MODULE

func is_equipment() -> bool:
	return category != Category.SPELL_CARD

func is_stackable() -> bool:
	return stack_limit > 1

func value() -> int:
	return base_value if base_value > 0 else base_price
