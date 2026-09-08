extends Node2D

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")

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
var _flow: Node2D

func configure_laser_beam(profile: Dictionary) -> void:
	beam_width_multiplier = maxf(float(profile.get("width_multiplier", 1.0)), 0.05)
	beam_tag = str(profile.get("beam_tag", "main"))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_flow = preload("res://Player/Weapons/Effects/beam_flow_visual.gd").new()
	add_child(_flow)
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	line.add_to_group(&"hybrid_ground_segment")
	line.set_meta("hybrid_ground_visible", false)
	line.set_meta("hybrid_segment_style", &"beam")
	line.set_meta("hybrid_segment_endpoints", true)
	call_deferred("_register_hybrid_segment")
	if oc_mode:
		expire_timer.wait_time = 5
	expire_timer.start()
	raycast.enabled = true
	raycast.target_position = target_position
	line.width = maxf(line.width * beam_width_multiplier, 1.0)
	if beam_tag.contains("focus"):
		line.default_color = Color(PALETTE.PLAYER_PRIMARY, 0.78)
	elif beam_tag.contains("prism_side"):
		line.default_color = Color(PALETTE.ENERGY, 0.78)

func cleanup_for_battle_end() -> void:
	queue_free()

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
	var beam_hit := _find_nearest_wide_beam_hit()
	if beam_hit.is_empty():
		line.points = [beam_start_position, raycast.target_position]
		_sync_flow()
		return
	var hit_local_position: Vector2 = beam_hit["local_position"]
	line.points = [beam_start_position, hit_local_position]
	_sync_flow()
	_apply_beam_tick(beam_hit["target"] as Node)

func _sync_flow() -> void:
	_flow.set("start", to_global(line.points[0]))
	_flow.set("finish", to_global(line.points[1]))
	_flow.set("active", frame_counter > frames_until_show)

func get_presentation_contact_position() -> Vector2:
	return to_global(line.points[1]) if line.points.size() > 1 else global_position

func _find_nearest_wide_beam_hit() -> Dictionary:
	if not is_inside_tree():
		return {}
	var local_start: Vector2 = beam_start_position
	var local_end: Vector2 = raycast.target_position
	var local_segment: Vector2 = local_end - local_start
	var length: float = local_segment.length()
	if length <= 0.01:
		return {}
	var global_start: Vector2 = to_global(local_start)
	var global_end: Vector2 = to_global(local_end)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, maxf(line.width, 1.0))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D((global_end - global_start).angle(), global_start.lerp(global_end, 0.5))
	query.collision_mask = raycast.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var nearest_target: Node2D
	var nearest_projection: float = INF
	var seen_targets: Dictionary = {}
	var direction: Vector2 = (global_end - global_start).normalized()
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var collider: Variant = hit.get("collider", null)
		if not collider is HurtBox:
			continue
		var target_node: Node = collider.get_damage_target() if collider.has_method("get_damage_target") else collider.get_owner()
		if target_node == null or not is_instance_valid(target_node) or not target_node is Node2D:
			continue
		var target := target_node as Node2D
		var target_id := target.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true
		var projection := clampf((target.global_position - global_start).dot(direction), 0.0, length)
		if projection < nearest_projection:
			nearest_projection = projection
			nearest_target = target
	if nearest_target == null:
		return {}
	return {
		"target": nearest_target,
		"local_position": to_local(global_start + direction * nearest_projection),
	}

func _apply_beam_tick(target: Node) -> void:
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

func _on_expire_timer_timeout() -> void:
	self.call_deferred("queue_free")

func _exit_tree() -> void:
	if line != null:
		HybridGroundRegistration.unregister(line)
	_hybrid_registered = false
