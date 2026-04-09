extends WeaponBranchBehavior
class_name DashFrostBranch

const FROST_FIELD_EFFECT_SCENE: PackedScene = preload("res://Player/Weapons/Effects/frost_field_effect.tscn")

@export var damage_multiplier: float = 1.22
@export var attack_range_multiplier: float = 2.1
@export var dash_speed_multiplier: float = 1.38
@export var return_speed_multiplier: float = 1.28
@export var cooldown_multiplier: float = 0.86
@export var freeze_finish_ratio: float = 0.35
@export var frost_field_duration_sec: float = 1.2
@export var frost_field_radius: float = 90.0
@export var frost_field_tick_sec: float = 0.4
@export var frost_field_tick_ratio: float = 0.2

func get_damage_multiplier() -> float:
	return maxf(damage_multiplier, 0.05)

func get_attack_range_multiplier() -> float:
	return maxf(attack_range_multiplier, 0.05)

func get_dash_speed_multiplier() -> float:
	return maxf(dash_speed_multiplier, 0.05)

func get_return_speed_multiplier() -> float:
	return maxf(return_speed_multiplier, 0.05)

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func on_target_hit(target: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if target == null or not is_instance_valid(target):
		return
	var runtime_damage := 1
	if weapon.has_method("get_runtime_shot_damage"):
		runtime_damage = max(1, int(weapon.call("get_runtime_shot_damage")))
	var freeze_damage: int = max(1, int(round(float(runtime_damage) * maxf(freeze_finish_ratio, 0.0))))
	var finish_damage: DamageData = DamageData.new().setup(
		freeze_damage,
		Attack.TYPE_FREEZE,
		{"amount": 0, "angle": Vector2.ZERO},
		weapon,
		DamageManager.resolve_source_player(weapon)
	)
	DamageManager.apply_to_target(target, finish_damage)
	_spawn_frost_field(target as Node2D, runtime_damage)

func _spawn_frost_field(target: Node2D, runtime_damage: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	var field: Node2D = FROST_FIELD_EFFECT_SCENE.instantiate() as Node2D
	if field == null:
		return
	if field.has_method("setup"):
		var tick_damage: int = max(1, int(round(float(runtime_damage) * maxf(frost_field_tick_ratio, 0.0))))
		field.call(
			"setup",
			weapon,
			DamageManager.resolve_source_player(weapon),
			Attack.TYPE_FREEZE,
			tick_damage,
			maxf(frost_field_tick_sec, 0.05),
			maxf(frost_field_duration_sec, 0.1),
			maxf(frost_field_radius, 8.0),
			false,
			3
		)
	field.global_position = target.global_position
	var tree := weapon.get_tree()
	var parent: Node = self
	if tree != null:
		parent = tree.current_scene if tree.current_scene != null else tree.root
	parent.call_deferred("add_child", field)
