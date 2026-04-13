extends Ranger

@onready var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
@onready var projectile_texture_resource = preload("res://Textures/test/bullet.png")
@export var radius : float = 80.0
@export var angle : float = 0.0
var knock_back = {
	"amount": 0,
	"angle": Vector2.ZERO
}
# Effect
@onready var rotate_around_player = preload("res://Player/Weapons/Effects/rotate_around_player.tscn")

var satellites : Array = []



# Weapon
var ITEM_NAME = "Orbit"
var spin_speed : float = 5.0
var number = 4
@export var offhand_main_attack_speed_mult: float = 1.3
@export var offhand_spin_speed_multiplier: float = 0.65
@export var offhand_buff_duration_sec: float = 0.5
@export var offhand_buff_icd_sec: float = 0.12
var _buff_target: Ranger
var _next_offhand_apply_msec: int = 0
var _offhand_buff_expires_at_msec: int = 0

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "15",
		"number": "1",
		"spin_speed": "3",
		"cost": "1",
	},
	"2": {
		"level": "2",
		"damage": "15",
		"number": "2",
		"spin_speed": "3",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "18",
		"number": "3",
		"spin_speed": "3",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "21",
		"number": "3",
		"spin_speed": "4",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "30",
		"number": "4",
		"spin_speed": "4",
		"cost": "1",
	},
	"6": {
		"level": "6",
		"damage": "40",
		"number": "5",
		"spin_speed": "4",
		"cost": "1",
	},
	"7": {
		"level": "7",
		"damage": "50",
		"number": "6",
		"spin_speed": "4",
		"cost": "1",
	}
}

func set_level(lv) -> void:
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	spin_speed = int(weapon_data[lv]["spin_speed"])
	number = int(weapon_data[lv]["number"])
	base_projectile_hits = 99999
	module_list.clear()
	sync_stats()
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_level_applied(level)
	_refresh_orbit_mode_state()

func apply_rotate_around_player(projectile_node : Node2D, offset_step : float, n : int, spin_speed_value: float) -> void:
	var rotate_around_player_ins = rotate_around_player.instantiate()
	rotate_around_player_ins.spin_speed = spin_speed_value
	rotate_around_player_ins.radius = radius
	rotate_around_player_ins.angle_offset = offset_step * n
	
	projectile_node.call_deferred("add_child",rotate_around_player_ins)
	projectile_node.module_list.append(rotate_around_player_ins)
	module_list.append(rotate_around_player_ins)
	pass


func remove_weapon() -> void:
	_clear_offhand_main_buff()
	module_list.clear()
	var idx := PlayerData.player_weapon_list.find(self)
	if idx >= 0:
		PlayerData.player_weapon_list.remove_at(idx)
	PlayerData.sanitize_main_weapon_index()
	PlayerData.on_select_weapon = PlayerData.main_weapon_index
	queue_free()

func _on_tree_exiting() -> void:
	_clear_offhand_main_buff()
	# Remove satellites when weapon node exits.
	for s in satellites:
		s.queue_free()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_main_weapon():
		return
	_process_offhand_main_weapon_buff()

func _on_weapon_role_changed(next_role: String) -> void:
	_update_satellite_runtime_state()
	if next_role == "main":
		_clear_offhand_main_buff()

func _refresh_orbit_mode_state() -> void:
	_clear_satellites()
	var offset_step = 2 * PI / max(1, number)
	var runtime_damage: int = get_runtime_shot_damage()
	var damage_multiplier: float = 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		damage_multiplier = maxf(branch_behavior.get_projectile_damage_multiplier(), 0.05)
	var damage_type: StringName = Attack.TYPE_PHYSICAL
	if branch_behavior and is_instance_valid(branch_behavior) and branch_behavior.has_method("get_damage_type_override"):
		damage_type = Attack.normalize_damage_type(branch_behavior.call("get_damage_type_override"))
	var effective_spin_speed: float = _get_effective_orbit_spin_speed()
	for n in range(number):
		var spawn_projectile = spawn_projectile_from_scene(projectile_template)
		if spawn_projectile == null:
			continue
		spawn_projectile.damage = max(1, int(round(float(runtime_damage) * damage_multiplier)))
		spawn_projectile.damage_type = damage_type
		spawn_projectile.hp = 99999
		spawn_projectile.expire_time = 99999
		spawn_projectile.size = size
		spawn_projectile.projectile_texture = projectile_texture_resource
		apply_rotate_around_player(spawn_projectile, offset_step, n, effective_spin_speed)
		apply_effects_on_projectile(spawn_projectile)
		get_tree().root.call_deferred("add_child", spawn_projectile)
		satellites.append(spawn_projectile)

func _update_satellite_runtime_state() -> void:
	var runtime_damage: int = get_runtime_shot_damage()
	var damage_multiplier: float = 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		damage_multiplier = maxf(branch_behavior.get_projectile_damage_multiplier(), 0.05)
	var damage_type: StringName = Attack.TYPE_PHYSICAL
	if branch_behavior and is_instance_valid(branch_behavior) and branch_behavior.has_method("get_damage_type_override"):
		damage_type = Attack.normalize_damage_type(branch_behavior.call("get_damage_type_override"))
	var effective_spin_speed: float = _get_effective_orbit_spin_speed()
	for item in satellites:
		var satellite: Projectile = item as Projectile
		if satellite == null or not is_instance_valid(satellite):
			continue
		satellite.damage = max(1, int(round(float(runtime_damage) * damage_multiplier)))
		satellite.damage_type = damage_type
		var rotate_effect: RotateAroundPlayer = _find_rotate_module(satellite)
		if rotate_effect != null and is_instance_valid(rotate_effect):
			rotate_effect.spin_speed = effective_spin_speed

func _find_rotate_module(satellite: Projectile) -> RotateAroundPlayer:
	for module_item in satellite.module_list:
		var rotate_effect: RotateAroundPlayer = module_item as RotateAroundPlayer
		if rotate_effect != null and is_instance_valid(rotate_effect):
			return rotate_effect
	return null

func _clear_satellites() -> void:
	for s in satellites:
		if s and is_instance_valid(s):
			s.queue_free()
	satellites.clear()

func _process_offhand_main_weapon_buff() -> void:
	var now_msec := Time.get_ticks_msec()
	if _buff_target != null and is_instance_valid(_buff_target) and now_msec >= _offhand_buff_expires_at_msec:
		_buff_target.set_external_attack_speed_multiplier(1.0)
		_buff_target = null
	if now_msec < _next_offhand_apply_msec:
		return
	_next_offhand_apply_msec = now_msec + int(maxf(offhand_buff_icd_sec, 0.05) * 1000.0)
	var main_weapon := _resolve_main_weapon()
	if main_weapon == null:
		return
	if _buff_target != main_weapon:
		_clear_offhand_main_buff()
		_buff_target = main_weapon
	_buff_target.set_external_attack_speed_multiplier(maxf(offhand_main_attack_speed_mult, 1.0))
	_offhand_buff_expires_at_msec = now_msec + int(maxf(offhand_buff_duration_sec, 0.05) * 1000.0)
	passive_triggered.emit(&"offhand_orbit_attack_speed", {
		"multiplier": offhand_main_attack_speed_mult,
		"duration": offhand_buff_duration_sec
	})

func _resolve_main_weapon() -> Ranger:
	if PlayerData.player_weapon_list.is_empty():
		return null
	PlayerData.sanitize_main_weapon_index()
	var idx := PlayerData.main_weapon_index
	if idx < 0 or idx >= PlayerData.player_weapon_list.size():
		return null
	var weapon: Variant = PlayerData.player_weapon_list[idx]
	if weapon == self:
		return null
	if weapon is Ranger:
		return weapon as Ranger
	return null

func _clear_offhand_main_buff() -> void:
	if _buff_target != null and is_instance_valid(_buff_target):
		_buff_target.set_external_attack_speed_multiplier(1.0)
	_buff_target = null
	_offhand_buff_expires_at_msec = 0

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_target_hit(target)

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if branch_behavior and is_instance_valid(branch_behavior) and branch_behavior.has_method("on_passive_event"):
		branch_behavior.call("on_passive_event", event_name, detail)

func get_satellites() -> Array[Node2D]:
	var valid_satellites: Array[Node2D] = []
	for item in satellites:
		var satellite: Node2D = item as Node2D
		if satellite == null or not is_instance_valid(satellite):
			continue
		valid_satellites.append(satellite)
	return valid_satellites

func _get_branch_spin_speed_multiplier() -> float:
	if branch_behavior == null or not is_instance_valid(branch_behavior):
		return 1.0
	if not branch_behavior.has_method("get_orbit_spin_speed_multiplier"):
		return 1.0
	return maxf(float(branch_behavior.call("get_orbit_spin_speed_multiplier")), 0.05)

func _get_effective_orbit_spin_speed() -> float:
	var role_multiplier: float = 1.0 if is_main_weapon() else maxf(offhand_spin_speed_multiplier, 0.05)
	return spin_speed * _get_branch_spin_speed_multiplier() * role_multiplier
