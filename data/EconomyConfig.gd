extends Resource
class_name EconomyConfig

@export var enemy_coin_drop_value: int = 1
@export var weapon_purchase_price_multiplier: float = 8.0
@export var weapon_upgrade_cost_multiplier: float = 8.0
@export var shop_refresh_start_cost: int = 8
@export var shop_refresh_step: int = 4
@export var shop_refresh_cost_cap: int = 40
@export var objective_economy_gold_by_level: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
