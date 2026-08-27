extends RefCounted
class_name WeaponTriggerRuntime

const STOW_CHARGE_DURATION_SEC: float = 5.0
const CROSS_WEAPON_WINDOW_MSEC: int = 2000
const CONTINUOUS_HIT_BREAK_MSEC: int = 800
const CONTINUOUS_HIT_THRESHOLDS: Array[int] = [3, 6, 10]

var weapon
var _magazine_quarters_earned: int = 0
var _stow_elapsed_sec: float = 0.0
var _stow_ready: bool = false
var _entry_ready: bool = false
var _continuous_hit_count: int = 0
var _continuous_last_hit_msec: int = 0
var _continuous_threshold_index: int = 0

func setup(source_weapon) -> void:
	weapon = source_weapon

func update(delta: float) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if weapon.is_main_weapon():
		return
	if _stow_ready:
		return
	_stow_elapsed_sec += maxf(delta, 0.0)
	if _stow_elapsed_sec + 0.0001 < STOW_CHARGE_DURATION_SEC:
		return
	_stow_elapsed_sec = STOW_CHARGE_DURATION_SEC
	_stow_ready = true
	_emit_standard_event(WeaponEvent.STOW_CHARGE_READY, {
		"duration": STOW_CHARGE_DURATION_SEC,
	})

func on_entered_main(old_role: String) -> void:
	_entry_ready = true
	_emit_standard_event(WeaponEvent.WEAPON_ENTERED_MAIN, {
		"old_role": old_role,
		"new_role": "main",
	})

func on_entered_offhand(old_role: String) -> void:
	_stow_elapsed_sec = 0.0
	_stow_ready = false
	_emit_standard_event(WeaponEvent.WEAPON_ENTERED_OFFHAND, {
		"old_role": old_role,
		"new_role": "offhand",
	})

func has_entry_charge() -> bool:
	return _entry_ready

func consume_entry_charge() -> bool:
	if not _entry_ready:
		return false
	_entry_ready = false
	return true

func is_stow_charge_ready() -> bool:
	return _stow_ready

func get_stow_charge_progress() -> float:
	return 1.0 if _stow_ready else clampf(_stow_elapsed_sec / STOW_CHARGE_DURATION_SEC, 0.0, 1.0)

func consume_stow_charge() -> bool:
	if not _stow_ready:
		return false
	_stow_ready = false
	_stow_elapsed_sec = 0.0
	return true

func on_ammo_consumed(ammo_before: int, ammo_after: int, magazine_capacity: int) -> void:
	if magazine_capacity <= 0 or ammo_after >= ammo_before:
		return
	var spent_ratio := clampf(float(magazine_capacity - ammo_after) / float(magazine_capacity), 0.0, 1.0)
	var earned_quarters := mini(int(floor(spent_ratio * 4.0 + 0.0001)), 4)
	while _magazine_quarters_earned < earned_quarters:
		_magazine_quarters_earned += 1
		_emit_standard_event(WeaponEvent.MAGAZINE_QUARTER_SPENT, {
			"quarter": _magazine_quarters_earned,
			"quarters_max": 4,
			"ammo_before": ammo_before,
			"ammo_after": ammo_after,
			"magazine_capacity": magazine_capacity,
			"spent_ratio": spent_ratio,
		})

func get_magazine_quarters_earned() -> int:
	return _magazine_quarters_earned

func on_reload_started(detail: Dictionary) -> void:
	detail["magazine_quarters"] = _magazine_quarters_earned
	detail["magazine_quarters_max"] = 4
	detail["emptied_magazine"] = int(detail.get("ammo_before", 0)) <= 0
	_magazine_quarters_earned = 0

func on_hit(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var now_msec := Time.get_ticks_msec()
	var previous_weapon_id := int(target.get_meta(Weapon.LAST_HIT_WEAPON_META, 0))
	var previous_hit_msec := int(target.get_meta(Weapon.LAST_HIT_WEAPON_TIME_META, 0))
	if previous_weapon_id != 0 \
			and previous_weapon_id != weapon.get_instance_id() \
			and now_msec <= previous_hit_msec + CROSS_WEAPON_WINDOW_MSEC:
		_emit_standard_event(WeaponEvent.CROSS_WEAPON_HIT, {
			"target": target,
			"previous_weapon_id": previous_weapon_id,
			"window_sec": float(CROSS_WEAPON_WINDOW_MSEC) / 1000.0,
		})
	if _continuous_last_hit_msec <= 0 \
			or now_msec > _continuous_last_hit_msec + CONTINUOUS_HIT_BREAK_MSEC:
		_continuous_hit_count = 0
		_continuous_threshold_index = 0
	_continuous_last_hit_msec = now_msec
	_continuous_hit_count += 1
	while _continuous_threshold_index < CONTINUOUS_HIT_THRESHOLDS.size() \
			and _continuous_hit_count >= CONTINUOUS_HIT_THRESHOLDS[_continuous_threshold_index]:
		var threshold := CONTINUOUS_HIT_THRESHOLDS[_continuous_threshold_index]
		_continuous_threshold_index += 1
		_emit_standard_event(WeaponEvent.CONTINUOUS_HIT_THRESHOLD, {
			"target": target,
			"hit_count": _continuous_hit_count,
			"threshold": threshold,
			"break_window_sec": float(CONTINUOUS_HIT_BREAK_MSEC) / 1000.0,
		})

func reset_continuous_hits() -> void:
	_continuous_hit_count = 0
	_continuous_last_hit_msec = 0
	_continuous_threshold_index = 0

func clear_for_weapon_exit() -> void:
	_magazine_quarters_earned = 0
	_stow_elapsed_sec = 0.0
	_stow_ready = false
	_entry_ready = false
	reset_continuous_hits()

func _emit_standard_event(event_type: StringName, detail: Dictionary) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var event := WeaponEvent.create(event_type, weapon)
	event.detail = detail
	if detail.get("target") is Node:
		event.target = detail.get("target") as Node
	weapon.emit_weapon_event(event)
	weapon.dispatch_passive_event(StringName("on_%s" % str(event_type)), event.to_legacy_detail())
