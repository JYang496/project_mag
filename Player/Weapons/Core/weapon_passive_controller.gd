extends RefCounted
class_name WeaponPassiveController

var weapon: Weapon
var passive_icd_msec: Dictionary = {}

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon

func emit_passive_trigger(event_name: StringName, detail: Dictionary = {}, passive_scope: StringName = Weapon.PASSIVE_SCOPE_BODY) -> void:
	var output := detail.duplicate(true) if detail != null else {}
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
	return {
		"id": "",
		"display_name": "",
		"state": "unavailable",
		"progress": 1.0 if is_passive_ready() else 0.0,
		"current": 1 if is_passive_ready() else 0,
		"required": 1,
		"ready": is_passive_ready(),
		"trigger_hint": "",
		"refresh_hint": "reload",
	}

func is_passive_ready() -> bool:
	return weapon._offhand_skill_ready

func notify_passive_triggered(_cooldown_sec := 0.0) -> void:
	weapon._offhand_skill_ready = false

func refresh_passive_on_reload() -> void:
	weapon._offhand_skill_ready = true
	weapon.offhand_refreshed_by_reload.emit(weapon)

func get_offhand_skill_cd_progress() -> float:
	return 1.0 if is_passive_ready() else 0.0

func force_ready() -> void:
	weapon._offhand_skill_ready = true

func clear_for_weapon_exit() -> void:
	passive_icd_msec.clear()
