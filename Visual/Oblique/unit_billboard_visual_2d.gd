class_name UnitBillboardVisual2D
extends "res://Visual/Oblique/billboard_visual_2d.gd"

const HIDDEN_VISIBILITY_LAYER: int = 0

static var _texture_bounds_cache: Dictionary = {}

var _hybrid_billboard_registered := false
var _original_visibility_layer: int = 1


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
	var flash := _resolve_overlay_feedback(&"HitFlashOverlay")
	var warning := _resolve_overlay_feedback(&"WarningFlashOverlay")
	var outline := _resolve_outline_feedback()
	return {
		"texture": texture,
		"visual_size_px": visual_size_px,
		"bottom_padding_px": bottom_padding_px,
		"local_ground_anchor": ground_anchor,
		"visible": visible and unit_owner != null and unit_owner.visible,
		"flip_h": bool(get("flip_h")),
		"flip_v": bool(get("flip_v")),
		"color": modulate * self_modulate,
		"flash_color": flash.color,
		"flash_amount": flash.amount,
		"warning_color": warning.color,
		"warning_amount": warning.amount,
		"outline_color": outline.color,
		"outline_width_px": outline.width,
	}


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


func _resolve_overlay_feedback(node_name: StringName) -> Dictionary:
	var overlay := get_node_or_null(NodePath(str(node_name))) as Sprite2D
	if overlay == null or not overlay.visible:
		return {"color": Color.WHITE, "amount": 0.0}
	return {
		"color": Color(overlay.modulate.r, overlay.modulate.g, overlay.modulate.b, 1.0),
		"amount": clampf(overlay.modulate.a, 0.0, 1.0),
	}


func _resolve_outline_feedback() -> Dictionary:
	var source_material := material as ShaderMaterial
	if source_material == null:
		return {"color": Color.TRANSPARENT, "width": 0.0}
	var width_value: Variant = source_material.get_shader_parameter("outline_width")
	if not (width_value is float or width_value is int):
		return {"color": Color.TRANSPARENT, "width": 0.0}
	var color_value: Variant = source_material.get_shader_parameter("outline_color")
	return {
		"color": color_value as Color if color_value is Color else Color.WHITE,
		"width": clampf(float(width_value), 0.0, 3.0),
	}


func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)
	visibility_layer = _original_visibility_layer
	_hybrid_billboard_registered = false
	super._exit_tree()
