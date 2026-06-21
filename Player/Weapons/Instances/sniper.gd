extends Ranger
class_name Sniper

var projectile_template: PackedScene = preload("res://Player/Weapons/Projectiles/sniper_projectile.tscn")
var projectile_texture_resource: Texture2D = preload("res://asset/images/test/sniper_bullet.png")

var ITEM_NAME := "Sniper"
const NEAR_DISTANCE_THRESHOLD: float = 220.0
const FAR_DAMAGE_MULTIPLIER: float = 1.8
@export var far_hit_trigger_distance: float = 400.0

var attack_range: float = 900.0
var _last_projectile_hit_damage: int = 0

var weapon_data := {
	"1": {"damage": "12", "speed": "1700", "projectile_hits": "5", "fire_interval_sec": "3.0", "ammo": "5"},
	"2": {"damage": "15", "speed": "1700", "projectile_hits": "6", "fire_interval_sec": "2.8", "ammo": "6"},
	"3": {"damage": "19", "speed": "1800", "projectile_hits": "7", "fire_interval_sec": "2.6", "ammo": "7"},
	"4": {"damage": "24", "speed": "1800", "projectile_hits": "8", "fire_interval_sec": "2.4", "ammo": "8"},
	"5": {"damage": "30", "speed": "1900", "projectile_hits": "9", "fire_interval_sec": "2.2", "ammo": "9"},
	"6": {"damage": "37", "speed": "1900", "projectile_hits": "10", "fire_interval_sec": "2.1", "ammo": "10"},
	"7": {"damage": "45", "speed": "2000", "projectile_hits": "11", "fire_interval_sec": "2.0", "ammo": "12"},
	"8": {"damage": "53", "speed": "2100", "projectile_hits": "12", "fire_interval_sec": "1.9", "ammo": "14"},
	"9": {"damage": "61", "speed": "2200", "projectile_hits": "13", "fire_interval_sec": "1.8", "ammo": "16"}
}

func set_level(lv) -> void:
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["projectile_hits"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)

func _on_shoot() -> void:
	is_on_cooldown = true
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	var projectile_damage_multiplier := branch_runtime.get_branch_projectile_damage_multiplier()
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()

	var spawn_projectile := spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return

	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	if projectile_direction == Vector2.ZERO:
		return
	var runtime_damage := get_runtime_shot_damage()
	spawn_projectile.damage = max(1, int(round(float(runtime_damage) * projectile_damage_multiplier)))
	spawn_projectile.damage_type = Attack.TYPE_PHYSICAL
	spawn_projectile.hp = max(1, projectile_hits)
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.2)

	var sniper_projectile := spawn_projectile as SniperProjectile
	if sniper_projectile:
		sniper_projectile.pierce_damage_gain_per_hit = _get_branch_pierce_damage_gain_per_hit()
		sniper_projectile.max_pierce_damage_stacks = _get_branch_max_pierce_damage_stacks()

	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func set_last_projectile_hit_damage(value: int) -> void:
	_last_projectile_hit_damage = max(0, int(value))

func on_projectile_hit_damage_dealt(_projectile: Node, _target: Node, _hit_damage_type: StringName, final_damage: int) -> void:
	set_last_projectile_hit_damage(final_damage)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	_try_trigger_far_hit(target)
	branch_runtime.notify_branch_target_hit(target)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	super.on_hit_target_with_damage_type(target, damage_type)
	_try_trigger_far_hit(target)
	branch_runtime.notify_branch_target_hit(target)

func _try_trigger_far_hit(target: Node) -> void:
	var target_node := target as Node2D
	if target_node == null or not is_instance_valid(target_node):
		return
	var player := PlayerData.player as Node2D
	if player == null or not is_instance_valid(player):
		return
	var distance := player.global_position.distance_to(target_node.global_position)
	var has_mark := _has_any_mark(target)
	if distance < maxf(far_hit_trigger_distance, 0.0) and not has_mark:
		return
	if not is_offhand_skill_ready():
		return
	notify_offhand_skill_triggered(0.0)
	emit_passive_trigger(&"sniper_far_hit_triggered", {
		"target": target,
		"distance": distance,
		"threshold": far_hit_trigger_distance,
		"forced_full_bonus_by_mark": has_mark,
		"refresh": "reload",
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var state := "ready"
	if not is_passive_ready():
		state = "waiting_refresh"
	var charge_current := passive_controller.get_passive_charge_current()
	var charge_max := passive_controller.get_passive_charge_max()
	return with_passive_charge_status({
		"id": "sniper_far_hit_triggered",
		"display_name": "Far Hit",
		"state": state,
		"progress": float(charge_current) / float(maxi(charge_max, 1)),
		"ready": state == "ready",
		"condition_type": "distance_threshold",
		"required": maxf(far_hit_trigger_distance, 0.0),
		"comparison": ">=",
		"trigger_hint": "hit_distance",
		"refresh_hint": "reload",
		"charge_current": charge_current,
		"charge_max": charge_max,
		"charges_current": charge_current,
		"charges_max": charge_max,
	})

func get_passive_max_charges() -> int:
	return 3

func get_sniper_distance_scaled_damage(target: Node, base_damage: int) -> int:
	return max(1, int(round(float(maxi(base_damage, 1)) * _get_distance_damage_multiplier(target))))

func _get_distance_damage_multiplier(target: Node) -> float:
	var target_node := target as Node2D
	if target_node == null or not is_instance_valid(target_node):
		return 1.0
	var far_distance: float = maxf(attack_range, NEAR_DISTANCE_THRESHOLD + 1.0)
	var distance: float = global_position.distance_to(target_node.global_position)
	var t: float = clampf((distance - NEAR_DISTANCE_THRESHOLD) / maxf(far_distance - NEAR_DISTANCE_THRESHOLD, 1.0), 0.0, 1.0)
	if _has_any_mark(target):
		t = 1.0
	return lerpf(1.0, FAR_DAMAGE_MULTIPLIER, t)

func _apply_distance_bonus_damage(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var target_node := target as Node2D
	if target_node == null:
		return
	var base_hit_damage: int = maxi(1, _last_projectile_hit_damage)
	var multiplier: float = _get_distance_damage_multiplier(target)
	var bonus_damage: int = int(round(float(base_hit_damage) * maxf(multiplier - 1.0, 0.0)))
	if bonus_damage <= 0:
		return
	var damage_data := DamageManager.build_damage_data(
		self,
		bonus_damage,
		Attack.TYPE_PHYSICAL,
		{"amount": 0, "angle": Vector2.ZERO},
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.PROJECTILE
	)
	DamageManager.apply_to_target(target, damage_data)

func _has_any_mark(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("has_any_mark"):
		return false
	return bool(target.call("has_any_mark"))

func _get_branch_pierce_damage_gain_per_hit() -> int:
	return branch_runtime.get_branch_pierce_damage_gain_per_hit()

func _get_branch_max_pierce_damage_stacks() -> int:
	return branch_runtime.get_branch_max_pierce_damage_stacks()

func _get_level_data(lv: String) -> Dictionary:
	return get_weapon_level_data(lv, weapon_data)
