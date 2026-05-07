extends Ranger

# Projectile
@onready var beam = preload("res://Player/Weapons/Projectiles/beam.tscn")

@onready var detect_area: Area2D = $DetectArea
@onready var oc_timer: Timer = $OCTimer

# Weapon
var ITEM_NAME = "Laser"
@export var focus_channel_trigger_sec: float = 0.6
@export var focus_channel_break_tolerance_sec: float = 0.25
var _focus_channel_target_id: int = 0
var _focus_channel_accum_sec: float = 0.0
var _focus_channel_last_hit_sec: float = -999.0

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "3",
		"fire_interval_sec": "2",
		"ammo": "45",
		"cost": "5",
	},
	"2": {
		"level": "2",
		"damage": "4",
		"fire_interval_sec": "1.6",
		"ammo": "50",
		"cost": "5",
	},
	"3": {
		"level": "3",
		"damage": "6",
		"fire_interval_sec": "1.1",
		"ammo": "55",
		"cost": "5",
	},
	"4": {
		"level": "4",
		"damage": "7",
		"fire_interval_sec": "0.8",
		"ammo": "60",
		"cost": "5",
	},
	"5": {
		"level": "5",
		"damage": "8",
		"fire_interval_sec": "0.6",
		"ammo": "65",
		"cost": "5",
	},
	"6": {
		"level": "6",
		"damage": "9",
		"fire_interval_sec": "0.5",
		"ammo": "70",
		"cost": "5",
	},
	"7": {
		"level": "7",
		"damage": "10",
		"fire_interval_sec": "0.45",
		"ammo": "75",
		"cost": "5",
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])

	base_attack_cooldown = float(weapon_data[lv]["fire_interval_sec"])
	apply_level_ammo(weapon_data[lv])
	sync_stats()

func _on_shoot():
	var beam_ins = beam.instantiate()
	beam_ins.global_position = self.global_position
	beam_ins.target_position = get_global_mouse_position() - self.global_position
	beam_ins.damage = get_runtime_shot_damage()
	beam_ins.source_weapon = self
	self.get_tree().root.call_deferred("add_child",beam_ins)
	is_on_cooldown = true
	cooldown_timer.start()


func _on_oc_timer_timeout() -> void:
	remove_weapon()

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	_try_trigger_focus_channel(target)

func _try_trigger_focus_channel(target: Node) -> void:
	if not is_main_weapon():
		_reset_focus_channel()
		return
	if target == null or not is_instance_valid(target):
		_reset_focus_channel()
		return
	if not is_offhand_skill_ready():
		return
	var now_sec := Time.get_ticks_msec() / 1000.0
	var target_id := target.get_instance_id()
	var gap_sec := now_sec - _focus_channel_last_hit_sec
	if _focus_channel_target_id == target_id and gap_sec <= maxf(focus_channel_break_tolerance_sec, 0.0):
		_focus_channel_accum_sec += maxf(gap_sec, 0.0)
	else:
		_focus_channel_target_id = target_id
		_focus_channel_accum_sec = 0.0
	_focus_channel_last_hit_sec = now_sec
	if _focus_channel_accum_sec < maxf(focus_channel_trigger_sec, 0.1):
		return
	_reset_focus_channel()
	notify_offhand_skill_triggered(0.0)
	emit_passive_trigger(&"laser_focus_channel_triggered", {
		"target": target,
		"duration": maxf(focus_channel_trigger_sec, 0.1),
		"break_tolerance": maxf(focus_channel_break_tolerance_sec, 0.0),
		"refresh": "reload",
	}, PASSIVE_SCOPE_GLOBAL)

func _reset_focus_channel() -> void:
	_focus_channel_target_id = 0
	_focus_channel_accum_sec = 0.0
	_focus_channel_last_hit_sec = -999.0
