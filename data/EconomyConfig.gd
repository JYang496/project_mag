extends Resource
class_name EconomyConfig

@export var enemy_coin_drop_value: int = 1
@export var default_player_gold: int = 10
@export var weapon_purchase_price_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.01) var weapon_upgrade_price_ratio: float = 0.75
@export var shop_refresh_start_cost: int = 4
@export var shop_refresh_step: int = 4
@export var shop_refresh_cost_cap: int = 16
@export_range(1.0, 10.0, 0.1) var shop_synergy_weight_after_dry_streak: float = 3.0
@export var duplicate_weapon_gold_minimum: int = 4
@export_range(0.0, 1.0, 0.01) var duplicate_weapon_gold_refund_ratio: float = 0.5
@export var duplicate_module_gold_minimum: int = 4
@export var duplicate_module_gold_cost_multiplier: float = 2.0
@export_range(0.0, 1.0, 0.01) var duplicate_module_gold_refund_ratio: float = 0.5
@export var module_purchase_price_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.01) var module_upgrade_price_ratio: float = 1.0
@export_range(0.0, 10.0, 0.01) var module_upgrade_level_2_ratio: float = 1.25
@export_range(0.0, 10.0, 0.01) var module_upgrade_level_3_ratio: float = 1.75
@export_range(0.0, 1.0, 0.01) var coin_bonus_augment_chance: float = 0.3
@export var coin_bonus_augment_gold_per_level: int = 1
@export var objective_economy_gold_by_level: PackedInt32Array = PackedInt32Array([3, 4, 6, 7, 8, 10, 11, 13, 14, 15])
@export var kill_gold_target_by_level: PackedInt32Array = PackedInt32Array([56, 56, 39, 43, 52, 62, 72, 83, 95, 108])
@export var kill_gold_target_increment_after_table: int = 12
@export_range(0.0, 1.0, 0.01) var kill_gold_budget_variance: float = 0.1
@export_range(0.05, 1.0, 0.01) var kill_gold_max_drop_chance: float = 0.65
@export var contract_total_gold_multipliers: Dictionary = {
	&"elimination": 1.00,
	&"survival": 1.05,
	&"operation": 1.00,
	&"containment": 1.15,
	&"extraction": 1.05,
}
@export var contract_kill_gold_shares: Dictionary = {
	&"elimination": 0.90,
	&"survival": 0.20,
	&"operation": 0.15,
	&"containment": 0.15,
	&"extraction": 0.20,
}
@export var contract_performance_gold_shares: Dictionary = {
	&"elimination": 0.03,
	&"survival": 0.00,
	&"operation": 0.10,
	&"containment": 0.15,
	&"extraction": 0.10,
}
@export var reward_module_options_enabled: bool = true
@export var task_reward_options_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var battle_drop_weapon_chance: float = 0.75
@export_range(0.0, 1.0, 0.01) var battle_drop_module_chance: float = 0.5
@export_range(0.0, 1.0, 0.01) var reward_weapon_option_chance: float = 0.5
@export_range(0.0, 1.0, 0.01) var reward_economy_option_chance: float = 0.15
@export var reward_economy_exp: int = 5
@export var reward_economy_gold: int = 7
@export_range(0.0, 1.0, 0.01) var task_reward_secondary_task_module_chance: float = 0.5
@export var early_standard_draft_count: int = 3
@export var early_weapon_progress_slot_enabled: bool = true
@export var early_module_option_chances: PackedFloat32Array = PackedFloat32Array([0.0, 0.2, -1.0])
@export var early_economy_option_enabled: bool = false
@export var early_allow_fallback_economy: bool = true

func get_default_player_gold() -> int:
	return maxi(default_player_gold, 0)

func get_contract_gold_plan(contract_id: StringName, level_index: int) -> Dictionary:
	var base_target := _get_kill_gold_target(level_index)
	var total_multiplier := maxf(float(contract_total_gold_multipliers.get(contract_id, 1.0)), 0.0)
	var kill_share := clampf(float(contract_kill_gold_shares.get(contract_id, 1.0)), 0.0, total_multiplier)
	var performance_share := clampf(float(contract_performance_gold_shares.get(contract_id, 0.0)), 0.0, maxf(total_multiplier - kill_share, 0.0))
	var total_gold := maxi(int(round(float(base_target) * total_multiplier)), 0)
	var kill_gold_cap := clampi(int(round(float(base_target) * kill_share)), 0, total_gold)
	var performance_gold_cap := clampi(int(round(float(base_target) * performance_share)), 0, maxi(total_gold - kill_gold_cap, 0))
	var completion_gold := maxi(total_gold - kill_gold_cap - performance_gold_cap, 0)
	return {
		"base_target": base_target,
		"total_gold": total_gold,
		"kill_gold_cap": kill_gold_cap,
		"kill_gold_multiplier": float(kill_gold_cap) / float(maxi(base_target, 1)),
		"completion_gold": completion_gold,
		"performance_gold_cap": performance_gold_cap,
	}

func _get_kill_gold_target(level_index: int) -> int:
	if kill_gold_target_by_level.is_empty():
		return 0
	var safe_level := maxi(level_index, 0)
	if safe_level < kill_gold_target_by_level.size():
		return maxi(int(kill_gold_target_by_level[safe_level]), 0)
	return maxi(int(kill_gold_target_by_level[-1]) + maxi(kill_gold_target_increment_after_table, 0) * (safe_level - kill_gold_target_by_level.size() + 1), 0)

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

func get_module_purchase_gold(module_cost: int) -> int:
	var purchase_value := int(round(float(maxi(module_cost, 0)) * maxf(module_purchase_price_multiplier, 0.0)))
	return maxi(purchase_value, 1)

func get_module_upgrade_gold(module_cost: int, current_level: int = 1) -> int:
	var purchase_value := float(get_module_purchase_gold(module_cost))
	var safe_level := clampi(current_level, 1, 2)
	var ratio := module_upgrade_level_2_ratio
	if safe_level >= 2:
		ratio = module_upgrade_level_3_ratio
	var upgrade_value := int(round(purchase_value * maxf(ratio, 0.0)))
	return maxi(upgrade_value, 1)

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

func get_task_reward_secondary_task_module_chance() -> float:
	return clampf(task_reward_secondary_task_module_chance, 0.0, 1.0)

func get_early_standard_draft_count() -> int:
	return maxi(early_standard_draft_count, 0)

func get_early_module_option_chance(draft_index: int) -> float:
	var safe_index := maxi(draft_index, 1)
	var array_index := safe_index - 1
	if array_index < 0 or array_index >= early_module_option_chances.size():
		return 1.0 - get_reward_weapon_option_chance()
	var configured := float(early_module_option_chances[array_index])
	if configured < 0.0:
		return 1.0 - get_reward_weapon_option_chance()
	return clampf(configured, 0.0, 1.0)
