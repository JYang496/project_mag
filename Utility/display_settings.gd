extends Node

const SETTINGS_PATH := "user://display_settings.cfg"
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const MIN_RESOLUTION := Vector2i(1280, 720)

enum WindowMode {
	WINDOWED,
	BORDERLESS,
	FULLSCREEN,
}

var window_mode: int = WindowMode.WINDOWED
var resolution: Vector2i = DEFAULT_RESOLUTION

func _ready() -> void:
	_load_settings()
	apply()

func can_apply_window_changes() -> bool:
	return not _is_embedded_run()

func apply() -> void:
	if _is_embedded_run():
		return
	DisplayServer.window_set_min_size(MIN_RESOLUTION)
	_apply_window_mode()
	if window_mode == WindowMode.WINDOWED:
		DisplayServer.window_set_size(resolution)
		_center_window()

func set_window_mode_name(mode_name: String) -> void:
	var normalized := mode_name.strip_edges().to_lower()
	match normalized:
		"windowed":
			window_mode = WindowMode.WINDOWED
		"borderless":
			window_mode = WindowMode.BORDERLESS
		"fullscreen":
			window_mode = WindowMode.FULLSCREEN
		_:
			return
	apply()
	_save_settings()

func set_resolution(size: Vector2i) -> void:
	resolution = Vector2i(
		max(size.x, MIN_RESOLUTION.x),
		max(size.y, MIN_RESOLUTION.y)
	)
	if _is_embedded_run():
		_save_settings()
		return
	if window_mode == WindowMode.WINDOWED:
		DisplayServer.window_set_size(resolution)
		_center_window()
	_save_settings()

func get_window_mode_name() -> String:
	match window_mode:
		WindowMode.WINDOWED:
			return "windowed"
		WindowMode.BORDERLESS:
			return "borderless"
		WindowMode.FULLSCREEN:
			return "fullscreen"
	return "windowed"

func _apply_window_mode() -> void:
	if _is_embedded_run():
		return
	match window_mode:
		WindowMode.WINDOWED:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var rect := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			DisplayServer.window_set_position(rect.position)
			DisplayServer.window_set_size(rect.size)
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _center_window() -> void:
	if _is_embedded_run():
		return
	var rect := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var position := rect.position + (rect.size - resolution) / 2
	DisplayServer.window_set_position(position)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	window_mode = int(cfg.get_value("display", "window_mode", WindowMode.WINDOWED))
	if window_mode < WindowMode.WINDOWED or window_mode > WindowMode.FULLSCREEN:
		window_mode = WindowMode.WINDOWED
	var width := int(cfg.get_value("display", "resolution_width", DEFAULT_RESOLUTION.x))
	var height := int(cfg.get_value("display", "resolution_height", DEFAULT_RESOLUTION.y))
	resolution = Vector2i(max(width, MIN_RESOLUTION.x), max(height, MIN_RESOLUTION.y))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "resolution_width", resolution.x)
	cfg.set_value("display", "resolution_height", resolution.y)
	cfg.save(SETTINGS_PATH)

func _is_embedded_run() -> bool:
	# In editor run modes, Godot may execute in an embedded container where
	# window APIs (move/resize/min size) are unsupported and emit warnings.
	return OS.has_feature("editor")
