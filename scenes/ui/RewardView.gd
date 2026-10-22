extends Control

## 直接奖励关：展示获得内容，点“领取”后真正结算并回到地图。

@onready var title_label: Label = $VBox/Title
@onready var desc_label: Label = $VBox/Desc
@onready var btn_claim: Button = $VBox/BtnClaim

func _ready() -> void:
	get_tree().paused = false
	btn_claim.pressed.connect(_on_claim)

	var reward := GameFlow.current_reward
	title_label.text = reward.display_name if reward != null else "奖励关"
	desc_label.text = reward.describe() if reward != null else "什么也没有"

	if reward is RewardGrant:
		title_label.modulate = Color(1.0, 0.85, 0.35)

func _on_claim() -> void:
	var reward := GameFlow.current_reward
	if reward != null:
		reward.enter()
	GameFlow.finish_node()
