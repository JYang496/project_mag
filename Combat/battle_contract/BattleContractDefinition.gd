extends Resource
class_name BattleContractDefinition

@export var contract_id: StringName = &""
@export var name_key: String = ""
@export var description_key: String = ""
@export var icon: Texture2D
@export var accent_color: Color = Color.WHITE
@export_range(0.0, 100.0, 0.05) var weight: float = 1.0
@export var build_tags: Array[StringName] = []
@export var parameters: Dictionary = {}

