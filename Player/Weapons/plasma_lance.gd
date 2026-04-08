extends Ranger

var projectile_template = preload("res://Player/Weapons/Projectiles/plasma_lance_projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")

var ITEM_NAME := "Plasma Lance"
const BULLET_PIXEL_SIZE := Vector2(10.0, 10.0)

@export var heat_accumulation: float = 20.0
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 15.0
@export var damage_gain_per_pierce: int = 3

var attack_range: float = 980.0

var weapon_data := {
	"1": {"level": "1", "damage": "26", "speed": "1100", "hp": "4", "reload": "1.5", "range": "900", "cost": "12"},
	"2": {"level": "2", "damage": "32", "speed": "1140", "hp": "5", "reload": "1.45", "range": "940", "cost": "12"},
	"3": {"level": "3", "damage": "38", "speed": "1180", "hp": "6", "reload": "1.38", "range": "980", "cost": "12"},
	"4": {"level": "4", "damage": "45", "speed": "1220", "hp": "7", "reload": "1.30", "range": "1020", "cost": "12"},
	"5": {"level": "5", "damage": "54", "speed": "1260", "hp": "8", "reload": "1.20", "range": "1080", "cost": "12"},
}

func set_level(lv) -> void:
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["hp"])
	base_attack_cooldown = float(level_data["reload"])
	attack_range = float(level_data.get("range", attack_range))
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
	spawn_projectile.damage = get_runtime_shot_damage()
	spawn_projectile.damage_type = Attack.TYPE_ENERGY
	spawn_projectile.hp = max(1, projectile_hits)
	var lance_projectile := spawn_projectile as PlasmaLanceProjectile
	if lance_projectile:
		lance_projectile.damage_gain_per_pierce = damage_gain_per_pierce
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.2)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "26", "speed": "1100", "hp": "4", "reload": "1.5", "range": "900", "cost": "12"}
