extends EventData
class_name EventTrade

## 以物易物：随机生成 1~3 个「失去 A → 获得 B」的选项，外加离开。
## 同一选项里 A != B；不同选项可以重复。不可行的选项也会生成，由界面置灰。

@export var gold_ratio_min := 0.25
@export var gold_ratio_max := 1.25
@export var hp_loss := 1
@export var hp_gain := 2
@export var max_hp_step := 1

const KINDS := ["hp", "max_hp", "gold", "spell"]

func build_options() -> Array[EventOption]:
	var opts: Array[EventOption] = []
	var count := randi_range(1, 3)
	var guard := 0

	while opts.size() < count and guard < 40:
		guard += 1
		var lose_kind: String = KINDS[randi_range(0, KINDS.size() - 1)]
		var gain_kind: String = KINDS[randi_range(0, KINDS.size() - 1)]
		if lose_kind == gain_kind:
			continue

		var opt := _make_option(lose_kind, gain_kind)
		if opt != null:
			opts.append(opt)

	var leave := EventOption.new()
	leave.label = "离开"
	var leave_outcome := EventOutcome.new()
	leave_outcome.text = "你选择了离开。"
	leave.outcome = leave_outcome
	opts.append(leave)

	return opts

func _gold_amount() -> int:
	return maxi(1, roundi(GameFlow.gold * randf_range(gold_ratio_min, gold_ratio_max)))

func _make_option(lose_kind: String, gain_kind: String) -> EventOption:
	var opt := EventOption.new()
	var outcome := EventOutcome.new()

	var lose_text := ""
	match lose_kind:
		"hp":
			opt.cost_hp = hp_loss
			lose_text = "失去 %d 点生命" % hp_loss
		"max_hp":
			opt.cost_max_hp = max_hp_step
			lose_text = "失去 %d 点最大生命" % max_hp_step
		"gold":
			var amount := _gold_amount()
			opt.cost_gold = amount
			lose_text = "失去 %d 金币" % amount
		"spell":
			opt.cost_spell = true
			lose_text = "失去当前法杖"

	var gain_text := ""
	match gain_kind:
		"hp":
			outcome.hp = hp_gain
			gain_text = "获得 %d 点生命" % hp_gain
		"max_hp":
			outcome.max_hp = max_hp_step
			gain_text = "获得 %d 点最大生命" % max_hp_step
		"gold":
			var amount := _gold_amount()
			outcome.gold = amount
			gain_text = "获得 %d 金币" % amount
		"spell":
			var pool := GameFlow.get_spell_pool()
			if pool.is_empty():
				return null
			outcome.grant_spell = pool[randi_range(0, pool.size() - 1)]
			gain_text = "获得一把法杖"

	opt.label = "%s → %s" % [lose_text, gain_text]
	outcome.text = "交易完成：%s，%s。" % [lose_text, gain_text]
	opt.outcome = outcome
	return opt
