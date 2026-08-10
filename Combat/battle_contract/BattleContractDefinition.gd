extends Resource
class_name BattleContractDefinition

@export var contract_id: StringName = &""
@export var name_key: String = ""
@export var description_key: String = ""
@export var icon: Texture2D
@export var accent_color: Color = Color.WHITE
@export_range(0.0, 100.0, 0.05) var weight: float = 1.0
@export var minimum_offer_level_index: int = 0
@export var long_form: bool = false
@export var multiple_long_offer_level_index: int = -1
@export var build_tags: Array[StringName] = []
@export_category("Build Synergy")
@export var produces_tags: Array[StringName] = []
@export var requires_any_tags: Array[StringName] = []
@export var requires_all_tags: Array[StringName] = []
@export var amplifies_tags: Array[StringName] = []
@export var conflicts_with_tags: Array[StringName] = []
@export var parameters: Dictionary = {}
