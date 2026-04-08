extends Ranger

var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/minigun_bullet.png")

var ITEM_NAME := "Pulse Sidearm"
const BULLET_PIXEL_SIZE := Vector2(8.0, 8.0)

@export var resonance_every_shots: int = 4
@export var resonance_damage_bonus_ratio: float = 0.25

var attack_range: float = 860.0
var _shots_fired: int = 0

var weapon_data := {
	"1": {"level": "1", "damage": "10", "speed": "1400", "hp": "1", "reload": "0.25", "range": "760", "cost": "9"},
	"2": {"level": "2", "damage": "12", "speed": "1450", "hp": "1", "reload": "0.244", "range": "780", "cost": "9"},
	"3": {"level": "3", "damage": "14", "speed": "1500", "hp": "1", "reload": "0.238", "range": "800", "cost": "9"},
	"4": {"level": "4", "damage": "17", "speed": "1550", "hp": "1", "reload": "0.232", "range": "830", "cost": "9"},
	"5": {"level": "5", "damage": "20", "speed": "1600", "hp": "1", "reload": "0.222", "range": "860", "cost": "9"},
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
	sync_stats()

func _on_shoot() -> void:
	is_on_cooldown = true
	cooldown_timer.wait_time = maxf(get_effective_cooldown(attack_cooldown), 0.05)
	cooldown_timer.start()

	var spawn_projectile := spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return

	_shots_fired += 1
	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	var shot_damage := get_runtime_shot_damage()
	if _is_resonance_shot():
		var bonus := int(round(float(shot_damage) * maxf(resonance_damage_bonus_ratio, 0.0)))
		shot_damage += max(1, bonus)

	spawn_projectile.damage = max(1, shot_damage)
	spawn_projectile.damage_type = Attack.TYPE_ENERGY
	spawn_projectile.hp = max(1, projectile_hits)
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.15)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func _is_resonance_shot() -> bool:
	var interval: int = max(1, resonance_every_shots)
	return (_shots_fired % interval) == 0

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "10", "speed": "1400", "hp": "1", "reload": "0.25", "range": "760", "cost": "9"}
