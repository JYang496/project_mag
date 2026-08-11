extends Node2D

const FLAME_VFX := preload("res://Player/Weapons/Effects/cone_spray_vfx.tscn")
const HIT_LABEL := preload("res://UI/labels/hit_label.tscn")

var _time := 0.0
var _sprays: Array[ConeSprayVfx] = []
var _spray_origins: Array[Vector2] = []
var _spray_ranges: Array[float] = []
var _spray_angles: Array[float] = []
var _titles: Dictionary = {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#080d14"))
	_spawn_case(Vector2(88, 190), 190.0, 30.0, [40], "SINGLE TARGET")
	_spawn_case(Vector2(710, 205), 350.0, 30.0, [18, 22, 16], "GROUP HIT")
	_spawn_case(Vector2(88, 505), 220.0, 34.0, [72], "SUSTAINED / MERGED")
	_spawn_density_case()
	queue_redraw()
	_capture_if_requested()


func _process(delta: float) -> void:
	_time += delta
	for index in _sprays.size():
		var direction := Vector2.RIGHT
		if index == 2:
			direction = direction.rotated(sin(_time * 1.7) * 0.08)
		_sprays[index].start_or_refresh(_spray_origins[index], direction, _spray_ranges[index], _spray_angles[index])
	queue_redraw()


func _spawn_case(origin: Vector2, range_value: float, half_angle: float, damages: Array[int], title: String) -> void:
	var spray := FLAME_VFX.instantiate() as ConeSprayVfx
	spray.z_index = -2
	add_child(spray)
	spray.start_or_refresh(origin, Vector2.RIGHT, range_value, half_angle)
	_sprays.append(spray)
	_spray_origins.append(origin)
	_spray_ranges.append(range_value)
	_spray_angles.append(half_angle)
	for index in damages.size():
		var ratio := 0.58 + float(index) * 0.12
		var angle := 0.0
		if damages.size() > 1:
			angle = deg_to_rad(lerpf(-half_angle * 0.55, half_angle * 0.55, float(index) / float(damages.size() - 1)))
		var target_position := origin + Vector2.RIGHT.rotated(angle) * range_value * ratio
		_spawn_target(target_position, damages[index], index == 0 and title != "GROUP HIT", false)
	_titles[title] = origin + Vector2(-6, -88)


func _spawn_density_case() -> void:
	var origin := Vector2(730, 505)
	for row in range(3):
		for column in range(5):
			var target_position := Vector2(810 + column * 72, 420 + row * 62)
			_spawn_target(target_position, 5 + (row + column) % 4, false, true)
	var spray := FLAME_VFX.instantiate() as ConeSprayVfx
	spray.z_index = -2
	add_child(spray)
	spray.start_or_refresh(origin, Vector2.RIGHT, 420.0, 25.0)
	_sprays.append(spray)
	_spray_origins.append(origin)
	_spray_ranges.append(420.0)
	_spray_angles.append(25.0)
	_titles["HIGH DENSITY"] = origin + Vector2(-6, -88)


func _spawn_target(target_position: Vector2, damage: int, critical: bool, periodic: bool) -> void:
	var target := ColorRect.new()
	target.position = (target_position - Vector2(12, 12)).round()
	target.size = Vector2(24, 24)
	target.color = Color("#68b7c6")
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(target)
	var label := HIT_LABEL.instantiate()
	label.z_index = 10
	label.fade_duration = 999.0
	label.position = target_position + Vector2(0, -25)
	label.configure({
		"final_damage": damage,
		"damage_type": Attack.TYPE_FIRE,
		"target_max_hp": 1000,
		"is_critical": critical,
		"is_periodic": periodic,
	})
	add_child(label)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(48, 48), "COMBAT READABILITY — FLAME LAYERS + TARGET-WINDOW DAMAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#d7edf2"))
	draw_string(font, Vector2(48, 76), "Low-opacity range cue / translucent body / bright core. Gameplay range and damage are unchanged.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#81a7b0"))
	for title in _titles:
		draw_string(font, _titles[title] as Vector2, String(title), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ff9a42"))
	draw_line(Vector2(640, 110), Vector2(640, 690), Color("#203441"), 1.0)
	draw_line(Vector2(48, 350), Vector2(1232, 350), Color("#203441"), 1.0)


func _exit_tree() -> void:
	for spray in _sprays:
		if spray != null and is_instance_valid(spray):
			spray.cleanup_for_battle_end()


func _capture_if_requested() -> void:
	if not OS.get_cmdline_user_args().has("--capture-showcase-vfx"):
		return
	for _frame in range(4):
		await get_tree().process_frame
	var output_directory := ProjectSettings.globalize_path("res://output/showcases/vfx")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var capture_path := output_directory.path_join("combat_readability_showcase.png")
	var error := get_viewport().get_texture().get_image().save_png(capture_path)
	print("SHOWCASE_CAPTURE=%s" % capture_path)
	print("SHOWCASE_CAPTURE_STATUS=%s" % error_string(error))
	get_tree().quit(0 if error == OK else 1)
