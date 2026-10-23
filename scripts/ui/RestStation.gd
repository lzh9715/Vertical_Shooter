extends CanvasLayer
class_name RestStation

## 商店面板（纯 UI）。生成报价、购买、刷新都由 ShopSession 负责。

signal closed

@export var close_button_text := "继续战斗"

@onready var btn_slot1: Button = $VBoxContainer/Btn_Slot1
@onready var btn_slot2: Button = $VBoxContainer/Btn_Slot2
@onready var btn_slot3: Button = $VBoxContainer/Btn_Slot3
@onready var btn_refresh: Button = $VBoxContainer/Btn_Refresh
@onready var btn_resume: Button = $VBoxContainer/Btn_Resume
@onready var gold_label: Label = $VBoxContainer/ShopGoldLabel
@onready var desc_label: Label = $DescLabel

var session: ShopSession
var _left := false

func _ready() -> void:
	btn_resume.text = close_button_text

	btn_slot1.pressed.connect(func(): buy_slot(0))
	btn_slot2.pressed.connect(func(): buy_slot(1))
	btn_slot3.pressed.connect(func(): buy_slot(2))
	btn_refresh.pressed.connect(refresh_shop)
	btn_resume.pressed.connect(_on_leave)

	btn_slot1.mouse_entered.connect(func(): show_tooltip(0))
	btn_slot1.mouse_exited.connect(hide_tooltip)
	btn_slot2.mouse_entered.connect(func(): show_tooltip(1))
	btn_slot2.mouse_exited.connect(hide_tooltip)
	btn_slot3.mouse_entered.connect(func(): show_tooltip(2))
	btn_slot3.mouse_exited.connect(hide_tooltip)

	GameFlow.stats_changed.connect(refresh_ui)

	session = ShopSession.new(GameFlow.get_pricing())
	session.generate()
	refresh_ui()

## 商店不再响应 Esc 关闭，避免误触；只能点「离开商店」按钮。
func open() -> void:
	btn_resume.text = close_button_text
	visible = true

	if session == null:
		session = ShopSession.new(GameFlow.get_pricing())
	if session.offers.is_empty():
		session.generate()
	refresh_ui()

func close() -> void:
	visible = false

## 所有离开路径统一走这里，保证只发一次 closed
func _on_leave() -> void:
	if _left:
		return
	_left = true
	closed.emit()

func buy_slot(index: int) -> void:
	if session != null and session.buy(index):
		AudioManager.play_sfx(&"buy")
		refresh_ui()

func refresh_shop() -> void:
	if session != null and session.refresh():
		refresh_ui()

func refresh_ui() -> void:
	gold_label.text = "当前金币: %d" % GameFlow.gold

	var buttons := [btn_slot1, btn_slot2, btn_slot3]
	for i in range(buttons.size()):
		if session == null or i >= session.offers.size():
			buttons[i].text = "空槽位"
			buttons[i].disabled = true
			continue

		var offer: ShopOffer = session.offers[i]
		if offer.sold:
			buttons[i].text = "已售出"
			buttons[i].disabled = true
			continue

		var affordable := session.can_afford(offer)
		var text := "%s (%d金币)" % [offer.item.display_name, offer.price]
		if not affordable:
			text += "（金币不足）"

		buttons[i].text = text
		buttons[i].disabled = not affordable

func show_tooltip(index: int) -> void:
	if session == null or index < 0 or index >= session.offers.size():
		return

	var offer: ShopOffer = session.offers[index]
	if offer.sold:
		return

	desc_label.text = offer.item.description
	desc_label.modulate = Color(1, 1, 1, 1)

func hide_tooltip() -> void:
	desc_label.text = "将鼠标悬停在商品上查看说明"
	desc_label.modulate = Color(1, 1, 1, 0.5)
