extends Resource
class_name EconomyConfig

@export var enemy_coin_drop_value: int = 1
@export var weapon_purchase_price_multiplier: float = 2.2
@export var weapon_upgrade_cost_multiplier: float = 1.6
@export var shop_refresh_start_cost: int = 6
@export var shop_refresh_step: int = 2
@export var shop_refresh_cost_cap: int = 20
@export var objective_economy_gold_by_level: PackedInt32Array = PackedInt32Array([4, 6, 8, 10, 12, 14, 16, 18, 20, 22])
