extends Node2D
class_name Projectile

var hp : int = 1
var damage = 1
var knock_back = {
	"amount": 0,
	"angle": Vector2.ZERO
}
var expire_time : float = 2.5
var base_displacement = Vector2.ZERO
var projectile_displacement = Vector2.ZERO
var projectile_texture
var size : float = 1.0
var desired_pixel_size : Vector2 = Vector2.ZERO
var module_list = []
var effect_list = []
var source_weapon: Weapon
var hitbox_type = "once"
var dot_cd : float
var _is_pooled: bool = false
var debug_source_weapon: String = ""
var debug_effect_names: Array[String] = []
var debug_effect_params: Dictionary = {}
@export var debug_overlay_enabled: bool = false
var _debug_label: Label
var overlapping : bool :
	set(value):
		if value != overlapping:
			overlapping = value
			overlapping_signal.emit()

# Signals
signal overlapping_signal()

# Preloads
@onready var hitbox_once = preload("res://Utility/hit_hurt_box/hit_box.tscn")
@onready var hitbox_dot = preload("res://Utility/hit_hurt_box/hit_box_dot.tscn")

# Children
@onready var expire_timer = $ExpireTimer
@onready var projectile_root: Node2D = $Bullet
@onready var projectile_sprite: Sprite2D = $Bullet/BulletSprite

var hitbox_ins

func _ready() -> void:
	_prepare_for_spawn()
	_is_pooled = true

func _prepare_for_spawn() -> void:
	overlapping = false
	expire_timer.wait_time = expire_time
	projectile_sprite.texture = projectile_texture
	projectile_sprite.scale = _resolve_projectile_scale()
	projectile_root.position = Vector2.ZERO
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
			return Vector2(
				desired_pixel_size.x / texture_size.x,
				desired_pixel_size.y / texture_size.y
			)
	return Vector2(size, size)

func init_hitbox(hb_type = "once") -> void:
	var shape = RectangleShape2D.new()
	shape.size = projectile_sprite.texture.get_size()
	match hb_type:
		"dot":
			hitbox_ins = hitbox_dot.instantiate()
			hitbox_ins.dot_cd = dot_cd
		_:
			hitbox_ins = hitbox_once.instantiate()
	hitbox_ins.get_child(0).shape = shape
	hitbox_ins.set_collision_mask_value(3, true)
	hitbox_ins.hitbox_owner = self
	projectile_sprite.call_deferred("add_child", hitbox_ins)

func _physics_process(delta: float) -> void:
	position += base_displacement * delta
	if base_displacement != Vector2.ZERO:
		rotation = base_displacement.angle() + deg_to_rad(90)
	projectile_root.position += projectile_displacement * delta

func enemy_hit(charge : int = 1):
	hp -= charge
	if hp <= 0:
		call_deferred("despawn")

func on_hit_target(target: Node) -> void:
	if source_weapon and is_instance_valid(source_weapon):
		source_weapon.on_hit_target(target)

func show_projectile() -> void:
	projectile_sprite.visible = true

func _on_expire_timer_timeout() -> void:
	call_deferred("despawn")

func set_debug_snapshot(source_weapon_name: String, effect_names: Array[String], effect_params: Dictionary, overlay_enabled: bool) -> void:
	debug_source_weapon = source_weapon_name
	debug_effect_names = effect_names.duplicate()
	debug_effect_params = effect_params.duplicate(true)
	debug_overlay_enabled = overlay_enabled
	if OS.is_debug_build():
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
	base_displacement = Vector2.ZERO
	projectile_displacement = Vector2.ZERO
	projectile_root.position = Vector2.ZERO
	source_weapon = null
	overlapping = false
	_remove_debug_overlay()

func _on_acquired_from_pool() -> void:
	visible = true

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
