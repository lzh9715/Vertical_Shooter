extends CanvasLayer
class_name RestStation

## 5×3 商店：第一行组件（宝石/杖身），第二行角色装备，第三行法术卡。

signal closed

@export var close_button_text := "离开商店"

@onready var rows_box: VBoxContainer = $Center/Panel/Margin/VBox/Rows
@onready var gold_label: Label = $Center/Panel/Margin/VBox/Header/Gold
@onready var desc_label: Label = $Center/Panel/Margin/VBox/Footer/DescLabel
@onready var btn_sell: Button = $Center/Panel/Margin/VBox/Footer/BtnSell
@onready var btn_leave: Button = $Center/Panel/Margin/VBox/Header/BtnLeave

var _sell_overlay: Control
var _sell_grid: GridContainer
var session: ShopSession
var _slots: Array[Panel] = []
var _name_labels: Array[Label] = []
var _sub_labels: Array[Label] = []
var _price_labels: Array[Label] = []
var _buy_buttons: Array[Button] = []
var _left := false

func _ready() -> void:
	btn_leave.text = close_button_text
	btn_leave.pressed.connect(_on_leave)
	btn_sell.pressed.connect(_open_sell)

	GameFlow.stats_changed.connect(refresh_ui)

	session = ShopSession.new(GameFlow.get_pricing())
	session.generate()
	_build_rows()
	_build_sell_overlay()
	refresh_ui()

func open() -> void:
	btn_leave.text = close_button_text
	visible = true

	if _sell_overlay != null:
		_sell_overlay.visible = false

	if session == null:
		session = ShopSession.new(GameFlow.get_pricing())
	if session.offers.is_empty():
		session.generate()
	refresh_ui()

func close() -> void:
	visible = false
	if _sell_overlay != null:
		_sell_overlay.visible = false

func _on_leave() -> void:
	if _left:
		return
	_left = true
	closed.emit()

func _build_rows() -> void:
	for child in rows_box.get_children():
		child.queue_free()
	_slots.clear()
	_name_labels.clear()
	_sub_labels.clear()
	_price_labels.clear()
	_buy_buttons.clear()

	var titles := ["组件 · 宝石 / 杖身", "角色装备 · 帽子 / 袍子 / 配饰", "法术模块"]

	for row in range(3):
		var title := Label.new()
		title.text = titles[row]
		title.add_theme_font_size_override("font_size", 24)
		rows_box.add_child(title)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		rows_box.add_child(hbox)

		for col in range(5):
			var index := row * 5 + col
			_make_slot(hbox, index)

func _make_slot(parent: HBoxContainer, index: int) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(340, 190)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.16, 0.21, 1.0)
	style.border_color = Color(0.28, 0.30, 0.38, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	_slots.append(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(0, 58)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	_name_labels.append(name_label)

	var sub_label := Label.new()
	sub_label.custom_minimum_size = Vector2(0, 30)
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_label.add_theme_font_size_override("font_size", 16)
	sub_label.modulate = Color(1, 1, 1, 0.7)
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_label)
	_sub_labels.append(sub_label)

	var price_label := Label.new()
	price_label.add_theme_font_size_override("font_size", 20)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(price_label)
	_price_labels.append(price_label)

	var buy := Button.new()
	buy.text = "购买"
	buy.custom_minimum_size = Vector2(0, 36)
	buy.add_theme_font_size_override("font_size", 18)
	buy.pressed.connect(func(): buy_slot(index))
	vbox.add_child(buy)
	_buy_buttons.append(buy)

	panel.mouse_entered.connect(func(): show_tooltip(index))
	panel.mouse_exited.connect(hide_tooltip)

func refresh_ui() -> void:
	if session == null:
		return
	gold_label.text = "金币：%d" % GameFlow.gold

	for i in range(_slots.size()):
		if i >= session.offers.size():
			_name_labels[i].text = "空槽位"
			_sub_labels[i].text = ""
			_price_labels[i].text = ""
			_buy_buttons[i].disabled = true
			continue

		var offer := session.offers[i]
		_name_labels[i].text = offer.display_name()
		_sub_labels[i].text = offer.subtitle()
		if offer.sold:
			_price_labels[i].text = "已售出"
			_buy_buttons[i].disabled = true
			continue

		_price_labels[i].text = "%d 金币" % offer.price
		_buy_buttons[i].disabled = not session.can_afford(offer)

func buy_slot(index: int) -> void:
	if session == null:
		return
	if session.buy(index):
		AudioManager.play_sfx(&"buy")
		desc_label.text = "购买成功：%s" % session.offers[index].display_name()
		desc_label.modulate = Color(1, 1, 1, 1)
		refresh_ui()
	else:
		desc_label.text = session.last_error
		desc_label.modulate = Color(1, 0.6, 0.5, 1)

func show_tooltip(index: int) -> void:
	if session == null or index < 0 or index >= session.offers.size():
		return
	var offer := session.offers[index]
	if offer.sold:
		return
	desc_label.text = offer.description()
	desc_label.modulate = Color(1, 1, 1, 1)

func hide_tooltip() -> void:
	desc_label.text = "将鼠标悬停在商品上查看词条说明"
	desc_label.modulate = Color(1, 1, 1, 0.5)

# ---------- 出售 ----------

func _build_sell_overlay() -> void:
	_sell_overlay = Control.new()
	_sell_overlay.visible = false
	_sell_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sell_overlay)
	_sell_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_sell_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_sell_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1800, 900)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "出售物品（50% 价值）"
	title.add_theme_font_size_override("font_size", 40)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var btn_close := Button.new()
	btn_close.text = "关闭"
	btn_close.custom_minimum_size = Vector2(150, 52)
	btn_close.add_theme_font_size_override("font_size", 24)
	btn_close.pressed.connect(func(): _sell_overlay.visible = false)
	header.add_child(btn_close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_sell_grid = GridContainer.new()
	_sell_grid.columns = 5
	_sell_grid.add_theme_constant_override("h_separation", 12)
	_sell_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_sell_grid)

func _open_sell() -> void:
	if _sell_overlay == null:
		return
	_sell_overlay.visible = true
	_rebuild_sell()

func _rebuild_sell() -> void:
	if _sell_grid == null:
		return
	for child in _sell_grid.get_children():
		child.queue_free()

	var inventory := GameFlow.get_inventory()
	var found := false

	for i in range(inventory.cells.size()):
		var item = inventory.cells[i]
		if item == null:
			continue
		found = true

		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(320, 160)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.16, 0.21, 1.0)
		style.border_color = Color(0.28, 0.30, 0.38, 1.0)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		panel.add_theme_stylebox_override("panel", style)
		_sell_grid.add_child(panel)

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		panel.add_child(margin)

		var vbox := VBoxContainer.new()
		margin.add_child(vbox)

		var name_label := Label.new()
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.add_theme_font_size_override("font_size", 20)
		if item is ItemStack:
			name_label.text = "%s ×%d" % [item.definition.display_name, item.count]
		else:
			name_label.text = item.definition.display_name
		vbox.add_child(name_label)

		var price := _sell_price(item)
		var price_label := Label.new()
		price_label.text = "售价：%d 金币" % price
		price_label.add_theme_font_size_override("font_size", 18)
		vbox.add_child(price_label)

		var btn := Button.new()
		btn.text = "出售"
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): _sell_cell(i, price))
		vbox.add_child(btn)

	if not found:
		var empty := Label.new()
		empty.text = "背包中没有可出售的物品"
		empty.add_theme_font_size_override("font_size", 24)
		_sell_grid.add_child(empty)

func _sell_price(item) -> int:
	var value := 1
	if item is ItemStack:
		value = item.get_value()
	elif item is ItemInstance:
		value = item.get_value()
	return maxi(1, floori(float(value) * 0.5))

func _sell_cell(index: int, price: int) -> void:
	var inventory := GameFlow.get_inventory()
	var item = inventory.take_cell(index)
	if item == null:
		return

	GameFlow.add_gold(price)
	inventory.auto_transfer()
	AudioManager.play_sfx(&"buy")
	desc_label.text = "出售获得 %d 金币" % price
	desc_label.modulate = Color(1, 1, 1, 1)
	refresh_ui()
	_rebuild_sell()
