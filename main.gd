extends Node2D

@export var enemy_scene: PackedScene
@export var all_spells: Array[SpellData] = [] 
@export var wave_pool: Array[Resource] = [] 

# --- 【新】当前商店货架上的 3 个商品 ---
var shop_spells: Array[SpellData] = []
var active_enemies = []

@onready var score_label: Label = $CanvasLayer/Label
@onready var gold_label: Label = $CanvasLayer/GoldLabel
@onready var shop_gold_label: Label = $RestStationUI/VBoxContainer/ShopGoldLabel
@onready var rest_ui: CanvasLayer = $RestStationUI
@onready var desc_label: Label = $RestStationUI/DescLabel
@onready var hp_label: Label = $CanvasLayer/HpLabel

var score := 0
var gold := 5000

func _ready():
	rest_ui.visible = false
	rest_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 【修改】连接三个槽位按钮（传 0, 1, 2 代表槽位索引）
	$RestStationUI/VBoxContainer/Btn_Slot1.pressed.connect(func(): buy_slot(0))
	$RestStationUI/VBoxContainer/Btn_Slot2.pressed.connect(func(): buy_slot(1))
	$RestStationUI/VBoxContainer/Btn_Slot3.pressed.connect(func(): buy_slot(2))
	$RestStationUI/VBoxContainer/Btn_Resume.pressed.connect(toggle_rest_station)
	$RestStationUI/VBoxContainer/Btn_Refresh.pressed.connect(refresh_shop)
	$Spawner.enemy_died.connect(_on_enemy_died)

		# 监听鼠标进入和离开事件
	$RestStationUI/VBoxContainer/Btn_Slot1.mouse_entered.connect(func(): show_tooltip(0))
	$RestStationUI/VBoxContainer/Btn_Slot1.mouse_exited.connect(hide_tooltip)
	
	$RestStationUI/VBoxContainer/Btn_Slot2.mouse_entered.connect(func(): show_tooltip(1))
	$RestStationUI/VBoxContainer/Btn_Slot2.mouse_exited.connect(hide_tooltip)
	
	$RestStationUI/VBoxContainer/Btn_Slot3.mouse_entered.connect(func(): show_tooltip(2))
	$RestStationUI/VBoxContainer/Btn_Slot3.mouse_exited.connect(hide_tooltip)

	
	
	# 游戏开局先随机生成一次货架
	generate_shop_items()
	update_ui()
	# 创建一个全新的波次定时器
	var wave_timer = Timer.new()
	wave_timer.wait_time = 3.5 # 每 3.5 秒出下一波（你可以随时调）
	wave_timer.autostart = true
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	add_child(wave_timer)
	update_hp_ui(3, 3) # 初始化血量显示

# --- 随机生成货架逻辑 ---
func generate_shop_items():
	shop_spells.clear()
	
	# 复制一份盲盒池，并打乱顺序
	var temp_pool = all_spells.duplicate()
	temp_pool.shuffle()
	
	# 取前 3 个放上货架（如果池子不足 3 个，有多少放多少）
	for i in range(min(3, temp_pool.size())):
		var spell = temp_pool[i]
		# 每次上架时，随机赋予一个 20~150 的价格
		spell.price = randi_range(20, 150) 
		shop_spells.append(spell)

# --- 购买逻辑 ---
func buy_slot(slot_index: int):
	# 如果槽位是空的（池子里法杖太少），直接返回
	if slot_index >= shop_spells.size():
		return
		
	var target_spell = shop_spells[slot_index]
	
	if gold >= target_spell.price:
		gold -= target_spell.price
		var player = get_node_or_null("player")
		if player:
			player.current_spell = target_spell
		update_ui()
		print("购买成功！装备了: ", target_spell.resource_path)
	else:
		print("金币不足，无法购买！")


func _on_enemy_died(score_gain: int, gold_gain: int) -> void:
	score += score_gain
	gold += gold_gain
	update_ui()

func toggle_rest_station():
	rest_ui.visible = not rest_ui.visible
	get_tree().paused = rest_ui.visible
# --- UI 刷新逻辑 ---
func update_ui():
	score_label.text = "Score: " + str(score)
	gold_label.text = "金币: " + str(gold)
	shop_gold_label.text = "当前金币: " + str(gold)
	
	# 动态更新三个槽位的按钮文本
	var buttons = [
		$RestStationUI/VBoxContainer/Btn_Slot1,
		$RestStationUI/VBoxContainer/Btn_Slot2,
		$RestStationUI/VBoxContainer/Btn_Slot3
	]
	
	for i in range(3):
		if i < shop_spells.size():
			var spell = shop_spells[i]
			# 用文件名来显示法杖名字，比如 Spell_Homing.tres 就显示 Spell_Homing
			var spell_name = spell.display_name
			# 加上个保险：如果忘了填中文名，就显示“神秘法杖”
			if spell_name == "" or spell_name == "未命名法杖":
				spell_name = "神秘法杖"
			buttons[i].text = "%s (%d金币)" % [spell_name, spell.price]
			buttons[i].disabled = false
		else:
			buttons[i].text = "空槽位"
			buttons[i].disabled = true

# --- 刷新商店逻辑 ---
func refresh_shop():
	if gold < 10:
		print("金币不足，无法刷新商店！")
		return

	gold -= 10
	generate_shop_items() # 重新生成货架
	update_ui()
	print("商店刷新完成！")
# 显示提示
func show_tooltip(slot_index: int):
	if slot_index < shop_spells.size():
		var spell = shop_spells[slot_index]
		desc_label.text = spell.description  # 👈 只要这句！不要带 $RestStationUI...
		desc_label.modulate = Color(1, 1, 1, 1)
# 隐藏提示（恢复默认文字）
func hide_tooltip():
	desc_label.text = "将鼠标悬停在法杖上查看说明"
	desc_label.modulate = Color(1, 1, 1, 0.5)

func _on_wave_timer_timeout():
	# 如果池子是空的，就不生成
	if wave_pool.is_empty():
		print("⚠️ 图纸池是空的，请去检查器里拖入图纸！")
		return
		
	# 随机抽一张图纸
	var random_data = wave_pool.pick_random()
	
	# 让 Spawner 去干活
	$Spawner.trigger_spawn(random_data)

# 新增供玩家调用的函数
func update_hp_ui(current: int, max_val: int):
	hp_label.text = "HP: %d/%d" % [current, max_val]
