extends Node2D

const TARGET_WARNING_SCENE := preload("res://Npc/enemy/scenes/target_warning.tscn")
const SkillWarningTelegraphType := preload("res://Npc/enemy/scripts/skill_warning_telegraph.gd")
const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")

const CYCLE_DURATION := 2.4
const PANEL_CENTERS := [
	Vector2(320, 250),
	Vector2(960, 250),
	Vector2(320, 545),
	Vector2(805, 545),
]

var _cycle_elapsed := 0.0
var _bomber_warning: TargetWarning
var _mortar_warning: TargetWarning
var _dash_warning: SkillWarningTelegraph
var _spike_line: Line2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#071019"))
	_build_spike_warning()
	_build_dash_warning()
	_restart_cycle()
	queue_redraw()
	_capture_if_requested()


func _process(delta: float) -> void:
	_cycle_elapsed += maxf(delta, 0.0)
	if _cycle_elapsed >= CYCLE_DURATION:
		_restart_cycle()
	var progress := clampf(_cycle_elapsed / CYCLE_DURATION, 0.0, 1.0)
	_update_spike_warning(progress)
	if _dash_warning != null:
		_dash_warning.update_dash_warning(PANEL_CENTERS[3] + Vector2(-170, 0), Vector2.RIGHT, delta)
	queue_redraw()


func _restart_cycle() -> void:
	_cycle_elapsed = 0.0
	_clear_circle_warning(_bomber_warning)
	_clear_circle_warning(_mortar_warning)
	_bomber_warning = _spawn_circle_warning(PANEL_CENTERS[0], 86.0, false)
	_mortar_warning = _spawn_circle_warning(PANEL_CENTERS[1], 76.0, false)
	if _dash_warning != null:
		_dash_warning.clear_warning()
		_dash_warning.show_dash_warning(PANEL_CENTERS[3] + Vector2(-170, 0), Vector2.RIGHT, 340.0, CYCLE_DURATION, 42.0)


func _spawn_circle_warning(center: Vector2, warning_radius: float, countdown: bool) -> TargetWarning:
	var warning := TARGET_WARNING_SCENE.instantiate() as TargetWarning
	warning.position = center
	warning.duration = CYCLE_DURATION
	warning.radius = warning_radius
	warning.visual_preset = TargetWarning.VisualPreset.DODGE_STYLE
	warning.show_countdown = countdown
	add_child(warning)
	return warning


func _clear_circle_warning(warning: TargetWarning) -> void:
	if warning != null and is_instance_valid(warning):
		warning.queue_free()


func _build_spike_warning() -> void:
	_spike_line = Line2D.new()
	_spike_line.name = "SpikeTurretAimWarning"
	_spike_line.width = 4.0
	_spike_line.begin_cap_mode = Line2D.LINE_CAP_BOX
	_spike_line.end_cap_mode = Line2D.LINE_CAP_BOX
	_spike_line.antialiased = false
	add_child(_spike_line)
	_update_spike_warning(0.0)


func _update_spike_warning(progress: float) -> void:
	if _spike_line == null:
		return
	var origin := PANEL_CENTERS[2] + Vector2(-175, 0)
	var target := PANEL_CENTERS[2] + Vector2(175, 0)
	_spike_line.points = PackedVector2Array([origin, target])
	_spike_line.default_color = Color(PALETTE.ENEMY_PRIMARY, lerpf(0.33, 0.96, progress))


func _build_dash_warning() -> void:
	_dash_warning = SkillWarningTelegraphType.new() as SkillWarningTelegraph
	_dash_warning.name = "RollingBallDashWarning"
	add_child(_dash_warning)


func _draw() -> void:
	_draw_checker_floor()
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(42, 42), "ATTACK WARNING GALLERY", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#d9f2f5"))
	draw_string(font, Vector2(42, 70), "The red boundary is the damage limit. The translucent fill reaches it at impact.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#88aeb8"))
	_draw_panel_title(font, Vector2(70, 126), "BOMBER AOE", "Expanding fill / no numeric countdown")
	_draw_panel_title(font, Vector2(710, 126), "MORTAR AOE", "Expanding fill / impact at boundary")
	_draw_panel_title(font, Vector2(70, 420), "SPIKE TURRET", "Line lock brightens until projectile release")
	_draw_panel_title(font, Vector2(710, 420), "ROLLING ELITE DASH", "Danger corridor fills toward dash endpoint")
	var impact_text := "IMPACT %.0f%%" % (clampf(_cycle_elapsed / CYCLE_DURATION, 0.0, 1.0) * 100.0)
	draw_string(font, Vector2(1110, 42), impact_text, HORIZONTAL_ALIGNMENT_RIGHT, 125, 16, PALETTE.ENEMY_PRIMARY)


func _draw_checker_floor() -> void:
	var panel_rects := [Rect2(42, 96, 596, 280), Rect2(682, 96, 556, 280), Rect2(42, 390, 596, 280), Rect2(682, 390, 556, 280)]
	for rect in panel_rects:
		draw_rect(rect, Color("#0b1822"), true)
		var tile := 32.0
		var rows := int(ceil(rect.size.y / tile))
		var columns := int(ceil(rect.size.x / tile))
		for row in range(rows):
			for column in range(columns):
				var cell := Rect2(rect.position + Vector2(column, row) * tile, Vector2(tile, tile))
				var color := Color("#162a35") if (row + column) % 2 == 0 else Color("#0f222d")
				draw_rect(cell.intersection(rect), color, true)
		draw_rect(rect, Color("#294552"), false, 2.0)


func _draw_panel_title(font: Font, position: Vector2, title: String, subtitle: String) -> void:
	draw_string(font, position, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PALETTE.ENEMY_PRIMARY)
	draw_string(font, position + Vector2(0, 23), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8caeb6"))


func _capture_if_requested() -> void:
	if not OS.get_cmdline_user_args().has("--capture-attack-warning-showcase"):
		return
	if DisplayServer.get_name() == "headless":
		push_error("Attack-warning showcase capture requires a graphical display driver.")
		get_tree().quit(2)
		return
	await get_tree().create_timer(CYCLE_DURATION * 0.72).timeout
	await get_tree().process_frame
	var output_directory := ProjectSettings.globalize_path("res://output/showcases/vfx")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var capture_path := output_directory.path_join("attack_warning_gallery_showcase.png")
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("Attack-warning showcase capture requires an active rendering driver.")
		get_tree().quit(2)
		return
	var error := image.save_png(capture_path)
	print("SHOWCASE_CAPTURE=%s" % capture_path)
	print("SHOWCASE_CAPTURE_STATUS=%s" % error_string(error))
	get_tree().quit(0 if error == OK else 1)
