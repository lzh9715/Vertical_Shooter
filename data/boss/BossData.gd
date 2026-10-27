extends Resource
class_name BossData

@export var display_name := "Boss"
@export var scene: PackedScene            # 默认 base_boss.tscn
@export var max_hp := 600
@export var attack_power := 16.0
@export var defense := 8.0
@export_range(0.0, 0.75, 0.01) var damage_reduction := 0.1
@export var visual_scale := 1.0
@export var texture: Texture2D
@export var enter_duration := 1.5
@export var hover_position := Vector2(1920, 720)
@export var phases: Array[BossPhaseData] = []