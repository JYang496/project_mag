extends Heat
class_name SharedHeatPool

var contributor_count: int = 0

func configure_from_weapons(weapons: Array) -> void:
	var total_max_heat: float = 0.0
	var total_cooldown_rate: float = 0.0
	var contributors: int = 0
	for weapon in weapons:
		if weapon == null or not is_instance_valid(weapon):
			continue
		var contributes := false
		if weapon.has_method("has_heat_trait"):
			contributes = bool(weapon.call("has_heat_trait"))
		elif weapon.has_method("has_heat_system"):
			contributes = bool(weapon.call("has_heat_system"))
		if not contributes:
			continue
		contributors += 1
		if weapon.get("heat_max_value") != null:
			total_max_heat += maxf(float(weapon.get("heat_max_value")), 0.0)
		if weapon.get("heat_cool_rate") != null:
			total_cooldown_rate += maxf(float(weapon.get("heat_cool_rate")), 0.0)
	contributor_count = contributors
	if contributor_count <= 0:
		_clear_state()
		return
	configure(1.0, maxf(total_max_heat, 1.0), maxf(total_cooldown_rate, 0.0))

func has_contributors() -> bool:
	return contributor_count > 0

func add_heat_amount(amount: float) -> void:
	if _lock_remaining_sec > 0.0:
		return
	if overheated:
		return
	var added: float = maxf(amount, 0.0)
	heat_value = clampf(heat_value + added, 0.0, max_heat)
	if heat_value >= max_heat:
		overheated = true

func _clear_state() -> void:
	heat_value = 0.0
	max_heat = 0.0
	cooldown_rate = 0.0
	overheated = false
	_lock_remaining_sec = 0.0
	_locked_value = 0.0
