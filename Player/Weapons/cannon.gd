extends Ranger
class_name Cannon

var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")

var ITEM_NAME := "Cannon"
const BULLET_PIXEL_SIZE := Vector2(11.0, 11.0)

@export var windup_sec: float = 0.15
var attack_range: float = 920.0
var _windup_in_progress: bool = false

var weapon_data := {
	"1": {"level": "1", "damage": "50", "speed": "1120", "hp": "1", "fire_interval_sec": "1.667", "ammo": "18", "range": "880", "cost": "13"},
	"2": {"level": "2", "damage": "60", "speed": "1140", "hp": "1", "fire_interval_sec": "1.600", "ammo": "20", "range": "905", "cost": "13"},
	"3": {"level": "3", "damage": "67", "speed": "1170", "hp": "2", "fire_interval_sec": "1.533", "ammo": "22", "range": "930", "cost": "13"},
	"4": {"level": "4", "damage": "80", "speed": "1200", "hp": "2", "fire_interval_sec": "1.467", "ammo": "24", "range": "960", "cost": "13"},
	"5": {"level": "5", "damage": "100", "speed": "1230", "hp": "2", "fire_interval_sec": "1.400", "ammo": "26", "range": "990", "cost": "13"},
	"6": {"level": "6", "damage": "120", "speed": "1260", "hp": "2", "fire_interval_sec": "1.333", "ammo": "28", "range": "1025", "cost": "13"},
	"7": {"level": "7", "damage": "140", "speed": "1290", "hp": "2", "fire_interval_sec": "1.267", "ammo": "30", "range": "1060", "cost": "13"},
}

@onready var windup_timer: Timer = $WindupTimer

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

func request_primary_fire() -> bool:
	if not is_attack_phase_allowed():
		return false
	if is_on_cooldown or _windup_in_progress:
		return false
	if not can_fire_with_heat():
		return false
	if windup_sec <= 0.0:
		emit_signal("shoot")
		register_shot_heat()
		return true
	_windup_in_progress = true
	is_on_cooldown = true
	if windup_timer:
		windup_timer.wait_time = maxf(windup_sec, 0.01)
		windup_timer.start()
	else:
		_on_windup_timer_timeout()
	return true

func _on_windup_timer_timeout() -> void:
	if not _windup_in_progress:
		return
	_windup_in_progress = false
	emit_signal("shoot")
	register_shot_heat()

func _on_shoot() -> void:
	is_on_cooldown = true
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	if branch_behavior and is_instance_valid(branch_behavior):
		cooldown *= maxf(branch_behavior.get_cooldown_multiplier(), 0.05)
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()

	var spawn_projectile := spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return

	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	var runtime_damage := get_runtime_shot_damage()
	var damage_multiplier := 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		damage_multiplier = maxf(branch_behavior.get_projectile_damage_multiplier(), 0.05)
	spawn_projectile.damage = max(1, int(round(float(runtime_damage) * damage_multiplier)))
	var damage_type: StringName = Attack.TYPE_PHYSICAL
	if branch_behavior and is_instance_valid(branch_behavior):
		damage_type = Attack.normalize_damage_type(branch_behavior.get_damage_type_override())
	spawn_projectile.damage_type = damage_type
	spawn_projectile.hp = max(1, projectile_hits)
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.2)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_target_hit(target)

func _on_cooldown_timer_timeout() -> void:
	is_on_cooldown = false
	_windup_in_progress = false

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "48", "speed": "1120", "hp": "1", "fire_interval_sec": "1.667", "ammo": "18", "range": "880", "cost": "13"}
