extends CellAuraModule
class_name LuckyStrikeAuraModule

@export var lucky_strike_chance: float = 0.3
@export var lucky_strike_extra_damage: int = 1

var _bonus_hit_mod_id: StringName

func _apply_aura_to_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.register_bonus_hit(
		_get_bonus_hit_mod_id(),
		clampf(lucky_strike_chance, 0.0, 1.0),
		max(1, lucky_strike_extra_damage)
	)

func _remove_aura_from_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.remove_bonus_hit(_get_bonus_hit_mod_id())

func set_aura_parameters(params: Dictionary) -> void:
	if params.has("aura_lucky_strike_chance"):
		lucky_strike_chance = clampf(float(params["aura_lucky_strike_chance"]), 0.0, 1.0)
	if params.has("aura_lucky_strike_extra_damage"):
		lucky_strike_extra_damage = max(1, int(params["aura_lucky_strike_extra_damage"]))

func _get_bonus_hit_mod_id() -> StringName:
	if _bonus_hit_mod_id == StringName():
		_bonus_hit_mod_id = _make_modifier_id("lucky_strike")
	return _bonus_hit_mod_id
