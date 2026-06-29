extends RefCounted
class_name WeaponPassiveController

var weapon: Weapon
var passive_icd_msec: Dictionary = {}
var passive_charge_count: int = -1

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon

func emit_passive_trigger(event_name: StringName, detail: Dictionary = {}, passive_scope: StringName = Weapon.PASSIVE_SCOPE_BODY) -> void:
	var output := detail.duplicate(true) if detail != null else {}
	output = with_passive_charge_status(output)
	if not output.has("passive_id"):
		output["passive_id"] = str(event_name)
	if not output.has("trigger_type"):
		output["trigger_type"] = str(output.get("trigger", event_name))
	if not output.has("refresh_type"):
		output["refresh_type"] = str(output.get("refresh", ""))
	if not output.has("state_after_trigger"):
		output["state_after_trigger"] = "ready" if is_passive_ready() else "cooldown"
	if not output.has("passive_scope"):
		output["passive_scope"] = passive_scope
	var effect_delivery := EffectDeliveryType.TARGET if output.get("target") is Node else EffectDeliveryType.SELF
	var effect_data := EffectData.new().setup(
		weapon,
		output.get("target") as Node,
		event_name,
		DamageData.SOURCE_PLAYER_WEAPON,
		effect_delivery,
		output
	)
	output["source_category"] = effect_data.source_category
	output["effect_delivery_type"] = effect_data.effect_delivery_type
	output["effect_data"] = effect_data
	weapon.passive_triggered.emit(event_name, output)

func can_passive_trigger(passive_id: StringName, icd_sec: float) -> bool:
	if passive_id == StringName():
		return true
	var now_msec := Time.get_ticks_msec()
	var ready_at: int = int(passive_icd_msec.get(passive_id, 0))
	if now_msec < ready_at:
		return false
	if icd_sec > 0.0:
		passive_icd_msec[passive_id] = now_msec + int(icd_sec * 1000.0)
	return true

func dispatch_passive_event(event_name: StringName, detail: Dictionary = {}) -> void:
	if weapon.is_offhand_weapon():
		on_offhand_passive_event(event_name, detail)
	else:
		on_main_passive_event(event_name, detail)

func on_offhand_passive_event(event_name: StringName, detail: Dictionary) -> void:
	on_passive_event(event_name, detail)

func on_main_passive_event(event_name: StringName, detail: Dictionary) -> void:
	on_passive_event(event_name, detail)

func on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	if bool(detail.get("_suppress_default_emit", false)):
		return
	emit_passive_trigger(event_name, detail, Weapon.PASSIVE_SCOPE_BODY)

func get_passive_status() -> Dictionary:
	var charge_max := get_passive_charge_max()
	var charge_current := get_passive_charge_current()
	return with_passive_charge_status({
		"id": "",
		"display_name": "",
		"state": "unavailable",
		"progress": 1.0 if is_passive_ready() else 0.0,
		"current": charge_current,
		"required": 1,
		"ready": is_passive_ready(),
		"trigger_hint": "",
		"refresh_hint": "reload",
		"charge_current": charge_current,
		"charge_max": charge_max,
		"charges_current": charge_current,
		"charges_max": charge_max,
	})

func with_passive_charge_status(status: Dictionary) -> Dictionary:
	var output := status.duplicate(true) if status != null else {}
	var charge_max := get_passive_charge_max()
	var charge_current := get_passive_charge_current()
	if not output.has("charge_current"):
		output["charge_current"] = charge_current
	if not output.has("charge_max"):
		output["charge_max"] = charge_max
	if not output.has("charges_current"):
		output["charges_current"] = charge_current
	if not output.has("charges_max"):
		output["charges_max"] = charge_max
	output["charge_based"] = true
	return output

func is_passive_ready() -> bool:
	return get_passive_charge_current() > 0

func notify_passive_triggered(_cooldown_sec := 0.0) -> void:
	var charge_max := get_passive_charge_max()
	passive_charge_count = clampi(max(0, get_passive_charge_current() - 1), 0, charge_max)
	weapon.set_offhand_skill_ready(passive_charge_count > 0)

func refresh_passive_on_reload() -> void:
	passive_charge_count = get_passive_charge_max()
	weapon.set_offhand_skill_ready(true)
	weapon.offhand_refreshed_by_reload.emit(weapon)

func get_offhand_skill_cd_progress() -> float:
	return 1.0 if is_passive_ready() else 0.0

func force_ready() -> void:
	passive_charge_count = get_passive_charge_max()
	weapon.set_offhand_skill_ready(true)

func clear_for_weapon_exit() -> void:
	passive_icd_msec.clear()

func get_passive_charge_max() -> int:
	if weapon == null or not is_instance_valid(weapon):
		return 1
	if weapon.has_method("get_passive_max_charges"):
		return maxi(1, int(weapon.call("get_passive_max_charges")))
	return 1

func get_passive_charge_current() -> int:
	var charge_max := get_passive_charge_max()
	if passive_charge_count < 0 or passive_charge_count > charge_max:
		passive_charge_count = charge_max if weapon != null and is_instance_valid(weapon) and weapon.get_offhand_skill_ready_flag() else 0
	return clampi(passive_charge_count, 0, charge_max)
