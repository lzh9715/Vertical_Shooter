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
	SPREAD,
	MULTICAST,
	BOUNCE,
	REFRACT,
	RETURN,
	ACCELERATE,
	DECELERATE,
	LIFETIME,
}

enum OffsetType {
	FIXED,
	RANDOM,
	MULTI,
}

enum CollisionShape {
	CIRCLE,
	RECTANGLE,
	CAPSULE,
}

enum TriggerType {
	NONE,
	ON_HIT,
	ON_EXPIRE,
	ON_HIT_OR_EXPIRE,
}

@export var id: StringName = &""
@export var sort_order := 0
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
@export var max_equipped := 0   # 0 = 不限制；未来用于同名模块装备上限
@export var base_value := 0
@export var visual_scene: PackedScene
@export var is_copy_module := false
@export var inherit_to_copy := true
@export var compatibility_group: StringName = &""
@export var damage_falloff := 0.8
@export var damage_floor := 0.3
@export var target_rule: StringName = &""

@export_group("攻击卡基础")
@export var base_damage := 0
@export var projectile_count := 1
@export var projectile_speed := 800.0
@export var spread_angle := 0.0
@export var offset_type: OffsetType = OffsetType.FIXED
@export var offset_angle := 0.0
@export var lifetime := 1.8
@export var collision_shape: CollisionShape = CollisionShape.CIRCLE
@export var collision_size := Vector2(5.0, 5.0)
@export var crit_chance_bonus := 0.0
@export var crit_damage_bonus := 0.0
@export var behavior_tag: StringName = &"normal"
@export var copyable := true
@export var copy_inherits_trigger := true
@export var trigger_type: TriggerType = TriggerType.NONE
@export var trigger_delay := 0.0
@export var trigger_target: StringName = &""
@export var trigger_count := 0

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
