extends Node2D

## Sibling overlay samples motion without writing projectile transforms or size.
var projectile: Projectile
var _age := 0.0
var _last_position := Vector2.ZERO
var _direction := Vector2.UP
var _id := ""
var _sprite_scale := Vector2.ONE
var _animation_scale := Vector2.ONE
var _squashed := false
var _last_remaining := 0.0

func _ready() -> void:
	if is_instance_valid(projectile.source_weapon):
		_id = projectile.source_weapon.get_script().resource_path.get_file().get_basename()
	_last_position = projectile.global_position
	_last_remaining = projectile.expire_timer.time_left
	_sprite_scale = projectile.projectile_sprite.scale
	_animation_scale = projectile.projectile_animation.scale
	top_level = true
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _id in ["rocket_launcher", "spear_launcher"]:
		preload("res://Player/Weapons/Feedback/impact_audio.gd").play_flight(projectile, _id)
	if _id == "orbit":
		# The mechanical silhouette replaces only the old decorative sprite.
		projectile.projectile_sprite.self_modulate.a = 0.0

func _process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(projectile) or not projectile.is_inside_tree():
		queue_free()
		return
	var motion := projectile.global_position - _last_position
	_last_position = projectile.global_position
	_last_remaining = projectile.expire_timer.time_left
	if motion.length_squared() > 0.001:
		_direction = motion.normalized()
		projectile.set_meta(&"presentation_motion_direction", _direction)
	var root := projectile.projectile_root
	var contact_frame := int(projectile.get_meta(&"presentation_contact_frame", -100))
	if _squashed:
		projectile.projectile_sprite.scale = _sprite_scale
		projectile.projectile_animation.scale = _animation_scale
		_squashed = false
	if Engine.get_process_frames() == contact_frame:
		_sprite_scale = projectile.projectile_sprite.scale
		_animation_scale = projectile.projectile_animation.scale
		projectile.projectile_sprite.scale *= Vector2(1.2, 0.8)
		projectile.projectile_animation.scale *= Vector2(1.2, 0.8)
		_squashed = true
	global_position = root.global_position
	global_rotation = root.world_direction_to_screen(_direction).angle()
	z_index = root.z_index
	visible = root.is_visible_in_tree() and (projectile.projectile_sprite.visible or projectile.projectile_animation.visible)
	queue_redraw()

func _exit_tree() -> void:
	# Preserve only a visual snapshot when an active satellite is recalled early.
	# Its collision and pool lifetime still end immediately.
	if _id != "orbit" or _age < 0.02 or _last_remaining <= 0.15:
		return
	if not is_instance_valid(projectile) or not projectile.is_inside_tree():
		return
	if projectile.get_meta(&"presentation_silent_cleanup", false):
		return
	var service := preload("res://Player/Weapons/Effects/projectile_impact_vfx_service.gd").ensure(projectile.get_tree())
	if service != null:
		service.play(_last_position, _direction, Attack.TYPE_ENERGY, 1, &"satellite_recall")

func _draw() -> void:
	match _id:
		"orbit":
			var deploy := clampf(_age / 0.12, 0.0, 1.0)
			var retract := clampf(projectile.expire_timer.time_left / 0.15, 0.0, 1.0)
			var spread := roundf(3 + 6 * minf(deploy, retract))
			draw_rect(Rect2(-5,-6,10,12),Color("243746"))
			draw_rect(Rect2(-4,-5,8,10),Color("71899a"),false,1)
			for side in [-1,1]:
				draw_line(Vector2(side*4,0),Vector2(side*spread,0),Color("b0c7d2"),2)
				draw_rect(Rect2(side*spread-3,-5,6,10),Color("284c69"))
				draw_line(Vector2(side*spread-2,-2),Vector2(side*spread+2,-2),Color("55a8d0"),1)
				draw_line(Vector2(side*spread-2,2),Vector2(side*spread+2,2),Color("55a8d0"),1)
			draw_rect(Rect2(-2,-3,4,6),Color("50e7ed"))
			draw_rect(Rect2(-1,-2,2,3),Color("edffff"))
			draw_line(Vector2(0,-6),Vector2(0,-9),Color("b0c7d2"),1)
		"shotgun":
			var tint := projectile.presentation_tint
			draw_line(Vector2(-7,0), Vector2(1,0), Color(1,0.48,0.16) * tint, 3)
			draw_line(Vector2(-3,0), Vector2(3,0), Color.WHITE * tint, 1)
		"rocket_launcher":
			var flicker := float(int(_age * 24.0) % 3)
			draw_rect(Rect2(-27 - flicker * 2, -4, 13, 8), Color(0.2, 0.15, 0.18, 0.35))
			draw_colored_polygon(PackedVector2Array([Vector2(-9,-4), Vector2(-25-flicker*2,0), Vector2(-9,4)]), Color("ff873d"))
			draw_line(Vector2(-9,0), Vector2(-18-flicker,0), Color("fff4d0"), 2)
		"spear_launcher":
			draw_line(Vector2(-25, -2), Vector2(-8, -2), Color(0.4,0.85,1,0.35), 2)
			draw_line(Vector2(-32, 2), Vector2(-12, 2), Color(0.4,0.85,1,0.18), 2)
			var flow := fmod(_age * 60, 18.0)
			draw_rect(Rect2(-15 + flow, -1, 4, 2), Color("d6faff"))
		"chainsaw_launcher":
			for index in range(6):
				var ray := Vector2.RIGHT.rotated(index * TAU / 6 + _age * 22)
				draw_line((ray*12).round(), (ray*15).round(), Color(1,0.86,0.55,0.75), 2)
