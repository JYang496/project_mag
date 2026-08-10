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
@export_category("Build Synergy")
@export var produces_tags: Array[StringName] = []
@export var requires_any_tags: Array[StringName] = []
@export var requires_all_tags: Array[StringName] = []
@export var amplifies_tags: Array[StringName] = []
@export var conflicts_with_tags: Array[StringName] = []
