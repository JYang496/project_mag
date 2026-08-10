extends WeaponBranchBehavior
class_name PistolArcBranch

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.ENERGY]

func get_damage_type_override() -> StringName:
	return Attack.TYPE_ENERGY

func get_energy_gain_per_damage_event() -> float:
	return 12.0

func get_energy_release_bonus_at_full() -> float:
	return 0.15

@export var discharge_chain_radius: float = 180.0
@export var discharge_chain_damage_ratio: float = 0.45
@export var discharge_chain_max_targets: int = 3

func apply_arc_discharge_chain(
	direct_target: Node,
	source_projectile: Node,
	final_damage: int
) -> int:
	if weapon == null or not is_instance_valid(weapon):
		return 0
	var direct_node := direct_target as Node2D
	if direct_node == null or not is_instance_valid(direct_node) or final_damage <= 0:
		return 0
	var candidates: Array[Node2D] = []
	for enemy in WeaponModuleRuntimeUtils.get_nearby_enemies(
		weapon.get_tree(),
		direct_node.global_position,
		maxf(discharge_chain_radius, 1.0)
	):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node) or enemy_node == direct_target:
			continue
		candidates.append(enemy_node)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(direct_node.global_position) \
			< b.global_position.distance_squared_to(direct_node.global_position)
	)
	var applied := 0
	var chain_damage := maxi(1, int(round(float(final_damage) * maxf(discharge_chain_damage_ratio, 0.0))))
	for target in candidates:
		if applied >= maxi(discharge_chain_max_targets, 0):
			break
		var data := DamageData.new().setup(
			chain_damage,
			Attack.TYPE_ENERGY,
			{"amount": 0, "angle": Vector2.ZERO},
			source_projectile,
			DamageManager.resolve_source_player(weapon),
			DamageData.SOURCE_PLAYER_WEAPON,
			DamageDeliveryType.AREA
		)
		data.damage_kind = DamageData.KIND_DIRECT
		data.suppress_reactive_effects = true
		data.dedupe_token = StringName("arc_discharge_%d_%d" % [
			source_projectile.get_instance_id(),
			target.get_instance_id(),
		])
		DamageManager.apply_to_target(target, data)
		applied += 1
	if applied > 0:
		weapon.emit_passive_trigger(&"pistol_arc_discharge_chain", {
			"release_mode": &"chain",
			"source_target": direct_target,
			"chain_targets": applied,
			"chain_damage": chain_damage,
		}, Weapon.PASSIVE_SCOPE_GLOBAL)
	return applied

@export var trail_color: Color = Color(0.55, 0.75, 1.0, 0.9)
@export var trail_width: float = 2.5
@export var trail_max_points: int = 16
@export var trail_sample_interval_sec: float = 0.010
@export var trail_fade_sec: float = 0.2

func get_projectile_trail_config() -> Dictionary:
	return {
		"trail_color": trail_color,
		"trail_width": trail_width,
		"max_points": max(3, trail_max_points),
		"sample_interval_sec": maxf(trail_sample_interval_sec, 0.004),
		"trail_fade_sec": maxf(trail_fade_sec, 0.05),
	}

func get_energy_full_fire_passive_id() -> StringName:
	return &"pistol_arc_energy_cycle"

func get_energy_full_fire_display_name() -> String:
	return "Arc Discharge"
