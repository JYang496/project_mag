extends Module
# Use on HEAT weapons to apply a fire-like erosion DOT payload on each hit.

var ITEM_NAME := "Thermal Ignition"

@export var dot_damage: float = 3.0
@export var dot_duration: float = 3.0

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not _is_valid_heat_weapon(source_weapon):
		return

	var final_damage: int = max(1, int(round(get_effective_additive(maxf(dot_damage, 0.0), 0.4))))
	var ticks: int = max(1, int(round(get_effective_additive(maxf(dot_duration, 0.0), 0.3))))
	if target.has_method("apply_status_payload"):
		target.apply_status_payload(&"erosion", {
			"damage": final_damage,
			"tick": ticks,
			"damage_type": &"fire",
		})
		return
	if target.has_method("apply_status_effect"):
		var owner_player := DamageManager.resolve_source_player(source_weapon)
		var effect := ErosionStatusEffect.new().setup_effect(ticks, final_damage, Attack.TYPE_FIRE)
		effect.set_source_context(owner_player, source_weapon)
		target.apply_status_effect(effect)

func _is_valid_heat_weapon(source_weapon: Weapon) -> bool:
	if source_weapon == null:
		return false
	if not source_weapon.has_method("has_heat_trait"):
		return false
	return bool(source_weapon.call("has_heat_trait"))
