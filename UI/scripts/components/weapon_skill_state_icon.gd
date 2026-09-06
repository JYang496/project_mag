extends Control
## Skill identity, condition fill, and cooldown are independent visual channels.
const PICTOGRAMS := preload("res://UI/scripts/components/weapon_skill_pictograms.gd")
var state := "disabled"
var effect_id := ""
var progress := 0.0
var cooldown_progress := 1.0
var cooling := false
var energy_blocked := false
var active := false

func set_effect_id(value: String) -> void:
	if value != effect_id:
		effect_id = value
		queue_redraw()

func set_status(status: Dictionary) -> void:
	var next := "disabled"
	var available := bool(status.get("available", false))
	var next_cooling := float(status.get("cooldown_remaining", 0.0)) > 0.0
	var next_energy := not bool(status.get("has_energy", true)) and bool(status.get("unlock_ready", false))
	var next_progress := 1.0 if bool(status.get("unlock_ready", false)) else clampf(float(status.get("unlock_progress", 0.0)), 0.0, 1.0)
	var next_cooldown := clampf(float(status.get("cooldown_progress", 1.0)), 0.0, 1.0)
	var next_active := bool(status.get("active", false))
	if available:
		next = "ready" if bool(status.get("ready", false)) else "building"
		if not bool(status.get("ready", false)):
			if next_cooling:
				next = "cooldown"
			elif next_energy:
				next = "energy"
	if state == next and is_equal_approx(progress, next_progress) and is_equal_approx(cooldown_progress, next_cooldown) and cooling == next_cooling and energy_blocked == next_energy and active == next_active:
		return
	state = next
	progress = next_progress
	cooldown_progress = next_cooldown
	cooling = next_cooling
	energy_blocked = next_energy
	active = next_active
	queue_redraw()

func _draw() -> void:
	var center := Vector2(24,24)
	draw_circle(center + Vector2(0,1), 23, Color(0.005,0.015,0.02,0.45))
	draw_circle(center, 21, Color(0.015,0.035,0.045,0.96))
	if state != "disabled" and progress > 0.001:
		var fill := Color("326858") if state == "ready" else Color("655432")
		if progress >= 0.999:
			draw_circle(center, 19, fill)
		else:
			var theta := asin(1.0 - 2.0 * progress)
			var points := PackedVector2Array()
			for i in range(49):
				var angle := theta + (PI - 2.0 * theta) * i / 48.0
				points.append(center + Vector2(cos(angle),sin(angle)) * 19)
			draw_colored_polygon(points, fill)
	draw_arc(center, 20, 0, TAU, 48, Color("b9e7dc") if active or state == "ready" else Color("71878d"), 2.0 if active else 1.0, true)
	draw_arc(center, 18.5, PI * 1.1, PI * 1.65, 20, Color(0.83,0.95,1.0,0.13), 1.0, true)
	PICTOGRAMS.draw_icon(self, effect_id, Vector2(10,10), Color("f2f7f6") if state != "disabled" else Color("6c787d"))
	if cooling:
		draw_arc(center, 23, 0, TAU, 48, Color("304a56"), 2.0, true)
		if cooldown_progress > 0.001:
			draw_arc(center, 23, -PI/2, -PI/2 + TAU * cooldown_progress, 48, Color("72c9f5"), 2.0, true)
			var tip := center + Vector2.from_angle(-PI/2 + TAU * cooldown_progress) * 23
			draw_circle(tip, 1.5, Color("d3f3ff"))
	if energy_blocked and state != "disabled":
		draw_circle(Vector2(43,8), 7, Color("192c33"))
		draw_colored_polygon(PackedVector2Array([Vector2(44,1),Vector2(38,9),Vector2(42,9),Vector2(40,15),Vector2(48,6),Vector2(44,6)]), Color("f4bc53"))
	if state == "disabled":
		draw_line(Vector2(10,38), Vector2(38,10), Color("95a4ab"), 2.0, true)
