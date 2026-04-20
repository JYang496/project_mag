extends Ranger
class_name Sniper

var projectile_template: PackedScene = preload("res://Player/Weapons/Projectiles/sniper_projectile.tscn")
var projectile_texture_resource: Texture2D = preload("res://Textures/test/sniper_bullet.png")

var ITEM_NAME := "Sniper"
const NEAR_DISTANCE_THRESHOLD: float = 220.0
const FAR_DAMAGE_MULTIPLIER: float = 1.8

var attack_range: float = 900.0
var _last_projectile_hit_damage: int = 0

var weapon_data := {
	"1": {"level": "1", "damage": "12", "speed": "1700", "hp": "5", "fire_interval_sec": "3.0", "ammo": "5", "range": "900", "cost": "14"},
	"2": {"level": "2", "damage": "15", "speed": "1700", "hp": "6", "fire_interval_sec": "2.8", "ammo": "6", "range": "980", "cost": "14"},
	"3": {"level": "3", "damage": "19", "speed": "1800", "hp": "7", "fire_interval_sec": "2.6", "ammo": "7", "range": "1060", "cost": "14"},
	"4": {"level": "4", "damage": "24", "speed": "1800", "hp": "8", "fire_interval_sec": "2.4", "ammo": "8", "range": "1140", "cost": "14"},
	"5": {"level": "5", "damage": "30", "speed": "1900", "hp": "9", "fire_interval_sec": "2.2", "ammo": "9", "range": "1220", "cost": "14"},
	"6": {"level": "6", "damage": "37", "speed": "1900", "hp": "10", "fire_interval_sec": "2.1", "ammo": "10", "range": "1300", "cost": "14"},
	"7": {"level": "7", "damage": "45", "speed": "2000", "hp": "11", "fire_interval_sec": "2.0", "ammo": "12", "range": "1380", "cost": "14"},
}

func set_level(lv) -> void:
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["hp"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	attack_range = float(level_data.get("range", attack_range))
	sync_stats()
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_level_applied(level)

func _on_shoot() -> void:
	is_on_cooldown = true
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	var projectile_damage_multiplier := 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		cooldown *= maxf(branch_behavior.get_cooldown_multiplier(), 0.05)
		projectile_damage_multiplier = maxf(branch_behavior.get_projectile_damage_multiplier(), 0.05)
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

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	_apply_distance_bonus_damage(target)
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_target_hit(target)

func _apply_distance_bonus_damage(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var target_node := target as Node2D
	if target_node == null:
		return
	var base_hit_damage: int = maxi(1, _last_projectile_hit_damage)
	var far_distance: float = maxf(attack_range, NEAR_DISTANCE_THRESHOLD + 1.0)
	var distance: float = global_position.distance_to(target_node.global_position)
	var t: float = clampf((distance - NEAR_DISTANCE_THRESHOLD) / maxf(far_distance - NEAR_DISTANCE_THRESHOLD, 1.0), 0.0, 1.0)
	var multiplier: float = lerpf(1.0, FAR_DAMAGE_MULTIPLIER, t)
	var bonus_damage: int = int(round(float(base_hit_damage) * maxf(multiplier - 1.0, 0.0)))
	if bonus_damage <= 0:
		return
	var damage_data := DamageManager.build_damage_data(
		self,
		bonus_damage,
		Attack.TYPE_PHYSICAL,
		{"amount": 0, "angle": Vector2.ZERO}
	)
	DamageManager.apply_to_target(target, damage_data)

func _get_branch_pierce_damage_gain_per_hit() -> int:
	if branch_behavior == null or not is_instance_valid(branch_behavior):
		return 0
	if not branch_behavior.has_method("get_pierce_damage_gain_per_hit"):
		return 0
	return max(0, int(branch_behavior.call("get_pierce_damage_gain_per_hit")))

func _get_branch_max_pierce_damage_stacks() -> int:
	if branch_behavior == null or not is_instance_valid(branch_behavior):
		return 0
	if not branch_behavior.has_method("get_max_pierce_damage_stacks"):
		return 0
	return max(0, int(branch_behavior.call("get_max_pierce_damage_stacks")))

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "12", "speed": "1700", "hp": "5", "fire_interval_sec": "3.0", "ammo": "5", "range": "900", "cost": "14"}
