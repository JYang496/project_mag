extends MeshInstance2D

const REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")
const NOISE := preload("res://Combat/visual/trail_surface_noise.tres")
const SHADER_2D := preload("res://Shaders/trail_surface_2d.gdshader")
const SHADER_3D := preload("res://Shaders/trail_surface_3d.gdshader")
const CAPACITY := 64

var ground_material: ShaderMaterial
var bounds := Rect2()
var enabled := false
var mote_material: ShaderMaterial
var mote_samples := PackedVector4Array()
var geometry_version := 0
var _last_ids := PackedInt64Array()

func _init() -> void:
	top_level = true
	visible = false
	mesh = QuadMesh.new()
	material = ShaderMaterial.new()
	material.shader = SHADER_2D
	material.set_shader_parameter("surface_noise", NOISE)
	ground_material = ShaderMaterial.new()
	ground_material.shader = SHADER_3D
	ground_material.render_priority = 29
	ground_material.set_shader_parameter("surface_noise", NOISE)
	mote_material = ShaderMaterial.new()
	mote_material.shader = preload("res://Shaders/trail_motes_3d.gdshader")
	mote_material.render_priority = 30
	mote_material.set_shader_parameter("surface_noise", NOISE)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _exit_tree() -> void:
	REGISTRATION.unregister(self)

func update_surface(active: Array[Dictionary], retired: Array[Dictionary], style: int, show_surface: bool) -> void:
	if active.is_empty() and retired.is_empty() and not enabled:
		return
	var records: Array[Dictionary] = []
	records.append_array(retired)
	records.append_array(active)
	var endpoints := PackedVector4Array()
	var timing := PackedVector4Array()
	endpoints.resize(CAPACITY)
	timing.resize(CAPACITY)
	var first := maxi(records.size() - CAPACITY, 0)
	var count := records.size() - first
	var ids := PackedInt64Array()
	for record in active:
		ids.append(int(record["id"]))
	bounds = Rect2()
	for index in range(count):
		var record := records[first + index]
		var a: Vector2 = record["from"]
		var b: Vector2 = record["to"]
		var radius: float = record["radius"]
		var rect := Rect2(a, Vector2.ZERO).expand(b).grow(radius + 6.0)
		bounds = rect if index == 0 else bounds.merge(rect)
		endpoints[index] = Vector4(a.x, a.y, b.x, b.y)
		timing[index] = Vector4(radius, float(record["born_at_msec"]) / 1000.0, float(record["expires_at_msec"]) / 1000.0, 0.0)
	enabled = show_surface and count > 0
	if ids != _last_ids:
		_last_ids = ids
		_rebuild_mote_samples(active)
		geometry_version += 1
	position = bounds.get_center()
	(mesh as QuadMesh).size = bounds.size.max(Vector2.ONE)
	for target in [material, ground_material]:
		target.set_shader_parameter("segments", endpoints)
		target.set_shader_parameter("lives", timing)
		target.set_shader_parameter("segment_total", count)
		target.set_shader_parameter("trail_style", style)
		target.set_shader_parameter("clock_sec", float(Time.get_ticks_msec()) / 1000.0)
		target.set_shader_parameter("surface_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
	visible = enabled and not REGISTRATION.register(self, &"register_ground_trail")
	mote_material.set_shader_parameter("trail_style", style)
	mote_material.set_shader_parameter("clock_sec", float(Time.get_ticks_msec()) / 1000.0)

func _rebuild_mote_samples(active: Array[Dictionary]) -> void:
	mote_samples.clear()
	if active.is_empty():
		return
	# Fixed world grid prevents flickering/reseeding when an emitter moves.
	var spacing := 30.0
	var cells_checked := 0
	for y in range(int(floor(bounds.position.y / spacing)), int(ceil(bounds.end.y / spacing))):
		for x in range(int(floor(bounds.position.x / spacing)), int(ceil(bounds.end.x / spacing))):
			# Decoration work stays bounded even for separated high-speed projectiles.
			cells_checked += 1
			if cells_checked > 1024:
				return
			var point := Vector2((float(x) + 0.5) * spacing, (float(y) + 0.5) * spacing)
			point += Vector2(sin(float(x * 7 + y * 3)), cos(float(x * 3 - y * 5))) * 7.0
			var expiry := 0.0
			var birth := 0.0
			for record in active:
				var a: Vector2 = record["from"]
				var b: Vector2 = record["to"]
				var nearest := Geometry2D.get_closest_point_to_segment(point, a, b) if a != b else a
				if point.distance_squared_to(nearest) < pow(float(record["radius"]) * 0.82, 2.0):
					expiry = maxf(expiry, float(record["expires_at_msec"]) / 1000.0)
					birth = float(record["born_at_msec"]) / 1000.0
			if expiry > 0.0:
				mote_samples.append(Vector4(point.x, point.y, birth, expiry))
			if mote_samples.size() >= 96:
				return
