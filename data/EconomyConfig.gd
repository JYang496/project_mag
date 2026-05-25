extends Resource
class_name EconomyConfig

@export var enemy_coin_drop_value: int = 1
@export var default_player_gold: int = 10
@export var weapon_purchase_price_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.01) var weapon_upgrade_price_ratio: float = 0.5
@export var shop_refresh_start_cost: int = 6
@export var shop_refresh_step: int = 2
@export var shop_refresh_cost_cap: int = 20
@export var duplicate_weapon_gold_minimum: int = 6
@export_range(0.0, 1.0, 0.01) var duplicate_weapon_gold_refund_ratio: float = 0.5
@export var duplicate_module_gold_minimum: int = 6
@export var duplicate_module_gold_cost_multiplier: float = 6.0
@export_range(0.0, 1.0, 0.01) var duplicate_module_gold_refund_ratio: float = 0.5
@export_range(0.0, 1.0, 0.01) var coin_bonus_augment_chance: float = 0.3
@export var coin_bonus_augment_gold_per_level: int = 1
@export var objective_economy_gold_by_level: PackedInt32Array = PackedInt32Array([4, 6, 8, 10, 12, 14, 16, 18, 20, 22])
@export var kill_gold_target_by_level: PackedInt32Array = PackedInt32Array([28, 38, 49, 61, 74, 88, 103, 119, 136, 154])
@export var kill_gold_expected_kills_by_level: PackedInt32Array = PackedInt32Array([48, 129, 93, 134, 79, 113, 183, 129, 197, 182])
@export var kill_gold_target_increment_after_table: int = 12
@export_range(0.0, 1.0, 0.01) var kill_gold_budget_variance: float = 0.1
@export_range(0.05, 1.0, 0.01) var kill_gold_max_drop_chance: float = 0.65
@export var reward_module_options_enabled: bool = false
@export_range(0.0, 1.0, 0.01) var reward_weapon_option_chance: float = 0.5
@export_range(0.0, 1.0, 0.01) var reward_economy_option_chance: float = 0.15
@export var reward_economy_exp: int = 5
@export var reward_economy_gold: int = 10

func get_default_player_gold() -> int:
	return maxi(default_player_gold, 0)

func get_duplicate_weapon_gold(base_price: int) -> int:
	var purchase_value := float(maxi(base_price, 0)) * maxf(weapon_purchase_price_multiplier, 0.0)
	var scaled_value := int(round(purchase_value * clampf(duplicate_weapon_gold_refund_ratio, 0.0, 1.0)))
	return maxi(maxi(duplicate_weapon_gold_minimum, 0), scaled_value)

func get_weapon_upgrade_gold(base_price: int) -> int:
	var purchase_value := float(maxi(base_price, 0)) * maxf(weapon_purchase_price_multiplier, 0.0)
	var upgrade_value := int(round(purchase_value * maxf(weapon_upgrade_price_ratio, 0.0)))
	return maxi(upgrade_value, 1)

func get_duplicate_module_gold(module_cost: int, module_level: int) -> int:
	var investment_value := float(maxi(module_cost, 0)) * maxf(duplicate_module_gold_cost_multiplier, 0.0)
	var base_value := int(round(investment_value * clampf(duplicate_module_gold_refund_ratio, 0.0, 1.0)))
	var value_per_level := maxi(maxi(duplicate_module_gold_minimum, 0), base_value)
	return value_per_level * maxi(module_level, 1)

func get_coin_bonus_augment_chance() -> float:
	return clampf(coin_bonus_augment_chance, 0.0, 1.0)

func get_coin_bonus_augment_gold(level: int) -> int:
	return maxi(level, 0) * maxi(coin_bonus_augment_gold_per_level, 0)

func get_reward_weapon_option_chance() -> float:
	return clampf(reward_weapon_option_chance, 0.0, 1.0)

func get_reward_economy_option_chance() -> float:
	return clampf(reward_economy_option_chance, 0.0, 1.0)

func get_reward_economy_exp() -> int:
	return maxi(reward_economy_exp, 0)

func get_reward_economy_gold() -> int:
	return maxi(reward_economy_gold, 0)
