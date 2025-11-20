@tool
extends Resource
class_name MechaDefinition

@export var mecha_id := ""
@export var display_name := ""
@export var scene: PackedScene
@export var max_level := 10
@export var next_level_exp: PackedInt32Array = []
@export var player_max_hp: PackedInt32Array = []
@export var player_speed: PackedFloat32Array = []
@export var armor: PackedInt32Array = []
@export var shield: PackedInt32Array = []
@export var hp_regen: PackedFloat32Array = []
@export var damage_reduction: PackedFloat32Array = []
@export var crit_rate: PackedFloat32Array = []
@export var crit_damage: PackedFloat32Array = []
@export var grab_radius: PackedFloat32Array = []
@export var player_gold: PackedInt32Array = []
