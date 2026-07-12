extends Node2D
class_name Projectile

enum ProjectileVisualMode { UPRIGHT, DIRECTIONAL, GROUND, SEGMENT, CUSTOM }

const DEFAULT_EXPIRE_TIME: float = 2.5
const PISTOL_PIERCE_MARK_ID := &"pistol_pierce"
const INITIAL_PROJECTILE_HITS_META := "initial_projectile_hits"

var hp : int = 1
var damage = 1
var damage_type: StringName = Attack.TYPE_PHYSICAL
var knock_back = {
	"amount": 0,
	"angle": Vector2.ZERO
}
var expire_time : float = DEFAULT_EXPIRE_TIME
var base_displacement = Vector2.ZERO
var projectile_displacement = Vector2.ZERO
var projectile_texture
var projectile_frames: SpriteFrames
var size : float = 1.0
var desired_pixel_size : Vector2 = Vector2.ZERO
var module_list = []
var effect_list = []
var source_weapon: Weapon
var hitbox_type = "once"
var dot_cd : float
var _is_pooled: bool = false
var _active_movement_controller: Node
var debug_source_weapon: String = ""
var debug_effect_names: Array[String] = []
var debug_effect_params: Dictionary = {}
@export var debug_overlay_enabled: bool = false
var wall_collision_mask: int = 0
@export var visual_mode: ProjectileVisualMode = ProjectileVisualMode.DIRECTIONAL
var _debug_label: Label
var _wall_hit_reported: bool = false
var overlapping : bool :
	set(value):
		if value != overlapping:
			overlapping = value
			overlapping_signal.emit()

# Signals
signal overlapping_signal()

# Preloads
@onready var hitbox_once = preload("res://Combat/collision/hit_box.tscn")
@onready var hitbox_dot = preload("res://Combat/collision/hit_box_dot.tscn")

# Children
@onready var expire_timer = $ExpireTimer
@onready var projectile_root: Node2D = $Bullet
@onready var hitbox_anchor: Node2D = $HitboxAnchor
@onready var projectile_sprite: Sprite2D = $Bullet/BulletSprite
@onready var projectile_animation: AnimatedSprite2D = $Bullet/BulletAnimation

var hitbox_ins

func _ready() -> void:
	_prepare_for_spawn()
	_is_pooled = true

func _prepare_for_spawn() -> void:
	_reset_projectile_visual_state()
	overlapping = false
	_capture_initial_projectile_hits()
	expire_timer.wait_time = expire_time
	projectile_sprite.texture = projectile_texture
	projectile_sprite.scale = _resolve_projectile_scale()
	projectile_sprite.visible = false
	projectile_animation.sprite_frames = projectile_frames
	projectile_animation.scale = projectile_sprite.scale
	projectile_animation.visible = false
	projectile_animation.stop()
	projectile_root.position = Vector2.ZERO
	hitbox_anchor.position = Vector2.ZERO
	if projectile_root.has_method("set_logical_local_position"):
		projectile_root.call("set_logical_local_position", Vector2.ZERO)
	_clear_hitbox()
	init_hitbox(hitbox_type)
	_apply_debug_overlay()
	expire_timer.start()
	await get_tree().physics_frame
	show_projectile()

func _resolve_projectile_scale() -> Vector2:
	if desired_pixel_size != Vector2.ZERO and projectile_sprite.texture:
		var texture_size : Vector2 = projectile_sprite.texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0:
			var base_scale := Vector2(
				desired_pixel_size.x / texture_size.x,
				desired_pixel_size.y / texture_size.y
			)
			return base_scale * maxf(size, 0.01)
	return Vector2(size, size)

func init_hitbox(hb_type = "once") -> void:
	var shape = RectangleShape2D.new()
	shape.size = projectile_sprite.texture.get_size() * projectile_sprite.scale.abs()
	match hb_type:
		"dot":
			hitbox_ins = hitbox_dot.instantiate()
			hitbox_ins.dot_cd = dot_cd
		_:
			hitbox_ins = hitbox_once.instantiate()
	hitbox_ins.get_child(0).shape = shape
	hitbox_ins.set_collision_mask_value(3, true)
	hitbox_ins.hitbox_owner = self
	hitbox_anchor.call_deferred("add_child", hitbox_ins)

func _physics_process(delta: float) -> void:
	_check_wall_contact(delta)
	position += base_displacement * delta
	if base_displacement != Vector2.ZERO:
		rotation = base_displacement.angle() + deg_to_rad(90)
	hitbox_anchor.position += projectile_displacement * delta
	if projectile_root.has_method("set_logical_local_position"):
		projectile_root.call("set_logical_local_position", hitbox_anchor.position)
	else:
		projectile_root.position = hitbox_anchor.position

func enemy_hit(charge : int = 1):
	hp -= charge
	if hp <= 0:
		call_deferred("despawn")

func enemy_hit_target(charge: int = 1, target: Node = null) -> void:
	if should_preserve_projectile_durability(target):
		return
	enemy_hit(charge)

func get_projectile_pierce_capacity() -> int:
	return maxi(1, int(get_meta(INITIAL_PROJECTILE_HITS_META, hp)))

func consume_projectile_durability(charge: int = 1, target: Node = null) -> void:
	if should_preserve_projectile_durability(target):
		return
	enemy_hit(charge)

func on_hit_target(target: Node) -> void:
	if source_weapon and is_instance_valid(source_weapon):
		if source_weapon.has_method("on_projectile_hit_target"):
			source_weapon.call("on_projectile_hit_target", self, target)
		source_weapon.on_hit_target(target)

func on_hit_target_with_damage_type(target: Node, hit_damage_type: StringName) -> void:
	if source_weapon and is_instance_valid(source_weapon):
		if source_weapon.has_method("on_projectile_hit_target"):
			source_weapon.call("on_projectile_hit_target", self, target)
		if source_weapon.has_method("on_hit_target_with_damage_type"):
			source_weapon.call("on_hit_target_with_damage_type", target, hit_damage_type)
		else:
			source_weapon.on_hit_target(target)

func on_hit_target_damage_dealt(target: Node, hit_damage_type: StringName, final_damage: int) -> void:
	if source_weapon and is_instance_valid(source_weapon):
		if source_weapon.has_method("on_projectile_hit_damage_dealt"):
			source_weapon.call("on_projectile_hit_damage_dealt", self, target, hit_damage_type, final_damage)

func show_projectile() -> void:
	if projectile_frames:
		projectile_animation.visible = true
		projectile_animation.play(&"spin")
	else:
		projectile_sprite.visible = true

func _on_expire_timer_timeout() -> void:
	call_deferred("despawn")

func set_debug_snapshot(source_weapon_name: String, effect_names: Array[String], effect_params: Dictionary, overlay_enabled: bool) -> void:
	debug_source_weapon = source_weapon_name
	debug_effect_names = effect_names.duplicate()
	debug_effect_params = effect_params.duplicate(true)
	debug_overlay_enabled = overlay_enabled
	if OS.is_debug_build() and debug_overlay_enabled:
		print("[ProjectileDebug] source=", debug_source_weapon, " effects=", debug_effect_names, " params=", debug_effect_params)
	_apply_debug_overlay()

func despawn() -> void:
	if not _is_pooled:
		queue_free()
		return
	var object_pool := _get_object_pool()
	if object_pool:
		object_pool.release(self)
	else:
		queue_free()

func _on_before_pooled() -> void:
	expire_timer.stop()
	_clear_hitbox()
	_release_effects()
	module_list.clear()
	effect_list.clear()
	hp = 1
	damage = 1
	damage_type = Attack.TYPE_PHYSICAL
	knock_back = {
		"amount": 0,
		"angle": Vector2.ZERO
	}
	expire_time = DEFAULT_EXPIRE_TIME
	size = 1.0
	desired_pixel_size = Vector2.ZERO
	projectile_texture = null
	projectile_frames = null
	hitbox_type = "once"
	dot_cd = 0.0
	base_displacement = Vector2.ZERO
	projectile_displacement = Vector2.ZERO
	projectile_root.position = Vector2.ZERO
	if projectile_root.has_method("reset_projection_state"):
		projectile_root.call("reset_projection_state")
	hitbox_anchor.position = Vector2.ZERO
	if projectile_root.has_method("set_logical_local_position"):
		projectile_root.call("set_logical_local_position", Vector2.ZERO)
	projectile_sprite.scale = Vector2.ONE
	projectile_sprite.texture = null
	projectile_animation.stop()
	projectile_animation.visible = false
	projectile_animation.scale = Vector2.ONE
	projectile_animation.sprite_frames = null
	source_weapon = null
	wall_collision_mask = 0
	_wall_hit_reported = false
	overlapping = false
	position = Vector2.ZERO
	rotation = 0.0
	debug_source_weapon = ""
	debug_effect_names.clear()
	debug_effect_params.clear()
	_active_movement_controller = null
	_reset_runtime_meta_flags()
	_remove_debug_overlay()
	_reset_projectile_visual_state()

func _on_acquired_from_pool() -> void:
	visible = true
	if projectile_root != null and projectile_root.has_method("reset_projection_state"):
		projectile_root.call("reset_projection_state")

func _reset_projectile_visual_state() -> void:
	if projectile_root == null:
		return
	if projectile_root.has_method("reset_projection_state"):
		projectile_root.call("reset_projection_state")
	if projectile_root.has_method("set_logical_local_position"):
		projectile_root.call("set_logical_local_position", Vector2.ZERO)
	projectile_root.position = Vector2.ZERO
	if hitbox_anchor != null:
		hitbox_anchor.position = Vector2.ZERO
	_reset_runtime_meta_flags()
	_wall_hit_reported = false

func _check_wall_contact(delta: float) -> void:
	if wall_collision_mask <= 0:
		return
	if _wall_hit_reported:
		return
	if not is_inside_tree():
		return
	var motion: Vector2 = (base_displacement + projectile_displacement) * maxf(delta, 0.0)
	if motion.length_squared() <= 0.01:
		return
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, wall_collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	_wall_hit_reported = true
	if source_weapon and is_instance_valid(source_weapon) and source_weapon.has_method("on_projectile_hit_wall"):
		source_weapon.call("on_projectile_hit_wall", self, result)

func _clear_hitbox() -> void:
	if hitbox_ins and is_instance_valid(hitbox_ins):
		hitbox_ins.queue_free()
	hitbox_ins = null

func _release_effects() -> void:
	var children := get_children()
	for child in children:
		if child == projectile_root or child == expire_timer:
			continue
		if child is Label:
			continue
		if child is Effect:
			# Give effects a deterministic despawn hook before they are released.
			if child.has_method("on_projectile_will_despawn"):
				child.call("on_projectile_will_despawn")
			if bool(child.get_meta("_pool_enabled", false)):
				var object_pool := _get_object_pool()
				if object_pool:
					object_pool.release(child)
				else:
					child.queue_free()
			else:
				child.queue_free()
		else:
			child.queue_free()

func _apply_debug_overlay() -> void:
	if not OS.is_debug_build():
		return
	if not debug_overlay_enabled:
		_remove_debug_overlay()
		return
	if _debug_label == null or not is_instance_valid(_debug_label):
		_debug_label = Label.new()
		_debug_label.name = "DebugOverlay"
		_debug_label.z_index = 99
		_debug_label.position = Vector2(16, -18)
		add_child(_debug_label)
	_debug_label.text = "%s | %s" % [debug_source_weapon, ",".join(debug_effect_names)]
	_debug_label.visible = true

func _remove_debug_overlay() -> void:
	if _debug_label and is_instance_valid(_debug_label):
		_debug_label.queue_free()
	_debug_label = null

func _get_object_pool() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var root := tree.root
	if root == null:
		return null
	return root.get_node_or_null("ObjectPool")

func _reset_runtime_meta_flags() -> void:
	var keep_meta: Dictionary = {
		"_pool_scene_key": true,
	}
	for meta_key_variant in get_meta_list():
		var meta_key := str(meta_key_variant)
		if keep_meta.has(meta_key):
			continue
		remove_meta(meta_key)

func should_preserve_projectile_durability(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("has_mark"):
		return false
	return bool(target.call("has_mark", PISTOL_PIERCE_MARK_ID))

func _capture_initial_projectile_hits() -> void:
	set_meta(INITIAL_PROJECTILE_HITS_META, maxi(1, hp))

func claim_movement_control(controller: Node) -> void:
	if controller == null:
		return
	_active_movement_controller = controller

func has_movement_control(controller: Node) -> bool:
	if controller == null:
		return false
	if _active_movement_controller == null or not is_instance_valid(_active_movement_controller):
		_active_movement_controller = controller
	return _active_movement_controller == controller
