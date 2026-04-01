extends Ranger

var projectile_template: PackedScene = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource: Texture2D = preload("res://Textures/test/sniper_bullet.png")

var ITEM_NAME := "Shatter Buckshot"

@export_range(0, 180) var arc: float = 36.0
@export var bullet_count: int = 6
@export var shatter_damage_ratio: float = 0.25
@export var shatter_required_hits: int = 3
@export var shatter_window_sec: float = 0.12

var weapon_data: Dictionary = {
	"1": {"level": "1", "damage": "8", "speed": "900", "hp": "1", "reload": "1.05", "range": "520", "cost": "11"},
	"2": {"level": "2", "damage": "9", "speed": "930", "hp": "1", "reload": "1.00", "range": "540", "cost": "11"},
	"3": {"level": "3", "damage": "11", "speed": "960", "hp": "1", "reload": "0.95", "range": "560", "cost": "11"},
	"4": {"level": "4", "damage": "13", "speed": "990", "hp": "1", "reload": "0.90", "range": "590", "cost": "11"},
	"5": {"level": "5", "damage": "15", "speed": "1020", "hp": "2", "reload": "0.85", "range": "620", "cost": "11"},
}

var attack_range: float = 520.0
var _target_window_hits: Dictionary = {}

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
	cooldown_timer.wait_time = maxf(attack_cooldown, 0.05)
	cooldown_timer.start()
	var main_target: Vector2 = get_mouse_target()
	var start_angle: float = global_position.direction_to(main_target).normalized().angle()
	var angle_step: float = deg_to_rad(arc) / maxf(float(max(1, bullet_count - 1)), 1.0)
	var start_offset: float = -deg_to_rad(arc) / 2.0
	var runtime_damage: int = get_runtime_shot_damage()
	for i in range(max(1, bullet_count)):
		var spawn_projectile: Node2D = spawn_projectile_from_scene(projectile_template)
		if spawn_projectile == null:
			continue
		var current_angle: float = start_angle + start_offset + (angle_step * float(i))
		projectile_direction = Vector2.RIGHT.rotated(current_angle)
		spawn_projectile.damage = runtime_damage
		spawn_projectile.damage_type = Attack.TYPE_FREEZE
		spawn_projectile.global_position = global_position
		spawn_projectile.projectile_texture = projectile_texture_resource
		spawn_projectile.size = size
		spawn_projectile.hp = projectile_hits
		spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.15)
		apply_effects_on_projectile(spawn_projectile)
		get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	if target == null or not is_instance_valid(target):
		return
	var target_id: int = target.get_instance_id()
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	var entry: Dictionary = _target_window_hits.get(target_id, {
		"window_start": now_sec,
		"hits": 0,
		"last_proc": -999.0,
	})
	var window_start: float = float(entry.get("window_start", now_sec))
	var hits: int = int(entry.get("hits", 0))
	if now_sec - window_start > maxf(shatter_window_sec, 0.01):
		window_start = now_sec
		hits = 0
	hits += 1
	entry["window_start"] = window_start
	entry["hits"] = hits
	if hits >= max(1, shatter_required_hits):
		var last_proc: float = float(entry.get("last_proc", -999.0))
		if now_sec - last_proc >= maxf(shatter_window_sec, 0.01):
			entry["last_proc"] = now_sec
			entry["hits"] = 0
			entry["window_start"] = now_sec
			_trigger_shatter(target)
	_target_window_hits[target_id] = entry

func _trigger_shatter(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var shatter_damage: int = max(1, int(round(float(get_runtime_shot_damage()) * maxf(shatter_damage_ratio, 0.0))))
	var owner_player: Node = DamageManager.resolve_source_player(self)
	var damage_data: DamageData = DamageData.new().setup(
		shatter_damage,
		Attack.TYPE_FREEZE,
		{"amount": 0, "angle": Vector2.ZERO},
		self,
		owner_player
	)
	DamageManager.apply_to_target(target, damage_data)

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "8", "speed": "900", "hp": "1", "reload": "1.05", "range": "520", "cost": "11"}
