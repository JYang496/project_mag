extends Control
class_name PassiveChargeBeans

@export var current_charges: int = 0:
	set(value):
		current_charges = maxi(0, value)
		queue_redraw()

@export var max_charges: int = 0:
	set(value):
		max_charges = maxi(0, value)
		queue_redraw()

@export var filled_color: Color = Color(1.0, 0.88, 0.34, 0.96)
@export var empty_color: Color = Color(0.34, 0.35, 0.36, 0.55)
@export var outline_color: Color = Color(0.08, 0.08, 0.08, 0.7)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var charge_max := maxi(max_charges, 0)
	if charge_max <= 0:
		return
	var dot_radius := minf(size.y * 0.38, 3.0)
	if dot_radius <= 0.5:
		return
	var gap := maxf(dot_radius * 0.9, 2.0)
	var total_width := float(charge_max) * dot_radius * 2.0 + float(charge_max - 1) * gap
	var start_x := (size.x - total_width) * 0.5 + dot_radius
	var center_y := size.y * 0.5
	var filled_count := clampi(current_charges, 0, charge_max)
	for index in range(charge_max):
		var center := Vector2(start_x + float(index) * (dot_radius * 2.0 + gap), center_y)
		draw_circle(center, dot_radius + 1.0, outline_color)
		draw_circle(center, dot_radius, filled_color if index < filled_count else empty_color)
