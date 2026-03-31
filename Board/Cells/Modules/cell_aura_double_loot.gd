extends CellAuraModule
class_name DoubleLootAuraModule

@export var double_coin_chance: float = 0.3
@export var double_chip_chance: float = 0.3
@export var loot_multiplier: int = 2

var _loot_mod_id: StringName

func _apply_aura_to_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.register_loot_bonus(
		_get_loot_mod_id(),
		clampf(double_coin_chance, 0.0, 1.0),
		clampf(double_chip_chance, 0.0, 1.0),
		max(2, loot_multiplier)
	)

func _remove_aura_from_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.remove_loot_bonus(_get_loot_mod_id())

func set_aura_parameters(params: Dictionary) -> void:
	if params.has("aura_double_loot_coin_chance"):
		double_coin_chance = clampf(float(params["aura_double_loot_coin_chance"]), 0.0, 1.0)
	if params.has("aura_double_loot_chip_chance"):
		double_chip_chance = clampf(float(params["aura_double_loot_chip_chance"]), 0.0, 1.0)
	if params.has("aura_double_loot_multiplier"):
		loot_multiplier = max(2, int(params["aura_double_loot_multiplier"]))

func _get_loot_mod_id() -> StringName:
	if _loot_mod_id == StringName():
		_loot_mod_id = _make_modifier_id("double_loot")
	return _loot_mod_id
