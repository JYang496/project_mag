extends Ranger

var projectile_template: PackedScene = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource: Texture2D = preload("res://asset/images/weapons/projectiles/plasma.png")

var ITEM_NAME := "Cryo Carbine"

var weapon_data: Dictionary = {
	"1": {"level": "1", "damage": "18", "speed": "1050", "hp": "1", "reload": "0.65", "range": "820", "cost": "12"},
	"2": {"level": "2", "damage": "22", "speed": "1080", "hp": "1", "reload": "0.62", "range": "850", "cost": "12"},
	"3": {"level": "3", "damage": "27", "speed": "1120", "hp": "1", "reload": "0.58", "range": "880", "cost": "12"},
	"4": {"level": "4", "damage": "33", "speed": "1160", "hp": "1", "reload": "0.55", "range": "920", "cost": "12"},
	"5": {"level": "5", "damage": "40", "speed": "1200", "hp": "2", "reload": "0.52", "range": "960", "cost": "12"},
}

@export var shard_damage_ratio: float = 0.4
@export var shard_radius: float = 120.0
@export var shard_target_count: int = 1

var attack_range: float = 820.0
var _target_hit_counter: Dictionary = {}

func set_level(lv) -> void:
	lv = str(lv)
	var level_data: Dictionary = _get_level_data(lv)
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
	var spawn_projectile: Node2D = spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return
	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	spawn_projectile.damage = get_runtime_shot_damage()
	spawn_projectile.damage_type = Attack.TYPE_FREEZE
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.2)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	if target == null or not is_instance_valid(target):
		return
	if not (target is Node2D):
		return
	var target_id: int = target.get_instance_id()
	var hit_count: int = int(_target_hit_counter.get(target_id, 0)) + 1
	_target_hit_counter[target_id] = hit_count
	if hit_count % 3 != 0:
		return
	_trigger_shard(target as Node2D, target)

func _trigger_shard(hit_target: Node2D, original_target: Node) -> void:
	var shard_damage: int = max(1, int(round(float(get_runtime_shot_damage()) * maxf(shard_damage_ratio, 0.0))))
	var candidates: Array[Node2D] = []
	for enemy_ref in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy == original_target:
			continue
		if enemy.global_position.distance_to(hit_target.global_position) <= maxf(shard_radius, 1.0):
			candidates.append(enemy)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_to(hit_target.global_position) < b.global_position.distance_to(hit_target.global_position)
	)
	var owner_player: Node = DamageManager.resolve_source_player(self)
	for i in range(mini(max(1, shard_target_count), candidates.size())):
		var chained_target: Node2D = candidates[i]
		var damage_data: DamageData = DamageData.new().setup(
			shard_damage,
			Attack.TYPE_FREEZE,
			{"amount": 0, "angle": Vector2.ZERO},
			self,
			owner_player
		)
		DamageManager.apply_to_target(chained_target, damage_data)

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "18", "speed": "1050", "hp": "1", "reload": "0.65", "range": "820", "cost": "12"}
