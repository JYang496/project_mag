extends SceneTree


func _initialize() -> void:
	var marker_path := "user://worker_isolation_marker.txt"
	var marker := FileAccess.open(marker_path, FileAccess.WRITE)
	if marker == null:
		print("WorkerIsolationFixture: FAIL")
		quit(1)
		return
	marker.store_string(ProjectSettings.globalize_path(marker_path))
	marker.close()
	print("ISOLATION_USER_DATA=%s" % ProjectSettings.globalize_path("user://"))
	print("WorkerIsolationFixture: PASS")
	quit(0)
