extends Area2D
class_name AreaEffect

static var debug_mode_enabled: bool = false

enum TargetGroup {
	ENEMIES,
	ALLIES,
	BOTH
}

@export var duration: float = 0.1
@export var radius: float = 24.0:
	set(value):
		radius = maxf(value, 1.0)
		_sync_radius()
		_sync_visual_scale()
		if _is_debug_draw_enabled():
			queue_redraw()
@export var target_group: TargetGroup = TargetGroup.ENEMIES:
	set(value):
		target_group = value
		_sync_collision_mask()
@export var visual_enabled: bool = false:
	set(value):
		visual_enabled = value
		_sync_visual_nodes()
@export var use_animated_visual: bool = false:
	set(value):
		use_animated_visual = value
		_sync_visual_nodes()
@export var visual_texture: Texture2D:
	set(value):
		visual_texture = value
		_sync_visual_nodes()
@export var visual_frames: SpriteFrames:
	set(value):
		visual_frames = value
		_sync_visual_nodes()
@export var visual_animation: StringName = &"default":
	set(value):
		visual_animation = value
		_sync_visual_nodes()
@export var visual_playback_speed: float = 1.0:
	set(value):
		visual_playback_speed = value
		_sync_visual_nodes()
@export var visual_modulate: Color = Color(1.0, 1.0, 1.0, 0.55):
	set(value):
		visual_modulate = value
		_sync_visual_nodes()
@export var visual_rotation_speed_deg: float = 0.0
@export var visual_size_multiplier: float = 1.0:
	set(value):
		visual_size_multiplier = maxf(value, 0.01)
		_sync_visual_scale()
@export var draw_enabled: bool = true:
	set(value):
		draw_enabled = value
		queue_redraw()
@export var debug_fill_color: Color = Color(1.0, 0.4, 0.2, 0.14)
@export var debug_line_color: Color = Color(1.0, 0.6, 0.3, 0.9)
@export var debug_line_width: float = 2.0
@export var apply_once_per_target: bool = true
@export var one_shot_damage: int = 0
@export var tick_damage: int = 0
@export var tick_interval: float = 0.4
@export var damage_type: StringName = Attack.TYPE_PHYSICAL
@export var status_on_apply: Dictionary = {}
@export var knock_back := {
	"amount": 0.0,
	"angle": Vector2.ZERO
}

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var life_timer: Timer = $LifeTimer
@onready var visual_root: Node2D = $VisualRoot
@onready var visual_sprite: Sprite2D = $VisualRoot/Sprite
@onready var visual_animated_sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite

var source_node: Node
var _affected_target_ids: Dictionary = {}
var _tick_elapsed: float = 0.0

signal target_affected(target: Node)


func _ready() -> void:
	_sync_radius()
	_sync_collision_mask()
	_sync_visual_nodes()
	life_timer.wait_time = maxf(duration, 0.01)
	life_timer.start()
	call_deferred("_apply_to_current_overlaps")

func _process(delta: float) -> void:
	if visual_root and is_instance_valid(visual_root) and not is_zero_approx(visual_rotation_speed_deg):
		visual_root.rotation += deg_to_rad(visual_rotation_speed_deg) * delta
	_apply_periodic_damage(delta)
	if _is_debug_draw_enabled():
		queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	_try_apply_on_hurt_box(area)


func _on_life_timer_timeout() -> void:
	queue_free()


func _apply_to_current_overlaps() -> void:
	for area in get_overlapping_areas():
		_try_apply_on_hurt_box(area)


func _try_apply_on_hurt_box(area: Area2D) -> void:
	if not area is HurtBox:
		return
	var hurt_box: HurtBox = area
	var target: Node = null
	if hurt_box.has_method("get_damage_target"):
		target = hurt_box.call("get_damage_target")
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_owner()
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_parent()
	if target == null or not is_instance_valid(target):
		return
	if not _can_affect_hurt_box(hurt_box):
		return
	var target_id := target.get_instance_id()
	if apply_once_per_target and _affected_target_ids.has(target_id):
		return
	_affected_target_ids[target_id] = true
	_apply_to_target(target, _is_enemy_hurt_box(hurt_box))
	target_affected.emit(target)


func _apply_to_target(target: Node, target_is_enemy: bool) -> void:
	if one_shot_damage > 0:
		var valid_source_node: Node = _resolve_valid_source_node()
		var damage_data := DamageManager.build_damage_data(
			valid_source_node,
			one_shot_damage,
			Attack.normalize_damage_type(damage_type),
			knock_back
		)
		var applied := DamageManager.apply_to_target(target, damage_data)
		if applied:
			var owner_player := damage_data.source_player as Player
			if owner_player and is_instance_valid(owner_player) and target_is_enemy:
				owner_player.apply_bonus_hit_if_needed(target)
			if valid_source_node and valid_source_node.has_method("on_hit_target"):
				valid_source_node.on_hit_target(target)
	if not status_on_apply.is_empty():
		_apply_status_to_target(target)
	apply_custom_effects(target)


# Applies periodic area damage for persistent zones like napalm.
func _apply_periodic_damage(delta: float) -> void:
	if tick_damage <= 0:
		return
	if tick_interval <= 0.0:
		return
	_tick_elapsed += delta
	while _tick_elapsed >= tick_interval:
		_tick_elapsed -= tick_interval
		_apply_tick_to_current_overlaps()


func _apply_tick_to_current_overlaps() -> void:
	for area in get_overlapping_areas():
		if not area is HurtBox:
			continue
		var hurt_box := area as HurtBox
		var target: Node = null
		if hurt_box.has_method("get_damage_target"):
			target = hurt_box.call("get_damage_target")
		if target == null or not is_instance_valid(target):
			target = hurt_box.get_owner()
		if target == null or not is_instance_valid(target):
			target = hurt_box.get_parent()
		if target == null or not is_instance_valid(target):
			continue
		if not _can_affect_hurt_box(hurt_box):
			continue
		var valid_source_node: Node = _resolve_valid_source_node()
		var damage_data := DamageManager.build_damage_data(
			valid_source_node,
			tick_damage,
			Attack.normalize_damage_type(damage_type),
			knock_back
		)
		if DamageManager.apply_to_target(target, damage_data):
			target_affected.emit(target)

func _resolve_valid_source_node() -> Node:
	if source_node != null and is_instance_valid(source_node):
		return source_node
	return null


func _apply_status_to_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_status_payload"):
		return
	for status_key in status_on_apply.keys():
		var status_name := StringName(str(status_key))
		var payload: Variant = status_on_apply[status_key]
		target.apply_status_payload(status_name, payload)


func _can_affect_hurt_box(hurt_box: HurtBox) -> bool:
	match target_group:
		TargetGroup.ENEMIES:
			return _is_enemy_hurt_box(hurt_box)
		TargetGroup.ALLIES:
			return _is_ally_hurt_box(hurt_box)
		TargetGroup.BOTH:
			return _is_enemy_hurt_box(hurt_box) or _is_ally_hurt_box(hurt_box)
	return false


func _is_enemy_hurt_box(hurt_box: HurtBox) -> bool:
	return hurt_box.get_collision_layer_value(3)


func _is_ally_hurt_box(hurt_box: HurtBox) -> bool:
	return hurt_box.get_collision_layer_value(1)


func _sync_radius() -> void:
	if not is_node_ready() or collision_shape == null:
		return
	if not collision_shape.shape or not (collision_shape.shape is CircleShape2D):
		collision_shape.shape = CircleShape2D.new()
	var circle := collision_shape.shape as CircleShape2D
	circle.radius = radius


func _sync_collision_mask() -> void:
	if not is_node_ready():
		return
	set_collision_mask_value(1, false)
	set_collision_mask_value(3, false)
	match target_group:
		TargetGroup.ENEMIES:
			set_collision_mask_value(3, true)
		TargetGroup.ALLIES:
			set_collision_mask_value(1, true)
		TargetGroup.BOTH:
			set_collision_mask_value(1, true)
			set_collision_mask_value(3, true)

func _sync_visual_nodes() -> void:
	if not is_node_ready():
		return
	if visual_root == null or visual_sprite == null or visual_animated_sprite == null:
		return
	visual_root.visible = visual_enabled
	visual_sprite.visible = false
	visual_animated_sprite.visible = false
	if not visual_enabled:
		return
	visual_sprite.modulate = visual_modulate
	visual_animated_sprite.modulate = visual_modulate
	if use_animated_visual and visual_frames != null:
		visual_animated_sprite.sprite_frames = visual_frames
		visual_animated_sprite.speed_scale = maxf(visual_playback_speed, 0.01)
		var animation_name := _resolve_animation_name()
		if animation_name != StringName():
			visual_animated_sprite.animation = animation_name
			visual_animated_sprite.play()
			visual_animated_sprite.visible = true
		else:
			visual_animated_sprite.stop()
			visual_animated_sprite.visible = false
	else:
		visual_animated_sprite.stop()
		visual_sprite.texture = visual_texture
		visual_sprite.visible = visual_texture != null
	_sync_visual_scale()


func _resolve_animation_name() -> StringName:
	if visual_frames == null:
		return StringName()
	if visual_frames.has_animation(visual_animation):
		return visual_animation
	var names: PackedStringArray = visual_frames.get_animation_names()
	if names.is_empty():
		return StringName()
	return StringName(names[0])


func _sync_visual_scale() -> void:
	if not is_node_ready():
		return
	if visual_root == null:
		return
	var target_diameter := maxf(radius * 2.0 * visual_size_multiplier, 1.0)
	var base_size := _resolve_visual_source_size()
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		visual_root.scale = Vector2.ONE
		return
	visual_root.scale = Vector2(
		target_diameter / base_size.x,
		target_diameter / base_size.y
	)


func _resolve_visual_source_size() -> Vector2:
	if use_animated_visual and visual_frames != null:
		var anim_name := _resolve_animation_name()
		if anim_name != StringName():
			var frame_tex := visual_frames.get_frame_texture(anim_name, 0)
			if frame_tex != null:
				return frame_tex.get_size()
	if visual_texture != null:
		return visual_texture.get_size()
	return Vector2.ZERO


func _draw() -> void:
	if not _is_debug_draw_enabled():
		return
	draw_circle(Vector2.ZERO, radius, debug_fill_color)
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		64,
		debug_line_color,
		maxf(debug_line_width, 1.0),
		true
	)


func _is_debug_draw_enabled() -> bool:
	if draw_enabled:
		return true
	if debug_mode_enabled:
		return true
	return false


static func set_debug_mode(enabled: bool) -> void:
	debug_mode_enabled = enabled


static func toggle_debug_mode() -> bool:
	debug_mode_enabled = not debug_mode_enabled
	return debug_mode_enabled


func apply_custom_effects(_target: Node) -> void:
	pass
