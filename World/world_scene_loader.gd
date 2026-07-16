extends Node
class_name WorldSceneLoader

signal progress_changed(ratio: float)

static var _cached_scenes: Dictionary = {}
static var _requested_paths: Dictionary = {}

var _cancelled := false
var _loading := false

static func preload_world(scene_path: String) -> Error:
	if _cached_scenes.has(scene_path):
		return OK
	if scene_path.is_empty():
		return ERR_INVALID_PARAMETER
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return ERR_CANT_OPEN
	_cached_scenes[scene_path] = scene
	return OK

static func request_world(scene_path: String) -> Error:
	if _cached_scenes.has(scene_path) or _requested_paths.has(scene_path):
		return OK
	# Retained for callers that explicitly need background loading. Startup uses
	# preload_world(), because this World graph contains tool scripts and shared
	# resources that are not safe to parse concurrently in the current project.
	var error := ResourceLoader.load_threaded_request(scene_path, "PackedScene", false)
	if error == OK:
		_requested_paths[scene_path] = true
	return error

func cancel() -> void:
	_cancelled = true

func load_world(scene_path: String) -> Dictionary:
	if _loading:
		return {"ok": false, "error": "A World load is already in progress."}
	_loading = true
	_cancelled = false
	LoadingPerformance.mark("threaded_load_started")
	if _cached_scenes.has(scene_path):
		var cached_scene := _cached_scenes[scene_path] as PackedScene
		_loading = false
		progress_changed.emit(1.0)
		LoadingPerformance.mark("threaded_load_finished")
		return {"ok": cached_scene != null, "scene": cached_scene, "error": "Cached World scene is invalid."}
	var request_error := request_world(scene_path)
	if request_error != OK:
		_loading = false
		return {"ok": false, "error": "Failed to request threaded World load: %s" % request_error}
	var progress: Array = []
	while not _cancelled and is_inside_tree():
		var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
			_requested_paths.erase(scene_path)
			_loading = false
			if scene == null:
				return {"ok": false, "error": "Threaded World load returned an invalid PackedScene."}
			progress_changed.emit(1.0)
			_cached_scenes[scene_path] = scene
			LoadingPerformance.mark("threaded_load_finished")
			return {"ok": true, "scene": scene}
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_requested_paths.erase(scene_path)
			_loading = false
			return {"ok": false, "error": "Threaded World load failed with status: %s" % status}
		progress_changed.emit(clamp(float(progress[0]) if not progress.is_empty() else 0.0, 0.0, 1.0))
		await get_tree().process_frame
	_loading = false
	return {"ok": false, "error": "Threaded World load was cancelled."}
