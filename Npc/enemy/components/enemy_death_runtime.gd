extends RefCounted
class_name EnemyDeathRuntime

const COIN_SCENE := preload("res://Objects/loots/coin.tscn")
const DROP_SCENE := preload("res://Objects/loots/drop.tscn")

var enemy

func setup(source_enemy) -> void:
	enemy = source_enemy

func finalize_death(killing_attack: Attack, grant_standard_rewards: bool = true) -> void:
	if enemy == null:
		return
	var death_position: Vector2 = enemy.global_position
	if grant_standard_rewards:
		_spawn_kill_gold_drop()
		if killing_attack != null and killing_attack.is_from_player():
			PlayerData.run_enemy_kills += 1
			if enemy is EliteEnemy:
				PlayerData.run_elite_kills += 1
			_notify_player_enemy_killed(killing_attack, death_position)
		_try_trigger_elite_kill_impact(killing_attack)
	enemy.enemy_death.emit(true)
	enemy.queue_free()

func _spawn_kill_gold_drop() -> void:
	var drop_value := _roll_kill_gold_drop_value()
	if drop_value <= 0:
		return
	var drop = DROP_SCENE.instantiate()
	drop.drop = COIN_SCENE
	drop.value = drop_value
	drop.spawn_global_position = enemy.global_position
	enemy.call_deferred("add_sibling", drop)
	if GlobalVariables.enemy_spawner and is_instance_valid(GlobalVariables.enemy_spawner) and GlobalVariables.enemy_spawner.has_method("record_kill_gold_coin_spawned"):
		GlobalVariables.enemy_spawner.record_kill_gold_coin_spawned(drop_value)

func _roll_kill_gold_drop_value() -> int:
	if GlobalVariables.enemy_spawner and is_instance_valid(GlobalVariables.enemy_spawner):
		if GlobalVariables.enemy_spawner.has_method("ensure_kill_gold_budget_active"):
			GlobalVariables.enemy_spawner.call("ensure_kill_gold_budget_active")
		if GlobalVariables.enemy_spawner.has_method("is_kill_gold_budget_active") and bool(GlobalVariables.enemy_spawner.call("is_kill_gold_budget_active")):
			return maxi(int(GlobalVariables.enemy_spawner.roll_enemy_kill_gold(enemy)), 0)
		if GlobalVariables.enemy_spawner.has_method("warn_inactive_kill_gold_budget"):
			GlobalVariables.enemy_spawner.call("warn_inactive_kill_gold_budget")
		return 0
	if GlobalVariables.economy_data:
		return max(1, int(GlobalVariables.economy_data.enemy_coin_drop_value))
	return max(1, int(EconomyConfig.new().enemy_coin_drop_value))

func _try_trigger_elite_kill_impact(killing_attack: Attack) -> void:
	if not (enemy is EliteEnemy):
		return
	if killing_attack == null or not killing_attack.is_from_player():
		return
	var controller: Node = enemy.get_tree().root.get_node_or_null("TimeImpactController")
	if controller and controller.has_method("trigger_elite_kill_impact"):
		controller.trigger_elite_kill_impact()

func _notify_player_enemy_killed(killing_attack: Attack, death_position: Vector2) -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	if not PlayerData.player.has_method("_broadcast_weapon_passive_event"):
		return
	PlayerData.player.call("_broadcast_weapon_passive_event", &"on_enemy_killed", {
		"enemy": enemy,
		"source_weapon": _resolve_killing_weapon(killing_attack),
		"position": death_position,
		"_suppress_default_emit": true,
	})

func _resolve_killing_weapon(killing_attack: Attack) -> Weapon:
	if killing_attack == null:
		return null
	var source := killing_attack.source_node
	if source == null or not is_instance_valid(source):
		return null
	if source is Weapon:
		return source as Weapon
	var source_weapon: Variant = source.get("source_weapon")
	if source_weapon is Weapon and is_instance_valid(source_weapon):
		return source_weapon as Weapon
	var current := source
	while current != null:
		if current is Weapon:
			return current as Weapon
		current = current.get_parent()
	return null
