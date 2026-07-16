extends Node
class_name WorldSceneLoader

signal progress_changed(ratio: float)

var _cancelled := false
var _loading := false

func cancel() -> void:
	_cancelled = true

func load_world(scene_path: String) -> Dictionary:
	if _loading:
		return {"ok": false, "error": "A World load is already in progress."}
	_loading = true
	_cancelled = false
	LoadingPerformance.mark("threaded_load_started")
	var request_error := ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if request_error != OK:
		_loading = false
		return {"ok": false, "error": "Failed to request threaded World load: %s" % request_error}
	var progress: Array = []
	while not _cancelled and is_inside_tree():
		var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
			_loading = false
			if scene == null:
				return {"ok": false, "error": "Threaded World load returned an invalid PackedScene."}
			progress_changed.emit(1.0)
			LoadingPerformance.mark("threaded_load_finished")
			return {"ok": true, "scene": scene}
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading = false
			return {"ok": false, "error": "Threaded World load failed with status: %s" % status}
		progress_changed.emit(clamp(float(progress[0]) if not progress.is_empty() else 0.0, 0.0, 1.0))
		await get_tree().process_frame
	_loading = false
	return {"ok": false, "error": "Threaded World load was cancelled."}
