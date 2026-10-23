extends CanvasLayer
class_name RestStation

## 商店面板。价格与「是否售出」都存在本组件的 offers 里，
## 不写回 SpellData 资源，所以重复商品、跨商店、跨局都不会串价。

signal closed

const SLOT_COUNT := 3

@export var close_button_text := "继续战斗"

@onready var btn_slot1: Button = $VBoxContainer/Btn_Slot1
@onready var btn_slot2: Button = $VBoxContainer/Btn_Slot2
@onready var btn_slot3: Button = $VBoxContainer/Btn_Slot3
@onready var btn_refresh: Button = $VBoxContainer/Btn_Refresh
@onready var btn_resume: Button = $VBoxContainer/Btn_Resume
@onready var gold_label: Label = $VBoxContainer/ShopGoldLabel
@onready var desc_label: Label = $DescLabel

# 每个槽位的报价：{ "spell": SpellData, "price": int, "sold": bool }
var offers: Array[Dictionary] = []
var pricing: ShopPricing

func _ready() -> void:
	btn_resume.text = close_button_text

	btn_slot1.pressed.connect(func(): buy_slot(0))
	btn_slot2.pressed.connect(func(): buy_slot(1))
	btn_slot3.pressed.connect(func(): buy_slot(2))
	btn_refresh.pressed.connect(refresh_shop)
	btn_resume.pressed.connect(func(): closed.emit())

	btn_slot1.mouse_entered.connect(func(): show_tooltip(0))
	btn_slot1.mouse_exited.connect(hide_tooltip)
	btn_slot2.mouse_entered.connect(func(): show_tooltip(1))
	btn_slot2.mouse_exited.connect(hide_tooltip)
	btn_slot3.mouse_entered.connect(func(): show_tooltip(2))
	btn_slot3.mouse_exited.connect(hide_tooltip)

	pricing = GameFlow.get_pricing()
	GameFlow.stats_changed.connect(refresh_ui)

	if offers.is_empty():
		generate_offers()
	refresh_ui()

## 商店不再响应 Esc 关闭，避免误触；只能点「离开商店」按钮。

func open() -> void:
	btn_resume.text = close_button_text
	visible = true
	if offers.is_empty():
		generate_offers()
	refresh_ui()

func close() -> void:
	visible = false

## 重新铺货：每个槽位独立抽，允许抽到重复法杖
func generate_offers() -> void:
	offers.clear()

	var pool := GameFlow.get_spell_pool()
	if pool.is_empty():
		return

	for i in range(SLOT_COUNT):
		var spell: SpellData = pool[randi_range(0, pool.size() - 1)]
		offers.append({
			"spell": spell,
			"price": pricing.roll_price(),
			"sold": false,
		})

func buy_slot(index: int) -> void:
	if index < 0 or index >= offers.size():
		return

	var offer: Dictionary = offers[index]
	if offer["sold"]:
		return

	if not GameFlow.spend_gold(offer["price"]):
		return

	offer["sold"] = true                 # 只标记本槽位售罄，刷新时才补货
	GameFlow.spell = offer["spell"]

	# 如果当前正在战斗中，立刻换装（商店房间时玩家不存在，跳过）
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.current_spell = offer["spell"]

	refresh_ui()

func refresh_shop() -> void:
	if GameFlow.get_spell_pool().is_empty():
		return

	if not GameFlow.spend_gold(10):
		return

	generate_offers()
	refresh_ui()

func refresh_ui() -> void:
	gold_label.text = "当前金币: %d" % GameFlow.gold

	var buttons := [btn_slot1, btn_slot2, btn_slot3]
	for i in range(SLOT_COUNT):
		if i >= offers.size():
			buttons[i].text = "空槽位"
			buttons[i].disabled = true
			continue

		var offer: Dictionary = offers[i]
		if offer["sold"]:
			buttons[i].text = "已售出"
			buttons[i].disabled = true
			continue

		var spell: SpellData = offer["spell"]
		var spell_name := spell.display_name
		if spell_name == "" or spell_name == "未命名法杖":
			spell_name = "神秘法杖"

		buttons[i].text = "%s (%d金币)" % [spell_name, offer["price"]]
		buttons[i].disabled = false

func show_tooltip(index: int) -> void:
	if index < 0 or index >= offers.size():
		return

	var offer: Dictionary = offers[index]
	if offer["sold"]:
		return

	var spell: SpellData = offer["spell"]
	desc_label.text = spell.description
	desc_label.modulate = Color(1, 1, 1, 1)

func hide_tooltip() -> void:
	desc_label.text = "将鼠标悬停在法杖上查看说明"
	desc_label.modulate = Color(1, 1, 1, 0.5)
