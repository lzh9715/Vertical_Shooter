extends Resource
class_name SpellData

@export var display_name: String = "未命名法杖"
@export_multiline var description: String = "这是一把神秘的法杖..." 
@export var bullet_count: int = 1

@export var spread_angle: float = 0.0
@export var bullet_speed: float = 800.0
@export var is_homing: bool = false
@export var price: int = 0 

@export_group("Special Effects") # 在检查器里分个组，更好看
@export var is_piercing: bool = false      # 是否穿透
@export var pierce_amount: int = 3         # 穿透几次（打中几个怪）
@export var is_explosive: bool = false     # 是否爆炸
@export var explosion_radius: float = 80.0 # 爆炸半径