class_name UnitBillboardVisual2D
extends "res://Visual/Oblique/billboard_visual_2d.gd"

const HIDDEN_VISIBILITY_LAYER: int = 0

static var _texture_bounds_cache: Dictionary = {}
static var _config_texture_ground_usec := 0
static var _config_projection_usec := 0
static var _config_effects_usec := 0
static var _config_store_usec := 0

var _hybrid_billboard_registered := false
var _original_visibility_layer: int = 1
var _billboard_config: Dictionary = {}
var _billboard_appearance_version := 0
var _billboard_visibility_version := 0
var _billboard_appearance_state: Array = []
@export var centered_anchor: bool = false
@export var orbit_y_occlusion_enabled: bool = false
const ORBIT_DEPTH_SEPARATION_PX := 0.5
const ORBIT_BEHIND_RENDER_PRIORITY_OFFSET := -1
const ORBIT_FRONT_RENDER_PRIORITY_OFFSET := 1


func _ready() -> void:
	_original_visibility_layer = visibility_layer
	super._ready()
	call_deferred("_register_unit_billboard")


func _process(delta: float) -> void:
	if _hybrid_billboard_registered:
		return
	super._process(delta)


func _register_unit_billboard() -> void:
	if not is_inside_tree():
		return
	if HybridGroundRegistration.register(self, &"register_unit_billboard"):
		_hybrid_billboard_registered = true
		visibility_layer = HIDDEN_VISIBILITY_LAYER


func mark_hybrid_billboard_registered() -> void:
	_hybrid_billboard_registered = true
	visibility_layer = HIDDEN_VISIBILITY_LAYER


func get_unit_billboard_config() -> Dictionary:
	var profile := EnemySimulationSystem.detailed_profiling_enabled
	var phase_started := Time.get_ticks_usec() if profile else 0
	var texture := _get_current_texture()
	var texture_size := texture.get_size() if texture != null else Vector2.ZERO
	var visual_scale := scale.abs()
	var visual_size_px := texture_size * visual_scale
	var bounds := _get_texture_used_rect(texture)
	var bottom_padding_px := 0.0
	if texture != null and bounds.size != Vector2i.ZERO:
		bottom_padding_px = maxf(texture_size.y - float(bounds.end.y), 0.0) * visual_scale.y
	var ground_anchor := Vector2.ZERO
	var unit_owner := get_parent() as Node2D
	if unit_owner != null:
		var shadow := unit_owner.get_node_or_null("GroundShadow") as Node2D
		if shadow != null:
			ground_anchor = shadow.position
	if centered_anchor:
		ground_anchor = _base_transform.origin
	if profile:
		_config_texture_ground_usec += Time.get_ticks_usec() - phase_started
		phase_started = Time.get_ticks_usec()
	var logical_anchor := unit_owner.global_transform * ground_anchor if unit_owner != null else Vector2.ZERO
	var depth_anchor_world := logical_anchor
	var projected_position_offset := Vector2.ZERO
	var render_priority_offset := 0
	var hybrid_view := _get_hybrid_view()
	if orbit_y_occlusion_enabled and unit_owner != null and hybrid_view != null:
		var orbit_holder := unit_owner.get_parent() as Node2D
		var orbit_owner := orbit_holder.get_parent() as Node2D if orbit_holder != null else null
		if orbit_owner != null:
			var owner_ground_y := 0.0
			var owner_shadow := orbit_owner.get_node_or_null("GroundShadow") as Node2D
			if owner_shadow != null:
				owner_ground_y = owner_shadow.position.y
			# Orbit layering is semantic: weapons above the player are behind, while
			# weapons below the player are in front. Horizontal orbit movement must
			# never change that relationship under an oblique camera projection.
			var is_behind_owner := bool(unit_owner.get_meta(
				&"orbit_behind_owner",
				unit_owner.position.y < 0.0
			))
			render_priority_offset = ORBIT_BEHIND_RENDER_PRIORITY_OFFSET \
				if is_behind_owner else ORBIT_FRONT_RENDER_PRIORITY_OFFSET
			var depth_local_y := owner_ground_y + (-ORBIT_DEPTH_SEPARATION_PX if is_behind_owner else ORBIT_DEPTH_SEPARATION_PX)
			depth_anchor_world = orbit_owner.global_transform * Vector2(0.0, depth_local_y)
			projected_position_offset = \
				(hybrid_view.call("project_world_to_screen", logical_anchor) as Vector2) \
				- (hybrid_view.call("project_world_to_screen", depth_anchor_world) as Vector2)
	var visual_rotation_radians := 0.0
	if mode == BillboardMode.DIRECTIONAL and unit_owner != null:
		var forward_angle := deg_to_rad(directional_forward_degrees)
		var logical_axis := _world_direction_override
		if logical_axis == Vector2.ZERO:
			logical_axis = Vector2.RIGHT.rotated(unit_owner.global_rotation + _base_transform.get_rotation() + forward_angle)
		if hybrid_view != null:
			var screen_axis := hybrid_view.call("world_vector_to_screen", logical_axis, logical_anchor) as Vector2
			if screen_axis.length_squared() > 0.0001:
				# Canvas angles use a downward-positive Y axis, while the camera-facing
				# 3D quad rotates in an upward-positive XY plane. Convert conventions at
				# this boundary so the rendered muzzle follows the projectile direction.
				visual_rotation_radians = forward_angle - screen_axis.angle()
	visual_rotation_radians -= screen_feedback_rotation
	if profile:
		_config_projection_usec += Time.get_ticks_usec() - phase_started
		phase_started = Time.get_ticks_usec()
	var flash_color := Color.WHITE
	var flash_amount := 0.0
	var flash_overlay := get_node_or_null(^"HitFlashOverlay") as Sprite2D
	if flash_overlay != null and flash_overlay.visible:
		flash_color = Color(flash_overlay.modulate.r, flash_overlay.modulate.g, flash_overlay.modulate.b, 1.0)
		flash_amount = clampf(flash_overlay.modulate.a, 0.0, 1.0)
	var extra_flash := _get_additional_flash_amount()
	if extra_flash > flash_amount:
		flash_amount = extra_flash
		flash_color = Color.WHITE
	var warning_color := Color.WHITE
	var warning_amount := 0.0
	var warning_overlay := get_node_or_null(^"WarningFlashOverlay") as Sprite2D
	if warning_overlay != null and warning_overlay.visible:
		warning_color = Color(warning_overlay.modulate.r, warning_overlay.modulate.g, warning_overlay.modulate.b, 1.0)
		warning_amount = clampf(warning_overlay.modulate.a, 0.0, 1.0)
	var outline_color := Color.TRANSPARENT
	var outline_width := 0.0
	var source_material := material as ShaderMaterial
	if source_material != null:
		var width_value: Variant = source_material.get_shader_parameter("outline_width")
		if width_value is float or width_value is int:
			outline_width = clampf(float(width_value), 0.0, 3.0)
			var color_value: Variant = source_material.get_shader_parameter("outline_color")
			outline_color = color_value as Color if color_value is Color else Color.WHITE
	if profile:
		_config_effects_usec += Time.get_ticks_usec() - phase_started
		phase_started = Time.get_ticks_usec()
	var appearance_state := [
		texture, visual_size_px, bottom_padding_px,
		bool(get("flip_h")), bool(get("flip_v")), modulate * self_modulate,
		flash_color, flash_amount, warning_color, warning_amount,
		outline_color, outline_width, visual_rotation_radians,
		0.0 if centered_anchor else 0.5 - clampf(bottom_padding_px / maxf(visual_size_px.y, 1.0), 0.0, 0.49),
		render_priority_offset,
	]
	if appearance_state != _billboard_appearance_state:
		_billboard_appearance_state = appearance_state
		_billboard_config["texture"] = texture
		_billboard_config["visual_size_px"] = visual_size_px
		_billboard_config["bottom_padding_px"] = bottom_padding_px
		_billboard_config["flip_h"] = appearance_state[3]
		_billboard_config["flip_v"] = appearance_state[4]
		_billboard_config["color"] = appearance_state[5]
		_billboard_config["flash_color"] = flash_color
		_billboard_config["flash_amount"] = flash_amount
		_billboard_config["warning_color"] = warning_color
		_billboard_config["warning_amount"] = warning_amount
		_billboard_config["outline_color"] = outline_color
		_billboard_config["outline_width_px"] = outline_width
		_billboard_config["visual_rotation_radians"] = visual_rotation_radians
		_billboard_config["vertical_anchor_offset"] = appearance_state[13]
		_billboard_config["render_priority_offset"] = appearance_state[14]
		_billboard_appearance_version += 1
	# These values may change with movement but do not change shader appearance.
	_billboard_config["local_ground_anchor"] = ground_anchor
	_billboard_config["depth_anchor_world"] = depth_anchor_world
	_billboard_config["screen_feedback_offset"] = projected_position_offset + screen_feedback_offset
	var next_visible := visible and unit_owner != null and unit_owner.visible
	if _billboard_config.get("visible") != next_visible:
		_billboard_config["visible"] = next_visible
		_billboard_visibility_version += 1
	_billboard_config["appearance_version"] = _billboard_appearance_version
	_billboard_config["visibility_version"] = _billboard_visibility_version
	if profile:
		_config_store_usec += Time.get_ticks_usec() - phase_started
	return _billboard_config


static func reset_config_profile() -> void:
	_config_texture_ground_usec = 0
	_config_projection_usec = 0
	_config_effects_usec = 0
	_config_store_usec = 0


static func get_config_profile() -> Dictionary:
	return {
		"texture_ground_ms": float(_config_texture_ground_usec) / 1000.0,
		"projection_ms": float(_config_projection_usec) / 1000.0,
		"effects_ms": float(_config_effects_usec) / 1000.0,
		"store_ms": float(_config_store_usec) / 1000.0,
	}


# Floating weapon visuals extend the base configuration with module feedback.
func _set_billboard_config_value(key: StringName, value: Variant) -> bool:
	if _billboard_config.has(key) and _billboard_config[key] == value:
		return false
	_billboard_config[key] = value
	return true


func _get_additional_flash_amount() -> float:
	return 0.0


func _get_current_texture() -> Texture2D:
	if is_class("Sprite2D"):
		return get("texture") as Texture2D
	if is_class("AnimatedSprite2D"):
		var frames := get("sprite_frames") as SpriteFrames
		var animation_name := get("animation") as StringName
		if frames == null or not frames.has_animation(animation_name):
			return null
		var frame_count := frames.get_frame_count(animation_name)
		if frame_count <= 0:
			return null
		return frames.get_frame_texture(animation_name, clampi(int(get("frame")), 0, frame_count - 1))
	return null


func _get_texture_used_rect(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i()
	var cache_key := texture.get_instance_id()
	if _texture_bounds_cache.has(cache_key):
		return _texture_bounds_cache[cache_key] as Rect2i
	var image := texture.get_image()
	var bounds := image.get_used_rect() if image != null and not image.is_empty() else Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
	_texture_bounds_cache[cache_key] = bounds
	return bounds


func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)
	visibility_layer = _original_visibility_layer
	_hybrid_billboard_registered = false
	super._exit_tree()
