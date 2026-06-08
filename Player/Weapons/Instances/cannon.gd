extends Ranger
class_name Cannon

var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")
var area_effect_scene: PackedScene = preload("res://Utility/area_effect/area_effect.tscn")

var ITEM_NAME := "Cannon"
const BULLET_PIXEL_SIZE := Vector2(11.0, 11.0)

@export var windup_sec: float = 0.15
@export var idle_fire_trigger_sec: float = 6.0
@export var idle_fire_empowered_shots: int = 3
@export var idle_fire_attack_speed_multiplier: float = 3.0
@export var idle_fire_aoe_radius: float = 160.0
@export var idle_fire_aoe_damage_ratio: float = 0.5
@export var idle_fire_aoe_duration: float = 0.14
var attack_range: float = 920.0
var _windup_in_progress: bool = false
var _idle_fire_ready: bool = false
var _idle_fire_reload_ready: bool = true
var _idle_fire_empowered_shots_remaining: int = 0
var _idle_fire_aoe_sequence: int = 0

var weapon_data := {
	"1": {"damage": "50", "speed": "1120", "projectile_hits": "2", "fire_interval_sec": "1.667", "ammo": "6"},
	"2": {"damage": "60", "speed": "1140", "projectile_hits": "2", "fire_interval_sec": "1.600", "ammo": "6"},
	"3": {"damage": "67", "speed": "1170", "projectile_hits": "2", "fire_interval_sec": "1.533", "ammo": "9"},
	"4": {"damage": "80", "speed": "1200", "projectile_hits": "2", "fire_interval_sec": "1.467", "ammo": "9"},
	"5": {"damage": "100", "speed": "1230", "projectile_hits": "2", "fire_interval_sec": "1.400", "ammo": "12"},
	"6": {"damage": "120", "speed": "1260", "projectile_hits": "2", "fire_interval_sec": "1.333", "ammo": "12"},
	"7": {"damage": "140", "speed": "1290", "projectile_hits": "3", "fire_interval_sec": "1.267", "ammo": "12"},
	"8": {"damage": "160", "speed": "1320", "projectile_hits": "4", "fire_interval_sec": "1.201", "ammo": "12"},
	"9": {"damage": "180", "speed": "1350", "projectile_hits": "5", "fire_interval_sec": "1.135", "ammo": "12"}
}

@onready var windup_timer: Timer = $WindupTimer
@onready var idle_fire_timer: Timer = $IdleFireTimer

func _ready() -> void:
	super._ready()
	_setup_idle_fire_timer()

func set_level(lv) -> void:
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["projectile_hits"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)

func request_primary_fire() -> bool:
	if not is_attack_phase_allowed():
		return false
	if is_on_cooldown or _windup_in_progress:
		return false
	if not can_fire_with_heat():
		return false
	if not can_fire_with_ammo():
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
		return false
	if not consume_ammo(1):
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
		return false
	if windup_sec <= 0.0:
		emit_signal("shoot")
		notify_main_weapon_fired()
		register_shot_heat()
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
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
	notify_main_weapon_fired()
	register_shot_heat()
	if uses_ammo_system() and current_ammo <= 0:
		request_reload()

func _on_shoot() -> void:
	is_on_cooldown = true
	var idle_triggered := _try_emit_idle_fire_trigger()
	if not idle_triggered:
		_restart_idle_fire_timer()
	var idle_empowered_shot := _consume_idle_empowered_shot()
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	if idle_empowered_shot:
		cooldown /= maxf(idle_fire_attack_speed_multiplier, 0.05)
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()

	var spawn_projectile := spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return

	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	var runtime_damage := get_runtime_shot_damage()
	var damage_multiplier := branch_runtime.get_branch_projectile_damage_multiplier()
	damage_multiplier *= _consume_branch_heat_spend_multiplier()
	spawn_projectile.damage = max(1, int(round(float(runtime_damage) * damage_multiplier)))
	var damage_type: StringName = branch_runtime.get_branch_damage_type_override(Attack.TYPE_PHYSICAL)
	spawn_projectile.damage_type = damage_type
	spawn_projectile.hp = max(1, projectile_hits)
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.2)
	if idle_empowered_shot:
		spawn_projectile.set_meta("cannon_idle_empowered", true)
		spawn_projectile.set_meta("cannon_idle_aoe_radius", maxf(idle_fire_aoe_radius, 1.0))
		spawn_projectile.set_meta("cannon_idle_aoe_damage_ratio", maxf(idle_fire_aoe_damage_ratio, 0.0))
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func _consume_branch_heat_spend_multiplier() -> float:
	var multiplier := 1.0
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior == null or not is_instance_valid(behavior):
			continue
		if behavior.has_method("consume_heat_spend_multiplier"):
			multiplier *= maxf(float(behavior.call("consume_heat_spend_multiplier")), 0.05)
	return maxf(multiplier, 0.05)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	branch_runtime.notify_branch_target_hit(target)

func on_projectile_hit_damage_dealt(projectile: Node, target: Node, hit_damage_type: StringName, final_damage: int) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if not bool(projectile.get_meta("cannon_idle_empowered", false)):
		return
	if target == null or not is_instance_valid(target):
		return
	if final_damage <= 0:
		return
	_apply_idle_fire_aoe(projectile, target, hit_damage_type, final_damage)

func _on_cooldown_timer_timeout() -> void:
	is_on_cooldown = false
	_windup_in_progress = false

func _setup_idle_fire_timer() -> void:
	if idle_fire_timer == null:
		return
	idle_fire_timer.one_shot = true
	if not idle_fire_timer.timeout.is_connected(Callable(self, "_on_idle_fire_timer_timeout")):
		idle_fire_timer.timeout.connect(Callable(self, "_on_idle_fire_timer_timeout"))
	_restart_idle_fire_timer()

func _restart_idle_fire_timer() -> void:
	_idle_fire_ready = false
	if not _idle_fire_reload_ready:
		return
	if idle_fire_timer == null:
		return
	idle_fire_timer.stop()
	idle_fire_timer.wait_time = maxf(idle_fire_trigger_sec, 0.1)
	idle_fire_timer.start()

func _on_idle_fire_timer_timeout() -> void:
	if not _idle_fire_reload_ready:
		return
	_idle_fire_ready = true

func _try_emit_idle_fire_trigger() -> bool:
	if not _idle_fire_reload_ready:
		return false
	if not _idle_fire_ready:
		return false
	_idle_fire_ready = false
	_idle_fire_reload_ready = false
	_idle_fire_empowered_shots_remaining = maxi(1, idle_fire_empowered_shots)
	if idle_fire_timer != null:
		idle_fire_timer.stop()
	emit_passive_trigger(&"cannon_idle_fire_triggered", {
		"duration": maxf(idle_fire_trigger_sec, 0.1),
		"trigger": "next_cannon_fire_after_idle",
		"refresh": "reload",
		"empowered_shots": maxi(1, idle_fire_empowered_shots),
		"attack_speed_multiplier": maxf(idle_fire_attack_speed_multiplier, 0.05),
		"aoe_radius": maxf(idle_fire_aoe_radius, 1.0),
		"aoe_damage_ratio": maxf(idle_fire_aoe_damage_ratio, 0.0),
	}, PASSIVE_SCOPE_BODY)
	return true

func _consume_idle_empowered_shot() -> bool:
	if _idle_fire_empowered_shots_remaining <= 0:
		return false
	_idle_fire_empowered_shots_remaining -= 1
	return true

func _apply_idle_fire_aoe(projectile: Node, direct_target: Node, hit_damage_type: StringName, direct_final_damage: int) -> void:
	var direct_node := direct_target as Node2D
	if direct_node == null:
		return
	var radius: float = maxf(float(projectile.get_meta("cannon_idle_aoe_radius", idle_fire_aoe_radius)), 1.0)
	var damage_ratio: float = maxf(float(projectile.get_meta("cannon_idle_aoe_damage_ratio", idle_fire_aoe_damage_ratio)), 0.0)
	var aoe_damage: int = maxi(1, int(round(float(direct_final_damage) * damage_ratio)))
	var center: Vector2 = direct_node.global_position
	_spawn_idle_fire_aoe_visual(center, radius)
	_idle_fire_aoe_sequence += 1
	var aoe_id := _idle_fire_aoe_sequence
	for enemy in WeaponModuleRuntimeUtils.get_nearby_enemies(get_tree(), center, radius):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy == direct_target:
			continue
		_apply_idle_fire_aoe_damage(enemy, aoe_damage, hit_damage_type, aoe_id)

func _apply_idle_fire_aoe_damage(target: Node, amount: int, hit_damage_type: StringName, aoe_id: int) -> void:
	var damage_data := DamageManager.build_damage_data(
		self,
		max(1, amount),
		Attack.normalize_damage_type(hit_damage_type),
		{
			"amount": 0,
			"angle": Vector2.ZERO,
		}
	)
	damage_data.dedupe_token = StringName("cannon_idle_aoe_%d_%d_%d" % [
		get_instance_id(),
		aoe_id,
		target.get_instance_id(),
	])
	damage_data.dedupe_window_sec = 0.05
	DamageManager.apply_to_target(target, damage_data)

func _spawn_idle_fire_aoe_visual(position_value: Vector2, radius: float) -> void:
	if area_effect_scene == null:
		return
	var area_effect := area_effect_scene.instantiate() as AreaEffect
	if area_effect == null:
		return
	area_effect.radius = maxf(radius, 1.0)
	area_effect.duration = maxf(idle_fire_aoe_duration, 0.01)
	area_effect.one_shot_damage = 0
	area_effect.tick_damage = 0
	area_effect.apply_once_per_target = true
	area_effect.target_group = AreaEffect.TargetGroup.ENEMIES
	area_effect.source_node = self
	area_effect.draw_enabled = true
	area_effect.debug_fill_color = Color(1.0, 0.35, 0.12, 0.16)
	area_effect.debug_line_color = Color(1.0, 0.75, 0.25, 0.9)
	area_effect.debug_line_width = 3.0
	area_effect.global_position = position_value
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_tree().root
	spawn_parent.call_deferred("add_child", area_effect)

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if event_name != &"on_reload_finished":
		return
	if detail.get("source_weapon", null) != self:
		return
	_idle_fire_empowered_shots_remaining = 0
	_idle_fire_reload_ready = true
	_restart_idle_fire_timer()

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_idle_fire_empowered_shots_remaining = 0
	_idle_fire_reload_ready = true
	_restart_idle_fire_timer()

func _get_level_data(lv: String) -> Dictionary:
	return get_weapon_level_data(lv, weapon_data)
