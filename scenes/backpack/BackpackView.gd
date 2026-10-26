extends CanvasLayer

## 网格背包 UI：10×6 普通格 + 红色溢出格 + 垃圾桶。
## 左键拖整组，右键拖单个；装备槽目前只展示，下一步接装配。

const SLOT_SIZE := Vector2(96, 96)
const OVERFLOW_SIZE := Vector2(76, 76)
const EQUIP_SIZE := Vector2(500, 84)

const NORMAL_BG := Color(0.30, 0.30, 0.33, 1.0)
const OVERFLOW_BG := Color(0.46, 0.12, 0.12, 1.0)
const TRASH_BG := Color(0.16, 0.16, 0.19, 1.0)
const EQUIP_BG := Color(0.22, 0.24, 0.30, 1.0)

@onready var grid: GridContainer = $Center/Panel/Margin/VBox/Content/GridBox/Grid
@onready var wand_tabs_box: HBoxContainer = $Center/Panel/Margin/VBox/Content/Side/WandTabs
@onready var selected_label: Label = $Center/Panel/Margin/VBox/Content/Side/AssemblyPanel/VBox/Header/SelectedLabel
@onready var body_slot: Panel = $Center/Panel/Margin/VBox/Content/Side/AssemblyPanel/VBox/Slots/BodySlot
@onready var gem_slot: Panel = $Center/Panel/Margin/VBox/Content/Side/AssemblyPanel/VBox/Slots/GemSlot
@onready var btn_edit_cards: Button = $Center/Panel/Margin/VBox/Content/Side/AssemblyPanel/VBox/Header/BtnEditCards
@onready var equip_slots_box: VBoxContainer = $Center/Panel/Margin/VBox/Content/Side/EquipSlots
@onready var overflow_box: HBoxContainer = $Center/Panel/Margin/VBox/OverflowBox
@onready var overflow_slots_box: HBoxContainer = $Center/Panel/Margin/VBox/OverflowBox/OverflowSlots
@onready var trash_slot: Panel = $Center/Panel/Margin/VBox/Footer/TrashSlot
@onready var gold_label: Label = $Center/Panel/Margin/VBox/Header/Gold
@onready var btn_close: Button = $Center/Panel/Margin/VBox/Header/BtnClose
@onready var card_panel: Control = $CardAssemblyPanel

var _grid_slots: Array[Panel] = []
var _equip_slots: Array[Panel] = []
var _overflow_slots: Array[Panel] = []
var _all_slots: Array[Panel] = []
var _wand_tabs: Array[Panel] = []
var _edit_index := 0

var _drag_item: Variant = null
var _drag_origin: Dictionary = {}
var _drag_panel: Panel
var _drag_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_close.pressed.connect(close)

	for i in range(GridInventory.COLUMNS * GridInventory.ROWS):
		var slot := _make_slot("cell", i, SLOT_SIZE)
		grid.add_child(slot)
		_grid_slots.append(slot)

	for i in range(3):
		var slot := _make_slot("equipment", i + 2, EQUIP_SIZE)
		equip_slots_box.add_child(slot)
		_equip_slots.append(slot)

	_setup_assembly_slots()
	_build_wand_tabs()
	btn_edit_cards.pressed.connect(_open_card_panel)
	card_panel.closed.connect(_refresh)

	trash_slot.set_meta("kind", "trash")
	trash_slot.set_meta("index", 0)
	trash_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	trash_slot.gui_input.connect(_on_slot_gui_input.bind(trash_slot))
	_add_slot_visuals(trash_slot)
	_all_slots.append(trash_slot)

	visible = false

func _process(_delta: float) -> void:
	if _drag_panel != null:
		_drag_panel.global_position = get_viewport().get_mouse_position() - _drag_panel.size * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if visible and card_panel.visible:
		return
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not visible or _drag_item == null:
		return
	if event is InputEventMouseButton and not event.pressed:
		_drop_at_mouse()

func open() -> void:
	_refresh()
	visible = true

func close() -> void:
	if _drag_item != null:
		_restore_drag()
	else:
		_cancel_drag()
	if card_panel != null and card_panel.visible:
		card_panel.close()
	visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

# ---------- 槽位构建 ----------

func _make_slot(kind: String, index: int, size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("kind", kind)
	panel.set_meta("index", index)
	panel.gui_input.connect(_on_slot_gui_input.bind(panel))
	_add_slot_visuals(panel)
	_all_slots.append(panel)
	return panel

func _add_slot_visuals(panel: Panel) -> void:
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
	name_label.add_theme_font_size_override("font_size", 17)
	panel.add_child(name_label)
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.offset_left = 6
	name_label.offset_top = 4
	name_label.offset_right = -6
	name_label.offset_bottom = -4

	var count_label := Label.new()
	count_label.name = "Count"
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(count_label)
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.offset_left = -54
	count_label.offset_top = -30
	count_label.offset_right = -6
	count_label.offset_bottom = -4

func _setup_existing_slot(panel: Panel, kind: String, index: int) -> void:
	panel.set_meta("kind", kind)
	panel.set_meta("index", index)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_slot_gui_input.bind(panel))
	_add_slot_visuals(panel)
	_all_slots.append(panel)

func _setup_assembly_slots() -> void:
	_setup_existing_slot(body_slot, "assembly", 0)
	_setup_existing_slot(gem_slot, "assembly", 1)

func _build_wand_tabs() -> void:
	for i in range(2):
		var tab := Panel.new()
		tab.custom_minimum_size = Vector2(250, 62)
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		wand_tabs_box.add_child(tab)

		var label := Label.new()
		label.name = "Label"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		tab.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var overlay := ColorRect.new()
		overlay.name = "Overlay"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(0, 0, 0, 0.68)
		tab.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		tab.gui_input.connect(_on_wand_tab_input.bind(tab, i))
		_wand_tabs.append(tab)

func _on_wand_tab_input(event: InputEvent, tab: Panel, index: int) -> void:
	if _drag_item != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_edit_index = index
		_refresh()
		get_viewport().set_input_as_handled()

func _open_card_panel() -> void:
	var wand := GameFlow.get_equipment().wand_slots[_edit_index]
	if wand == null:
		return
	card_panel.open(wand, _edit_index)

# ---------- 刷新 ----------

func _refresh() -> void:
	var inv := GameFlow.get_inventory()

	for i in range(_grid_slots.size()):
		_paint_slot(_grid_slots[i], inv.cells[i], NORMAL_BG)

	_refresh_overflow(inv)
	_paint_slot(trash_slot, inv.trash, TRASH_BG)
	if inv.trash == null:
		trash_slot.get_node("Name").text = "垃圾桶"
	_refresh_assembly()
	_refresh_character_equipment()

	gold_label.text = "金币：%d" % GameFlow.gold

func _refresh_overflow(inv: GridInventory) -> void:
	for slot in _overflow_slots:
		_all_slots.erase(slot)
		slot.queue_free()
	_overflow_slots.clear()

	for i in range(inv.overflow.size()):
		var slot := _make_slot("overflow", i, OVERFLOW_SIZE)
		overflow_slots_box.add_child(slot)
		_overflow_slots.append(slot)
		_paint_slot(slot, inv.get_overflow_at(i), OVERFLOW_BG)

	overflow_box.visible = inv.overflow_count() > 0

func _paint_slot(slot: Panel, item, bg_color: Color) -> void:
	var bg: ColorRect = slot.get_node("Bg")
	var name_label: Label = slot.get_node("Name")
	var count_label: Label = slot.get_node("Count")

	bg.color = bg_color

	if item == null:
		name_label.text = ""
		count_label.text = ""
		return

	if item is ItemStack:
		name_label.text = item.definition.display_name
		count_label.text = str(item.count) if item.count > 1 else ""
	else:
		name_label.text = item.definition.display_name
		count_label.text = ""

func _refresh_assembly() -> void:
	var eq := GameFlow.get_equipment()
	var wand: WandInstance = eq.wand_slots[_edit_index]

	for i in range(_wand_tabs.size()):
		var tab := _wand_tabs[i]
		var label: Label = tab.get_node("Label")
		var overlay: ColorRect = tab.get_node("Overlay")
		label.text = "法杖 %d" % [i + 1]
		overlay.visible = i != _edit_index

	if wand == null:
		selected_label.text = "当前：法杖 %d（空）" % [_edit_index + 1]
		_paint_component(body_slot, null, "杖身")
		_paint_component(gem_slot, null, "宝石")
		return

	selected_label.text = "当前：法杖 %d   战斗：法杖 %d" % [
		_edit_index + 1, eq.active_wand_index + 1
	]

	_paint_component(body_slot, wand.body, "杖身")
	var dragging_gem: bool = (
		_drag_item != null
		and _drag_origin.get("kind") == "assembly"
		and _drag_origin.get("index") == 1
		and _drag_origin.get("wand_instance") == wand
	)
	_paint_component(gem_slot, null if dragging_gem else wand.gem, "宝石")

func _paint_component(panel: Panel, item: ItemInstance, empty_text: String) -> void:
	var bg: ColorRect = panel.get_node("Bg")
	var label: Label = panel.get_node("Name")
	var count: Label = panel.get_node("Count")
	count.text = ""

	if item == null:
		bg.color = Color(0.20, 0.20, 0.24, 1.0)
		label.text = empty_text
		return

	bg.color = EQUIP_BG
	if item.definition.category == ItemDefinition.Category.STAFF_BODY:
		label.text = "%s\n+%d 伤害" % [item.definition.display_name, item.definition.damage_bonus]
	elif item.definition.category == ItemDefinition.Category.GEM:
		label.text = "%s\n%d 槽" % [item.definition.display_name, item.definition.gem_slots]
	else:
		label.text = item.definition.display_name

func _refresh_character_equipment() -> void:
	var eq := GameFlow.get_equipment()
	var items: Array[ItemInstance] = [eq.hat, eq.robe, eq.accessory]
	var titles := ["巫师帽", "巫师袍", "配饰"]

	for i in range(_equip_slots.size()):
		var slot := _equip_slots[i]
		var bg: ColorRect = slot.get_node("Bg")
		var label: Label = slot.get_node("Name")
		var item := items[i]
		bg.color = EQUIP_BG if item != null else Color(0.18, 0.18, 0.21, 1.0)
		label.text = "%s\n%s" % [titles[i], _equip_name(item)]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.offset_left = 12

func _equip_name(item: ItemInstance) -> String:
	if item == null:
		return "空"
	return item.definition.display_name

# ---------- 拖拽 ----------

func _on_slot_gui_input(event: InputEvent, slot: Panel) -> void:
	if _drag_item != null:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return

	_start_drag(slot, event.button_index == MOUSE_BUTTON_RIGHT)
	get_viewport().set_input_as_handled()

func _start_drag(slot: Panel, split: bool) -> void:
	var kind: String = slot.get_meta("kind")
	var index: int = slot.get_meta("index")

	if kind == "assembly":
		var eq := GameFlow.get_equipment()
		var wand: WandInstance = eq.wand_slots[_edit_index]
		if wand == null:
			return

		var item: ItemInstance = null
		if index == 0:
			item = wand.body
			wand.body = null
		else:
			# 宝石和程序先保留在原法杖，只有有效落点才提交拆卸。
			item = wand.gem

		if item == null:
			return

		_drag_item = item
		_drag_origin = {"kind": "assembly", "index": index, "wand_instance": wand, "split": false}
		_create_drag_visual(item)
		_refresh()
		return

	if kind == "equipment":
		if index < 2:
			return
		var eq := GameFlow.get_equipment()
		var equipped := eq.clear_equipment(index)
		if equipped == null:
			return
		_drag_item = equipped
		_drag_origin = {"kind": "equipment", "index": index, "split": false}
		_create_drag_visual(equipped)
		_refresh()
		return

	var inv := GameFlow.get_inventory()
	var item = null

	match kind:
		"cell":
			item = inv.cells[index]
		"overflow":
			item = inv.get_overflow_at(index)
		"trash":
			item = inv.trash

	if item == null:
		return

	var is_split := false
	if split and item is ItemStack and item.count > 1:
		item.count -= 1
		item = ItemStack.new(item.definition, 1)
		is_split = true
	else:
		match kind:
			"cell":
				item = inv.take_cell(index)
			"overflow":
				item = inv.take_overflow(index)
			"trash":
				inv.trash = null

	_drag_item = item
	_drag_origin = {"kind": kind, "index": index, "split": is_split}
	_create_drag_visual(item)
	_refresh()

func _create_drag_visual(item) -> void:
	_drag_panel = Panel.new()
	_drag_panel.size = SLOT_SIZE
	_drag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.25, 0.35, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_panel.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_drag_label = Label.new()
	_drag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_drag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drag_label.add_theme_font_size_override("font_size", 17)
	_drag_panel.add_child(_drag_label)
	_drag_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drag_label.text = _item_label(item)

func _item_label(item) -> String:
	if item is ItemStack:
		return "%s\n×%d" % [item.definition.display_name, item.count]
	return item.definition.display_name

func _drop_at_mouse() -> void:
	var target := _slot_under_mouse()
	if target == null:
		_restore_drag()
		return

	var kind: String = target.get_meta("kind")
	if kind == "trash":
		_drop_to_trash()
	elif kind == "cell":
		_drop_to_cell(int(target.get_meta("index")))
	elif kind == "equipment":
		_drop_to_equipment(int(target.get_meta("index")))
	elif kind == "assembly":
		_drop_to_assembly(int(target.get_meta("index")))
	else:
		_restore_drag()

func _slot_under_mouse() -> Panel:
	var mouse := get_viewport().get_mouse_position()
	for slot in _all_slots:
		if slot.is_visible_in_tree() and slot.get_global_rect().has_point(mouse):
			return slot
	return null

func _drop_to_cell(target_index: int) -> void:
	var inv := GameFlow.get_inventory()
	var src: Dictionary = _drag_origin
	var item = _drag_item

	if src.kind == "cell":
		var source_index: int = src.index
		if source_index == target_index:
			_restore_drag()
			return

		var target = inv.cells[target_index]

		if src.split:
			if target == null:
				inv.cells[target_index] = item
			elif item is ItemStack and target is ItemStack \
				and item.definition == target.definition and target.room() > 0:
				var take: int = mini(target.room(), item.count)
				target.count += take
				item.count -= take
				if item.count > 0:
					inv.add(item)
			else:
				_restore_drag()
				return
		else:
			if target == null:
				inv.cells[target_index] = item
			elif item is ItemStack and target is ItemStack \
				and item.definition == target.definition:
				var take: int = mini(target.room(), item.count)
				target.count += take
				item.count -= take
				if item.count > 0:
					inv.cells[source_index] = item
			else:
				inv.cells[source_index] = target
				inv.cells[target_index] = item

	elif src.kind == "equipment":
		if inv.cells[target_index] == null:
			inv.cells[target_index] = item
		else:
			_restore_drag()
			return

	elif src.kind == "assembly":
		if inv.cells[target_index] == null:
			inv.cells[target_index] = item
		else:
			_restore_drag()
			return

	elif src.kind == "overflow":
		var target = inv.cells[target_index]
		if target == null:
			inv.cells[target_index] = item
		elif item is ItemStack and target is ItemStack \
			and item.definition == target.definition and target.room() > 0:
			var take: int = mini(target.room(), item.count)
			target.count += take
			item.count -= take
			if item.count > 0:
				inv.overflow.append(item)
		else:
			inv.overflow.append(target)
			inv.cells[target_index] = item

	elif src.kind == "trash":
		var target = inv.cells[target_index]
		if target == null:
			inv.cells[target_index] = item
			inv.trash = null
		elif item is ItemStack and target is ItemStack \
			and item.definition == target.definition and target.room() > 0:
			var take: int = mini(target.room(), item.count)
			target.count += take
			item.count -= take
			if item.count > 0:
				inv.trash = item
			else:
				inv.trash = null
		else:
			inv.cells[target_index] = item
			inv.trash = target

	inv.auto_transfer()
	_finish_drag()

func _drop_to_trash() -> void:
	var inv := GameFlow.get_inventory()
	var src: Dictionary = _drag_origin

	if src.kind == "trash":
		_restore_drag()
		return

	inv.trash = _drag_item
	inv.auto_transfer()
	_finish_drag()

func _drop_to_assembly(target_index: int) -> void:
	var inv := GameFlow.get_inventory()
	var eq := GameFlow.get_equipment()
	var wand: WandInstance = eq.wand_slots[_edit_index]
	var src: Dictionary = _drag_origin
	var item = _drag_item

	if wand == null or not (item is ItemInstance):
		_restore_drag()
		return

	if target_index == 0:
		if item.definition.category != ItemDefinition.Category.STAFF_BODY:
			_restore_drag()
			return
	elif target_index == 1:
		if item.definition.category != ItemDefinition.Category.GEM:
			_restore_drag()
			return
	else:
		_restore_drag()
		return

	if src.kind == "assembly":
		_restore_drag()
		return

	var old: ItemInstance = null
	var returned: Array[ItemDefinition] = []

	if target_index == 0:
		old = wand.body
		wand.body = item
	else:
		old = wand.gem
		returned = wand.cards.duplicate()
		wand.cards.clear()
		wand.cast_index = 0
		wand.gem = item
		wand.ensure_slots()

	if old != null:
		if src.kind == "cell" and inv.cells[int(src.index)] == null:
			inv.cells[int(src.index)] = old
		else:
			inv.add(old)

	# 先安置旧组件，再让卡牌合并、占空格或进入溢出队列。
	for card in returned:
		if card != null:
			inv.add_card(card, 1)

	inv.auto_transfer()
	_finish_drag()

func _drop_to_equipment(target_index: int) -> void:
	if target_index < 2:
		_restore_drag()
		return

	var inv := GameFlow.get_inventory()
	var eq := GameFlow.get_equipment()
	var src: Dictionary = _drag_origin
	var item = _drag_item

	if not (item is ItemInstance) or not eq.accepts(target_index, item):
		_restore_drag()
		return

	if src.kind == "equipment":
		_restore_drag()
		return

	var old: ItemInstance = null
	match src.kind:
		"cell":
			var source_index: int = src.index
			old = eq.equip_item(item)
			if old != null:
				if inv.cells[source_index] == null:
					inv.cells[source_index] = old
				else:
					inv.add(old)
		"overflow", "trash":
			old = eq.equip_item(item)
			if old != null:
				inv.add(old)
		_:
			_restore_drag()
			return

	inv.auto_transfer()
	_finish_drag()

func _restore_drag() -> void:
	var inv := GameFlow.get_inventory()
	var src: Dictionary = _drag_origin
	var item = _drag_item
	if item == null:
		_finish_drag(false)
		return

	if src.kind == "assembly" and src.index == 1:
		var original_wand: WandInstance = src.wand_instance
		if original_wand != null and original_wand.gem == item:
			# 未提交的拖拽没有改动模型，也不触发溢出补位。
			_finish_drag(false)
			return

	match src.kind:
		"cell":
			var index: int = src.index
			if not src.split and inv.cells[index] == null:
				inv.cells[index] = item
			else:
				inv.add(item)
		"overflow":
			inv.add(item)
		"trash":
			if inv.trash == null:
				inv.trash = item
			else:
				inv.add(item)
		"equipment":
			var eq := GameFlow.get_equipment()
			var index: int = src.index
			if eq.equipment_item_at(index) == null:
				eq.equip_item(item)
			else:
				inv.add(item)
		"assembly":
			var wand: WandInstance = src.wand_instance
			if wand != null:
				if src.index == 0 and wand.body == null:
					wand.body = item
				elif src.index == 1 and wand.gem == null:
					wand.gem = item
				else:
					inv.add(item)
			else:
				inv.add(item)

	inv.auto_transfer()
	_finish_drag(false)

func _commit_gem_drag() -> void:
	if _drag_origin.get("kind") != "assembly" or _drag_origin.index != 1:
		return
	var wand: WandInstance = _drag_origin.wand_instance
	if wand == null or wand.gem != _drag_item:
		return
	var returned := wand.cards.duplicate()
	wand.gem = null
	wand.cards.clear()
	wand.cast_index = 0
	for card in returned:
		if card != null:
			GameFlow.get_inventory().add_card(card, 1)

func _finish_drag(commit: bool = true) -> void:
	if commit:
		_commit_gem_drag()
	_cancel_drag()
	_refresh()
	EventBus.loadout_changed.emit()

func _cancel_drag() -> void:
	if _drag_panel != null:
		_drag_panel.queue_free()
		_drag_panel = null
		_drag_label = null
	_drag_item = null
	_drag_origin = {}
