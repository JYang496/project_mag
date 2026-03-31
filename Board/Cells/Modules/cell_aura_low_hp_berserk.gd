extends CellAuraModule
class_name LowHpBerserkAuraModule

@export var min_hp_ratio: float = 0.25
@export var max_damage_mul: float = 1.5

var _low_hp_mod_id: StringName

func _apply_aura_to_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.register_low_hp_damage_bonus(
		_get_low_hp_mod_id(),
		clampf(min_hp_ratio, 0.05, 1.0),
		maxf(max_damage_mul, 1.0)
	)

func _remove_aura_from_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.remove_low_hp_damage_bonus(_get_low_hp_mod_id())

func set_aura_parameters(params: Dictionary) -> void:
	if params.has("aura_low_hp_min_hp_ratio"):
		min_hp_ratio = clampf(float(params["aura_low_hp_min_hp_ratio"]), 0.05, 1.0)
	if params.has("aura_low_hp_max_damage_mul"):
		max_damage_mul = maxf(float(params["aura_low_hp_max_damage_mul"]), 1.0)

func _get_low_hp_mod_id() -> StringName:
	if _low_hp_mod_id == StringName():
		_low_hp_mod_id = _make_modifier_id("low_hp_berserk")
	return _low_hp_mod_id
