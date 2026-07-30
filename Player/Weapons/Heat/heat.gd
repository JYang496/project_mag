extends RefCounted
class_name Heat

signal heat_changed(previous_value: float, current_value: float)
signal heat_zone_changed(previous_zone: StringName, current_zone: StringName)

const MIN_HEAT: float = -100.0
const MAX_HEAT: float = 100.0
const DEFAULT_NEUTRALIZE_DELAY_SEC: float = 1.5
const ZONE_HYSTERESIS: float = 5.0

var heat_value: float = 0.0
var max_heat: float = 100.0
var heat_per_shot: float = 1.0
var cooldown_rate: float = 20.0
var overheated: bool = false
var _lock_remaining_sec: float = 0.0
var _locked_value: float = 0.0
var _neutralize_delay_remaining_sec: float = 0.0
var _current_zone: StringName = &"neutral"

func configure(per_shot: float, _max_value: float, cool_rate: float) -> void:
	heat_per_shot = clampf(per_shot, MIN_HEAT, MAX_HEAT)
	# Kept as a compatibility field. The bipolar Heat axis always uses fixed bounds.
	max_heat = MAX_HEAT
	cooldown_rate = maxf(cool_rate, 0.0)
	set_heat(heat_value)
	overheated = false

func add_heat(multiplier: float = 1.0) -> void:
	add_heat_amount(heat_per_shot * maxf(multiplier, 0.0))

func add_heat_amount(amount: float) -> void:
	if _lock_remaining_sec > 0.0:
		return
	if is_zero_approx(amount):
		return
	set_heat(heat_value + amount)
	_neutralize_delay_remaining_sec = DEFAULT_NEUTRALIZE_DELAY_SEC
	overheated = false

func cool_down(delta: float) -> void:
	neutralize(delta, cooldown_rate)

func cool_down_at_rate(delta: float, rate: float) -> void:
	neutralize(delta, rate)

func neutralize(delta: float, rate: float = cooldown_rate) -> void:
	var safe_delta := maxf(delta, 0.0)
	if _lock_remaining_sec > 0.0:
		_lock_remaining_sec = maxf(0.0, _lock_remaining_sec - safe_delta)
		set_heat(_locked_value)
		overheated = false
		return
	if _neutralize_delay_remaining_sec > 0.0:
		_neutralize_delay_remaining_sec = maxf(0.0, _neutralize_delay_remaining_sec - safe_delta)
		return
	set_heat(move_toward(heat_value, 0.0, maxf(rate, 0.0) * safe_delta))
	overheated = false

func can_fire() -> bool:
	return true

func get_ratio() -> float:
	return get_fire_alignment()

func get_signed_ratio() -> float:
	return clampf(heat_value / MAX_HEAT, -1.0, 1.0)

func get_gauge_ratio() -> float:
	return clampf((heat_value - MIN_HEAT) / (MAX_HEAT - MIN_HEAT), 0.0, 1.0)

func get_fire_alignment() -> float:
	return maxf(get_signed_ratio(), 0.0)

func get_freeze_alignment() -> float:
	return maxf(-get_signed_ratio(), 0.0)

func get_neutral_alignment() -> float:
	return 1.0 - absf(get_signed_ratio())

func get_percent() -> int:
	return int(round(get_signed_ratio() * 100.0))

func lock_to_value(value: float, duration_sec: float) -> void:
	_locked_value = clampf(value, MIN_HEAT, MAX_HEAT)
	_lock_remaining_sec = maxf(duration_sec, 0.0)
	set_heat(_locked_value)
	overheated = false

func is_locked() -> bool:
	return _lock_remaining_sec > 0.0

func set_heat(value: float) -> void:
	var previous := heat_value
	var next := clampf(value, MIN_HEAT, MAX_HEAT)
	if is_equal_approx(previous, next):
		heat_value = next
		return
	heat_value = next
	heat_changed.emit(previous, heat_value)
	_update_zone()

func reset_to_neutral() -> void:
	_lock_remaining_sec = 0.0
	_neutralize_delay_remaining_sec = 0.0
	_locked_value = 0.0
	set_heat(0.0)

func get_heat_zone() -> StringName:
	return _current_zone

func _update_zone() -> void:
	var previous := _current_zone
	_current_zone = _resolve_zone_with_hysteresis(previous)
	if previous != _current_zone:
		heat_zone_changed.emit(previous, _current_zone)

func _resolve_zone_with_hysteresis(previous: StringName) -> StringName:
	var value := heat_value
	match previous:
		&"extreme_cold":
			if value <= -90.0 + ZONE_HYSTERESIS:
				return previous
		&"deep_cold":
			if value <= -60.0 + ZONE_HYSTERESIS and value > -90.0 - ZONE_HYSTERESIS:
				return previous
		&"cold":
			if value <= -25.0 + ZONE_HYSTERESIS and value > -60.0 - ZONE_HYSTERESIS:
				return previous
		&"neutral":
			if value >= -24.0 - ZONE_HYSTERESIS and value <= 24.0 + ZONE_HYSTERESIS:
				return previous
		&"hot":
			if value >= 25.0 - ZONE_HYSTERESIS and value < 60.0 + ZONE_HYSTERESIS:
				return previous
		&"high_heat":
			if value >= 60.0 - ZONE_HYSTERESIS and value < 90.0 + ZONE_HYSTERESIS:
				return previous
		&"extreme_heat":
			if value >= 90.0 - ZONE_HYSTERESIS:
				return previous
	if value <= -90.0:
		return &"extreme_cold"
	if value <= -60.0:
		return &"deep_cold"
	if value <= -25.0:
		return &"cold"
	if value < 25.0:
		return &"neutral"
	if value < 60.0:
		return &"hot"
	if value < 90.0:
		return &"high_heat"
	return &"extreme_heat"
