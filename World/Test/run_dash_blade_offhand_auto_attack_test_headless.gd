extends Node

const DASH_BLADE_SCENE := preload("res://Player/Weapons/Instances/dash_blade.tscn")
const DUMMY_ENEMY_SCENE := preload("res://World/Test/dps_test_dummy_enemy.tscn")
const IDLE_STATE := 0

var _failed := false
var _player: Node2D

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	PhaseManager.phase = PhaseManager.BATTLE
	_player = Node2D.new()
	_player.name = "DashBladeOffhandTestPlayer"
	_player.global_position = Vector2.ZERO
	add_child(_player)
	PlayerData.player = _player

	var dash := DASH_BLADE_SCENE.instantiate() as Weapon
	if dash == null:
		_fail("Dash Blade scene did not instantiate as Weapon.")
		return
	add_child(dash)
	dash.global_position = Vector2.ZERO
	dash.set_weapon_role("offhand")
	PlayerData.player_weapon_list.append(dash)
	PlayerData.set_main_weapon_index(-1)
	await get_tree().process_frame

	var target := DUMMY_ENEMY_SCENE.instantiate() as Node2D
	if target == null:
		_fail("Dummy enemy scene did not instantiate.")
		return
	target.global_position = Vector2(80.0, 0.0)
	add_child(target)
	await get_tree().process_frame
	dash.call("_on_attack_range_body_entered", target)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var state := int(dash.get("_state"))
	if state == IDLE_STATE:
		_fail("Offhand auto-fire Dash Blade did not start attacking; %s." % _describe_dash_state(dash))
		return

	_pass()

func _pass() -> void:
	_cleanup()
	print("PASS: dash blade offhand auto attack")
	get_tree().quit(0)

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("FAIL: dash blade offhand auto attack: %s" % message)
	_cleanup()
	get_tree().quit(1)

func _cleanup() -> void:
	PlayerData.player_weapon_list.clear()
	PlayerData.set_main_weapon_index(-1)
	PlayerData.player = null
	PhaseManager.phase = PhaseManager.PREPARE
	for child in get_children():
		child.free()

func _describe_dash_state(dash: Weapon) -> String:
	if dash == null or not is_instance_valid(dash):
		return "dash=null"
	return "state=%s role=%s phase=%s auto_fire=%s can_run=%s target=%s tracked=%s" % [
		str(dash.get("_state")),
		str(dash.get("weapon_role")),
		str(PhaseManager.current_state()),
		str(dash.call("has_weapon_trait", WeaponTrait.AUTO_FIRE)),
		str(dash.call("_can_run_dash_attack")),
		str(dash.get("_target")),
		str(dash.get("_tracked_enemies")),
	]
