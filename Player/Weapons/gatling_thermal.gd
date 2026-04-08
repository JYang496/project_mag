extends Ranger

var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")

var ITEM_NAME := "Gatling Thermal"
const BULLET_PIXEL_SIZE := Vector2(10.0, 10.0)

@export var heat_accumulation: float = 4.0
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 20.0
@export_range(5.0, 80.0, 1.0) var front_fire_half_angle_deg: float = 35.0
@export_range(0.0, 1.0, 0.01) var overheat_burn_threshold_ratio: float = 0.8
@export_range(0.0, 2.0, 0.01) var burn_bonus_damage_ratio: float = 0.35

var attack_range: float = 760.0
var bullets_per_shot: int = 3

var weapon_data := {
	"1": {"level": "1", "damage": "7", "speed": "920", "hp": "1", "reload": "0.16", "bullet_count": "3", "range": "700", "cost": "11"},
	"2": {"level": "2", "damage": "8", "speed": "940", "hp": "1", "reload": "0.15", "bullet_count": "3", "range": "720", "cost": "11"},
	"3": {"level": "3", "damage": "9", "speed": "980", "hp": "1", "reload": "0.14", "bullet_count": "4", "range": "740", "cost": "11"},
	"4": {"level": "4", "damage": "11", "speed": "1020", "hp": "1", "reload": "0.13", "bullet_count": "4", "range": "780", "cost": "11"},
	"5": {"level": "5", "damage": "13", "speed": "1080", "hp": "2", "reload": "0.12", "bullet_count": "5", "range": "820", "cost": "11"},
}

func set_level(lv) -> void:
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["hp"])
	base_attack_cooldown = float(level_data["reload"])
	bullets_per_shot = max(1, int(level_data.get("bullet_count", bullets_per_shot)))
	attack_range = float(level_data.get("range", attack_range))
	heat_per_shot = heat_accumulation
	heat_max_value = max_heat
	heat_cool_rate = heat_cooldown_rate
	configure_heat(heat_per_shot, heat_max_value, heat_cool_rate)
	sync_stats()

func _on_shoot() -> void:
	is_on_cooldown = true
	cooldown_timer.wait_time = maxf(get_effective_cooldown(attack_cooldown), 0.03)
	cooldown_timer.start()

	var target_position: Vector2 = get_mouse_target()
	var forward := global_position.direction_to(target_position).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.UP

	var runtime_damage := get_runtime_shot_damage()
	var is_burning_mode := get_heat_ratio() >= overheat_burn_threshold_ratio
	for i in range(bullets_per_shot):
		var spawn_projectile := spawn_projectile_from_scene(projectile_template)
		if spawn_projectile == null:
			continue
		var offset_rad := deg_to_rad(randf_range(-front_fire_half_angle_deg, front_fire_half_angle_deg))
		var shot_dir := forward.rotated(offset_rad).normalized()
		projectile_direction = shot_dir
		var shot_damage := runtime_damage
		if is_burning_mode:
			shot_damage = int(round(float(runtime_damage) * (1.0 + burn_bonus_damage_ratio)))
			spawn_projectile.damage_type = Attack.TYPE_FIRE
		else:
			spawn_projectile.damage_type = Attack.TYPE_PHYSICAL
		spawn_projectile.damage = max(1, shot_damage)
		spawn_projectile.hp = projectile_hits
		spawn_projectile.global_position = global_position
		spawn_projectile.projectile_texture = projectile_texture_resource
		spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
		spawn_projectile.size = size
		spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.12)
		apply_effects_on_projectile(spawn_projectile)
		get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "7", "speed": "920", "hp": "1", "reload": "0.16", "bullet_count": "3", "range": "700", "cost": "11"}
