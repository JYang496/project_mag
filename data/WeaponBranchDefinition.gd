@tool
extends Resource
class_name WeaponBranchDefinition

@export var branch_id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export var unlock_fuse := 2
@export var weapon_scene: PackedScene
@export var behavior_scene: PackedScene
