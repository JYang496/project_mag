extends RefCounted
## Presentation-only pictograms keyed by the active skill effect, in a 28px grid.
const PATHS := {
	"machine_gun_infinite_chain": [[[2,12],[6,8],[10,8],[18,16],[22,16],[26,12],[22,8],[18,8],[10,16],[6,16],[2,12]],[[6,21],[22,21]]],
	"charged_blaster_prism_overload": [[[1,14],[10,14]],[[10,14],[15,5],[20,14],[15,23],[10,14]],[[20,14],[27,5]],[[20,14],[28,14]],[[20,14],[27,23]]],
	"spear_phalanx": [[[6,25],[6,5]],[[2,10],[6,3],[10,10]],[[14,25],[14,2]],[[10,7],[14,0],[18,7]],[[22,25],[22,5]],[[18,10],[22,3],[26,10]]],
	"shotgun_double_discipline": [[[5,23],[5,7],[9,3],[13,7],[13,23],[5,23]],[[17,23],[17,7],[21,3],[25,7],[25,23],[17,23]],[[5,19],[13,19]],[[17,19],[25,19]]],
	"orbit_proliferation": [[[10,14],[14,10],[18,14],[14,18],[10,14]]],
	"rocket_cluster_warhead": [[[10,4],[14,0],[18,4],[18,11],[14,15],[10,11],[10,4]],[[14,15],[14,21]],[[11,15],[5,21]],[[17,15],[23,21]]],
	"laser_refraction_matrix": [[[0,14],[12,14],[26,3]],[[12,14],[28,14]],[[12,14],[26,25]],[[8,10],[12,14],[8,18]]],
	"chainsaw_cage": [[[3,3],[25,3],[25,25],[3,25],[3,3]],[[8,0],[8,6]],[[20,0],[20,6]],[[8,22],[8,28]],[[20,22],[20,28]],[[0,8],[6,8]],[[22,20],[28,20]],[[11,19],[17,9],[17,15],[21,15]]],
	"dash_rift": [[[2,23],[11,14],[8,10],[24,2],[17,13],[20,17],[10,26]],[[0,14],[5,14]],[[2,19],[7,19]]],
	"flame_moving_inferno": [[[14,1],[7,12],[6,18],[11,23],[18,22],[23,14],[16,17],[14,1]],[[1,27],[11,27]],[[16,27],[27,27]]],
	"plasma_storm": [[[4,10],[8,4],[18,3],[25,10],[24,19],[18,25],[8,24],[2,18]],[[11,10],[18,9],[17,15],[22,15],[11,23],[13,16],[8,16],[11,10]]],
	"glacier_white_frost_domain": [[[14,2],[14,24]],[[4,7],[24,19]],[[4,19],[24,7]],[[10,3],[14,7],[18,3]],[[10,23],[14,19],[18,23]],[[1,27],[27,27]]],
	"cannon_siege_trajectory": [[[2,21],[6,10],[12,5],[20,6],[25,13]],[[20,13],[26,13],[26,19],[20,19],[20,13]],[[17,25],[21,21]],[[24,27],[24,23]],[[28,24],[27,21]]],
	"sniper_lethal_aim": [[[14,0],[14,8]],[[14,20],[14,28]],[[0,14],[8,14]],[[20,14],[28,14]],[[10,18],[18,10]]],
}

static func draw_icon(canvas: CanvasItem, effect_id: String, origin: Vector2, color: Color) -> void:
	canvas.draw_set_transform(origin)
	var paths: Array = PATHS.get(effect_id, [[[4,14],[14,4],[24,14],[14,24],[4,14]]])
	for raw: Array in paths:
		var points := PackedVector2Array()
		for point: Array in raw:
			points.append(Vector2(point[0], point[1]))
		canvas.draw_polyline(points, Color(0.015,0.03,0.04,0.9), 4.0, true)
		canvas.draw_polyline(points, color, 2.0, true)
	if effect_id == "orbit_proliferation":
		canvas.draw_arc(Vector2(14,14), 10, 0, TAU, 32, color, 1.5, true)
		for i in range(3):
			canvas.draw_circle(Vector2(14,14) + Vector2.from_angle(i * TAU / 3.0) * 11, 3, color)
	elif effect_id == "sniper_lethal_aim":
		canvas.draw_arc(Vector2(14,14), 9, 0, TAU, 32, color, 1.5, true)
	elif effect_id == "rocket_cluster_warhead":
		for x in [4,14,24]:
			canvas.draw_circle(Vector2(x,24), 2, color)
	canvas.draw_set_transform(Vector2.ZERO)
