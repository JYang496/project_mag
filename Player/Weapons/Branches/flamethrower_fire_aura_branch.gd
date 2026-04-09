extends WeaponBranchBehavior
class_name FlamethrowerFireAuraBranch

const AREA_EFFECT_SCENE: PackedScene = preload("res://Utility/area_effect/area_effect.tscn")

@export var pulse_interval_sec: float = 0.8
@export var pulse_radius: float = 140.0
@export var pulse_damage_ratio: float = 0.45
@export var pulse_duration_sec: float = 0.08

var _pulse_elapsed_sec: float = 0.0

func on_weapon_ready() -> void:
	_pulse_elapsed_sec = 0.0
	set_process(true)

func on_removed() -> void:
	set_process(false)
	_pulse_elapsed_sec = 0.0

func disables_primary_fire() -> bool:
	return true

func _process(delta: float) -> void:
	if weapon == null or not is_instance_valid(weapon):
		set_process(false)
		return
	if not _is_in_battle_phase():
		_pulse_elapsed_sec = 0.0
		return
	_pulse_elapsed_sec += maxf(delta, 0.0)
	var interval_sec: float = maxf(pulse_interval_sec, 0.05)
	if _pulse_elapsed_sec < interval_sec:
		return
	while _pulse_elapsed_sec >= interval_sec:
		_pulse_elapsed_sec -= interval_sec
		_emit_fire_pulse()

func _emit_fire_pulse() -> void:
	if AREA_EFFECT_SCENE == null:
		return
	var area_effect := AREA_EFFECT_SCENE.instantiate() as AreaEffect
	if area_effect == null:
		return
	var pulse_damage: int = _compute_pulse_damage()
	area_effect.source_node = weapon
	area_effect.radius = maxf(pulse_radius, 8.0)
	area_effect.duration = maxf(pulse_duration_sec, 0.01)
	area_effect.target_group = AreaEffect.TargetGroup.ENEMIES
	area_effect.apply_once_per_target = true
	area_effect.one_shot_damage = pulse_damage
	area_effect.tick_damage = 0
	area_effect.damage_type = Attack.TYPE_FIRE
	area_effect.visual_enabled = false
	area_effect.global_position = _resolve_pulse_center()
	_resolve_spawn_parent().call_deferred("add_child", area_effect)

func _compute_pulse_damage() -> int:
	if weapon == null or not is_instance_valid(weapon):
		return 1
	if not weapon.has_method("get_runtime_shot_damage"):
		return 1
	var base_damage: int = max(1, int(weapon.call("get_runtime_shot_damage")))
	return max(1, int(round(float(base_damage) * maxf(pulse_damage_ratio, 0.0))))

func _resolve_pulse_center() -> Vector2:
	if PlayerData.player != null and is_instance_valid(PlayerData.player):
		return PlayerData.player.global_position
	if weapon != null and is_instance_valid(weapon):
		return weapon.global_position
	return Vector2.ZERO

func _resolve_spawn_parent() -> Node:
	if weapon != null and is_instance_valid(weapon):
		if weapon.has_method("get_projectile_spawn_parent"):
			var parent_candidate: Variant = weapon.call("get_projectile_spawn_parent")
			if parent_candidate != null and parent_candidate is Node and is_instance_valid(parent_candidate):
				return parent_candidate as Node
		if weapon.get_tree() != null:
			var tree_from_weapon: SceneTree = weapon.get_tree()
			return tree_from_weapon.current_scene if tree_from_weapon.current_scene != null else tree_from_weapon.root
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		return tree.current_scene if tree.current_scene != null else tree.root
	return self

func _is_in_battle_phase() -> bool:
	if PhaseManager == null:
		return false
	if not PhaseManager.has_method("current_state"):
		return false
	return str(PhaseManager.current_state()) == str(PhaseManager.BATTLE)
