extends WeaponBranchBehavior
class_name CannonZeroBranch

const ZERO_CANNON_TEXTURE: Texture2D = preload("res://asset/images/weapons/cannon3.png")

func on_weapon_ready() -> void:
	_apply_zero_cannon_visual()

func on_level_applied(_level: int) -> void:
	_apply_zero_cannon_visual()

func on_removed() -> void:
	super.on_removed()
	if weapon != null and is_instance_valid(weapon):
		weapon.call("_apply_fuse_sprite")

func _apply_zero_cannon_visual() -> void:
	if weapon == null or not is_instance_valid(weapon) or weapon.sprite == null:
		return
	weapon.sprite.texture = ZERO_CANNON_TEXTURE

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.ENERGY]

func get_suppressed_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.PHYSICAL]

func get_damage_type_override() -> StringName:
	return Attack.TYPE_ENERGY

func get_energy_gain_per_damage_event() -> float:
	return 10.0

func get_energy_release_bonus_at_full() -> float:
	return 1.0

@export var zero_burst_radius: float = 90.0
@export var zero_burst_damage_ratio: float = 0.50
@export var zero_burst_execute_threshold: float = 0.30
@export var zero_burst_execute_multiplier: float = 1.50

func apply_zero_release_impact(
	direct_target: Node,
	source_projectile: Node,
	final_damage: int
) -> int:
	var direct_node := direct_target as Node2D
	if direct_node == null or not is_instance_valid(direct_node) or final_damage <= 0:
		return 0
	return apply_zero_release_ground_impact(direct_node.global_position, source_projectile, final_damage)

func apply_zero_release_ground_impact(
	impact_position: Vector2,
	source_attack: Node,
	direct_damage: int
) -> int:
	if weapon == null or not is_instance_valid(weapon):
		return 0
	if source_attack == null or not is_instance_valid(source_attack) or direct_damage <= 0:
		return 0
	var applied := 0
	var strongest_pulse_damage := 0
	for enemy in WeaponModuleRuntimeUtils.get_nearby_enemies(
		weapon.get_tree(),
		impact_position,
		maxf(zero_burst_radius, 1.0)
	):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(impact_position) > maxf(zero_burst_radius, 1.0):
			continue
		var ratio := maxf(zero_burst_damage_ratio, 0.0)
		if enemy.has_method("get_health_ratio") \
				and float(enemy.call("get_health_ratio")) <= clampf(zero_burst_execute_threshold, 0.0, 1.0):
			ratio *= maxf(zero_burst_execute_multiplier, 1.0)
		var pulse_damage := maxi(1, int(round(float(direct_damage) * ratio)))
		strongest_pulse_damage = maxi(strongest_pulse_damage, pulse_damage)
		var data := DamageData.new().setup(
			pulse_damage,
			Attack.TYPE_ENERGY,
			{"amount": 0, "angle": Vector2.ZERO},
			source_attack,
			DamageManager.resolve_source_player(weapon),
			DamageData.SOURCE_PLAYER_WEAPON,
			DamageDeliveryType.AREA
		)
		data.damage_kind = DamageData.KIND_DIRECT
		data.suppress_reactive_effects = true
		data.dedupe_token = StringName("zero_burst_%d_%d" % [
			source_attack.get_instance_id(),
			enemy.get_instance_id(),
		])
		if DamageManager.apply_to_target(enemy, data):
			applied += 1
	weapon.emit_passive_trigger(&"cannon_zero_burst_impact", {
		"release_mode": &"stored_burst",
		"pulse_damage": strongest_pulse_damage,
		"radius": maxf(zero_burst_radius, 1.0),
		"targets": applied,
	}, Weapon.PASSIVE_SCOPE_GLOBAL)
	return applied

func get_energy_full_fire_passive_id() -> StringName:
	return &"cannon_zero_energy_cycle"

func get_energy_full_fire_display_name() -> String:
	return "Zero Burst"
