extends Resource
class_name CellEffectDefinition

@export var effect_id: String = ""
@export var family_id: String = ""
@export var tier: int = 1
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("NONE:0", "CORROSION:1", "JUNGLE:2", "SPEED_BOOST:3", "REGEN:4", "LUCKY_STRIKE:5", "DOUBLE_LOOT:6", "LOW_HP_BERSERK:7")
var terrain_type: int = Cell.TerrainType.NONE
@export var icon_texture: Texture2D
@export var can_swap_installed: bool = true
@export var unlock_level: int = 1
@export var drop_weight: float = 1.0
@export_enum("common", "rare", "epic") var rarity: String = "common"

@export_group("Aura Parameters")
@export var aura_speed_move_speed_mul: float = 1.0
@export var aura_regen_interval_sec: float = 5.0
@export var aura_regen_heal_amount: int = 0
@export var aura_jungle_vision_mul: float = 1.0
@export var aura_lucky_strike_chance: float = 0.0
@export var aura_lucky_strike_extra_damage: int = 0
@export var aura_double_loot_coin_chance: float = 0.0
@export var aura_double_loot_chip_chance: float = 0.0
@export var aura_double_loot_multiplier: int = 1
@export var aura_low_hp_min_hp_ratio: float = 0.25
@export var aura_low_hp_max_damage_mul: float = 1.0
@export var aura_corrosion_move_speed_mul: float = 1.0

func get_display_name() -> String:
	if display_name.strip_edges() != "":
		return display_name
	return effect_id.replace("_", " ").capitalize()

func get_family_id() -> String:
	if family_id.strip_edges() != "":
		return family_id.strip_edges()
	return effect_id.strip_edges()

func get_reward_weight() -> float:
	return maxf(drop_weight, 0.0)

func get_aura_parameters() -> Dictionary:
	return {
		"aura_speed_move_speed_mul": aura_speed_move_speed_mul,
		"aura_regen_interval_sec": aura_regen_interval_sec,
		"aura_regen_heal_amount": aura_regen_heal_amount,
		"aura_jungle_vision_mul": aura_jungle_vision_mul,
		"aura_lucky_strike_chance": aura_lucky_strike_chance,
		"aura_lucky_strike_extra_damage": aura_lucky_strike_extra_damage,
		"aura_double_loot_coin_chance": aura_double_loot_coin_chance,
		"aura_double_loot_chip_chance": aura_double_loot_chip_chance,
		"aura_double_loot_multiplier": aura_double_loot_multiplier,
		"aura_low_hp_min_hp_ratio": aura_low_hp_min_hp_ratio,
		"aura_low_hp_max_damage_mul": aura_low_hp_max_damage_mul,
		"aura_corrosion_move_speed_mul": aura_corrosion_move_speed_mul,
	}
