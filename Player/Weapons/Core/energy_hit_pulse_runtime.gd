extends RefCounted
class_name EnergyHitPulseRuntime

const DEFAULT_REQUIRED_HITS: int = 5
const PROGRESS_EVENT: StringName = &"energy_hit_pulse_progress"

var weapon: Weapon
var current_hits: int = 0
var required_hits: int = DEFAULT_REQUIRED_HITS


func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon
	required_hits = DEFAULT_REQUIRED_HITS


func record_applied_damage(target: Node, data: DamageData, result: DamageResult) -> Dictionary:
	if not _is_valid_energy_hit(target, data, result):
		return {"accepted": false, "triggered": false}
	current_hits += 1
	var triggered := current_hits >= required_hits
	if triggered:
		current_hits = current_hits % required_hits
	var detail := {
		"accepted": true,
		"triggered": triggered,
		"target": target,
		"current": current_hits,
		"required": required_hits,
		"final_damage": result.final_damage,
		"damage_type": result.damage_type,
		"delivery_type": data.delivery_type,
		"trigger": "fifth_valid_energy_hit" if triggered else "valid_energy_hit",
		"refresh": "automatic_after_discharge",
	}
	if triggered:
		var effect_detail: Variant = weapon.call("_execute_energy_hit_discharge", target, data, result)
		if effect_detail is Dictionary:
			detail.merge(effect_detail as Dictionary, true)
		weapon.emit_passive_trigger(weapon.get_energy_hit_passive_id(), detail, Weapon.PASSIVE_SCOPE_BODY)
	else:
		weapon.emit_passive_trigger(PROGRESS_EVENT, detail, Weapon.PASSIVE_SCOPE_BODY)
	return detail


func get_status(passive_id: StringName, display_name: String) -> Dictionary:
	var required := maxi(required_hits, 1)
	var progress := clampf(float(current_hits) / float(required), 0.0, 1.0)
	return {
		"id": str(passive_id),
		"display_name": display_name,
		"state": "charging",
		"progress": progress,
		"progress_role": "trigger_condition",
		"current": current_hits,
		"required": required,
		"ready": false,
		"condition_visible": true,
		"condition_progress": progress,
		"condition_thresholds": [0.2, 0.4, 0.6, 0.8],
		"trigger_hint": "fifth_valid_energy_hit",
		"refresh_hint": "automatic_after_discharge",
		"charge_based": false,
		"energy_hit_cycle": true,
	}


func clear() -> void:
	current_hits = 0


func _is_valid_energy_hit(target: Node, data: DamageData, result: DamageResult) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if target == null or not is_instance_valid(target) or data == null or result == null:
		return false
	if not result.applied or result.final_damage <= 0:
		return false
	if data.source_category != DamageData.SOURCE_PLAYER_WEAPON:
		return false
	if data.damage_kind != DamageData.KIND_DIRECT or data.suppress_reactive_effects:
		return false
	if Attack.normalize_damage_type(result.damage_type) != Attack.TYPE_ENERGY:
		return false
	if not weapon.has_weapon_trait(WeaponTrait.ENERGY):
		return false
	return weapon.accepts_energy_hit_pulse(target, data, result)
