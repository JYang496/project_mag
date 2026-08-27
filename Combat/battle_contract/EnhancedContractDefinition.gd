extends Resource
class_name EnhancedContractDefinition

@export var enhanced_id: StringName = &""
@export var contract_id: StringName = &""
@export var risk_text_keys: Array[String] = []
@export var risk_fallback_lines: Array[String] = []
@export var parameters: Dictionary = {}
@export var reward_pool: Array[StringName] = [
	&"compatible_module",
	&"gold_pack",
	&"equipped_weapon_core",
]
@export var minimum_level_index := 0

