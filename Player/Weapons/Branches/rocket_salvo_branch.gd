extends WeaponBranchBehavior
class_name RocketSalvoBranch

const ENEMY_SEEK_EFFECT_ID: StringName = &"enemy_seek_steer"

@export var cooldown_multiplier: float = 1.55
@export var projectile_damage_multiplier: float = 0.8
@export var projectile_count: int = 3
@export var spread_deg: float = 10.0
@export var seek_effect_priority: int = 10
@export var seek_turn_rate_deg_per_sec: float = 82.5
@export var seek_search_radius: float = 260.0
@export var seek_max_lock_angle_deg: float = 85.0
@export var seek_retarget_interval_sec: float = 0.05
@export var seek_min_speed_ratio: float = 1.0

func on_weapon_ready() -> void:
	_ensure_enemy_seek_effect()

func on_level_applied(_level: int) -> void:
	_ensure_enemy_seek_effect()

func on_removed() -> void:
	_remove_enemy_seek_effect()

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_projectile_damage_multiplier() -> float:
	return maxf(projectile_damage_multiplier, 0.05)

# Splits one rocket shot into multiple directions for a salvo pattern.
func get_shot_directions(base_direction: Vector2, shot_count: int = -1) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	var count := projectile_count if shot_count < 0 else shot_count
	count = clampi(count, 1, 12)
	var normalized_base := base_direction.normalized()
	if count == 1:
		return [normalized_base]
	var spread_step := deg_to_rad(spread_deg)
	var center_offset := float(count - 1) * 0.5
	for i in range(count):
		var angle := (float(i) - center_offset) * spread_step
		dirs.append(normalized_base.rotated(angle))
	return dirs

func _ensure_enemy_seek_effect() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.has_method("ensure_effect_config"):
		return
	var config_variant: Variant = weapon.call("ensure_effect_config", ENEMY_SEEK_EFFECT_ID)
	var config := config_variant as EffectConfig
	if config == null:
		return
	config.enabled = true
	config.priority = maxi(seek_effect_priority, 0)
	if config is EnemySeekSteerEffectConfig:
		var seek_config := config as EnemySeekSteerEffectConfig
		seek_config.turn_rate_deg_per_sec = maxf(seek_turn_rate_deg_per_sec, 0.0)
		seek_config.search_radius = maxf(seek_search_radius, 1.0)
		seek_config.max_lock_angle_deg = clampf(seek_max_lock_angle_deg, 0.0, 180.0)
		seek_config.retarget_interval_sec = maxf(seek_retarget_interval_sec, 0.01)
		seek_config.min_speed_ratio = maxf(seek_min_speed_ratio, 0.0)
	if weapon.has_method("update_configuration_warnings"):
		weapon.call("update_configuration_warnings")

func _remove_enemy_seek_effect() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var effect_configs_variant: Variant = weapon.get("effect_configs")
	if not (effect_configs_variant is Array):
		return
	var effect_configs: Array = effect_configs_variant
	for i in range(effect_configs.size() - 1, -1, -1):
		var config := effect_configs[i] as EffectConfig
		if config == null:
			continue
		if config.effect_id == ENEMY_SEEK_EFFECT_ID:
			effect_configs.remove_at(i)
	weapon.set("effect_configs", effect_configs)
	if weapon.has_method("update_configuration_warnings"):
		weapon.call("update_configuration_warnings")
