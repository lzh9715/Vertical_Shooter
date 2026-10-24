extends RefCounted
class_name GridInventory

## 背包：10×6 普通格 + 无限溢出队列 + 1 个垃圾桶格。
## 所有物品在普通格里都只占 1 格。

const COLUMNS := 10
const ROWS := 6

var cells: Array = []
var overflow: Array = []
var trash: Variant = null

func _init() -> void:
	cells.resize(COLUMNS * ROWS)
	cells.fill(null)

func capacity() -> int:
	return cells.size()

func occupied_count() -> int:
	var total := 0
	for cell in cells:
		if cell != null:
			total += 1
	return total

func free_cells() -> int:
	return capacity() - occupied_count()

func is_full() -> bool:
	return free_cells() <= 0

func has_overflow() -> bool:
	return not overflow.is_empty()

func overflow_count() -> int:
	return overflow.size()

# ---------- 添加 ----------

func add(item) -> bool:
	if item == null:
		return false

	if item is ItemStack:
		var remaining: int = item.count
		remaining = _merge_into_cells(item.definition, remaining)

		while remaining > 0:
			var chunk: int = mini(remaining, maxi(item.definition.stack_limit, 1))
			var stack := ItemStack.new(item.definition, chunk)
			if free_cells() > 0:
				_place_first_free(stack)
			else:
				_add_to_overflow(stack)
			remaining -= chunk

	elif item is ItemInstance:
		if free_cells() > 0:
			_place_first_free(item)
		else:
			overflow.append(item)

	else:
		return false

	_auto_transfer_overflow()
	return true

func add_card(definition: ItemDefinition, count := 1) -> void:
	var remaining := count
	while remaining > 0:
		var chunk: int = mini(remaining, maxi(definition.stack_limit, 1))
		add(ItemStack.new(definition, chunk))
		remaining -= chunk

# ---------- 取出 / 移动 ----------

func remove_at(index: int):
	if index < 0 or index >= cells.size():
		return null

	var item = cells[index]
	cells[index] = null
	_auto_transfer_overflow()
	return item

## 拖拽用：取出但不触发溢出补位
func take_cell(index: int):
	if index < 0 or index >= cells.size():
		return null
	var item = cells[index]
	cells[index] = null
	return item

func take_overflow(index: int):
	if index < 0 or index >= overflow.size():
		return null
	return overflow.pop_at(index)

func auto_transfer() -> void:
	_auto_transfer_overflow()

func move_cell(from_index: int, to_index: int) -> bool:
	if from_index == to_index:
		return false
	if from_index < 0 or from_index >= cells.size():
		return false
	if to_index < 0 or to_index >= cells.size():
		return false

	var source = cells[from_index]
	var target = cells[to_index]
	if source == null:
		return false

	if target == null:
		cells[to_index] = source
		cells[from_index] = null
	elif source is ItemStack and target is ItemStack \
		and source.definition == target.definition and target.room() > 0:
		var take: int = mini(target.room(), source.count)
		target.count += take
		source.count -= take
		if source.count <= 0:
			cells[from_index] = null
	else:
		cells[from_index] = target
		cells[to_index] = source

	_auto_transfer_overflow()
	return true

# ---------- 垃圾桶 ----------

func send_to_trash(index: int) -> bool:
	if index < 0 or index >= cells.size() or cells[index] == null:
		return false

	trash = cells[index]
	cells[index] = null
	_auto_transfer_overflow()
	return true

func send_overflow_to_trash(index: int) -> bool:
	if index < 0 or index >= overflow.size():
		return false

	trash = overflow[index]
	overflow.remove_at(index)
	_auto_transfer_overflow()
	return true

## 从垃圾桶拖到普通格：空位/可堆叠则正常放入，否则与目标交换。
func take_trash_to_cell(index: int) -> bool:
	if trash == null:
		return false
	if index < 0 or index >= cells.size():
		return false

	var target = cells[index]

	if target == null:
		cells[index] = trash
		trash = null
	elif trash is ItemStack and target is ItemStack \
		and trash.definition == target.definition and target.room() > 0:
		var take: int = mini(target.room(), trash.count)
		target.count += take
		trash.count -= take
		if trash.count <= 0:
			trash = null
	else:
		cells[index] = trash
		trash = target

	_auto_transfer_overflow()
	return true

# ---------- 溢出 ----------

func clear_overflow() -> int:
	var count := overflow.size()
	overflow.clear()
	return count

func get_overflow_at(index: int):
	if index < 0 or index >= overflow.size():
		return null
	return overflow[index]

# ---------- 内部 ----------

func _place_first_free(item) -> bool:
	for i in range(cells.size()):
		if cells[i] == null:
			cells[i] = item
			return true
	return false

func _merge_into_cells(definition: ItemDefinition, amount: int) -> int:
	var remaining := amount
	for i in range(cells.size()):
		if remaining <= 0:
			break

		var cell = cells[i]
		if cell is ItemStack and cell.definition == definition and cell.room() > 0:
			var take: int = mini(cell.room(), remaining)
			cell.count += take
			remaining -= take

	return remaining

func _add_to_overflow(stack: ItemStack) -> void:
	for i in range(overflow.size()):
		var existing = overflow[i]
		if existing is ItemStack and existing.definition == stack.definition and existing.room() > 0:
			var take: int = mini(existing.room(), stack.count)
			existing.count += take
			stack.count -= take
			if stack.count <= 0:
				return

	overflow.append(stack)

func _auto_transfer_overflow() -> void:
	while free_cells() > 0 and not overflow.is_empty():
		var item = overflow[0]

		if item is ItemStack:
			var remaining := _merge_into_cells(item.definition, item.count)
			if remaining <= 0:
				overflow.pop_front()
			elif free_cells() > 0:
				overflow.pop_front()
				_place_first_free(ItemStack.new(item.definition, remaining))
			else:
				overflow[0] = ItemStack.new(item.definition, remaining)
				return
		else:
			overflow.pop_front()
			_place_first_free(item)
