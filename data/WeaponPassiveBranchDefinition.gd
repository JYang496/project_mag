@tool
extends Resource
class_name WeaponPassiveBranchDefinition

@export var passive_id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export var condition_type := ""
@export var refresh_type := ""
@export_enum("none", "state", "progress", "threshold", "cooldown") var ui_mode := "state"
