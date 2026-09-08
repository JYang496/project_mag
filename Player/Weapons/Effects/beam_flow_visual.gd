extends Node2D

## Canvas accent follows logical endpoints, including the hybrid ground camera.
var start := Vector2.ZERO
var finish := Vector2.ZERO
var chain := false
var phase_offset := 0.0
var age := 0.0
var active := false
var body_width := 4.0
var body_color := Color(0.3, 0.6, 1.0, 0.28)

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var a := start
	var b := finish
	var view := get_tree().get_first_node_in_group(&"hybrid_ground_view_3d")
	if view != null:
		if not view.call("can_project_world_point", a) or not view.call("can_project_world_point", b):
			return
		a = view.call("project_world_to_canvas", a, get_viewport())
		b = view.call("project_world_to_canvas", b, get_viewport())
	a = to_local(a).round()
	b = to_local(b).round()
	var axis := b - a
	var side := axis.normalized().orthogonal()
	var pulse := fposmod(age * 2.5 - phase_offset, 1.0)
	if chain:
		var points := PackedVector2Array([a, (a + axis * 0.33 + side * 4).round(), (a + axis * 0.67 - side * 4).round(), b])
		draw_polyline(points, body_color, body_width)
		draw_polyline(points, Color(0.58,0.87,1,0.55 + pulse * 0.35), 2)
		draw_rect(Rect2(b - Vector2(2,2),Vector2(4,4)),Color(0.8,0.96,1,0.8))
		var segment := mini(int(pulse * 3.0), 2)
		var head := points[segment].lerp(points[segment + 1], fposmod(pulse * 3.0, 1.0)).round()
		draw_rect(Rect2(head - Vector2.ONE, Vector2(2,2)), Color.WHITE)
		return
	else:
		draw_line(a,b,Color(0.95,1,1,0.8),1)
	var head := a.lerp(b,pulse).round()
	draw_line(head, (head-axis.normalized()*minf(axis.length()*0.1,12)).round(),Color.WHITE,2)
