extends Ranger

var projectile_template = preload("res://Player/Weapons/Projectiles/plasma_lance_projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")

var ITEM_NAME := "Plasma Lance"
const BULLET_PIXEL_SIZE := Vector2(10.0, 10.0)

@export var heat_accumulation: float = 10.0
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 0.0
@export var heat_spend_attacks_trigger_count: int = 3
@export var plasma_heat_spend_amount: float = 20.0
@export var plasma_heat_max_spend_amount: float = 20.0
@export var plasma_heat_spend_damage_bonus: float = 0.25
@export var heat_feedback_duration_sec: float = 10.0
@export var heat_feedback_threshold: float = 0.7
@export var heat_feedback_low_gain_mul: float = 1.2
@export var heat_feedback_high_gain_mul: float = 0.8

var attack_range: float = 980.0
var _heat_spend_attack_count: int = 0
var _heat_spend_chain_pending: bool = false
var _heat_spend_chain_last_spent: float = 0.0
var _overcharge_lance_stack_count: int = 0
var _overcharge_lance_remaining_sec: float = 0.0

var weapon_data := {
	"1": {"level": "1", "damage": "26", "speed": "1100", "hp": "3", "fire_interval_sec": "1.5", "ammo": "16", "cost": "12"},
	"2": {"level": "2", "damage": "32", "speed": "1140", "hp": "3", "fire_interval_sec": "1.45", "ammo": "18", "cost": "12"},
	"3": {"level": "3", "damage": "38", "speed": "1180", "hp": "3", "fire_interval_sec": "1.38", "ammo": "20", "cost": "12"},
	"4": {"level": "4", "damage": "45", "speed": "1220", "hp": "3", "fire_interval_sec": "1.30", "ammo": "22", "cost": "12"},
	"5": {"level": "5", "damage": "54", "speed": "1260", "hp": "3", "fire_interval_sec": "1.20", "ammo": "24", "cost": "12"},
	"6": {"level": "6", "damage": "64", "speed": "1300", "hp": "3", "fire_interval_sec": "1.09", "ammo": "26", "cost": "12"},
	"7": {"level": "7", "damage": "76", "speed": "1340", "hp": "3", "fire_interval_sec": "0.97", "ammo": "28", "cost": "12"},
}

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tick_overcharge_lance_stacks(delta)

func set_level(lv) -> void:
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["hp"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	heat_per_shot = heat_accumulation
	heat_max_value = max_heat
	heat_cool_rate = heat_cooldown_rate
	configure_heat(heat_per_shot, heat_max_value, heat_cool_rate)
	sync_stats()

func _on_shoot() -> void:
	is_on_cooldown = true
	cooldown_timer.wait_time = maxf(get_effective_cooldown(attack_cooldown), 0.05)
	cooldown_timer.start()

	var spawn_projectile := spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return

	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	var runtime_damage := get_runtime_shot_damage()
	var heat_spend_multiplier := _consume_heat_spend_multiplier()
	spawn_projectile.damage = max(1, int(round(float(runtime_damage) * heat_spend_multiplier)))
	spawn_projectile.damage_type = Attack.TYPE_ENERGY
	spawn_projectile.hp = _get_effective_projectile_hits()
	var lance_projectile := spawn_projectile as PlasmaLanceProjectile
	if lance_projectile:
		lance_projectile.damage_gain_per_pierce = get_branch_pierce_damage_gain_per_hit()
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.2)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func _consume_heat_spend_multiplier() -> float:
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player):
		return 1.0
	var intended_cost := maxf(plasma_heat_spend_amount, 0.0)
	if intended_cost <= 0.0:
		return 1.0
	if not player.has_method("consume_shared_heat"):
		return 1.0
	if not player.has_method("get_total_heat_value"):
		return 1.0
	var available_heat := maxf(float(player.call("get_total_heat_value")), 0.0)
	if available_heat < intended_cost:
		return 1.0
	var max_spend := _get_effective_heat_spend_max_amount(intended_cost)
	var effective_cost := minf(available_heat, max_spend)
	if player.has_method("get_heat_stabilized_cost_mul"):
		effective_cost *= clampf(float(player.call("get_heat_stabilized_cost_mul")), 0.0, 1.0)
	var spent := float(player.call("consume_shared_heat", effective_cost))
	if spent <= 0.0:
		return 1.0
	var overcharge_config := _get_overcharge_lance_config()
	var overcharge_active_stacks := 0
	var overcharge_extra_spent := 0.0
	var overcharge_bonus := 0.0
	if not overcharge_config.is_empty():
		overcharge_active_stacks = _get_overcharge_lance_stack_count()
		var extra_heat_per_stack := maxf(float(overcharge_config.get("extra_heat_per_stack", 0.0)), 0.0)
		var bonus_per_stack := maxf(float(overcharge_config.get("damage_bonus_per_stack", 0.0)), 0.0)
		if overcharge_active_stacks > 0 and extra_heat_per_stack > 0.0 and bonus_per_stack > 0.0:
			var heat_after_base := maxf(float(player.call("get_total_heat_value")), 0.0)
			var payable_stacks := mini(overcharge_active_stacks, int(floor(heat_after_base / extra_heat_per_stack)))
			if payable_stacks > 0:
				var requested_extra_cost := extra_heat_per_stack * float(payable_stacks)
				overcharge_extra_spent = float(player.call("consume_shared_heat", requested_extra_cost))
				var paid_stacks := int(floor((overcharge_extra_spent + 0.001) / extra_heat_per_stack))
				paid_stacks = clampi(paid_stacks, 0, payable_stacks)
				overcharge_bonus = bonus_per_stack * float(paid_stacks)
		_add_overcharge_lance_stack(float(overcharge_config.get("duration", 5.0)))
	var max_spend_ratio := maxf(max_spend / maxf(intended_cost, 0.001), 1.0)
	var spent_ratio := clampf(spent / maxf(intended_cost, 0.001), 0.0, max_spend_ratio)
	var multiplier := 1.0 + maxf(plasma_heat_spend_damage_bonus, 0.0) * spent_ratio + overcharge_bonus
	var heat_prepared_active := false
	if player.has_method("has_heat_prepared") and bool(player.call("has_heat_prepared")):
		heat_prepared_active = true
	emit_passive_trigger(&"plasma_lance_heat_spend", {
		"trigger": "shot",
		"heat_spent": spent,
		"heat_cost": effective_cost,
		"spent_ratio": spent_ratio,
		"overcharge_active_stacks": overcharge_active_stacks,
		"overcharge_extra_heat_spent": overcharge_extra_spent,
		"overcharge_damage_bonus": overcharge_bonus,
		"overcharge_stack_count_after": _get_overcharge_lance_stack_count(),
		"damage_multiplier": multiplier,
		"heat_prepared_active": heat_prepared_active,
	}, PASSIVE_SCOPE_GLOBAL)
	_try_trigger_heat_spend_chain(spent)
	return maxf(multiplier, 0.05)

func _get_effective_projectile_hits() -> int:
	return get_branch_projectile_hit_override(projectile_hits)

func _get_effective_heat_spend_max_amount(intended_cost: float) -> float:
	var max_amount := maxf(plasma_heat_max_spend_amount, intended_cost)
	for behavior in get_branch_behaviors():
		max_amount = maxf(max_amount, behavior.get_heat_spend_max_amount(max_amount))
	return maxf(max_amount, intended_cost)

func _get_overcharge_lance_config() -> Dictionary:
	for behavior in get_branch_behaviors():
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

func _add_overcharge_lance_stack(duration_sec: float) -> void:
	_overcharge_lance_stack_count += 1
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
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "26", "speed": "1100", "hp": "2", "fire_interval_sec": "1.5", "ammo": "16", "cost": "12"}

func _try_trigger_heat_spend_chain(spent: float) -> void:
	if not is_main_weapon():
		return
	if spent <= 0.0:
		return
	if not is_offhand_skill_ready():
		return
	_heat_spend_attack_count += 1
	_heat_spend_chain_last_spent = spent
	var required_count := maxi(1, heat_spend_attacks_trigger_count)
	if _heat_spend_attack_count < required_count:
		return
	_heat_spend_chain_pending = true

func _trigger_pending_heat_spend_chain() -> void:
	if not _heat_spend_chain_pending:
		return
	if not is_main_weapon():
		return
	if not is_offhand_skill_ready():
		return
	var required_count := maxi(1, heat_spend_attacks_trigger_count)
	if _heat_spend_attack_count < required_count:
		return
	notify_offhand_skill_triggered(0.0)
	var player: Node = PlayerData.player
	if player != null and is_instance_valid(player) and player.has_method("apply_plasma_lance_heat_feedback"):
		player.call(
			"apply_plasma_lance_heat_feedback",
			maxf(heat_feedback_duration_sec, 0.05),
			maxf(heat_feedback_low_gain_mul, 0.0),
			maxf(heat_feedback_high_gain_mul, 0.0),
			clampf(heat_feedback_threshold, 0.0, 1.0)
		)
	emit_passive_trigger(&"plasma_lance_heat_spend_chain_triggered", {
		"trigger": "reload_finished_after_heat_spend_attack_count",
		"heat_spend_attack_count": _heat_spend_attack_count,
		"required_count": required_count,
		"last_heat_spent": _heat_spend_chain_last_spent,
		"refresh": "reload",
		"status": "plasma_lance_heat_feedback",
		"duration": maxf(heat_feedback_duration_sec, 0.05),
		"threshold": clampf(heat_feedback_threshold, 0.0, 1.0),
		"low_heat_gain_multiplier": maxf(heat_feedback_low_gain_mul, 0.0),
		"high_heat_gain_multiplier": maxf(heat_feedback_high_gain_mul, 0.0),
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var required_count := maxi(1, heat_spend_attacks_trigger_count)
	var current_count := mini(_heat_spend_attack_count, required_count)
	var state := "charging"
	if not is_main_weapon():
		state = "inactive"
	elif not is_passive_ready():
		state = "waiting_refresh"
	elif _heat_spend_chain_pending or current_count >= required_count:
		state = "ready_pending_action"
	return {
		"id": "plasma_lance_heat_spend_chain_triggered",
		"display_name": "Heat Spend Chain",
		"state": state,
		"progress": clampf(float(current_count) / float(required_count), 0.0, 1.0),
		"current": current_count,
		"required": required_count,
		"ready": state == "ready_pending_action",
		"trigger_hint": "reload_finished",
		"refresh_hint": "reload",
	}

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if event_name != &"on_reload_finished":
		return
	if detail.get("source_weapon", null) != self:
		return
	_trigger_pending_heat_spend_chain()
	_heat_spend_attack_count = 0
	_heat_spend_chain_pending = false
	_heat_spend_chain_last_spent = 0.0

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_heat_spend_attack_count = 0
	_heat_spend_chain_pending = false
	_heat_spend_chain_last_spent = 0.0
	_clear_overcharge_lance_stacks()
