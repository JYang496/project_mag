extends Effect
class_name ExplosionEffect

@onready var area_effect_scene = preload("res://Utility/area_effect/area_effect.tscn")
@export var damage = 10
@export var explosion_size = 2.0
@export var base_radius: float = 24.0
@export var duration: float = 0.1
@export var area_tick_damage: int = 0
@export var area_tick_interval: float = 0.4
@export var visual_enabled: bool = true
@export var use_animated_visual: bool = false
@export var visual_texture: Texture2D = preload("res://Textures/test/bullet.png")
@export var visual_frames: SpriteFrames
@export var visual_animation: StringName = &"default"
@export var visual_playback_speed: float = 1.0
@export var visual_modulate: Color = Color(1.0, 0.55, 0.2, 0.45)
@export var visual_rotation_speed_deg: float = 240.0
@export var visual_size_multiplier: float = 1.0
var oc_mode : bool = false

func projectile_effect_ready() -> void:
	projectile.tree_exiting.connect(_on_parent_exiting)
	projectile.tree_exited.connect(_on_parent_exited)	

func _on_parent_exiting() -> void:
	var area_effect := area_effect_scene.instantiate() as AreaEffect
	area_effect.one_shot_damage = damage
	area_effect.tick_damage = area_tick_damage
	area_effect.tick_interval = area_tick_interval
	area_effect.radius = maxf(base_radius * explosion_size, 1.0)
	area_effect.duration = duration
	area_effect.target_group = AreaEffect.TargetGroup.ENEMIES
	area_effect.visual_enabled = visual_enabled
	area_effect.use_animated_visual = use_animated_visual
	area_effect.visual_texture = visual_texture
	area_effect.visual_frames = visual_frames
	area_effect.visual_animation = visual_animation
	area_effect.visual_playback_speed = visual_playback_speed
	area_effect.visual_modulate = visual_modulate
	area_effect.visual_rotation_speed_deg = visual_rotation_speed_deg
	area_effect.visual_size_multiplier = visual_size_multiplier
	var source_weapon_value: Variant = projectile.get("source_weapon")
	if source_weapon_value != null and source_weapon_value is Node:
		area_effect.source_node = source_weapon_value
	else:
		area_effect.source_node = projectile
	area_effect.global_position = global_position
	var spawn_parent: Node = projectile.get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = projectile.get_tree().root
	spawn_parent.call_deferred("add_child", area_effect)
	

func _on_parent_exited() -> void:
	pass
