class_name UnitBillboardVisual2D
extends "res://Visual/Oblique/billboard_visual_2d.gd"

const HIDDEN_VISIBILITY_LAYER: int = 0

static var _texture_bounds_cache: Dictionary = {}

var _hybrid_billboard_registered := false
var _original_visibility_layer: int = 1
var _billboard_config: Dictionary = {}
var _billboard_appearance_version := 0
var _billboard_visibility_version := 0


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
	var flash_color := Color.WHITE
	var flash_amount := 0.0
	var flash_overlay := get_node_or_null(^"HitFlashOverlay") as Sprite2D
	if flash_overlay != null and flash_overlay.visible:
		flash_color = Color(flash_overlay.modulate.r, flash_overlay.modulate.g, flash_overlay.modulate.b, 1.0)
		flash_amount = clampf(flash_overlay.modulate.a, 0.0, 1.0)
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
	var appearance_changed := _set_billboard_config_value(&"texture", texture)
	appearance_changed = _set_billboard_config_value(&"visual_size_px", visual_size_px) or appearance_changed
	appearance_changed = _set_billboard_config_value(&"bottom_padding_px", bottom_padding_px) or appearance_changed
	appearance_changed = _set_billboard_config_value(&"local_ground_anchor", ground_anchor) or appearance_changed
	var visibility_changed := _set_billboard_config_value(&"visible", visible and unit_owner != null and unit_owner.visible)
	appearance_changed = _set_billboard_config_value(&"flip_h", bool(get("flip_h"))) or appearance_changed
	appearance_changed = _set_billboard_config_value(&"flip_v", bool(get("flip_v"))) or appearance_changed
	appearance_changed = _set_billboard_config_value(&"color", modulate * self_modulate) or appearance_changed
	appearance_changed = _set_billboard_config_value(&"flash_color", flash_color) or appearance_changed
	appearance_changed = _set_billboard_config_value(&"flash_amount", flash_amount) or appearance_changed
	appearance_changed = _set_billboard_config_value(&"warning_color", warning_color) or appearance_changed
	appearance_changed = _set_billboard_config_value(&"warning_amount", warning_amount) or appearance_changed
	appearance_changed = _set_billboard_config_value(&"outline_color", outline_color) or appearance_changed
	appearance_changed = _set_billboard_config_value(&"outline_width_px", outline_width) or appearance_changed
	if appearance_changed:
		_billboard_appearance_version += 1
	if visibility_changed:
		_billboard_visibility_version += 1
	_billboard_config["appearance_version"] = _billboard_appearance_version
	_billboard_config["visibility_version"] = _billboard_visibility_version
	return _billboard_config


func _set_billboard_config_value(key: StringName, value: Variant) -> bool:
	if _billboard_config.has(key) and _billboard_config[key] == value:
		return false
	_billboard_config[key] = value
	return true


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
