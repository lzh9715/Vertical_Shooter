extends RefCounted
class_name EquipmentStats

## 汇总装备词条与玩家基础属性，供 Player / UI 读取。

const BASE_MAX_HP := 100.0
const BASE_HP_REGEN := 1.0
const BASE_MAX_MANA := 100.0
const BASE_MANA_REGEN := 35.0
const BASE_MOVE_SPEED := 400.0
const BASE_CRIT_CHANCE := 0.05
const BASE_CRIT_DAMAGE := 1.5

var hp_flat := 0.0
var hp_pct := 0.0
var hp_regen_flat := 0.0
var mana_flat := 0.0
var mana_pct := 0.0
var mana_regen_flat := 0.0
var damage_flat := 0.0
var damage_pct := 0.0
var crit_chance_flat := 0.0
var crit_damage_flat := 0.0
var defense_flat := 0.0
var damage_reduction_flat := 0.0
var move_speed_pct := 0.0
var pickup_radius_pct := 0.0
var luck := 0.0

static func compute(equipment: PlayerEquipment) -> EquipmentStats:
	var stats := EquipmentStats.new()
	if equipment == null:
		return stats

	for wand in equipment.wand_slots:
		if wand == null:
			continue
		stats._add_item(wand.body)
		stats._add_item(wand.gem)

	stats._add_item(equipment.hat)
	stats._add_item(equipment.robe)
	stats._add_item(equipment.accessory)
	return stats

func max_hp() -> float:
	return maxf((BASE_MAX_HP + hp_flat) * (1.0 + hp_pct), 1.0)

func hp_regen() -> float:
	return maxf(BASE_HP_REGEN + hp_regen_flat, 0.0)

func max_mana() -> float:
	return maxf((BASE_MAX_MANA + mana_flat) * (1.0 + mana_pct), 1.0)

func mana_regen() -> float:
	return maxf(BASE_MANA_REGEN + mana_regen_flat, 0.0)

func move_speed() -> float:
	return BASE_MOVE_SPEED * maxf(1.0 + move_speed_pct, 0.1)

func crit_chance() -> float:
	return clampf(BASE_CRIT_CHANCE + crit_chance_flat, 0.0, 1.0)

func crit_damage() -> float:
	return maxf(BASE_CRIT_DAMAGE + crit_damage_flat, 1.0)

func defense() -> float:
	return maxf(defense_flat, 0.0)

func damage_reduction() -> float:
	return clampf(damage_reduction_flat, 0.0, 0.8)

func _add_item(item: ItemInstance) -> void:
	if item == null:
		return
	for affix in item.affixes:
		_apply_affix(affix)

func _apply_affix(affix: ItemAffix) -> void:
	if affix == null:
		return

	match affix.stat:
		&"damage":
			damage_flat += affix.amount
		&"spell_power":
			damage_pct += affix.amount
		&"max_hp":
			hp_flat += affix.amount
		&"hp_regen":
			hp_regen_flat += affix.amount
		&"max_mana":
			mana_flat += affix.amount
		&"mana_regen":
			mana_regen_flat += affix.amount
		&"armor":
			defense_flat += affix.amount
		&"damage_reduction":
			damage_reduction_flat += affix.amount
		&"crit_chance":
			crit_chance_flat += affix.amount
		&"crit_damage":
			crit_damage_flat += affix.amount
		&"move_speed":
			move_speed_pct += affix.amount
		&"pickup_radius":
			pickup_radius_pct += affix.amount
		&"luck":
			luck += affix.amount
