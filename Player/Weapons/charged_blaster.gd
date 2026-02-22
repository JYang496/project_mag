extends Ranger

# Bullet
@onready var beam_blast = preload("res://Player/Weapons/Bullets/beam_blast.tscn")

# Weapon
var ITEM_NAME = "Beam Blaster"
var hit_cd : float
var duration : float
var charge_level :int
var charge_time : float = 0.0
var time_per_level : float = 1.0
var max_charge_level : int
var beam_range : float = 450.0
var beam_local_forward := Vector2.UP
var normal_turn_speed := 12.0
var firing_turn_speed := 1.2
var is_firing_beam := false
var firing_turn_timer: Timer

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "3",
		"hit_cd": "0.2",
		"reload": "5",
		"duration": "3.0",
		"max_charge_level": "2",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "4",
		"hit_cd": "0.2",
		"reload": "5",
		"duration": "3.0",
		"max_charge_level": "2",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "4",
		"hit_cd": "0.15",
		"reload": "5",
		"duration": "3.0",
		"max_charge_level": "3",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "5",
		"hit_cd": "0.15",
		"reload": "5",
		"duration": "3.0",
		"max_charge_level": "3",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "6",
		"hit_cd": "0.15",
		"reload": "5",
		"duration": "3.90",
		"max_charge_level": "3",
		"cost": "1",
		"features": [],
	},
}


func _physics_process(delta):
	_update_smoothed_rotation(delta)
	if not is_on_cooldown:
		if Input.is_action_pressed("ATTACK"):
			charge_time += delta
			if charge_time >= time_per_level:
				charge_level = clampi(charge_level + 1, 0, max_charge_level)
				charge_time -= time_per_level
				if charge_level >= max_charge_level:
					emit_signal("shoot")
					charge_time = 0.0
		if Input.is_action_just_released("ATTACK"):
			emit_signal("shoot")

func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	hit_cd = float(weapon_data[lv]["hit_cd"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	duration = float(weapon_data[lv]["duration"])
	max_charge_level = int(weapon_data[lv]["max_charge_level"])
	sync_stats()
	for feature in weapon_data[lv]["features"]:
		if not weapon_features.has(feature):
			weapon_features.append(feature)

func _on_shoot():
	if charge_level < 1 or is_on_cooldown:
		return
	is_on_cooldown = true
	var beam_blast_ins = beam_blast.instantiate()
	# Beam direction is fixed to weapon local forward so it always fires from gun orientation.
	beam_blast_ins.target_position = beam_local_forward.normalized() * beam_range
	beam_blast_ins.width = charge_level * 6
	beam_blast_ins.damage = damage * charge_level
	beam_blast_ins.duration = duration
	beam_blast_ins.hit_cd = hit_cd
	beam_blast_ins.source_weapon = self
	call_deferred("add_child",beam_blast_ins)
	_start_firing_turn_slowdown(duration)
	charge_level = 0
	cooldown_timer.start()

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	charge_level = max_charge_level *2
	duration *= 2
	emit_signal("shoot")
	var remove_timer = Timer.new()
	remove_timer.wait_time = duration
	remove_timer.one_shot = true
	remove_timer.connect("timeout",Callable(self,"_on_remove_timer_timeout"))
	self.add_child(remove_timer)
	remove_timer.start()

func _on_remove_timer_timeout() -> void:
	remove_weapon()

func _on_charged_blast_timer_timeout() -> void:
	is_on_cooldown = false


func _update_smoothed_rotation(delta: float) -> void:
	var mouse_direction := get_global_mouse_position() - global_position
	if mouse_direction == Vector2.ZERO:
		return
	var target_rotation := mouse_direction.angle() + AIM_ROTATION_OFFSET
	var turn_speed := firing_turn_speed if is_firing_beam else normal_turn_speed
	rotation = lerp_angle(rotation, target_rotation, clamp(turn_speed * delta, 0.0, 1.0))


func _start_firing_turn_slowdown(active_duration: float) -> void:
	is_firing_beam = true
	if firing_turn_timer == null:
		firing_turn_timer = Timer.new()
		firing_turn_timer.one_shot = true
		firing_turn_timer.timeout.connect(_on_firing_turn_timeout)
		add_child(firing_turn_timer)
	firing_turn_timer.wait_time = max(active_duration, 0.01)
	firing_turn_timer.start()


func _on_firing_turn_timeout() -> void:
	is_firing_beam = false
