extends Heat
class_name SharedHeatPool

var contributor_count: int = 0
var heat_gain_multiplier_provider: Callable = Callable()

func configure_from_weapons(weapons: Array, _max_heat_multiplier: float = 1.0) -> void:
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
		if weapon.get("heat_cool_rate") != null:
			total_cooldown_rate += maxf(float(weapon.get("heat_cool_rate")), 0.0)
	contributor_count = contributors
	if contributor_count <= 0:
		_clear_state()
		return
	# max_heat_multiplier is intentionally ignored: the global axis is always -100..100.
	configure(1.0, MAX_HEAT, maxf(total_cooldown_rate / float(contributor_count), 0.0))

func has_contributors() -> bool:
	return contributor_count > 0

func add_heat_amount(amount: float) -> void:
	if _lock_remaining_sec > 0.0:
		return
	var multiplier := 1.0
	if heat_gain_multiplier_provider.is_valid():
		multiplier = maxf(float(heat_gain_multiplier_provider.call()), 0.0)
	super.add_heat_amount(amount * multiplier)

func _clear_state() -> void:
	reset_to_neutral()
	max_heat = MAX_HEAT
	cooldown_rate = 0.0
	overheated = false
