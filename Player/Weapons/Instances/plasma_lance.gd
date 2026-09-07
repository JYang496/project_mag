extends Ranger

const WEAPON_SKILL_AREA := preload("res://Player/Weapons/Effects/weapon_skill_area.gd")
const MOVING_WALL_ATTACK := preload("res://Player/Weapons/Geometry/moving_wall_attack.gd")

var ITEM_NAME := "Plasma Lance"
@export var heat_accumulation: float = 10.0
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 0.0
@export var plasma_heat_damage_bonus_at_full_heat: float = 0.75
@export var discharge_damage_multiplier: float = 1.85
@export var discharge_heat_cost: float = 35.0
@export var wall_width: float = 150.0
@export var wall_thickness: float = 20.0
@export var wall_travel_speed: float = 520.0
@export var discharge_width_multiplier: float = 1.35
@export var discharge_thickness_multiplier: float = 1.25

var attack_range: float = 980.0
var _overcharge_lance_stack_count: int = 0
var _overcharge_lance_remaining_sec: float = 0.0
var _plasma_discharge_heat_spent: float = 0.0

var weapon_data := {
	"1": {"damage": "26", "speed": "1100", "projectile_hits": "3", "fire_interval_sec": "1.5", "ammo": "6"},
	"2": {"damage": "32", "speed": "1140", "projectile_hits": "3", "fire_interval_sec": "1.5", "ammo": "6"},
	"3": {"damage": "38", "speed": "1180", "projectile_hits": "3", "fire_interval_sec": "1.30", "ammo": "6"},
	"4": {"damage": "45", "speed": "1220", "projectile_hits": "3", "fire_interval_sec": "1.30", "ammo": "7"},
	"5": {"damage": "54", "speed": "1260", "projectile_hits": "3", "fire_interval_sec": "1.20", "ammo": "7"},
	"6": {"damage": "64", "speed": "1300", "projectile_hits": "3", "fire_interval_sec": "1.20", "ammo": "8"},
	"7": {"damage": "76", "speed": "1340", "projectile_hits": "3", "fire_interval_sec": "1.10", "ammo": "8"},
	"8": {"damage": "88", "speed": "1380", "projectile_hits": "3", "fire_interval_sec": "1.10", "ammo": "9"},
	"9": {"damage": "100", "speed": "1420", "projectile_hits": "3", "fire_interval_sec": "1.00", "ammo": "9"}
}

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tick_overcharge_lance_stacks(delta)

func activate_weapon_skill_effect(_context: SkillActionContext) -> bool:
	var center: Vector2 = get_mouse_target()
	var target := find_closest_enemy(center, 200.0)
	if target != null:
		center = target.global_position
	var storm := WEAPON_SKILL_AREA.new().setup(
		WEAPON_SKILL_AREA.Mode.PLASMA_STORM, self, center, 4.0, 175.0, 0.5, 0.45
	)
	get_projectile_spawn_parent().add_child(storm)
	return true

func set_level(lv) -> void:
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["projectile_hits"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	heat_per_shot = heat_accumulation
	heat_max_value = max_heat
	heat_cool_rate = heat_cooldown_rate
	configure_heat(heat_per_shot, heat_max_value, heat_cool_rate)
	sync_stats()

func _on_shoot() -> void:
	is_on_cooldown = true
	cooldown_timer.wait_time = maxf(get_runtime_attack_cooldown(), 0.05)
	cooldown_timer.start()

	projectile_direction = get_aim_forward()
	if projectile_direction == Vector2.ZERO:
		return
	var runtime_damage: int = get_runtime_damage()
	var heat_damage_multiplier: float = _get_heat_damage_multiplier()
	var profile := {
		"origin": get_muzzle_global_position(),
		"direction": projectile_direction,
		"width": get_effective_area_radius(wall_width),
		"thickness": get_effective_area_radius(wall_thickness),
		"speed": wall_travel_speed,
		"travel_distance": attack_range,
		"damage": maxi(1, int(round(float(runtime_damage) * heat_damage_multiplier))),
		"damage_type": Attack.TYPE_ENERGY,
	}
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior != null and is_instance_valid(behavior) and behavior.has_method("get_plasma_wall_profile"):
			var modifiers: Dictionary = behavior.call("get_plasma_wall_profile")
			profile["width"] = float(profile["width"]) * maxf(float(modifiers.get("width_multiplier", 1.0)), 0.1)
			profile["thickness"] = float(profile["thickness"]) * maxf(float(modifiers.get("thickness_multiplier", 1.0)), 0.1)
			profile["travel_distance"] = float(profile["travel_distance"]) * maxf(float(modifiers.get("travel_distance_multiplier", 1.0)), 0.1)
	if is_energy_release_attack_active():
		profile["width"] = float(profile["width"]) * discharge_width_multiplier
		profile["thickness"] = float(profile["thickness"]) * discharge_thickness_multiplier
	var wall: Node = MOVING_WALL_ATTACK.new().setup(self, profile) as Node
	apply_energy_release_marker(wall)
	apply_heat_snapshot_marker(wall)
	get_projectile_spawn_parent().add_child(wall)

func _get_heat_damage_multiplier() -> float:
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player):
		return 1.0
	if not player.has_method("get_total_heat_ratio"):
		return 1.0
	var heat_ratio := clampf(float(player.call("get_total_heat_ratio")), 0.0, 1.0)
	var overcharge_config := _get_overcharge_lance_config()
	var overcharge_active_stacks := _get_overcharge_lance_stack_count()
	var overcharge_bonus := 0.0
	if not overcharge_config.is_empty():
		var bonus_per_stack := maxf(float(overcharge_config.get("damage_bonus_per_stack", 0.0)), 0.0)
		overcharge_bonus = bonus_per_stack * float(overcharge_active_stacks)
		var threshold := clampf(float(overcharge_config.get("heat_ratio_threshold", 0.7)), 0.0, 1.0)
		if heat_ratio >= threshold:
			_add_overcharge_lance_stack(
				float(overcharge_config.get("duration", 5.0)),
				maxi(int(overcharge_config.get("max_stacks", 3)), 1)
			)
	var multiplier := 1.0 + maxf(plasma_heat_damage_bonus_at_full_heat, 0.0) * heat_ratio + overcharge_bonus
	var heat_prepared_active := false
	if player.has_method("has_heat_prepared") and bool(player.call("has_heat_prepared")):
		heat_prepared_active = true
	emit_passive_trigger(&"plasma_lance_heat_power", {
		"trigger": "shot",
		"heat_ratio": heat_ratio,
		"overcharge_active_stacks": overcharge_active_stacks,
		"overcharge_damage_bonus": overcharge_bonus,
		"overcharge_stack_count_after": _get_overcharge_lance_stack_count(),
		"damage_multiplier": multiplier,
		"heat_prepared_active": heat_prepared_active,
	}, PASSIVE_SCOPE_GLOBAL)
	return maxf(multiplier, 0.05)

func on_plasma_wall_damage_dealt(_wall: Node, _target: Node, _damage_type: StringName, _final_damage: int) -> void:
	pass

func _get_overcharge_lance_config() -> Dictionary:
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior.has_method("get_overcharge_lance_config"):
			var config: Variant = behavior.call("get_overcharge_lance_config")
			if config is Dictionary:
				return config
	return {}

func _tick_overcharge_lance_stacks(delta: float) -> void:
	if _overcharge_lance_stack_count <= 0:
		return
	_overcharge_lance_remaining_sec = maxf(_overcharge_lance_remaining_sec - maxf(delta, 0.0), 0.0)
	if _overcharge_lance_remaining_sec <= 0.0:
		_clear_overcharge_lance_stacks()

func _add_overcharge_lance_stack(duration_sec: float, max_stacks: int) -> void:
	_overcharge_lance_stack_count = mini(_overcharge_lance_stack_count + 1, maxi(max_stacks, 1))
	_overcharge_lance_remaining_sec = maxf(duration_sec, 0.05)

func _get_overcharge_lance_stack_count() -> int:
	_tick_overcharge_lance_stacks(0.0)
	return _overcharge_lance_stack_count

func _get_overcharge_lance_remaining_sec() -> float:
	_tick_overcharge_lance_stacks(0.0)
	return _overcharge_lance_remaining_sec

func _clear_overcharge_lance_stacks() -> void:
	_overcharge_lance_stack_count = 0
	_overcharge_lance_remaining_sec = 0.0

func _get_level_data(lv: String) -> Dictionary:
	return get_weapon_level_data(lv, weapon_data)

func get_energy_full_fire_passive_id() -> StringName:
	return &"plasma_lance_energy_discharge_triggered"

func get_energy_full_fire_display_name() -> String:
	return "Plasma Discharge"

func get_energy_gain_per_damage_event() -> float:
	return 10.0

func get_energy_release_bonus_at_full() -> float:
	return maxf(discharge_damage_multiplier - 1.0, 0.0)

func prepare_energy_release_attack() -> Dictionary:
	_plasma_discharge_heat_spent = 0.0
	var player := _resolve_energy_pool_player()
	var state := super.prepare_energy_release_attack()
	if not bool(state.get("triggered", false)):
		return state
	if player != null and is_instance_valid(player) and player.has_method("consume_shared_heat"):
		_plasma_discharge_heat_spent = maxf(float(player.call("consume_shared_heat", maxf(discharge_heat_cost, 0.0))), 0.0)
	_energy_release_damage_multiplier = maxf(discharge_damage_multiplier, 1.0)
	state["multiplier"] = _energy_release_damage_multiplier
	state["release_mode"] = &"heat_exchange"
	state["heat_spent"] = _plasma_discharge_heat_spent
	emit_passive_trigger(&"plasma_discharge_heat_exchange", {
		"trigger": "full_energy_attack_fired",
		"release_mode": &"heat_exchange",
		"heat_spent": _plasma_discharge_heat_spent,
		"damage_multiplier": _energy_release_damage_multiplier,
	}, PASSIVE_SCOPE_GLOBAL)
	return state

func finish_energy_release_attack() -> void:
	super.finish_energy_release_attack()
	_plasma_discharge_heat_spent = 0.0

func get_passive_status() -> Dictionary:
	return get_energy_full_fire_status()

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_clear_overcharge_lance_stacks()
	_plasma_discharge_heat_spent = 0.0
