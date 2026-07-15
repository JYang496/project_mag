extends Node2D

@export var radius := 70.0
@export var visual_modulate := Color(0.22, 0.68, 0.82, 0.18)
@export var ground_height_offset := 0.0

# Hybrid ground area contract.
var visual_enabled := true
var use_animated_visual := false
var animated_visual_is_ground := false
var visual_shape := 0
var draw_enabled := false
var debug_fill_color := Color.TRANSPARENT
var ground_detail_texture: Texture2D
var ground_detail_color := Color.WHITE
var ground_detail_scale := Vector2.ONE
var ground_flow_speed := Vector2.ZERO
var ground_uv_distortion := 0.0
var visual_texture: Texture2D

func _ready() -> void:
	HybridGroundRegistration.register(self, &"register_area_effect")

func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)
