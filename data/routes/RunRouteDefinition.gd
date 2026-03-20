extends Resource
class_name RunRouteDefinition

@export var route_id: String = "normal"
@export var display_name: String = "Normal Route"
@export_multiline var description: String = "Standard battle flow with default rewards."
@export var display_order: int = 0
@export var battle_enabled: bool = true
@export var grants_prepare_loot: bool = true

@export_group("Enemy")
@export_range(0.1, 10.0, 0.01) var enemy_hp_multiplier: float = 1.0
@export_range(0.1, 10.0, 0.01) var enemy_damage_multiplier: float = 1.0
@export_range(0.1, 2.0, 0.01) var battle_timeout_multiplier: float = 1.0

@export_group("Rewards")
@export_range(1, 6, 1) var reward_option_count: int = 3
@export_range(0.1, 10.0, 0.01) var reward_chip_multiplier: float = 1.0
@export var reward_item_level_bonus: int = 0
@export var reward_module_level_bonus: int = 0
@export var fallback_reward_chip_value: int = 5

func sanitize() -> void:
	route_id = route_id.strip_edges().to_lower()
	if route_id == "":
		route_id = "normal"
	display_name = display_name.strip_edges()
	if display_name == "":
		display_name = route_id.capitalize()
	reward_option_count = clampi(reward_option_count, 1, 6)
	enemy_hp_multiplier = maxf(enemy_hp_multiplier, 0.1)
	enemy_damage_multiplier = maxf(enemy_damage_multiplier, 0.1)
	battle_timeout_multiplier = clampf(battle_timeout_multiplier, 0.1, 2.0)
	reward_chip_multiplier = maxf(reward_chip_multiplier, 0.1)
	fallback_reward_chip_value = max(1, fallback_reward_chip_value)
