extends RefCounted
class_name KillGoldBudgetRuntime

var owner: Node
var debug_print_kill_gold_stats := true
var debug_print_kill_gold_drop_stats := false
var kill_gold_budget: int = 0
var kill_gold_paid: int = 0
var kill_gold_battle_timeout: int = 1
var kill_gold_budget_active: bool = false
var warned_inactive_kill_gold_budget: bool = false
var kill_gold_collected: int = 0
var target_hp_multiplier := 1.0
var target_gold_multiplier := 1.0

var _profile_provider := Callable()
var _economy_provider := Callable()

func bind(owner_node: Node, profile_provider: Callable, economy_provider: Callable) -> void:
	owner = owner_node
	_profile_provider = profile_provider
	_economy_provider = economy_provider

func configure(print_stats: bool, print_drop_stats: bool) -> void:
	debug_print_kill_gold_stats = print_stats
	debug_print_kill_gold_drop_stats = print_drop_stats

func configure_target_multipliers(hp_multiplier: float, gold_multiplier: float) -> void:
	target_hp_multiplier = maxf(hp_multiplier, 0.01)
	target_gold_multiplier = maxf(gold_multiplier, 0.0)

func roll_enemy_kill_gold(enemy_instance: Node = null) -> int:
	if not kill_gold_budget_active:
		return 0
	var remaining_budget := maxi(kill_gold_budget - kill_gold_paid, 0)
	if remaining_budget <= 0:
		return 0
	var expected_gold := resolve_enemy_kill_expected_gold(enemy_instance)
	if expected_gold <= 0.0:
		return 0
	var max_drop_chance := get_kill_gold_max_drop_chance()
	var drop_value := maxi(int(ceil(expected_gold / max_drop_chance)), 1)
	var drop_chance := clampf(expected_gold / float(drop_value), 0.0, max_drop_chance)
	var gold := mini(drop_value, remaining_budget) if randf() < drop_chance else 0
	kill_gold_paid += gold
	return gold

func record_kill_gold_coin_spawned(value: int) -> void:
	var gold_value := maxi(value, 0)
	if gold_value <= 0:
		return
	if debug_print_kill_gold_drop_stats:
		print("[KillGoldDrop] level=%d value=%d generated_total=%d collected_total=%d remaining_coin_value=%d" % [
			maxi(PhaseManager.current_level, 0),
			gold_value,
			kill_gold_paid,
			kill_gold_collected,
			get_remaining_coin_value(),
		])

func record_kill_gold_coin_collected(value: int) -> void:
	var gold_value := maxi(value, 0)
	if gold_value <= 0:
		return
	kill_gold_collected += gold_value

func resolve_enemy_kill_expected_gold(enemy_instance: Node) -> float:
	var level_index := maxi(PhaseManager.current_level, 0)
	var target_total_hp := resolve_kill_gold_target_total_hp_for_level(level_index)
	if target_total_hp <= 0:
		return 0.0
	var enemy_hp := resolve_enemy_kill_gold_hp(enemy_instance)
	if enemy_hp <= 0:
		return 0.0
	return float(kill_gold_budget) * float(enemy_hp) / float(target_total_hp)

func resolve_enemy_kill_gold_hp(enemy_instance: Node) -> int:
	if enemy_instance != null:
		if enemy_instance.has_meta("_spawn_budget_scaled_hp"):
			return maxi(int(enemy_instance.get_meta("_spawn_budget_scaled_hp")), 1)
		var hp_value: Variant = enemy_instance.get("hp")
		if hp_value != null:
			return maxi(int(hp_value), 1)
	return 0

func resolve_kill_gold_target_total_hp_for_level(level_index: int) -> int:
	var profile := _get_spawn_combat_profile()
	if profile == null:
		return 0
	return maxi(int(round(float(profile.call("get_target_total_hp", level_index)) * target_hp_multiplier)), 0)

func is_kill_gold_budget_active() -> bool:
	return kill_gold_budget_active

func get_kill_gold_budget_snapshot() -> Dictionary:
	return {
		"budget": kill_gold_budget,
		"paid": kill_gold_paid,
		"remaining": maxi(kill_gold_budget - kill_gold_paid, 0),
		"battle_timeout": kill_gold_battle_timeout,
	}

func start_kill_gold_budget(level_index: int, effective_time_out: int) -> void:
	var target := int(round(float(resolve_kill_gold_target_for_level(level_index)) * target_gold_multiplier))
	var variance := get_kill_gold_budget_variance()
	var roll_min := maxf(0.0, 1.0 - variance)
	var roll_max := maxf(roll_min, 1.0 + variance)
	kill_gold_budget = maxi(0, int(round(float(target) * randf_range(roll_min, roll_max))))
	kill_gold_paid = 0
	kill_gold_collected = 0
	kill_gold_battle_timeout = maxi(effective_time_out, 1)
	kill_gold_budget_active = kill_gold_budget > 0
	warned_inactive_kill_gold_budget = false

func warn_inactive_kill_gold_budget() -> void:
	if warned_inactive_kill_gold_budget:
		return
	warned_inactive_kill_gold_budget = true
	push_warning("Enemy kill gold budget is inactive; kill gold drops are disabled for this battle.")

func resolve_kill_gold_target_for_level(level_index: int) -> int:
	var economy := _get_economy_config()
	var targets: PackedInt32Array = economy.kill_gold_target_by_level
	if targets.is_empty():
		return 0
	var safe_level := maxi(level_index, 0)
	if safe_level < targets.size():
		return maxi(int(targets[safe_level]), 0)
	var increment := maxi(int(economy.kill_gold_target_increment_after_table), 0)
	return maxi(int(targets[targets.size() - 1]) + increment * (safe_level - targets.size() + 1), 0)

func get_kill_gold_budget_variance() -> float:
	var economy := _get_economy_config()
	return clampf(float(economy.kill_gold_budget_variance), 0.0, 1.0)

func get_kill_gold_max_drop_chance() -> float:
	var economy := _get_economy_config()
	return clampf(float(economy.kill_gold_max_drop_chance), 0.05, 1.0)

func print_kill_gold_debug_summary(context: String, level_index: int) -> void:
	if not debug_print_kill_gold_stats:
		return
	var remaining_coin_value := get_remaining_coin_value()
	print("[KillGoldSummary] context=%s level=%d budget=%d generated=%d collected=%d player_round=%d player_gold=%d remaining_coin_value=%d remaining_coin_count=%d" % [
		context,
		level_index,
		kill_gold_budget,
		kill_gold_paid,
		kill_gold_collected,
		PlayerData.round_coin_collected,
		PlayerData.player_gold,
		remaining_coin_value,
		get_remaining_coin_count(),
	])

func get_remaining_coin_value() -> int:
	var total := 0
	for coin in get_registered_coins():
		if is_uncollected_coin(coin):
			total += maxi(int(coin.value), 0)
	return total

func get_remaining_coin_count() -> int:
	var total := 0
	for coin in get_registered_coins():
		if is_uncollected_coin(coin):
			total += 1
	return total

func get_registered_coins() -> Array[Coin]:
	var output: Array[Coin] = []
	if owner == null or not is_instance_valid(owner):
		return output
	var registry: Node = owner.get_node_or_null("/root/CollectableRegistry")
	if registry != null and registry.has_method("get_coins"):
		var registered_coins: Variant = registry.call("get_coins")
		if registered_coins is Array:
			for coin_ref in registered_coins:
				var coin := coin_ref as Coin
				if coin != null and is_instance_valid(coin):
					output.append(coin)
			return output
	for collectable in owner.get_tree().get_nodes_in_group("collectables"):
		var coin := collectable as Coin
		if coin != null and is_instance_valid(coin):
			output.append(coin)
	return output

func is_uncollected_coin(collectable: Node) -> bool:
	var coin := collectable as Coin
	if coin == null:
		return false
	if coin.sprite != null and not coin.sprite.visible:
		return false
	return true

func _get_spawn_combat_profile() -> SpawnCombatProfile:
	if not _profile_provider.is_valid():
		return null
	return _profile_provider.call() as SpawnCombatProfile

func _get_economy_config() -> EconomyConfig:
	if _economy_provider.is_valid():
		var economy := _economy_provider.call() as EconomyConfig
		if economy != null:
			return economy
	return EconomyConfig.new()
