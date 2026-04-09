@tool
extends Resource
class_name WeaponDefinition

@export var weapon_id := ""
@export var display_name := ""
@export var icon: Texture2D
@export var price := 0
@export_multiline var description := ""
@export var scene: PackedScene
@export var appears_as_standalone: bool = true
@export var standalone_replacement_weapon_id: String = ""
