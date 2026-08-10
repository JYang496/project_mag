extends Node2D
class_name EliteDeathGroundPulse

const DURATION_SEC := 0.62
var age_sec := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"hybrid_enemy_aura_source")
	call_deferred("_register_ground_visual")
	queue_redraw()


func _process(delta: float) -> void:
	age_sec += maxf(delta, 0.0)
	if age_sec >= DURATION_SEC:
		queue_free()
		return
	queue_redraw()


func get_hybrid_aura_visual() -> Dictionary:
	var progress := clampf(age_sec / DURATION_SEC, 0.0, 1.0)
	var color := Color(1.0, 0.76, 0.22, (1.0 - progress) * 0.82)
	return {
		"visible": progress < 1.0,
		"radius": lerpf(18.0, 92.0, 1.0 - pow(1.0 - progress, 2.0)),
		"line_width": lerpf(4.0, 1.0, progress),
		"line_color": color,
		"fill_color": Color(color.r, color.g, color.b, color.a * 0.05),
		"relationship_kind": &"elite_death_pulse",
	}


func _register_ground_visual() -> void:
	HybridGroundRegistration.register(self, &"register_enemy_support_visual")


func _draw() -> void:
	if bool(get_meta(&"hybrid_ground_registered", false)):
		return
	var config := get_hybrid_aura_visual()
	draw_arc(Vector2.ZERO, float(config.get("radius")), 0.0, TAU, 48, config.get("line_color") as Color, float(config.get("line_width")), false)


func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)
