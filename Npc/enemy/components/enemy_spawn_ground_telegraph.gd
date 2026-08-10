extends Node2D
class_name EnemySpawnGroundTelegraph

const WARNING_COLOR := Color(1.0, 0.67, 0.18, 0.92)
const MATERIALIZE_COLOR := Color(0.52, 0.92, 1.0, 0.86)

var progress := 0.0
var telegraph_ratio := 0.32
var radius := 42.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"hybrid_enemy_aura_source")
	call_deferred("_register_ground_visual")
	queue_redraw()


func configure(visual_radius: float) -> void:
	radius = clampf(visual_radius, 28.0, 72.0)
	queue_redraw()


func set_sequence_progress(value: float, warning_ratio: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	telegraph_ratio = clampf(warning_ratio, 0.1, 0.8)
	queue_redraw()


func get_hybrid_aura_visual() -> Dictionary:
	var warning_phase := progress < telegraph_ratio
	var phase_progress := progress / telegraph_ratio if warning_phase else (progress - telegraph_ratio) / maxf(1.0 - telegraph_ratio, 0.01)
	var line_color := WARNING_COLOR if warning_phase else WARNING_COLOR.lerp(MATERIALIZE_COLOR, phase_progress)
	var fill_color := line_color
	fill_color.a = 0.07 + (1.0 - absf(phase_progress * 2.0 - 1.0)) * 0.06
	return {
		"visible": progress < 1.0,
		"radius": radius * (1.08 - phase_progress * 0.08),
		"line_width": 3.0 if warning_phase else 2.0,
		"line_color": line_color,
		"fill_color": fill_color,
		"detail_color": Color(line_color, line_color.a * 0.55),
		"detail_width": 1.0,
		"relationship_kind": &"elite_spawn_warning",
	}


func _register_ground_visual() -> void:
	HybridGroundRegistration.register(self, &"register_enemy_support_visual")


func _draw() -> void:
	if bool(get_meta(&"hybrid_ground_registered", false)) or progress >= 1.0:
		return
	var config := get_hybrid_aura_visual()
	var draw_color := config.get("line_color") as Color
	draw_arc(Vector2.ZERO, float(config.get("radius")), 0.0, TAU, 48, draw_color, float(config.get("line_width")), false)


func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)
