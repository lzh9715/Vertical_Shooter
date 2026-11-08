extends Control

var _cards: Array = []
var _straight_visual: Node2D
var _orbit_visual: Node2D
var _straight_x := -520.0
var _orbit_angle := 0.0

@onready var list: ItemList = $Panel/List
@onready var straight_holder: Node2D = $StraightArea/Holder
@onready var orbit_holder: Node2D = $OrbitArea/Holder
@onready var title: Label = $Header/Title
@onready var info: Label = $Header/Info

func _ready() -> void:
	_cards.clear()
	for card in ItemCatalog.cards():
		if card != null and String(card.id).begins_with("projectile_"):
			_cards.append(card)
	for card in _cards:
		var index := list.add_item(card.display_name)
		list.set_item_metadata(index, card)
	list.item_selected.connect(_on_selected)
	if not _cards.is_empty():
		list.select(0)
		_on_selected(0)

func _on_selected(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	var card: ItemDefinition = _cards[index]
	_clear_holders()
	title.text = card.display_name
	info.text = "%s  |  伤害 %d  |  法力 %d  |  速度 %d" % [
		String(card.id), card.base_damage, card.mana_cost, int(card.projectile_speed)
	]
	_straight_visual = _make_visual(card)
	if _straight_visual != null:
		_straight_holder.add_child(_straight_visual)
		_straight_x = -520.0
		_straight_visual.position = Vector2(_straight_x, 0)
		_straight_visual.rotation = PI / 2.0
	_orbit_visual = _make_visual(card)
	if _orbit_visual != null:
		_orbit_holder.add_child(_orbit_visual)
		_orbit_angle = 0.0
		_orbit_visual.position = Vector2(240, 0)

func _make_visual(card: ItemDefinition) -> Node2D:
	if card.visual_scene == null:
		return null
	var visual := card.visual_scene.instantiate()
	if visual is Node2D:
		visual.scale = Vector2(2.0, 2.0)
		return visual
	return null

func _clear_holders() -> void:
	for child in straight_holder.get_children():
		child.queue_free()
	for child in orbit_holder.get_children():
		child.queue_free()
	_straight_visual = null
	_orbit_visual = null

func _process(delta: float) -> void:
	if _straight_visual != null:
		_straight_x += 260.0 * delta
		if _straight_x > 620.0:
			_straight_x = -620.0
		_straight_visual.position = Vector2(_straight_x, 0)
	if _orbit_visual != null:
		_orbit_angle += 1.1 * delta
		_orbit_visual.position = Vector2(cos(_orbit_angle), sin(_orbit_angle)) * 240.0
		_orbit_visual.rotation = _orbit_angle + PI / 2.0
