extends Ranger

var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")

var ITEM_NAME := "Zero Cannon"
const BULLET_PIXEL_SIZE := Vector2(12.0, 12.0)
const DAMAGE_STATE_META := &"_incoming_damage_state"

@export var execute_burst_ratio: float = 0.70
@export var execute_trigger_cooldown_sec: float = 2.0

var attack_range: float = 980.0
var _execute_ready_at_msec: Dictionary = {}

var weapon_data := {
	"1": {"level": "1", "damage": "52", "speed": "1050", "hp": "1", "reload": "1.333", "range": "900", "cost": "13"},
	"2": {"level": "2", "damage": "62", "speed": "1080", "hp": "1", "reload": "1.282", "range": "920", "cost": "13"},
	"3": {"level": "3", "damage": "74", "speed": "1110", "hp": "2", "reload": "1.220", "range": "940", "cost": "13"},
	"4": {"level": "4", "damage": "88", "speed": "1140", "hp": "2", "reload": "1.163", "range": "960", "cost": "13"},
	"5": {"level": "5", "damage": "104", "speed": "1180", "hp": "2", "reload": "1.111", "range": "980", "cost": "13"},
}

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
	if not target.has_meta(DAMAGE_STATE_META):
		return
	var state_variant: Variant = target.get_meta(DAMAGE_STATE_META, {})
	if not (state_variant is Dictionary):
		return
	var state: Dictionary = state_variant
	var recorded_energy_damage: int = max(0, int(state.get("energy_damage_recorded", 0)))
	if recorded_energy_damage <= 0:
		return
	var hp_value: Variant = target.get("hp")
	if hp_value == null:
		return
	var target_hp: int = int(hp_value)
	if target_hp >= recorded_energy_damage:
		return
	var target_id: int = target.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var ready_msec: int = int(_execute_ready_at_msec.get(target_id, 0))
	if now_msec < ready_msec:
		return
	_execute_ready_at_msec[target_id] = now_msec + int(maxf(execute_trigger_cooldown_sec, 0.1) * 1000.0)

	var burst_damage: int = max(1, int(round(float(recorded_energy_damage) * maxf(execute_burst_ratio, 0.0))))
	var burst_data: DamageData = DamageManager.build_damage_data(
		self,
		burst_damage,
		Attack.TYPE_ENERGY
	)
	if DamageManager.apply_to_target(target, burst_data):
		var owner_player: Player = burst_data.source_player as Player
		if owner_player and is_instance_valid(owner_player):
			owner_player.apply_bonus_hit_if_needed(target)

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "52", "speed": "1050", "hp": "1", "reload": "1.333", "range": "900", "cost": "13"}
