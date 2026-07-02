extends RefCounted
class_name SkillEnergyState

var _player
var _player_energy: float = 100.0

func setup(player) -> void:
	_player = player

func reset_to_max() -> void:
	_player_energy = get_max_energy()

func get_current_energy() -> float:
	return _player_energy

func get_max_energy() -> float:
	if _player == null or not is_instance_valid(_player):
		return 1.0
	return maxf(float(_player.player_max_energy), 1.0)

func get_active_skill_energy_cost() -> float:
	var skill := _get_first_active_skill()
	if skill == null:
		return 0.0
	if skill.has_method("get_energy_cost"):
		return maxf(float(skill.call("get_energy_cost")), 0.0)
	return maxf(float(skill.get("energy_cost")), 0.0)

func consume_energy(amount: float) -> bool:
	var required := maxf(amount, 0.0)
	if _player_energy < required:
		return false
	_player_energy -= required
	return true

func add_energy(amount: float) -> void:
	_player_energy = clampf(_player_energy + maxf(amount, 0.0), 0.0, get_max_energy())

func regen_energy(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if float(_player.player_energy_regen_per_sec) <= 0.0:
		return
	add_energy(float(_player.player_energy_regen_per_sec) * maxf(delta, 0.0))

func _get_first_active_skill() -> Skills:
	if _player == null or not is_instance_valid(_player):
		return null
	if _player.active_skill_holder == null or not is_instance_valid(_player.active_skill_holder):
		return null
	for child in _player.active_skill_holder.get_children():
		if child is Skills:
			return child as Skills
	return null
