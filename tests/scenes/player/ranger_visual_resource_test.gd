extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const RANGER_SCENE := preload("res://Player/Mechas/scenes/ranger.tscn")
const MELEE_SCENE := preload("res://Player/Mechas/scenes/melee.tscn")

const RANGER_TEXTURE_PREFIX := "res://asset/images/characters/pixel/ranger/"
const SHARED_TEXTURE_PREFIX := "res://asset/images/characters/pixel/"
const RANGER_MOVE_FRAMES_PATH := "res://Player/Mechas/animations/ranger_move_frames.tres"
const SHARED_MOVE_FRAMES_PATH := "res://Player/Mechas/animations/mecha_move_frames.tres"

var _failed := false


func _ready() -> void:
	var ranger := RANGER_SCENE.instantiate()
	var melee := MELEE_SCENE.instantiate()
	_test_ranger_uses_independent_visual_resources(ranger)
	_test_existing_mecha_keeps_shared_visual_resources(melee)
	ranger.free()
	melee.free()

	print("FAIL Ranger visual resources" if _failed else "PASS Ranger visual resources")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _test_ranger_uses_independent_visual_resources(ranger: Node) -> void:
	var idle_top := ranger.get("mecha_idle_top_texture") as Texture2D
	var idle_bottom := ranger.get("mecha_idle_bottom_texture") as Texture2D
	var move_frames := ranger.get("mecha_move_sprite_frames") as SpriteFrames
	_expect(idle_top != null and idle_top.resource_path == RANGER_TEXTURE_PREFIX + "idle_top.png", "Ranger top idle must use its approved v3 texture.")
	_expect(idle_bottom != null and idle_bottom.resource_path == RANGER_TEXTURE_PREFIX + "idle_bottom.png", "Ranger bottom idle must use its approved v3 texture.")
	_expect(idle_top != null and idle_top.get_size() == Vector2(128, 128), "Ranger top idle must remain on the 128x128 player grid.")
	_expect(idle_bottom != null and idle_bottom.get_size() == Vector2(128, 128), "Ranger bottom idle must remain on the 128x128 player grid.")
	_expect(move_frames != null and move_frames.resource_path == RANGER_MOVE_FRAMES_PATH, "Ranger movement must use its independent magnetic-hover SpriteFrames.")
	_test_move_frames(move_frames)


func _test_move_frames(move_frames: SpriteFrames) -> void:
	if move_frames == null:
		return
	for animation_name: StringName in [&"move_top", &"move_bottom"]:
		_expect(move_frames.has_animation(animation_name), "Ranger movement resource must include %s." % animation_name)
		if not move_frames.has_animation(animation_name):
			continue
		_expect(move_frames.get_frame_count(animation_name) == 8, "%s must contain eight locked animation frames." % animation_name)
		_expect(is_equal_approx(move_frames.get_animation_speed(animation_name), 10.0), "%s must preserve the existing 10 FPS cadence." % animation_name)
		for frame_index in range(move_frames.get_frame_count(animation_name)):
			var texture := move_frames.get_frame_texture(animation_name, frame_index)
			_expect(texture != null and texture.get_size() == Vector2(128, 128), "%s frame %d must use the 128x128 player grid." % [animation_name, frame_index])


func _test_existing_mecha_keeps_shared_visual_resources(melee: Node) -> void:
	var idle_top := melee.get("mecha_idle_top_texture") as Texture2D
	var idle_bottom := melee.get("mecha_idle_bottom_texture") as Texture2D
	var move_frames := melee.get("mecha_move_sprite_frames") as SpriteFrames
	_expect(idle_top != null and idle_top.resource_path == SHARED_TEXTURE_PREFIX + "idle_top.png", "Existing mechas must retain the shared top idle texture.")
	_expect(idle_bottom != null and idle_bottom.resource_path == SHARED_TEXTURE_PREFIX + "idle_bottom.png", "Existing mechas must retain the shared bottom idle texture.")
	_expect(move_frames != null and move_frames.resource_path == SHARED_MOVE_FRAMES_PATH, "Existing mechas must retain the shared movement animation resource.")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
