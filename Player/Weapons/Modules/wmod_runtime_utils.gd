extends RefCounted
class_name WeaponModuleRuntimeUtils

static func get_value_by_level(module_level: int, lv1: float, lv2: float, lv3: float) -> float:
	match module_level:
		3:
			return lv3
		2:
			return lv2
		_:
			return lv1

static func get_spent_ratio(detail: Dictionary) -> float:
	if detail == null:
		return 0.0
	return clampf(float(detail.get("spent_ratio", 0.0)), 0.0, 1.0)

static func resolve_player_node(source_weapon: Weapon = null) -> Node:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		if source_weapon == null or not is_instance_valid(source_weapon):
			return null
		var current: Node = source_weapon.get_parent()
		while current != null:
			if current is Node2D:
				return current
			current = current.get_parent()
		return null
	return PlayerData.player

static func get_player_weapons() -> Array:
	if PlayerData.player_weapon_list == null:
		return []
	return PlayerData.player_weapon_list

static func get_runtime_weapon_damage(source_weapon: Weapon) -> int:
	assert(source_weapon != null)
	assert(is_instance_valid(source_weapon))
	return source_weapon.get_runtime_damage()

static func get_nearby_enemies(tree: SceneTree, origin: Vector2, radius: float) -> Array[Node2D]:
	var output: Array[Node2D] = []
	if tree == null:
		return output
	var registry := tree.root.get_node_or_null("EnemyRegistry")
	if registry != null and registry.has_method("get_enemies_in_radius"):
		var registered_enemies: Variant = registry.call("get_enemies_in_radius", origin, radius)
		if registered_enemies is Array:
			for enemy_ref in registered_enemies:
				var enemy := enemy_ref as Node2D
				if enemy != null and is_instance_valid(enemy):
					output.append(enemy)
			return output
	return output

static func get_enemy_candidates(tree: SceneTree) -> Array[Node2D]:
	var output: Array[Node2D] = []
	if tree == null:
		return output
	var registry := tree.root.get_node_or_null("EnemyRegistry")
	if registry != null and registry.has_method("get_enemies"):
		var registered_enemies: Variant = registry.call("get_enemies")
		if registered_enemies is Array:
			for enemy_ref in registered_enemies:
				var enemy := enemy_ref as Node2D
				if enemy != null and is_instance_valid(enemy):
					output.append(enemy)
			return output
	return output

static func get_enemies_in_rect(tree: SceneTree, world_rect: Rect2) -> Array[Node2D]:
	var output: Array[Node2D] = []
	if tree == null:
		return output
	var registry := tree.root.get_node_or_null("EnemyRegistry")
	if registry != null and registry.has_method("get_enemies_in_rect"):
		var registered_enemies: Variant = registry.call("get_enemies_in_rect", world_rect)
		if registered_enemies is Array:
			for enemy_ref in registered_enemies:
				var enemy := enemy_ref as Node2D
				if enemy != null and is_instance_valid(enemy):
					output.append(enemy)
			return output
	return output
