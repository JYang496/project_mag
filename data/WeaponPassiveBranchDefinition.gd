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
@export_enum("bean_only", "bean_with_condition") var hud_mode := "bean_only"
@export_enum("instant", "timed") var effect_mode := "instant"
