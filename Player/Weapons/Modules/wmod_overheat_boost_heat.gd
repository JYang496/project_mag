extends Module
# Use on HEAT weapons to keep firing while overheated, with reduced overheated damage.

var ITEM_NAME := "Overheat Boost"

@export var overheated_damage_mult: float = 0.5
var _bypass_registered: bool = false

func _ready() -> void:
	_ensure_bypass_registration()

func _physics_process(_delta: float) -> void:
	if _bypass_registered:
		return
	_ensure_bypass_registration()

func _exit_tree() -> void:
	if not _bypass_registered:
		return
	if weapon != null and weapon.has_method("unregister_overheat_fire_bypass"):
		weapon.call("unregister_overheat_fire_bypass", self)
	_bypass_registered = false

func apply_stat_modifiers(stat_block: Dictionary) -> Dictionary:
	var output := super.apply_stat_modifiers(stat_block)
	if output == null or output.is_empty() or not output.has("damage"):
		return output
	if weapon == null:
		weapon = _resolve_weapon()
	if weapon == null or not _is_valid_heat_weapon(weapon):
		return output
	if not bool(weapon.call("is_weapon_overheated")):
		return output

	var clamped_mult := maxf(overheated_damage_mult, 0.05)
	var final_mult := get_effective_multiplier(clamped_mult, 0.25)
	output["damage"] = float(output["damage"]) * final_mult
	return output

func _is_valid_heat_weapon(target_weapon: Weapon) -> bool:
	if target_weapon == null:
		return false
	if not target_weapon.has_method("has_heat_trait"):
		return false
	if not bool(target_weapon.call("has_heat_trait")):
		return false
	return target_weapon.has_method("is_weapon_overheated")

func _ensure_bypass_registration() -> void:
	if _bypass_registered:
		return
	if weapon == null:
		weapon = _resolve_weapon()
	if weapon == null or not _is_valid_heat_weapon(weapon):
		return
	if not weapon.has_method("register_overheat_fire_bypass"):
		return
	weapon.call("register_overheat_fire_bypass", self)
	_bypass_registered = true
