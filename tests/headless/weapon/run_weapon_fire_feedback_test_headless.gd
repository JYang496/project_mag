extends Node

const WEAPON_CASES := [
	{
		"label": "Machine Gun",
		"scene": "res://Player/Weapons/Instances/machine_gun.tscn",
		"expect_muzzle": true,
		"expect_shake": true,
	},
	{
		"label": "Shotgun",
		"scene": "res://Player/Weapons/Instances/shotgun.tscn",
		"expect_muzzle": true,
		"expect_shake": true,
	},
	{
		"label": "Rocket Launcher",
		"scene": "res://Player/Weapons/Instances/rocket_launcher.tscn",
		"expect_muzzle": true,
		"expect_shake": true,
	},
	{
		"label": "Auto Pistol",
		"scene": "res://Player/Weapons/Instances/pistol.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
	{
		"label": "Sniper",
		"scene": "res://Player/Weapons/Instances/sniper.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
	{
		"label": "Cannon",
		"scene": "res://Player/Weapons/Instances/cannon.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
	{
		"label": "Charged Blaster",
		"scene": "res://Player/Weapons/Instances/charged_blaster.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
	{
		"label": "Laser",
		"scene": "res://Player/Weapons/Instances/laser.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
	{
		"label": "Flamethrower",
		"scene": "res://Player/Weapons/Instances/flamethrower.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
	{
		"label": "Glacier Projector",
		"scene": "res://Player/Weapons/Instances/glacier_projector.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
	{
		"label": "Plasma Lance",
		"scene": "res://Player/Weapons/Instances/plasma_lance.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
	{
		"label": "Spear Launcher",
		"scene": "res://Player/Weapons/Instances/spear_launcher.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
	{
		"label": "Chainsaw Launcher",
		"scene": "res://Player/Weapons/Instances/chainsaw_launcher.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
	{
		"label": "Orbit",
		"scene": "res://Player/Weapons/Instances/orbit.tscn",
		"expect_muzzle": false,
		"expect_shake": false,
	},
]
const MUZZLE_FLASH_SCRIPT := preload("res://Player/Weapons/Feedback/muzzle_flash_vfx.gd")

class FakePlayer:
	extends Node2D

	var shake_requests: int = 0
	var shake_total: float = 0.0

	func request_camera_shake(amount: float, _source_global_position: Vector2 = Vector2.ZERO, _max_distance: float = 900.0) -> void:
		shake_requests += 1
		shake_total += maxf(amount, 0.0)

	func apply_heat_expansion(_duration_sec: float, _max_heat_mul: float) -> bool:
		return true

class FakeCameraPlayer:
	extends Node2D

	var camera_lookahead_lerp_speed: float = 16.0
	var camera_zoom_lerp_speed: float = 16.0
	var rest_camera_zoom_transition_enabled: bool = false
	var rest_camera_zoom_enter_duration: float = 0.12
	var rest_camera_zoom_exit_duration: float = 0.12
	var rest_phase_camera_zoom_factor: float = 1.0
	var battle_camera_view_mul: float = 1.0

	func get_total_vision_mul() -> float:
		return 1.0

var _failed: bool = false
var _fake_player: FakePlayer
var _player_data: Node
var _phase_manager: Node


func _ready() -> void:
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		_fail("weapon fire feedback test timed out")
		_finish()
	)
	call_deferred("_run")


func _run() -> void:
	_player_data = get_tree().root.get_node_or_null("/root/PlayerData")
	_phase_manager = get_tree().root.get_node_or_null("/root/PhaseManager")
	if _player_data == null:
		_fail("missing PlayerData autoload")
		_finish()
		return
	if _phase_manager == null:
		_fail("missing PhaseManager autoload")
		_finish()
		return
	_player_data.call("reset_runtime_state")
	_phase_manager.set("phase", "battle")
	_fake_player = FakePlayer.new()
	_fake_player.name = "WeaponFireFeedbackFakePlayer"
	_fake_player.global_position = Vector2.ZERO
	_fake_player.set_meta("_benchmark_mouse_target", Vector2(240.0, 0.0))
	get_tree().root.add_child(_fake_player)
	_player_data.set("player", _fake_player)

	for weapon_case in WEAPON_CASES:
		await _assert_weapon_feedback_lifecycle(weapon_case)
		if _failed:
			_finish()
			return

	await _assert_camera_trauma_limit()
	if _failed:
		_finish()
		return

	_player_data.call("reset_runtime_state")
	if _fake_player != null and is_instance_valid(_fake_player):
		_fake_player.queue_free()
	await _drain_cleanup_frames()
	print("PASS: weapon fire feedback lifecycle")
	get_tree().quit(0)


func _assert_weapon_feedback_lifecycle(weapon_case: Dictionary) -> void:
	var label := str(weapon_case.get("label", "weapon"))
	var scene_path := str(weapon_case.get("scene", ""))
	var expect_muzzle := bool(weapon_case.get("expect_muzzle", false))
	var expect_shake := bool(weapon_case.get("expect_shake", false))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("%s feedback: failed to load %s" % [label, scene_path])
		return
	var root_ids_before := _capture_root_child_ids()
	var weapon := packed.instantiate() as Weapon
	if weapon == null:
		_fail("%s feedback: scene did not instantiate a Weapon" % label)
		return
	weapon.name = "%sFeedbackTest" % label.replace(" ", "")
	weapon.global_position = Vector2.ZERO
	weapon.set_meta("_benchmark_mouse_target", Vector2(320.0, 0.0))
	get_tree().root.add_child(weapon)
	await get_tree().process_frame
	await get_tree().physics_frame
	weapon.set_weapon_role("main")
	weapon.set("is_on_cooldown", false)
	weapon.set("current_ammo", maxi(1, int(weapon.get("magazine_capacity"))))
	var shake_before := _fake_player.shake_requests
	var muzzle_before := _count_muzzle_flash_nodes()
	var feedback_before := _get_last_feedback_msec(weapon)
	var ok := bool(weapon.call("request_primary_fire"))
	if not ok:
		_fail("%s feedback: request_primary_fire should succeed" % label)
		_cleanup_weapon(weapon)
		return
	var feedback_after := await _wait_for_feedback_msec(weapon, feedback_before)
	if feedback_after <= feedback_before:
		_fail("%s feedback: success fire did not mark feedback playback" % label)
	var muzzle_after := _count_muzzle_flash_nodes()
	if expect_muzzle and muzzle_after <= muzzle_before:
		_fail("%s feedback: success fire did not spawn muzzle flash" % label)
	if not expect_muzzle and muzzle_after > muzzle_before:
		_fail("%s feedback: recoil-only fire should not spawn muzzle flash" % label)
	if expect_shake and _fake_player.shake_requests <= shake_before:
		_fail("%s feedback: success fire did not request camera shake" % label)
	if not expect_shake and _fake_player.shake_requests != shake_before:
		_fail("%s feedback: recoil-only fire should not request camera shake" % label)

	var feedback_after_success := feedback_after
	var shake_after_success := _fake_player.shake_requests
	var failed_cooldown := bool(weapon.call("request_primary_fire"))
	if failed_cooldown:
		_fail("%s feedback: cooldown fire should fail" % label)
	await get_tree().process_frame
	if _get_last_feedback_msec(weapon) != feedback_after_success:
		_fail("%s feedback: cooldown failure should not replay feedback" % label)
	if _fake_player.shake_requests != shake_after_success:
		_fail("%s feedback: cooldown failure should not request camera shake" % label)

	weapon.set("is_on_cooldown", false)
	weapon.set("current_ammo", 0)
	var failed_empty := bool(weapon.call("request_primary_fire"))
	if failed_empty:
		_fail("%s feedback: empty fire should fail" % label)
	await get_tree().process_frame
	if _get_last_feedback_msec(weapon) != feedback_after_success:
		_fail("%s feedback: empty failure should not replay feedback" % label)

	weapon.set("is_on_cooldown", false)
	weapon.set("current_ammo", maxi(1, int(weapon.get("magazine_capacity"))))
	_phase_manager.set("phase", "prepare")
	var failed_phase := bool(weapon.call("request_primary_fire"))
	if failed_phase:
		_fail("%s feedback: prepare-phase fire should fail" % label)
	await get_tree().process_frame
	if _get_last_feedback_msec(weapon) != feedback_after_success:
		_fail("%s feedback: phase failure should not replay feedback" % label)
	_phase_manager.set("phase", "battle")

	for i in range(30):
		await get_tree().process_frame
	if _count_muzzle_flash_nodes() > 0:
		_fail("%s feedback: muzzle flash nodes did not clean up" % label)
	if weapon.sprite != null and weapon.sprite.position.distance_to(Vector2.ZERO) > 0.01:
		_fail("%s feedback: sprite recoil did not recover" % label)

	_cleanup_weapon(weapon)
	_cleanup_new_root_children(root_ids_before)
	await _drain_cleanup_frames()


func _assert_camera_trauma_limit() -> void:
	var fake := FakeCameraPlayer.new()
	var camera := Camera2D.new()
	fake.add_child(camera)
	get_tree().root.add_child(fake)
	var camera_system := PlayerCameraSystem.new()
	camera_system.setup(fake, camera)
	for i in range(20):
		camera_system.request_camera_shake(0.2, Vector2.ZERO, 900.0)
	var trauma := camera_system.get_camera_shake_trauma()
	if trauma > 0.3501:
		_fail("camera trauma exceeded hard cap: %.4f" % trauma)
	camera_system.tick(1.0 / 60.0)
	if camera.offset.length() <= 0.0:
		_fail("camera shake did not produce an offset")
	fake.queue_free()
	await _drain_cleanup_frames()


func _drain_cleanup_frames() -> void:
	for i in range(3):
		await get_tree().process_frame


func _get_last_feedback_msec(weapon: Node) -> int:
	return int(weapon.get_meta(&"_last_fire_feedback_msec", -1))


func _wait_for_feedback_msec(weapon: Node, previous_msec: int) -> int:
	for i in range(30):
		await get_tree().process_frame
		var next_msec := _get_last_feedback_msec(weapon)
		if next_msec > previous_msec:
			return next_msec
	return _get_last_feedback_msec(weapon)


func _count_muzzle_flash_nodes() -> int:
	return _count_muzzle_flash_nodes_recursive(get_tree().root)


func _count_muzzle_flash_nodes_recursive(node: Node) -> int:
	var count := 0
	if node.get_script() == MUZZLE_FLASH_SCRIPT:
		count += 1
	for child in node.get_children():
		count += _count_muzzle_flash_nodes_recursive(child)
	return count


func _cleanup_weapon(weapon: Node) -> void:
	if weapon != null and is_instance_valid(weapon):
		weapon.queue_free()


func _capture_root_child_ids() -> Dictionary:
	var ids := {}
	for child in get_tree().root.get_children():
		ids[child.get_instance_id()] = true
	return ids


func _cleanup_new_root_children(root_ids_before: Dictionary) -> void:
	for child in get_tree().root.get_children():
		if root_ids_before.has(child.get_instance_id()):
			continue
		if child == self or child == _fake_player:
			continue
		child.queue_free()


func _fail(message: String) -> void:
	_failed = true
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _player_data != null:
		_player_data.call("reset_runtime_state")
	if _fake_player != null and is_instance_valid(_fake_player):
		_fake_player.queue_free()
	if _failed:
		get_tree().quit(1)
		return
	get_tree().quit(0)
