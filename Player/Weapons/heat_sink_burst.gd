extends Ranger

var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/03(5).png")
var area_effect_scene = preload("res://Utility/area_effect/area_effect.tscn")

var ITEM_NAME := "Heat Sink Burst"

@export var heat_accumulation: float = 10
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 25.0

@export var burst_radius: float = 170.0
@export var burst_duration: float = 0.2
@export var burst_base_damage: int = 90
@export var burst_damage_per_level: int = 14

var attack_range: float = 740.0

var weapon_data := {
	"1": {"level": "1", "damage": "9", "speed": "980", "hp": "1", "reload": "0.20", "range": "680", "cost": "10"},
	"2": {"level": "2", "damage": "11", "speed": "1020", "hp": "1", "reload": "0.18", "range": "700", "cost": "10"},
	"3": {"level": "3", "damage": "13", "speed": "1060", "hp": "1", "reload": "0.17", "range": "730", "cost": "10"},
	"4": {"level": "4", "damage": "16", "speed": "1100", "hp": "1", "reload": "0.16", "range": "760", "cost": "10"},
	"5": {"level": "5", "damage": "20", "speed": "1150", "hp": "2", "reload": "0.15", "range": "790", "cost": "10"},
}

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

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
	start_weapon_cooldown(attack_cooldown, 0.03)

	var spawn_projectile := spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return
	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	spawn_projectile.damage = get_runtime_shot_damage()
	spawn_projectile.damage_type = Attack.TYPE_ENERGY
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.12)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func _trigger_overheat_burst() -> void:
	if area_effect_scene == null:
		return
	var burst := area_effect_scene.instantiate() as AreaEffect
	if burst == null:
		return
	var burst_base: float = float(burst_base_damage + int(max(0, level - 1)) * burst_damage_per_level)
	var burst_damage: int = get_runtime_damage_value(burst_base)
	burst.source_node = self
	burst.global_position = global_position
	burst.radius = maxf(burst_radius, 8.0)
	burst.duration = maxf(burst_duration, 0.05)
	burst.one_shot_damage = burst_damage
	burst.damage_type = Attack.TYPE_FIRE
	burst.target_group = AreaEffect.TargetGroup.ENEMIES
	burst.apply_once_per_target = true
	burst.visual_enabled = false
	get_projectile_spawn_parent().call_deferred("add_child", burst)

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "9", "speed": "980", "hp": "1", "reload": "0.20", "range": "680", "cost": "10"}

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	if not can_run_active_behavior():
		return
	if not pressed or is_on_cooldown:
		return
	if not can_fire_with_heat():
		return
	var was_overheated := is_weapon_overheated()
	emit_signal("shoot")
	register_shot_heat()
	if not was_overheated and is_weapon_overheated():
		_trigger_overheat_burst()
