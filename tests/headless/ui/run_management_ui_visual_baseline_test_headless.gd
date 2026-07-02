extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const OUTPUT_ROOT := "user://project_slimming/ui2_visual"
const PANEL_SIZE := Vector2(312, 320)
const CONFIGS := [
	{"locale": "en", "size": Vector2i(1280, 720)},
	{"locale": "zh_CN", "size": Vector2i(1280, 720)},
	{"locale": "en", "size": Vector2i(1920, 1080)},
	{"locale": "zh_CN", "size": Vector2i(1920, 1080)},
]

class RestAreaAvailabilityStub:
	extends Node

	func is_module_management_available() -> bool:
		return true

var _failures := PackedStringArray()
var _baseline_mode := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_baseline_mode = not FileAccess.file_exists(
		"%s/baseline/en_1280x720.png" % OUTPUT_ROOT
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("%s/%s" % [
			OUTPUT_ROOT,
			"baseline" if _baseline_mode else "candidate",
		])
	)
	for config in CONFIGS:
		await _capture_config(
			str(config.get("locale", "en")),
			config.get("size", Vector2i(1280, 720)) as Vector2i
		)
	await _finish()

func _capture_config(locale: String, viewport_size: Vector2i) -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	LocalizationManager.set_locale(locale, false)

	var viewport := SubViewport.new()
	viewport.name = "ManagementVisualViewport"
	viewport.size = viewport_size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var player := PLAYER_SCENE.instantiate() as Player
	viewport.add_child(player)
	player.visible = false
	var rest_area_stub := RestAreaAvailabilityStub.new()
	rest_area_stub.add_to_group("rest_area")
	viewport.add_child(rest_area_stub)
	var ui := UI_SCENE.instantiate() as UI
	viewport.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	ui._apply_responsive_layout()
	ui._refresh_localized_static_text()
	_prepare_visual_grid(ui, viewport_size)
	for _frame in range(4):
		await get_tree().process_frame

	var image := viewport.get_texture().get_image()
	var file_stem := "%s_%dx%d" % [locale, viewport_size.x, viewport_size.y]
	if image == null or image.is_empty():
		_record("%s did not produce a viewport image" % file_stem)
	else:
		if image.get_width() != viewport_size.x or image.get_height() != viewport_size.y:
			_record(
				"%s image size is %dx%d"
				% [file_stem, image.get_width(), image.get_height()]
			)
		var phase := "baseline" if _baseline_mode else "candidate"
		var output_path := "%s/%s/%s.png" % [OUTPUT_ROOT, phase, file_stem]
		var save_error := image.save_png(output_path)
		if save_error != OK:
			_record("%s failed to save: %s" % [file_stem, error_string(save_error)])
		elif not _baseline_mode:
			_compare_with_baseline(file_stem, image)
		print(
			"ManagementUIVisualBaseline: %s %s sha256=%s path=%s"
			% [phase, file_stem, _image_sha256(image), ProjectSettings.globalize_path(output_path)]
		)

	ui.queue_free()
	player.queue_free()
	rest_area_stub.queue_free()
	viewport.queue_free()
	await get_tree().process_frame

func _prepare_visual_grid(ui: UI, viewport_size: Vector2i) -> void:
	ui.set_physics_process(false)
	ui.character_root.visible = false
	if ui.controls_hint_view != null and is_instance_valid(ui.controls_hint_view):
		ui.controls_hint_view.visible = false
	if ui.spread_cursor_overlay != null and is_instance_valid(ui.spread_cursor_overlay):
		ui.spread_cursor_overlay.visible = false
	ui.purchase_management_root.visible = false
	ui.upgrade_management_root.visible = false
	ui.warehouse_management_root.visible = false
	ui.pause_menu_root.visible = false
	var entries := [
		{"root": ui.purchase_primary_root, "panel": ui.purchase_primary_panel, "column": 0, "row": 0},
		{"root": ui.upgrade_primary_root, "panel": ui.upgrade_primary_panel, "column": 1, "row": 0},
		{"root": ui.warehouse_primary_root, "panel": ui.warehouse_primary_panel, "column": 0, "row": 1},
		{"root": ui.board_edit_primary_root, "panel": ui.board_edit_primary_panel, "column": 1, "row": 1},
	]
	for entry in entries:
		var root := entry.get("root", null) as Control
		var panel := entry.get("panel", null) as Panel
		if root == null or panel == null:
			_record("visual grid is missing a primary menu root or panel")
			continue
		root.visible = true
		root.position = Vector2.ZERO
		root.size = Vector2(viewport_size)
		panel.size = PANEL_SIZE
		panel.position = _grid_panel_position(
			viewport_size,
			int(entry.get("column", 0)),
			int(entry.get("row", 0))
		)

func _grid_panel_position(viewport_size: Vector2i, column: int, row: int) -> Vector2:
	var cell_size := Vector2(viewport_size) * 0.5
	return Vector2(
		cell_size.x * float(column) + (cell_size.x - PANEL_SIZE.x) * 0.5,
		cell_size.y * float(row) + (cell_size.y - PANEL_SIZE.y) * 0.5
	)

func _compare_with_baseline(file_stem: String, candidate: Image) -> void:
	var baseline_path := "%s/baseline/%s.png" % [OUTPUT_ROOT, file_stem]
	var baseline := Image.load_from_file(baseline_path)
	if baseline == null or baseline.is_empty():
		_record("%s baseline is missing or unreadable" % file_stem)
		return
	if baseline.get_size() != candidate.get_size():
		_record("%s candidate dimensions changed" % file_stem)
		return
	if baseline.get_data() != candidate.get_data():
		_record(
			"%s pixels changed: baseline=%s candidate=%s"
			% [file_stem, _image_sha256(baseline), _image_sha256(candidate)]
		)
		return
	print("ManagementUIVisualBaseline: MATCH %s" % file_stem)

func _image_sha256(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()

func _record(message: String) -> void:
	_failures.append(message)
	push_error("ManagementUIVisualBaseline: " + message)

func _finish() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	if _failures.is_empty():
		print(
			"ManagementUIVisualBaseline: %s PASS"
			% ("BASELINE_CREATED" if _baseline_mode else "CANDIDATE_MATCH")
		)
		await get_tree().create_timer(0.2).timeout
		get_tree().quit(0)
		return
	print("ManagementUIVisualBaseline: FAIL (%d)" % _failures.size())
	for failure in _failures:
		print(" - " + failure)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1)
