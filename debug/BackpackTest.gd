extends Node

## 背包体验场景：
## 1 填满普通格 / 2 填满并制造溢出 / 3 清空溢出 / 4 重置测试物品
## B 打开或关闭背包

var _map
var _hint: Label
var _filled_def: ItemDefinition
var _overflow_def: ItemDefinition

func _ready() -> void:
	_filled_def = _make_def(&"debug_gear", "测试装备", ItemDefinition.Category.ACCESSORY, 1, 10)
	_overflow_def = _make_def(&"debug_card", "测试法术卡", ItemDefinition.Category.SPELL_CARD, 3, 10)

	_map = load("res://scenes/map/MapView.tscn").instantiate()
	add_child(_map)
	await get_tree().process_frame

	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	_hint = Label.new()
	_hint.position = Vector2(30, 26)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_hint.text = "测试：1 填满背包  2 填满并制造溢出  3 清空溢出  4 重置物品    B 开关背包"
	layer.add_child(_hint)

	_map.backpack.open()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_1:
			_fill_normal()
		KEY_2:
			_fill_normal()
			_add_overflow()
		KEY_3:
			var inv := GameFlow.get_inventory()
			inv.clear_overflow()
			_map.backpack._refresh()
		KEY_4:
			GameFlow._seed_starter_inventory()
			_map.backpack._refresh()

func _fill_normal() -> void:
	var inv := GameFlow.get_inventory()
	while inv.occupied_count() < inv.capacity():
		inv.add(ItemInstance.create(_filled_def))
	inv.auto_transfer()
	_map.backpack._refresh()

func _add_overflow() -> void:
	var inv := GameFlow.get_inventory()
	inv.add_card(_overflow_def, 5)
	_map.backpack._refresh()

func _make_def(id: StringName, name: String, category: int, stack_limit: int, price: int) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.display_name = name
	def.category = category
	def.stack_limit = stack_limit
	def.base_price = price
	return def
