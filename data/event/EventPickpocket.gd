extends EventData
class_name EventPickpocket

## 扒手：进入事件时立刻扣钱（透明展示），玩家可以选择追回或认栽。
## 追回 = 限时 Boss 战，胜利返还被偷金额 + 额外奖励；超时保持损失，无额外惩罚。

@export var boss: BossData
@export var time_limit := 40.0
@export var win_bonus := 120
@export var steal_ratio_min := 0.08
@export var steal_ratio_max := 0.12
@export var min_steal := 10

var lost := 0

func on_enter() -> void:
	var gold_now := GameFlow.gold
	if gold_now <= 0:
		lost = 0
		return

	lost = clampi(
		roundi(gold_now * randf_range(steal_ratio_min, steal_ratio_max)),
		mini(min_steal, gold_now),
		gold_now
	)
	GameFlow.add_gold(-lost)
	GameFlow.event_context["stolen"] = lost

func get_body() -> String:
	if lost <= 0:
		return body + "\n\n（你身无分文，扒手空手而归。）"
	return body + "\n\n你被偷走了 %d 金币。" % lost

func build_options() -> Array[EventOption]:
	var opts: Array[EventOption] = []

	if lost > 0:
		var chase := EventOption.new()
		chase.label = "追上去（限时战斗）"

		var battle := EventBattle.new()
		battle.boss = boss
		battle.time_limit = time_limit
		battle.win_gold = win_bonus
		battle.refund_stolen = true

		var outcome := EventOutcome.new()
		outcome.text = "你追上了扒手。"
		outcome.battle = battle
		chase.outcome = outcome
		opts.append(chase)

	var leave := EventOption.new()
	leave.label = "认栽离开"
	var leave_outcome := EventOutcome.new()
	leave_outcome.text = "你损失了 %d 金币。" % maxi(lost, 0)
	leave.outcome = leave_outcome
	opts.append(leave)

	return opts
