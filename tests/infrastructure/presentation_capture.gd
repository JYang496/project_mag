class_name PresentationCapture
extends RefCounted


static func capture(owner: Node, artifact_name: String) -> bool:
	if owner == null or owner.get_viewport() == null:
		return false
	await owner.get_tree().process_frame
	await owner.get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1280 \
			and int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 720
	var image := owner.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		return false
	var output_dir := ProjectSettings.globalize_path("user://visual-regression")
	DirAccess.make_dir_recursive_absolute(output_dir)
	return image.save_png(output_dir.path_join("%s.png" % artifact_name)) == OK
