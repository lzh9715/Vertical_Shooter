extends Control

## 法术卡装配面板：上方槽位可横向滚动，下方背包法术卡独立滚动。
## 每次施法按槽位顺序消耗一张，循环。

signal closed

const SLOT_SIZE := Vector2(130, 170)
const BAG_SIZE := Vector2(100, 100)
const SLOT_BG := Color(0.20, 0.23, 0.30, 1.0)
const BAG_BG := Color(0.28, 0.28, 0.31, 1.0)

@onready var title: Label = $Center/Panel/Margin/VBox/Header/Title
@onready var btn_close: Button = $Center/Panel/Margin/VBox/Header/BtnClose
@onready var btn_clear: Button = $Center/Panel/Margin/VBox/Header/BtnClear
@onready var slots_box: HBoxContainer = $Center/Panel/Margin/VBox/SlotsScroll/SlotsBox
@onready var bag_grid: GridContainer = $Center/Panel/Margin/VBox/BagScroll/BagGrid
@onready var bag_scroll: ScrollContainer = $Center/Panel/Margin/VBox/BagScroll
@onready var warnings_box: VBoxContainer = $Center/Panel/Margin/VBox/WarningsBox
@onready var warnings_list: VBoxContainer = $Center/Panel/Margin/VBox/WarningsBox/WarningsScroll/WarningsVBox

var _wand: WandInstance
var _wand_index := 0
var _slot_panels: Array[Panel] = []
var _bag_panels: Array[Panel] = []
var _targets: Array[Panel] = []

var _drag_card: ItemDefinition
var _drag_origin: Dictionary = {}
var _drag_panel: Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	btn_close.pressed.connect(close)
	btn_clear.pressed.connect(_clear_cards)

func _clear_cards() -> void:
	if _wand == null:
		return

	var inventory := GameFlow.get_inventory()
	for card in _wand.cards:
		if card != null:
			inventory.add_card(card, 1)
	_wand.cards.clear()
	_wand.ensure_slots()
	_refresh()

func open(wand: WandInstance, wand_index: int) -> void:
	_wand = wand
	_wand_index = wand_index
	_wand.ensure_slots()
	visible = true
	_build_slots()
	_refresh()

func close() -> void:
	if _drag_card != null:
		_restore_drag()
	else:
		_cancel_drag()
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or _drag_card == null:
		return
	if event is InputEventMouseButton and not event.pressed:
		_drop_at_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _drag_panel != null:
		_drag_panel.global_position = get_global_mouse_position() - _drag_panel.size * 0.5

# ---------- 构建 ----------

func _build_slots() -> void:
	for child in slots_box.get_children():
		child.queue_free()
	_slot_panels.clear()
	_targets.clear()

	if _wand == null:
		return

	_wand.ensure_slots()
	for i in range(_wand.max_cards()):
		var slot := _make_slot(i, SLOT_SIZE)
		slots_box.add_child(slot)
		_slot_panels.append(slot)
		_targets.append(slot)

func _make_slot(index: int, size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("kind", "card_slot")
	panel.set_meta("index", index)
	panel.gui_input.connect(_on_slot_input.bind(panel))
	_add_visuals(panel, 18)
	return panel

func _make_bag_slot(cell_index: int, size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("kind", "bag")
	panel.set_meta("index", cell_index)
	panel.gui_input.connect(_on_slot_input.bind(panel))
	_add_visuals(panel, 16)
	return panel

func _add_visuals(panel: Panel, font_size: int) -> void:
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", font_size)
	panel.add_child(name_label)
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.offset_left = 6
	name_label.offset_top = 4
	name_label.offset_right = -6
	name_label.offset_bottom = -4

	var index_label := Label.new()
	index_label.name = "Index"
	index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	index_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	index_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(index_label)
	index_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	index_label.offset_left = 6
	index_label.offset_top = 4

	var count_label := Label.new()
	count_label.name = "Count"
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(count_label)
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.offset_left = -54
	count_label.offset_top = -28
	count_label.offset_right = -6
	count_label.offset_bottom = -4

# ---------- 刷新 ----------

func _refresh() -> void:
	if _wand == null:
		return

	_wand.ensure_slots()
	title.text = "法术卡装配 - 法杖 %d" % [_wand_index + 1]

	for i in range(_slot_panels.size()):
		var panel := _slot_panels[i]
		var bg: ColorRect = panel.get_node("Bg")
		var name_label: Label = panel.get_node("Name")
		var index_label: Label = panel.get_node("Index")
		var count_label: Label = panel.get_node("Count")

		index_label.text = str(i + 1)
		count_label.text = ""

		var card: ItemDefinition = _wand.cards[i] if i < _wand.cards.size() else null
		if card != null:
			bg.color = SLOT_BG
			name_label.text = card.display_name
		else:
			bg.color = Color(0.15, 0.16, 0.19, 1.0)
			name_label.text = "空槽"

	# 背包法术卡（不随上方槽位滚动）
	for child in bag_grid.get_children():
		child.queue_free()
	_bag_panels.clear()
	for slot in _targets.duplicate():
		if slot.get_meta("kind") == "bag":
			_targets.erase(slot)

	var inv := GameFlow.get_inventory()
	for i in range(inv.cells.size()):
		var item = inv.cells[i]
		if not (item is ItemStack) or not item.definition.is_card():
			continue

		var panel := _make_bag_slot(i, BAG_SIZE)
		bag_grid.add_child(panel)
		_bag_panels.append(panel)
		_targets.append(panel)

		var bg: ColorRect = panel.get_node("Bg")
		var name_label: Label = panel.get_node("Name")
		var count_label: Label = panel.get_node("Count")
		bg.color = BAG_BG
		name_label.text = item.definition.display_name
		count_label.text = str(item.count) if item.count > 1 else ""

	_refresh_warnings()

# ---------- 拖拽 ----------

func _on_slot_input(event: InputEvent, panel: Panel) -> void:
	if _drag_card != null:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	_start_drag(panel)
	get_viewport().set_input_as_handled()

func _start_drag(panel: Panel) -> void:
	if _wand == null:
		return

	var kind: String = panel.get_meta("kind")
	var index: int = panel.get_meta("index")
	var inv := GameFlow.get_inventory()

	if kind == "card_slot":
		if index >= _wand.cards.size() or _wand.cards[index] == null:
			return
		_drag_card = _wand.remove_card(index)
		_drag_origin = {"kind": "card_slot", "index": index}
	elif kind == "bag":
		var stack = inv.cells[index]
		if not (stack is ItemStack) or not stack.definition.is_card():
			return
		_drag_card = stack.definition
		if stack.count > 1:
			stack.count -= 1
			_drag_origin = {"kind": "bag", "index": index}
		else:
			inv.take_cell(index)
			_drag_origin = {"kind": "bag", "index": index}

	_create_drag_visual()
	_refresh()

func _create_drag_visual() -> void:
	_drag_panel = Panel.new()
	_drag_panel.size = Vector2(110, 110)
	_drag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.25, 0.35, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_panel.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	label.text = _drag_card.display_name
	_drag_panel.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _drop_at_mouse() -> void:
	var target := _target_under_mouse()
	if target == null:
		# 法术卡面板里没有其他丢弃区：拖出到任何非槽位位置都安全回背包
		_drop_to_bag()
		return

	var kind: String = target.get_meta("kind")
	if kind == "card_slot":
		var slot_index := int(target.get_meta("index"))
		if not _wand.insert_card(slot_index, _drag_card):
			# 槽位已满时，拖到具体槽位直接替换该槽卡牌
			if slot_index >= 0 and slot_index < _wand.cards.size():
				var old_card: ItemDefinition = _wand.cards[slot_index]
				_wand.cards[slot_index] = _drag_card
				if _drag_origin.get("kind", "") == "card_slot":
					_wand.cards[int(_drag_origin.index)] = old_card
				else:
					GameFlow.get_inventory().add_card(old_card, 1)
			else:
				_restore_drag()
				return
	elif kind == "bag":
		_drop_to_bag()
	else:
		_restore_drag()
		return

	GameFlow.get_inventory().auto_transfer()
	_finish_drag()

func _is_over_bag_area() -> bool:
	return bag_scroll != null and bag_scroll.get_global_rect().has_point(get_global_mouse_position())

func _drop_to_bag() -> void:
	GameFlow.get_inventory().add_card(_drag_card, 1)
	GameFlow.get_inventory().auto_transfer()
	_finish_drag()

func _target_under_mouse() -> Panel:
	var mouse := get_global_mouse_position()
	for panel in _targets:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(mouse):
			return panel
	return null

func _restore_drag() -> void:
	if _drag_card == null:
		_finish_drag()
		return

	if _drag_origin.get("kind", "") == "card_slot":
		_wand.insert_card(int(_drag_origin.index), _drag_card)
	else:
		GameFlow.get_inventory().add_card(_drag_card, 1)

	GameFlow.get_inventory().auto_transfer()
	_finish_drag()

func _finish_drag() -> void:
	_cancel_drag()
	_refresh()

func _cancel_drag() -> void:
	if _drag_panel != null:
		_drag_panel.queue_free()
		_drag_panel = null
	_drag_card = null
	_drag_origin = {}

# ---------- 配装警告 ----------

func _is_shuffled() -> bool:
	return (
		_wand != null
		and _wand.gem != null
		and _wand.gem.definition != null
		and _wand.gem.definition.cast_mode == ItemDefinition.CastMode.SHUFFLED
	)

func _refresh_warnings() -> void:
	for child in warnings_list.get_children():
		warnings_list.remove_child(child)
		child.queue_free()

	if _wand == null:
		warnings_box.visible = false
		return

	var warnings: Array[String] = []
	var seen := {}

	if _is_shuffled():
		_add_unique(warnings, seen, "⚠ 乱序法杖不会透支生命，无法支付的组合会降级或跳过")

	var blocks := CastSimulator.build_blocks(_wand.cards)
	if blocks.is_empty():
		_add_unique(warnings, seen, "⚠ 当前法杖没有法术卡")
	else:
		var has_attack := false
		for block in blocks:
			for card in block:
				if card != null and card.is_attack():
					has_attack = true
		if not has_attack:
			_add_unique(warnings, seen, "⚠ 当前配装没有可发射弹体")

		if not _is_shuffled():
			var staff_interval := 0.0
			if _wand.body != null and _wand.body.definition != null:
				staff_interval = _wand.body.definition.cast_interval

			var index := 0
			while index < blocks.size():
				var result := CastSimulator.simulate_action(
					blocks,
					index,
					GameFlow.max_mana,
					GameFlow.max_mana,
					GameFlow.hp,
					staff_interval,
					true
				)
				var indices: Array = result.get("indices", [])
				if indices.is_empty():
					break

				var block_number := int(indices[0]) + 1
				if result.status == "overdraft":
					_add_unique(
						warnings,
						seen,
						"⚠ 施法块 %d 需要透支 %.1f 生命" % [block_number, result.hp_cost]
					)
				elif result.status == "degrade":
					_add_unique(
						warnings,
						seen,
						"⚠ 施法块 %d 无法安全释放，战斗中会跳过" % block_number
					)

				index = int(indices[indices.size() - 1]) + 1

	warnings_box.visible = not warnings.is_empty()
	for text in warnings:
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
		warnings_list.add_child(label)

func _add_unique(warnings: Array[String], seen: Dictionary, text: String) -> void:
	if seen.has(text):
		return
	seen[text] = true
	warnings.append(text)
