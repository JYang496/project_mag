extends Node2D

const CONTAINMENT := &"containment"
const PURPLE_RIFT := Color(0.55, 0.12, 0.72, 0.28)
const CYAN_STABILIZE := Color(0.20, 0.88, 1.0, 0.82)
const ORANGE_CONTEST := Color(1.0, 0.38, 0.12, 0.88)

@export var radius := 70.0
@export var rectangle_size := Vector2(140.0, 140.0)
@export var visual_modulate := Color(0.22, 0.68, 0.82, 0.18)
@export var ground_height_offset := 0.0

# Hybrid ground area contract.
var visual_enabled := true
var use_animated_visual := false
var animated_visual_is_ground := true
var visual_shape := 1
var draw_enabled := false
var debug_fill_color := Color.TRANSPARENT
var ground_detail_texture: Texture2D
var ground_detail_color := Color.WHITE
var ground_detail_scale := Vector2.ONE
var ground_flow_speed := Vector2.ZERO
var ground_uv_distortion := 0.0
var visual_texture: Texture2D
var visual_kind: StringName = &"operation"
var progress := 0.0
var player_inside := false
var enemy_count := 0
var completed := false
var completion_elapsed := 0.0
var _elapsed := 0.0

func _ready() -> void:
	if visual_kind == CONTAINMENT:
		ground_detail_texture = _build_data_projection_texture()
		ground_detail_scale = Vector2(2.0, 2.0)
		ground_flow_speed = Vector2(0.04, -0.025)
		ground_uv_distortion = 0.012
	_apply_visual_state()
	HybridGroundRegistration.register(self, &"register_area_effect")

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if completed:
		completion_elapsed += maxf(delta, 0.0)
	_apply_visual_state()

func configure_style(kind: StringName) -> void:
	visual_kind = kind
	_apply_visual_state()

func set_state(value: float, inside: bool, enemies: int, is_completed: bool = false) -> void:
	progress = clampf(value, 0.0, 1.0)
	player_inside = inside
	enemy_count = maxi(enemies, 0)
	if is_completed and not completed:
		completed = true
		completion_elapsed = 0.0
	_apply_visual_state()

func get_visual_state_snapshot() -> Dictionary:
	return {"base_color": visual_modulate, "detail_color": ground_detail_color, "progress": progress, "player_inside": player_inside, "enemy_count": enemy_count, "completed": completed, "completion_elapsed": completion_elapsed}

func _apply_visual_state() -> void:
	if visual_kind != CONTAINMENT:
		return
	if completed:
		var ratio := clampf(completion_elapsed / 0.72, 0.0, 1.0)
		var flash_color := Color.WHITE.lerp(CYAN_STABILIZE, smoothstep(0.18, 0.62, ratio))
		flash_color.a = (1.0 - smoothstep(0.46, 1.0, ratio)) * 0.64
		visual_modulate = flash_color
		ground_detail_color = Color(CYAN_STABILIZE.r, CYAN_STABILIZE.g, CYAN_STABILIZE.b, flash_color.a)
		ground_flow_speed = Vector2(0.16, -0.12) * (1.0 - ratio)
		return
	var stable_ratio := clampf(progress, 0.0, 1.0)
	visual_modulate = PURPLE_RIFT.lerp(Color(0.12, 0.36, 0.46, 0.24), stable_ratio * 0.55)
	var cyan_alpha := 0.16 + stable_ratio * 0.54
	if player_inside:
		cyan_alpha = maxf(cyan_alpha, 0.52)
	ground_detail_color = Color(CYAN_STABILIZE.r, CYAN_STABILIZE.g, CYAN_STABILIZE.b, cyan_alpha)
	ground_flow_speed = Vector2(0.07, -0.045) if player_inside else Vector2(0.025, -0.018)
	if enemy_count > 0:
		var contest_pulse := 0.62 + 0.20 * (0.5 + 0.5 * sin(_elapsed * 7.0))
		ground_detail_color = Color(ORANGE_CONTEST.r, ORANGE_CONTEST.g, ORANGE_CONTEST.b, contest_pulse)
		ground_flow_speed = Vector2(0.13, -0.10)

func _build_data_projection_texture() -> Texture2D:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(size, size) * 0.5
	for y in range(size):
		for x in range(size):
			var point := Vector2(x, y)
			var distance := point.distance_to(center)
			var ring := absf(distance - 22.0) <= 1.0 or absf(distance - 15.0) <= 0.75
			var scan := y % 8 == 0 and x >= 10 and x <= 54
			var segment := ring and posmod(int(atan2(point.y - center.y, point.x - center.x) * 12.0), 4) != 0
			if segment or scan:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.72 if segment else 0.22))
	return ImageTexture.create_from_image(image)

func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)
