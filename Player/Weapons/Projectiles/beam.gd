extends Node2D

@onready var raycast = $RayCast2D
@onready var line = $RayCast2D/Line2D
@onready var expire_timer = $ExpireTimer

var target_position : Vector2 = Vector2.ZERO

var attack : Attack
var damage = 1
var beam_owner
var source_weapon: Weapon

var frame_counter = 0
var frames_until_show = 1

var beam_start_position : Vector2 = Vector2.ZERO
var oc_mode : bool = false
var beam_width_multiplier: float = 1.0
var beam_tag: String = "main"
var _hybrid_registered: bool = false
@export_range(0.01, 0.12, 0.005) var damage_tick_interval_sec: float = 0.03
var _elapsed_sec: float = 0.0
var _last_damage_tick_by_target: Dictionary = {}

func configure_laser_beam(profile: Dictionary) -> void:
	beam_width_multiplier = maxf(float(profile.get("width_multiplier", 1.0)), 0.05)
	beam_tag = str(profile.get("beam_tag", "main"))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	line.add_to_group(&"hybrid_ground_segment")
	line.set_meta("hybrid_ground_visible", false)
	line.set_meta("hybrid_segment_style", &"beam")
	line.set_meta("hybrid_segment_endpoints", true)
	call_deferred("_register_hybrid_segment")
	if oc_mode:
		expire_timer.wait_time = 5
	expire_timer.start()
	raycast.enabled = true
	raycast.target_position = 42 * target_position
	line.width = maxf(line.width * beam_width_multiplier, 1.0)
	if beam_tag.contains("focus"):
		line.default_color = Color(0.45, 0.95, 1.0, 1.0)
	elif beam_tag.contains("prism_side"):
		line.default_color = Color(0.85, 0.55, 1.0, 0.9)

func _register_hybrid_segment() -> void:
	_hybrid_registered = HybridGroundRegistration.register(line, &"register_ground_segment")
	if _hybrid_registered:
		line.visible = false

func _physics_process(delta: float) -> void:
	_elapsed_sec += maxf(delta, 0.0)
	frame_counter += 1
	if frame_counter > frames_until_show:
		line.set_meta("hybrid_ground_visible", true)
		line.visible = not bool(line.get_meta(&"hybrid_ground_registered", false))
	if oc_mode and PlayerData.cloestest_enemy != null:
		raycast.target_position = to_local(PlayerData.cloestest_enemy.global_position)
		beam_start_position = to_local(beam_owner.global_position)
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		var collider = raycast.get_collider()
		line.points = [beam_start_position, to_local(collision_point)]
		if collider is HurtBox:
			var target: Node = collider.get_damage_target() if collider.has_method("get_damage_target") else collider.get_owner()
			if target == null or not is_instance_valid(target):
				return
			var target_id := target.get_instance_id()
			var tick_interval := maxf(damage_tick_interval_sec, 0.01)
			var current_tick := int(floor(_elapsed_sec / tick_interval))
			if int(_last_damage_tick_by_target.get(target_id, -1)) == current_tick:
				return
			_last_damage_tick_by_target[target_id] = current_tick
			var damage_data := DamageManager.build_damage_data(
				self,
				int(damage),
				Attack.TYPE_ENERGY,
				{},
				DamageData.SOURCE_PLAYER_WEAPON,
				DamageDeliveryType.BEAM
			)
			DamageManager.apply_to_target(target, damage_data)
			var owner_player := damage_data.source_player as Player
			if owner_player and is_instance_valid(owner_player):
				owner_player.apply_bonus_hit_if_needed(target)
			if source_weapon and is_instance_valid(source_weapon):
				source_weapon.on_hit_target_with_damage_type(target, Attack.TYPE_ENERGY)
	else:
		line.points = [beam_start_position, to_local(raycast.target_position)]

func _on_expire_timer_timeout() -> void:
	self.call_deferred("queue_free")

func _exit_tree() -> void:
	if line != null:
		HybridGroundRegistration.unregister(line)
	_hybrid_registered = false
