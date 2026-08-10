extends BaseNPC
class_name BaseEnemy

const SPAWN_TAG_RANGED := &"ranged"
const SPAWN_TAG_ELITE := &"elite"
const SPAWN_TAG_SUPPORT := &"support"
const SPAWN_TAG_INTERCEPTOR := &"interceptor"
const QUEST_OUTLINE_SHADER: Shader = preload("res://Shaders/quest_outline.gdshader") as Shader
const ENEMY_SPAWN_SEQUENCE_SCRIPT := preload("res://Npc/enemy/components/enemy_spawn_sequence.gd")
const BOSS_VISUAL_RUNTIME_SCRIPT := preload("res://Npc/enemy/components/boss_visual_runtime.gd")
const SHADOW_WIDTH_MULTIPLIER: float = 1.10
const SHADOW_DEPTH_MULTIPLIER: float = 0.45
const SHADOW_SIZE_MIN := Vector2(20.0, 9.0)
const SHADOW_SIZE_MAX := Vector2(52.0, 24.0)

@export var damage := 0
@export var is_boss: bool = false
@export_enum("melee", "ranged") var combat_role: String = "melee"
@export var loot_value_multiplier: float = 1.0
@export_group("Spawn Metadata")
@export var spawn_cost: int = 3
@export var spawn_tags: Array[StringName] = []
@export var spawn_alive_cap: int = 0
@export var spawn_batch_cap: int = 0
@export_group("Support")
@export var support_role: StringName = &""
@export_group("")
@export_group("Crowd Motion")
@export_range(0.0, 30.0, 0.5) var crowd_lateral_speed: float = 6.0
@export_range(0.0, 96.0, 1.0) var separation_radius: float = 48.0
@export_range(0.0, 80.0, 1.0) var separation_speed: float = 36.0
@export_range(1, 24, 1) var separation_max_neighbors: int = 12
@export_range(0.02, 0.2, 0.01) var separation_update_interval: float = 0.05
@export_group("AI Distance LOD")
@export var ai_near_distance: float = 900.0
@export var ai_mid_distance: float = 1800.0
@export_range(10.0, 30.0, 1.0) var ai_mid_hz: float = 30.0
@export_range(5.0, 15.0, 1.0) var ai_far_hz: float = 12.0
@export var simplify_far_physics: bool = true
@export_group("")
signal enemy_death(was_killed: bool)
signal spawn_phase_started
signal spawn_phase_completed

@onready var enable_collision_timer: Timer = $EnableCollisionTimer
var stun_remaining: float:
	get: return movement_runtime.get_stun_remaining()
	set(value): movement_runtime.set_stun_remaining(value)
var slow_remaining: float:
	get: return movement_runtime.get_slow_remaining()
	set(value): movement_runtime.set_slow_remaining(value)
var slow_multiplier: float:
	get: return movement_runtime.get_current_slow_multiplier()
	set(value): movement_runtime.slow_multiplier = value
var _ranged_wander_dir: Vector2 = Vector2.ZERO
var _ranged_wander_time_left: float = 0.0
var _board_generator_ref: Node = null
var _constraint_pending_physics_tick: bool = true
var _constraint_cache_valid := false
var _constraint_cached_cell_id := -1
var _constraint_safe_rect := Rect2()
var _constraint_fast_accepts := 0
var _constraint_full_refreshes := 0
var _ai_tick_accumulator := 0.0
var _ai_tier_refresh_remaining := 0.0
var _ai_tick_interval := 0.0
var _ai_is_far_tier := false
var _ai_logic_ticks := 0
var _ai_cached_movement_ticks := 0
var _far_physics_simplified := false
var _far_area_monitoring_state: Array[Dictionary] = []
var _far_body_collision_mask := 0
var movement_runtime: EnemyMovementRuntime = EnemyMovementRuntime.new()
var death_runtime: EnemyDeathRuntime = EnemyDeathRuntime.new()
var _quest_lock_active := false
var _quest_lock_damage_mul := 1.0
var _quest_freeze_movement := false
var _quest_outline_enabled := false
var _quest_outline_original_material: Material
var _quest_outline_material: ShaderMaterial
var _support_damage_reduction_sources: Dictionary = {}
var _speed_bonus_sources: Dictionary = {}
var _slow_field_sources: Dictionary = {}
var _spawn_phase_active := false
var _spawn_sequence_duration_override := -1.0
var _spawn_previous_process_mode := Node.PROCESS_MODE_INHERIT
var _spawn_collision_state: Array[Dictionary] = []
var boss_visual_runtime: Node

func _init() -> void:
	super._init()
	movement_runtime.setup(self)
	death_runtime.setup(self)

func _enter_tree() -> void:
	var enemy_registry := get_node_or_null("/root/EnemyRegistry")
	if enemy_registry != null and enemy_registry.has_method("register_enemy"):
		enemy_registry.call("register_enemy", self)
	if _spawn_phase_active:
		call_deferred("_start_prepared_spawn_sequence")
	# Some specialized enemies override _ready() without calling the base
	# implementation. Defer visual anchoring so every inherited scene is covered.
	call_deferred("_sync_ground_identity_visuals")
	call_deferred("_register_central_simulation")

func _register_central_simulation() -> void:
	var simulation := get_node_or_null("/root/EnemySimulationSystem")
	if simulation != null and simulation.has_method("register_enemy"):
		simulation.call("register_enemy", self)

func uses_central_simulation() -> bool:
	return not (self is EliteEnemy) and not is_boss and not is_in_group(&"boss")

func simulation_physics_step(delta: float) -> void:
	# Specialized enemy scripts retain their authoritative behavior; only the
	# scheduling owner moves from N callbacks to this single system callback.
	call("_physics_process", delta)
	if _constraint_pending_physics_tick:
		_constraint_pending_physics_tick = false
	else:
		_constrain_to_board_traversable_area()

func _ready() -> void:
	_incoming_damage_max_hp = max(1, int(hp))
	_initialize_ai_lod_stagger()
	_sync_ground_identity_visuals()


func _sync_ground_identity_visuals() -> void:
	_ensure_boss_visual_runtime()
	var marker := get_node_or_null("AffiliationMarker") as Node2D
	var ground_shadow := get_node_or_null("GroundShadow") as Node2D
	var visual_extent := _resolve_hurtbox_or_visible_sprite_extent()
	if visual_extent == Vector2.ZERO:
		return
	if ground_shadow != null:
		var base_shadow_size := _get_polygon_visual_size(ground_shadow as Polygon2D)
		if base_shadow_size != Vector2.ZERO:
			var target_shadow_size := Vector2(
				roundf(clampf(visual_extent.x * SHADOW_WIDTH_MULTIPLIER, SHADOW_SIZE_MIN.x, SHADOW_SIZE_MAX.x)),
				roundf(clampf(visual_extent.y * SHADOW_DEPTH_MULTIPLIER, SHADOW_SIZE_MIN.y, SHADOW_SIZE_MAX.y))
			)
			ground_shadow.scale = target_shadow_size / base_shadow_size
		HybridGroundRegistration.register(ground_shadow, &"register_shadow")
	if marker != null and marker.has_method("sync_to_ground_shadow"):
		if "marker_rank" in marker:
			marker.set("marker_rank", 1 if has_spawn_tag(SPAWN_TAG_ELITE) or self is EliteEnemy else 0)
		marker.call("sync_to_ground_shadow")


func _ensure_boss_visual_runtime() -> void:
	if not is_boss or boss_visual_runtime != null or not is_inside_tree():
		return
	boss_visual_runtime = BOSS_VISUAL_RUNTIME_SCRIPT.new()
	boss_visual_runtime.name = "BossVisualRuntime"
	boss_visual_runtime.call("setup", self)
	add_child(boss_visual_runtime)


func begin_boss_attack_telegraph(duration_sec: float = 0.9) -> void:
	_ensure_boss_visual_runtime()
	if boss_visual_runtime != null:
		boss_visual_runtime.call("begin_attack_telegraph", duration_sec)


func is_boss_attack_damage_confirmed() -> bool:
	return boss_visual_runtime != null and bool(boss_visual_runtime.call("is_damage_confirmed"))


func set_boss_visual_phase(phase_index: int, phase_count: int) -> void:
	_ensure_boss_visual_runtime()
	if boss_visual_runtime != null:
		boss_visual_runtime.call("set_phase", phase_index, phase_count)


func begin_boss_death_release(duration_sec: float = 1.5) -> void:
	var duration := clampf(duration_sec, 1.2, 1.8)
	set_meta(&"boss_death_release_active", true)
	velocity = Vector2.ZERO
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for descendant in find_children("*", "CollisionObject2D", true, false):
		var collision_object := descendant as CollisionObject2D
		if collision_object != null:
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0
			if collision_object is Area2D:
				(collision_object as Area2D).monitoring = false
	var marker := get_node_or_null("AffiliationMarker") as CanvasItem
	if marker != null:
		marker.set_meta(&"hybrid_ground_visible", false)
	var body := sprite_body as Node2D
	if body != null:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_parallel(true)
		tween.tween_property(body, "modulate:a", 0.0, duration * 0.72).set_delay(duration * 0.18)
		tween.tween_property(body, "scale", body.scale * 0.78, duration * 0.82).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var release_timer := Timer.new()
	release_timer.name = "BossDeathReleaseTimer"
	release_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	release_timer.one_shot = true
	release_timer.wait_time = duration
	release_timer.timeout.connect(Callable(self, "queue_free"), CONNECT_ONE_SHOT)
	add_child(release_timer)
	release_timer.start()


func _resolve_hurtbox_or_visible_sprite_extent() -> Vector2:
	var collision := get_node_or_null("HurtBox/CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape != null:
		var shape_size := _get_collision_shape_size(collision.shape) * collision.scale.abs()
		if shape_size.x > 0.0 and shape_size.y > 0.0:
			return shape_size
	if sprite_body == null or sprite_body.texture == null:
		return Vector2.ZERO
	var image: Image = sprite_body.texture.get_image()
	if image == null or image.is_empty():
		return Vector2.ZERO
	var extra_scale := sprite_body.get("extra_scale") as Vector2
	return Vector2(image.get_used_rect().size) * extra_scale.abs()


func _get_collision_shape_size(shape: Shape2D) -> Vector2:
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size
	if shape is CircleShape2D:
		var diameter := (shape as CircleShape2D).radius * 2.0
		return Vector2(diameter, diameter)
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return Vector2(capsule.radius * 2.0, capsule.height)
	if shape is ConvexPolygonShape2D:
		var points := (shape as ConvexPolygonShape2D).points
		if not points.is_empty():
			var bounds := Rect2(points[0], Vector2.ZERO)
			for point in points:
				bounds = bounds.expand(point)
			return bounds.size
	return Vector2.ZERO


func _get_polygon_visual_size(polygon: Polygon2D) -> Vector2:
	if polygon == null or polygon.polygon.is_empty():
		return Vector2.ZERO
	var bounds := Rect2(polygon.polygon[0], Vector2.ZERO)
	for point in polygon.polygon:
		bounds = bounds.expand(point)
	return bounds.size

func _exit_tree() -> void:
	_set_far_physics_simplified(false)
	_disconnect_board_constraint_signals()
	var simulation := get_node_or_null("/root/EnemySimulationSystem")
	if simulation != null and simulation.has_method("unregister_enemy"):
		simulation.call("unregister_enemy", self)
	if damage_feedback != null:
		damage_feedback.shutdown()
	HybridGroundRegistration.unregister(self)
	var enemy_registry := get_node_or_null("/root/EnemyRegistry")
	if enemy_registry != null and enemy_registry.has_method("unregister_enemy"):
		enemy_registry.call("unregister_enemy", self)


func prepare_spawn_sequence(duration_override: float = -1.0) -> void:
	if _spawn_phase_active:
		return
	_spawn_phase_active = true
	_spawn_sequence_duration_override = duration_override
	_spawn_previous_process_mode = process_mode
	_capture_and_disable_spawn_collisions()
	velocity = Vector2.ZERO
	process_mode = Node.PROCESS_MODE_DISABLED
	if is_inside_tree():
		call_deferred("_start_prepared_spawn_sequence")


func _start_prepared_spawn_sequence() -> void:
	if not _spawn_phase_active or not is_inside_tree():
		return
	if get_node_or_null("EnemySpawnSequence") != null:
		return
	var sequence := ENEMY_SPAWN_SEQUENCE_SCRIPT.new()
	sequence.name = "EnemySpawnSequence"
	sequence.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sequence)
	sequence.begin(self, _spawn_sequence_duration_override)
	spawn_phase_started.emit()


func complete_spawn_sequence() -> void:
	if not _spawn_phase_active:
		return
	_restore_spawn_collisions()
	_spawn_phase_active = false
	_spawn_sequence_duration_override = -1.0
	process_mode = _spawn_previous_process_mode
	spawn_phase_completed.emit()


func is_spawn_phase_active() -> bool:
	return _spawn_phase_active


func _capture_and_disable_spawn_collisions() -> void:
	_spawn_collision_state.clear()
	var collision_objects: Array[CollisionObject2D] = [self]
	for descendant in find_children("*", "CollisionObject2D", true, false):
		var collision_object := descendant as CollisionObject2D
		if collision_object != null:
			collision_objects.append(collision_object)
	for collision_object in collision_objects:
		var state := {
			"node": collision_object,
			"collision_layer": collision_object.collision_layer,
			"collision_mask": collision_object.collision_mask,
		}
		if collision_object is Area2D:
			var area := collision_object as Area2D
			state["monitoring"] = area.monitoring
			state["monitorable"] = area.monitorable
			area.monitoring = false
			area.monitorable = false
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		_spawn_collision_state.append(state)


func _restore_spawn_collisions() -> void:
	for state in _spawn_collision_state:
		var collision_object := state.get("node") as CollisionObject2D
		if collision_object == null or not is_instance_valid(collision_object):
			continue
		collision_object.collision_layer = int(state.get("collision_layer", 0))
		collision_object.collision_mask = int(state.get("collision_mask", 0))
		if collision_object is Area2D:
			var area := collision_object as Area2D
			area.monitoring = bool(state.get("monitoring", false))
			area.monitorable = bool(state.get("monitorable", false))
	_spawn_collision_state.clear()

func _process(delta: float) -> void:
	if FixedObliqueProjectionType.is_enabled():
		z_index = int(round(FixedObliqueProjectionType.get_projected_depth(global_position) / 16.0))

func _notification(what: int) -> void:
	if what != NOTIFICATION_PHYSICS_PROCESS:
		return
	if _constraint_pending_physics_tick:
		_constraint_pending_physics_tick = false
		return
	_constrain_to_board_traversable_area()

func death(killing_attack: Attack = null) -> void:
	_before_death(killing_attack)
	death_runtime.finalize_death(killing_attack, _grants_standard_death_rewards())

func _before_death(_killing_attack: Attack) -> void:
	pass

func _grants_standard_death_rewards() -> bool:
	return true

func erase() -> void:
	enemy_death.emit(false)
	queue_free()

func _on_enable_collision_timer_timeout() -> void:
	self.set_collision_mask_value(6,true)
	# Enemy bodies pass through both players and other enemies. Player contact
	# damage is resolved centrally from HurtBox overlaps.
	self.set_collision_mask_value(1,false)
	self.set_collision_mask_value(3,false)

func register_hybrid_support_visuals() -> void:
	if not is_inside_tree():
		return
	HybridGroundRegistration.register(self, &"register_enemy_support_visual")

func uses_hybrid_ground_visuals() -> bool:
	return is_inside_tree() and not get_tree().get_nodes_in_group(&"hybrid_ground_view_3d").is_empty()

func apply_stun(duration: float) -> void:
	movement_runtime.apply_stun(duration)

func is_stunned() -> bool:
	return stun_remaining > 0.0

func apply_slow(multiplier: float, duration: float) -> void:
	movement_runtime.apply_slow(multiplier, duration)

func is_slowed() -> bool:
	return slow_remaining > 0.0 and slow_multiplier < 1.0

func get_current_movement_speed() -> float:
	if is_quest_movement_locked():
		return 0.0
	return movement_speed * slow_multiplier * _get_speed_bonus_multiplier() * _get_field_slow_multiplier()

func decay_knockback() -> void:
	knockback.amount = clampf(float(knockback.amount) - maxf(float(knockback_recover), 0.0), 0.0, float(knockback.amount))

func move_enemy(desired_velocity: Vector2, delta: float) -> void:
	movement_runtime.move_enemy(desired_velocity, delta)

func consume_ai_update_delta(delta: float) -> float:
	var safe_delta := maxf(delta, 0.0)
	_ai_tier_refresh_remaining -= safe_delta
	if _ai_tier_refresh_remaining <= 0.0:
		_ai_tier_refresh_remaining = 0.25
		_ai_tick_interval = _resolve_ai_tick_interval()
	_ai_tick_accumulator += safe_delta
	if _ai_tick_interval <= 0.0 or _ai_tick_accumulator + 0.00001 >= _ai_tick_interval:
		var accumulated := _ai_tick_accumulator
		_ai_tick_accumulator = 0.0
		_ai_logic_ticks += 1
		return accumulated
	return 0.0

func continue_lod_movement(delta: float) -> void:
	_ai_cached_movement_ticks += 1
	decay_knockback()
	if is_stunned() or is_quest_movement_locked():
		movement_runtime.move_enemy(Vector2.ZERO, delta)
		return
	movement_runtime.continue_cached_movement(delta)

func _resolve_ai_tick_interval() -> float:
	if self is EliteEnemy or is_boss or is_in_group("boss"):
		_ai_is_far_tier = false
		_set_far_physics_simplified(false)
		return 0.0
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		_ai_is_far_tier = true
		_set_far_physics_simplified(true)
		return 1.0 / maxf(ai_far_hz, 1.0)
	var distance_sq := global_position.distance_squared_to(PlayerData.player.global_position)
	if distance_sq <= maxf(ai_near_distance, 1.0) ** 2 or is_world_position_in_player_screen(global_position, 64.0):
		_ai_is_far_tier = false
		_set_far_physics_simplified(false)
		return 0.0
	if distance_sq <= maxf(ai_mid_distance, ai_near_distance) ** 2:
		_ai_is_far_tier = false
		_set_far_physics_simplified(false)
		return 1.0 / maxf(ai_mid_hz, 1.0)
	_ai_is_far_tier = true
	_set_far_physics_simplified(true)
	return 1.0 / maxf(ai_far_hz, 1.0)

func _initialize_ai_lod_stagger() -> void:
	# Instance ids are stable for the node lifetime and spread expensive tier
	# refreshes without introducing random/replay-dependent timing.
	var phase := float(get_instance_id() % 16) / 16.0
	_ai_tier_refresh_remaining = phase * 0.25
	_ai_tick_interval = _resolve_ai_tick_interval()
	if _ai_tick_interval > 0.0:
		_ai_tick_accumulator = phase * _ai_tick_interval

func _set_far_physics_simplified(enabled: bool) -> void:
	var should_enable := enabled and simplify_far_physics and not _spawn_phase_active
	if should_enable == _far_physics_simplified:
		return
	_far_physics_simplified = should_enable
	if should_enable:
		_far_body_collision_mask = collision_mask
		collision_mask = 0
		_far_area_monitoring_state.clear()
		for descendant in find_children("*", "Area2D", true, false):
			var area := descendant as Area2D
			# HurtBoxes must remain monitorable so off-screen projectiles and area
			# damage can still hit them. Gameplay support fields are also preserved;
			# only explicitly optional perception/sensor Areas may be suspended.
			if area == null or not area.monitoring or not bool(area.get_meta(&"far_physics_optional", false)):
				continue
			_far_area_monitoring_state.append({"area": area, "monitoring": true})
			area.set_deferred("monitoring", false)
		return
	collision_mask = _far_body_collision_mask
	for state in _far_area_monitoring_state:
		var area := state.get("area") as Area2D
		if area != null and is_instance_valid(area):
			area.set_deferred("monitoring", bool(state.get("monitoring", false)))
	_far_area_monitoring_state.clear()

func uses_simplified_far_movement() -> bool:
	return _ai_is_far_tier and not is_boss and not (self is EliteEnemy)

func reset_ai_lod_debug_metrics() -> void:
	_ai_tick_accumulator = 0.0
	_ai_tier_refresh_remaining = 0.0
	_ai_logic_ticks = 0
	_ai_cached_movement_ticks = 0

func get_ai_lod_debug_metrics() -> Dictionary:
	return {
		"logic_ticks": _ai_logic_ticks,
		"cached_movement_ticks": _ai_cached_movement_ticks,
		"tick_interval": _ai_tick_interval,
		"far_physics_simplified": _far_physics_simplified,
	}

func interrupt_movement() -> void:
	if has_method("_finish_dash"):
		call_deferred("_finish_dash")
	if has_method("apply_stun"):
		apply_stun(0.2)

func apply_status_payload(status_name: StringName, status_data: Variant) -> void:
	super.apply_status_payload(status_name, status_data)
	if not (status_data is Dictionary):
		return
	var payload := status_data as Dictionary
	match status_name:
		&"stun":
			apply_stun(float(payload.get("duration", 0.0)))
		&"slow":
			apply_slow(
				float(payload.get("multiplier", 1.0)),
				float(payload.get("duration", 0.0))
			)


func set_quest_highlight(enabled: bool, color: Color = Color.WHITE) -> void:
	set_outline_highlight(enabled, color, 1.0)


func set_quest_lock(active: bool, damage_mul: float = 0.5, freeze_movement: bool = true) -> void:
	if active:
		if _quest_lock_active:
			return
		_quest_lock_active = true
		_quest_lock_damage_mul = damage_taken_multiplier
		_quest_freeze_movement = freeze_movement
		damage_taken_multiplier = minf(damage_taken_multiplier, maxf(damage_mul, 0.05))
		return
	if not _quest_lock_active:
		return
	_quest_lock_active = false
	_quest_freeze_movement = false
	damage_taken_multiplier = _quest_lock_damage_mul

func is_quest_movement_locked() -> bool:
	return _quest_lock_active and _quest_freeze_movement

func set_outline_highlight(enabled: bool, color: Color = Color.WHITE, width: float = 1.0) -> void:
	if sprite_body == null:
		return
	if enabled:
		if not _quest_outline_enabled:
			_quest_outline_original_material = sprite_body.material
			_quest_outline_material = _build_quest_outline_material(color, width)
			_quest_outline_enabled = true
		if _quest_outline_material:
			_quest_outline_material.set_shader_parameter("outline_color", color)
			_quest_outline_material.set_shader_parameter("outline_width", width)
			sprite_body.material = _quest_outline_material
		return
	if not _quest_outline_enabled:
		return
	_quest_outline_enabled = false
	sprite_body.material = _quest_outline_original_material

func _build_quest_outline_material(color: Color, width: float) -> ShaderMaterial:
	var outline_material := ShaderMaterial.new()
	outline_material.shader = QUEST_OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_color", color)
	outline_material.set_shader_parameter("outline_width", width)
	return outline_material

func has_spawn_tag(tag: StringName) -> bool:
	return spawn_tags.has(tag)

func get_source_damage_taken_multiplier(attack: Attack) -> float:
	var base_multiplier := super.get_source_damage_taken_multiplier(attack)
	if attack == null or not _attack_is_from_player_weapon_source(attack):
		return base_multiplier
	return base_multiplier * get_support_damage_taken_multiplier()

func set_support_damage_reduction(source: Node, multiplier: float) -> void:
	if source == null or source == self:
		return
	_support_damage_reduction_sources[source.get_instance_id()] = {
		"source": weakref(source),
		"multiplier": clampf(multiplier, 0.0, 1.0),
	}

func clear_support_damage_reduction(source: Node) -> void:
	if source != null:
		_support_damage_reduction_sources.erase(source.get_instance_id())

func get_support_damage_taken_multiplier() -> float:
	var strongest := 1.0
	for source_id in _support_damage_reduction_sources.keys():
		var entry: Dictionary = _support_damage_reduction_sources[source_id]
		var source_ref := entry.get("source") as WeakRef
		if source_ref == null or source_ref.get_ref() == null:
			_support_damage_reduction_sources.erase(source_id)
			continue
		strongest = minf(strongest, float(entry.get("multiplier", 1.0)))
	return strongest

func add_speed_bonus_source(source: Node, multiplier: float) -> void:
	if source != null and source != self:
		_speed_bonus_sources[source.get_instance_id()] = maxf(multiplier, 0.0)

func remove_speed_bonus_source(source: Node) -> void:
	if source != null:
		_speed_bonus_sources.erase(source.get_instance_id())

func add_slow_field_source(source: Node, multiplier: float) -> void:
	if source != null:
		_slow_field_sources[source.get_instance_id()] = clampf(multiplier, 0.05, 1.0)

func remove_slow_field_source(source: Node) -> void:
	if source != null:
		_slow_field_sources.erase(source.get_instance_id())

func _get_speed_bonus_multiplier() -> float:
	var strongest := 1.0
	for value in _speed_bonus_sources.values():
		strongest = maxf(strongest, float(value))
	return strongest

func _get_field_slow_multiplier() -> float:
	var strongest := 1.0
	for value in _slow_field_sources.values():
		strongest = minf(strongest, float(value))
	return strongest

func is_support_unit() -> bool:
	return support_role != &""

func can_receive_support_from(source: BaseEnemy) -> bool:
	if source == null or source == self:
		return false
	return support_role == &"" or support_role != source.support_role

func compute_ranged_navigation(
	delta: float,
	detect_range: float,
	attack_range: float,
	approach_speed_mul: float = 1.0,
	wander_speed_mul: float = 0.75,
	wander_change_interval_sec: float = 3.0
) -> Vector2:
	if PlayerData.player == null:
		return Vector2.ZERO
	var to_player: Vector2 = PlayerData.player.global_position - global_position
	var distance: float = to_player.length()
	var to_player_dir: Vector2 = to_player.normalized() if distance > 0.001 else Vector2.RIGHT
	var safe_detect := maxf(detect_range, 1.0)
	var safe_attack := clampf(attack_range, 1.0, safe_detect)
	var base_speed := get_current_movement_speed()
	if distance > safe_detect:
		_ranged_wander_time_left = 0.0
		return to_player_dir * base_speed * maxf(approach_speed_mul, 0.05)
	_ranged_wander_time_left -= maxf(delta, 0.0)
	if _ranged_wander_time_left <= 0.0 or _ranged_wander_dir == Vector2.ZERO:
		_ranged_wander_time_left = maxf(wander_change_interval_sec, 0.1)
		var tangent := Vector2(-to_player_dir.y, to_player_dir.x)
		var random_dir := Vector2.RIGHT.rotated(randf() * TAU)
		var tangent_sign := -1.0 if randf() < 0.5 else 1.0
		var blended := tangent * tangent_sign + random_dir * 0.35
		_ranged_wander_dir = blended.normalized() if blended.length() > 0.001 else tangent.normalized()
	var desired_dir := _ranged_wander_dir
	if distance > safe_attack:
		desired_dir = (desired_dir * 0.65 + to_player_dir * 0.35).normalized()
	else:
		desired_dir = (desired_dir * 0.8 - to_player_dir * 0.2).normalized()
	return desired_dir * base_speed * maxf(wander_speed_mul, 0.05)

func is_world_position_in_player_screen(world_pos: Vector2, margin: float = 0.0) -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var visible_rect := viewport.get_visible_rect().grow(maxf(margin, 0.0))
	var canvas_pos := viewport.get_canvas_transform() * world_pos
	return visible_rect.has_point(canvas_pos)

func _get_board_generator() -> Node:
	if _board_generator_ref != null and is_instance_valid(_board_generator_ref):
		return _board_generator_ref
	var scene_root := get_tree().current_scene
	if scene_root:
		_board_generator_ref = scene_root.get_node_or_null("Board")
		_connect_board_constraint_signals()
	return _board_generator_ref

func _constrain_to_board_traversable_area() -> void:
	var board := _get_board_generator()
	if board == null:
		return
	if _constraint_cache_valid and _constraint_safe_rect.has_point(global_position):
		_constraint_fast_accepts += 1
		return
	if not board.has_method("build_enemy_traversable_cache"):
		return
	_constraint_full_refreshes += 1
	var cache_value: Variant = board.call("build_enemy_traversable_cache", global_position)
	if not (cache_value is Dictionary):
		_constraint_cache_valid = false
		return
	var cache := cache_value as Dictionary
	var projected_pos: Vector2 = cache.get("position", global_position)
	_constraint_cached_cell_id = int(cache.get("cell_id", -1))
	_constraint_safe_rect = cache.get("safe_rect", Rect2()) as Rect2
	_constraint_cache_valid = _constraint_cached_cell_id >= 0 and _constraint_safe_rect.size.x > 0.0 and _constraint_safe_rect.size.y > 0.0
	if projected_pos.distance_squared_to(global_position) > 0.25:
		global_position = projected_pos
		var enemy_registry := get_node_or_null("/root/EnemyRegistry")
		if enemy_registry != null and enemy_registry.has_method("update_enemy_position"):
			enemy_registry.call("update_enemy_position", self)

func invalidate_board_constraint_cache(_unused: Variant = null) -> void:
	_constraint_cache_valid = false
	_constraint_cached_cell_id = -1
	_constraint_safe_rect = Rect2()

func get_board_constraint_debug_metrics() -> Dictionary:
	return {
		"cache_valid": _constraint_cache_valid,
		"cached_cell_id": _constraint_cached_cell_id,
		"fast_accepts": _constraint_fast_accepts,
		"full_refreshes": _constraint_full_refreshes,
	}

func _connect_board_constraint_signals() -> void:
	var board := _board_generator_ref
	if board == null or not is_instance_valid(board):
		return
	var invalidate_callable := Callable(self, "invalidate_board_constraint_cache")
	if board.has_signal("active_cells_changed") and not board.is_connected("active_cells_changed", invalidate_callable):
		board.connect("active_cells_changed", invalidate_callable)
	if board.has_signal("board_recentered") and not board.is_connected("board_recentered", invalidate_callable):
		board.connect("board_recentered", invalidate_callable)

func _disconnect_board_constraint_signals() -> void:
	var board := _board_generator_ref
	if board == null or not is_instance_valid(board):
		return
	var invalidate_callable := Callable(self, "invalidate_board_constraint_cache")
	if board.has_signal("active_cells_changed") and board.is_connected("active_cells_changed", invalidate_callable):
		board.disconnect("active_cells_changed", invalidate_callable)
	if board.has_signal("board_recentered") and board.is_connected("board_recentered", invalidate_callable):
		board.disconnect("board_recentered", invalidate_callable)
