@tool
extends Resource
class_name EffectConfig

@export var effect_id: StringName
@export var enabled: bool = true
@export var priority: int = 0

# Builds runtime params consumed by Effect.configure().
func build_params() -> Dictionary:
	return {}

# Returns a concise editor-facing summary for quick inspection.
func get_editor_summary() -> String:
	return "%s (enabled=%s, priority=%d)" % [str(effect_id), str(enabled), priority]
