extends Resource
class_name BossData

@export var display_name := "Boss"
@export var scene: PackedScene            # 默认 base_boss.tscn
@export var max_hp := 600
@export var visual_scale := 1.0
@export var texture: Texture2D
@export var enter_duration := 1.5
@export var hover_position := Vector2(360, 240)
@export var phases: Array[BossPhaseData] = []