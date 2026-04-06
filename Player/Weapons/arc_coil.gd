extends Ranger

var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")

var ITEM_NAME := "Arc Coil"
const BULLET_PIXEL_SIZE := Vector2(10.0, 10.0)

@export var chain_count: int = 2
@export var chain_radius: float = 240.0
@export var chain_damage_ratio_1: float = 0.65
@export var chain_damage_ratio_2: float = 0.40

var attack_range: float = 900.0

var weapon_data := {
	"1": {"level": "1", "damage": "18", "speed": "1200", "hp": "1", "reload": "0.625", "range": "820", "cost": "12"},
	"2": {"level": "2", "damage": "22", "speed": "1220", "hp": "1", "reload": "0.606", "range": "840", "cost": "12"},
	"3": {"level": "3", "damage": "27", "speed": "1240", "hp": "1", "reload": "0.588", "range": "860", "cost": "12"},
	"4": {"level": "4", "damage": "33", "speed": "1260", "hp": "1", "reload": "0.571", "range": "880", "cost": "12"},
	"5": {"level": "5", "damage": "40", "speed": "1280", "hp": "1", "reload": "0.556", "range": "900", "cost": "12"},
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
	cooldown_timer.wait_time = maxf(attack_cooldown, 0.05)
	cooldown_timer.start()

	var spawn_projectile := spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return

	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	spawn_projectile.damage = get_runtime_shot_damage()
	spawn_projectile.damage_type = Attack.TYPE_ENERGY
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
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	var center := target as Node2D
	if center == null:
		return

	var ratios := [chain_damage_ratio_1, chain_damage_ratio_2]
	var candidates: Array[Node2D] = []
	for enemy_ref in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_ref as Node2D
		if enemy == null or enemy == center:
			continue
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(center.global_position) <= maxf(chain_radius, 1.0):
			candidates.append(enemy)

	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_to(center.global_position) < b.global_position.distance_to(center.global_position)
	)

	var hops := mini(max(0, chain_count), candidates.size())
	for i in range(hops):
		var ratio: float = ratios[min(i, ratios.size() - 1)] if not ratios.is_empty() else 0.5
		var chain_damage: int = max(1, int(round(float(get_runtime_shot_damage()) * maxf(ratio, 0.05))))
		var chain_data := DamageManager.build_damage_data(
			self,
			chain_damage,
			Attack.TYPE_ENERGY
		)
		if DamageManager.apply_to_target(candidates[i], chain_data):
			var owner_player := chain_data.source_player as Player
			if owner_player and is_instance_valid(owner_player):
				owner_player.apply_bonus_hit_if_needed(candidates[i])

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "18", "speed": "1200", "hp": "1", "reload": "0.625", "range": "820", "cost": "12"}
