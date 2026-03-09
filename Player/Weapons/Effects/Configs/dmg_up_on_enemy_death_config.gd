@tool
extends EffectConfig
class_name DmgUpOnEnemyDeathEffectConfig

@export var dmg_up_per_kill: int = 2

func _init() -> void:
	effect_id = &"dmg_up_on_enemy_death"

# Builds runtime params consumed by Effect.configure().
func build_params() -> Dictionary:
	return {
		"dmg_up_per_kill": dmg_up_per_kill,
	}
