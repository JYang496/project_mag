extends RefCounted
class_name Heat

var heat_value: float = 0.0
var max_heat: float = 100.0
var heat_per_shot: float = 1.0
var cooldown_rate: float = 20.0
var overheated: bool = false

func configure(per_shot: float, max_value: float, cool_rate: float) -> void:
	heat_per_shot = maxf(per_shot, 0.0)
	max_heat = maxf(max_value, 1.0)
	cooldown_rate = maxf(cool_rate, 0.0)
	heat_value = clampf(heat_value, 0.0, max_heat)
	if heat_value <= 0.0:
		overheated = false

func add_heat(multiplier: float = 1.0) -> void:
	if overheated:
		return
	var added: float = maxf(0.0, heat_per_shot * maxf(multiplier, 0.0))
	heat_value = clampf(heat_value + added, 0.0, max_heat)
	if heat_value >= max_heat:
		overheated = true

func cool_down(delta: float) -> void:
	heat_value = move_toward(heat_value, 0.0, cooldown_rate * maxf(delta, 0.0))
	if overheated and heat_value <= 0.001:
		overheated = false

func can_fire() -> bool:
	return not overheated

func get_ratio() -> float:
	return clampf(heat_value / maxf(max_heat, 1.0), 0.0, 1.0)

func get_percent() -> int:
	return int(round(get_ratio() * 100.0))
