extends "res://Visual/Oblique/unit_billboard_visual_2d.gd"

const FEEDBACK_SHADER := preload("res://Player/Weapons/Feedback/floating_weapon.gdshader")
const SKILL_READY_PULSE_SEC := 0.4
var _module_weapon: Node2D
var _module_feedback := Vector2.ZERO
var _skill_ready_pulse: float = 0.0

func _ready() -> void:
	_module_weapon = get_parent() as Node2D
	while _module_weapon != null and not _module_weapon.has_method("get_heat_ratio"):
		_module_weapon = _module_weapon.get_parent() as Node2D
	self_modulate = Color(0.80, 0.84, 0.88, 1.0)
	var feedback_material := ShaderMaterial.new()
	feedback_material.shader = FEEDBACK_SHADER
	material = feedback_material
	super._ready()

func _process(delta: float) -> void:
	_skill_ready_pulse = 0.0
	if is_instance_valid(_module_weapon):
		var heat := maxf(float(_module_weapon.call("get_signed_heat_ratio")), 0.0)
		var age := float(Time.get_ticks_msec() - int(_module_weapon.get_meta(&"_last_fire_feedback_msec", -100000))) / 1000.0
		_module_feedback = Vector2(smoothstep(0.65, 1.0, heat), clampf(1.0 - age / 0.18, 0.0, 1.0))
		(material as ShaderMaterial).set_shader_parameter("module_feedback", _module_feedback)
		var ready_age := float(Time.get_ticks_msec() - int(_module_weapon.get_meta(&"_weapon_skill_cooldown_ready_msec", -100000))) / 1000.0
		if ready_age >= 0.0 and ready_age < SKILL_READY_PULSE_SEC:
			_skill_ready_pulse = sin(ready_age / SKILL_READY_PULSE_SEC * PI) * 0.9
	(material as ShaderMaterial).set_shader_parameter("skill_ready_pulse", _skill_ready_pulse)
	super._process(delta)

func get_unit_billboard_config() -> Dictionary:
	var config := super.get_unit_billboard_config()
	var changed := _set_billboard_config_value(&"module_feedback", _module_feedback)
	changed = _set_billboard_config_value(&"floating_module", true) or changed
	# Reuse the billboard flash channel so the pulse also appears in the hybrid view.
	var flash_amount := float(config.get("flash_amount", 0.0))
	if _skill_ready_pulse > flash_amount:
		changed = _set_billboard_config_value(&"flash_amount", _skill_ready_pulse) or changed
		changed = _set_billboard_config_value(&"flash_color", Color.WHITE) or changed
	if changed:
		_billboard_appearance_version += 1
		config["appearance_version"] = _billboard_appearance_version
	return config

func get_visual_muzzle_canvas_position() -> Vector2:
	var texture := _get_current_texture()
	if texture == null:
		return global_position
	var bounds := _get_texture_used_rect(texture)
	return _module_axis_canvas_position((texture.get_height() * 0.5 - float(bounds.position.y)) * scale.y)

func get_visual_dock_canvas_position() -> Vector2:
	var texture := _get_current_texture()
	if texture == null:
		return global_position
	return _module_axis_canvas_position(-(texture.get_height() * 0.5 - 8.0) * scale.y)

func _module_axis_canvas_position(distance: float) -> Vector2:
	var parent := get_parent() as Node2D
	var logical := parent.global_transform * _base_transform.origin
	var direction := Vector2.UP.rotated(parent.global_rotation)
	var view := _get_hybrid_view()
	if view == null:
		return logical + direction * distance
	var canvas := get_viewport().get_canvas_transform()
	var projected := view.call("project_world_to_canvas", logical, get_viewport()) as Vector2
	var screen_direction := view.call("world_vector_to_screen", direction, logical) as Vector2
	return projected + canvas.basis_xform_inv(screen_direction.normalized() * distance + screen_feedback_offset)
