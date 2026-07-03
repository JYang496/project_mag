extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const WEAPON_BASE_SCENE := preload("res://Player/Weapons/weapon.tscn")
const TEST_WEAPON_SCRIPT := preload("res://tests/headless/player/player_active_skill_test_weapon.gd")
const ACTIVE_SKILL_RUNTIME_SCRIPT := preload("res://Player/Mechas/scripts/player_active_skill_runtime.gd")

var _failed: bool = false
var _player_active_signal_count: int = 0
var _legacy_active_signal_count: int = 0
var _weapon_active_signal_count: int = 0
var _weapon_trigger_success_count: int = 0
var _weapon_trigger_failure_count: int = 0
var _last_weapon_trigger_reason: String = ""
var _original_auto_reload_switch: bool = false

class CountingSkill:
	extends Skills

	var activation_count: int = 0

	func activate_skill() -> void:
		activation_count += 1

class HintRecorderPlayer:
	extends Node

	var reload_block_hint_interval_sec: float = 1.25
	var hint_count: int = 0
	var last_hint_key: StringName = StringName()
	var last_hint_throttle_sec: float = 0.0

	func _spawn_keyed_player_floating_hint(
		_text: String,
		hint_key: StringName,
		throttle_sec: float
	) -> void:
		hint_count += 1
		last_hint_key = hint_key
		last_hint_throttle_sec = throttle_sec

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_auto_reload_switch = PlayerAssistSettings.auto_reload_switch
	PlayerData.reset_runtime_state()
	GlobalVariables.reset_runtime_state()
	PhaseManager.phase = PhaseManager.BATTLE
	PlayerAssistSettings.auto_reload_switch = true
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_fail("player scene did not instantiate")
		return
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_default_skill_loading(player):
		return
	if not await _test_energy_and_player_cast(player):
		return
	if not await _test_weapon_active_reload_and_assist(player):
		return
	if not _test_reload_hint_throttle():
		return
	PlayerAssistSettings.auto_reload_switch = _original_auto_reload_switch
	GlobalVariables.ui = null
	player.queue_free()
	await get_tree().process_frame
	print("PASS: player active skill characterization")
	# Keep the scene alive briefly so editor/MCP runners can capture the PASS marker.
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)

func _test_default_skill_loading(player: Player) -> bool:
	if player.active_skill_holder == null:
		return _fail("player has no ActiveSkill holder")
	if player.active_skill_holder.get_child_count() != 1:
		return _fail(
			"default active skill count expected=1 actual=%d"
			% player.active_skill_holder.get_child_count()
		)
	var skill := player.active_skill_holder.get_child(0) as Skills
	if skill == null:
		return _fail("default active skill does not inherit Skills")
	if skill.scene_file_path != "res://Player/Skills/bullet_time.tscn":
		return _fail("unexpected default active skill path: %s" % skill.scene_file_path)
	if not is_equal_approx(player.get_active_skill_energy_cost(), 50.0):
		return _fail(
			"default active skill energy cost expected=50 actual=%s"
			% str(player.get_active_skill_energy_cost())
		)
	return true

func _test_energy_and_player_cast(player: Player) -> bool:
	player.player_max_energy = 100.0
	player.player_energy_regen_per_sec = 10.0
	player._active_skill_runtime.call("reset_energy_to_max")
	if not _assert_float(100.0, player.get_current_energy(), "initial energy"):
		return false
	player.player_max_energy = 0.0
	player._active_skill_runtime.call("reset_energy_to_max")
	if not _assert_float(1.0, player.get_max_energy(), "minimum max energy"):
		return false
	if not _assert_float(1.0, player.get_current_energy(), "energy reset to minimum max"):
		return false
	player.player_max_energy = 100.0
	player._active_skill_runtime.call("reset_energy_to_max")
	if not player.consume_energy(25.0):
		return _fail("valid energy consumption was rejected")
	if not _assert_float(75.0, player.get_current_energy(), "energy after consumption"):
		return false
	if player.consume_energy(80.0):
		return _fail("insufficient energy consumption succeeded")
	if not _assert_float(75.0, player.get_current_energy(), "energy after rejected consumption"):
		return false
	if not player.consume_energy(-5.0):
		return _fail("negative energy consumption should be a zero-cost success")
	if not _assert_float(75.0, player.get_current_energy(), "energy after negative consumption"):
		return false
	player.add_energy(-10.0)
	if not _assert_float(75.0, player.get_current_energy(), "energy after negative add"):
		return false
	player.add_energy(1000.0)
	if not _assert_float(100.0, player.get_current_energy(), "energy upper clamp"):
		return false
	if not player.consume_energy(95.0):
		return _fail("energy setup consumption failed")
	player.call("_regen_energy", 0.5)
	if not _assert_float(10.0, player.get_current_energy(), "energy regeneration"):
		return false
	player.call("_regen_energy", -1.0)
	if not _assert_float(10.0, player.get_current_energy(), "negative delta regeneration"):
		return false

	for child in player.active_skill_holder.get_children():
		child.queue_free()
	await get_tree().process_frame
	var counting_skill := CountingSkill.new()
	counting_skill.energy_cost = 30.0
	counting_skill.cooldown = 0.0
	player.active_skill_holder.add_child(counting_skill)
	await get_tree().process_frame
	await get_tree().process_frame
	player.player_active_skill.connect(_on_player_active_signal)
	player.active_skill.connect(_on_legacy_active_signal)
	player._active_skill_runtime.call("reset_energy_to_max")
	player.call("_try_cast_player_active_skill")
	if counting_skill.activation_count != 1:
		return _fail("player skill activation count expected=1 actual=%d" % counting_skill.activation_count)
	if _player_active_signal_count != 1 or _legacy_active_signal_count != 1:
		return _fail(
			"player skill signal counts expected=1/1 actual=%d/%d"
			% [_player_active_signal_count, _legacy_active_signal_count]
		)
	if not _assert_float(70.0, player.get_current_energy(), "energy after player skill cast"):
		return false
	if not player.consume_energy(70.0):
		return _fail("failed to exhaust energy before rejected skill cast")
	player.call("_try_cast_player_active_skill")
	if counting_skill.activation_count != 1:
		return _fail("insufficient energy still activated player skill")
	if _player_active_signal_count != 2 or _legacy_active_signal_count != 2:
		return _fail(
			"cast request signals should emit once per request; expected=2/2 actual=%d/%d"
			% [_player_active_signal_count, _legacy_active_signal_count]
		)
	return true

func _test_weapon_active_reload_and_assist(player: Player) -> bool:
	for weapon_variant in PlayerData.player_weapon_list:
		var existing_weapon := weapon_variant as Weapon
		if existing_weapon != null and is_instance_valid(existing_weapon):
			existing_weapon.queue_free()
	PlayerData.player_weapon_list.clear()
	await get_tree().process_frame
	var first_weapon := _instantiate_test_weapon()
	var second_weapon := _instantiate_test_weapon()
	if first_weapon == null or second_weapon == null:
		return _fail("active skill test weapons did not instantiate")
	player.equppied_weapons.add_child(first_weapon)
	player.equppied_weapons.add_child(second_weapon)
	PlayerData.player_weapon_list.append(first_weapon)
	PlayerData.player_weapon_list.append(second_weapon)
	PlayerData.set_main_weapon_index(0)
	first_weapon.set_weapon_role("main")
	second_weapon.set_weapon_role("offhand")
	await get_tree().process_frame
	player.weapon_active_skill.connect(_on_weapon_active_signal)
	first_weapon.weapon_active_triggered.connect(_on_weapon_active_triggered)
	player._active_skill_runtime.call("reset_energy_to_max")
	player.call("_try_cast_main_weapon_active_skill")
	if int(first_weapon.get("active_execution_count")) != 1:
		return _fail("main weapon active execution count expected=1")
	if _weapon_active_signal_count != 1 or _weapon_trigger_success_count != 1:
		return _fail(
			"weapon active success signals expected=1/1 actual=%d/%d"
			% [_weapon_active_signal_count, _weapon_trigger_success_count]
		)
	if not _assert_float(80.0, player.get_current_energy(), "energy after weapon active"):
		return false
	player.call("_try_cast_main_weapon_active_skill")
	if int(first_weapon.get("active_execution_count")) != 1:
		return _fail("weapon active executed while on cooldown")
	if _weapon_active_signal_count != 1 or _weapon_trigger_failure_count != 1:
		return _fail(
			"weapon active cooldown signals expected success/failure=1/1 actual=%d/%d"
			% [_weapon_active_signal_count, _weapon_trigger_failure_count]
		)
	if _last_weapon_trigger_reason != "cd" or player.get_last_weapon_skill_fail_reason() != "cd":
		return _fail(
			"weapon active cooldown reason mismatch signal=%s player=%s"
			% [_last_weapon_trigger_reason, player.get_last_weapon_skill_fail_reason()]
		)
	first_weapon.is_reloading = false
	first_weapon.current_ammo = maxi(1, first_weapon.magazine_capacity - 1)
	second_weapon.is_reloading = false
	second_weapon.current_ammo = maxi(1, second_weapon.magazine_capacity)
	PlayerData.set_main_weapon_index(0)
	first_weapon.set_weapon_role("main")
	second_weapon.set_weapon_role("offhand")
	player.call("_try_reload_main_weapon")
	if not first_weapon.is_reloading:
		return _fail("manual reload request did not start reload")
	if PlayerData.main_weapon_index != 1 or player.get_main_weapon() != second_weapon:
		return _fail("Assist post-reload processing did not switch to the ready offhand weapon")
	return true

func _test_reload_hint_throttle() -> bool:
	GlobalVariables.ui = null
	var hint_player := HintRecorderPlayer.new()
	add_child(hint_player)
	var weapon := _instantiate_test_weapon()
	add_child(weapon)
	weapon.is_reloading = true
	var runtime := ACTIVE_SKILL_RUNTIME_SCRIPT.new() as PlayerActiveSkillRuntime
	runtime.setup(hint_player)
	runtime.try_show_reload_block_hint(weapon)
	runtime.try_show_reload_block_hint(weapon)
	if hint_player.hint_count != 1:
		return _fail("reload hint throttle expected one hint from two immediate requests")
	if hint_player.last_hint_key != &"reload_blocked":
		return _fail("reload hint key changed: %s" % str(hint_player.last_hint_key))
	if not is_equal_approx(hint_player.last_hint_throttle_sec, 1.25):
		return _fail("reload hint throttle interval changed")
	runtime.set("_reload_block_hint_ready_at_msec", 0)
	runtime.try_show_reload_block_hint(weapon)
	if hint_player.hint_count != 2:
		return _fail("reload hint did not resume after throttle deadline reset")
	weapon.queue_free()
	hint_player.queue_free()
	return true

func _instantiate_test_weapon() -> Weapon:
	var weapon := WEAPON_BASE_SCENE.instantiate() as Weapon
	if weapon == null:
		return null
	weapon.set_script(TEST_WEAPON_SCRIPT)
	return weapon as Weapon

func _on_player_active_signal() -> void:
	_player_active_signal_count += 1

func _on_legacy_active_signal() -> void:
	_legacy_active_signal_count += 1

func _on_weapon_active_signal() -> void:
	_weapon_active_signal_count += 1

func _on_weapon_active_triggered(success: bool, reason: String) -> void:
	if success:
		_weapon_trigger_success_count += 1
	else:
		_weapon_trigger_failure_count += 1
	_last_weapon_trigger_reason = reason

func _assert_float(expected: float, actual: float, label: String) -> bool:
	if is_equal_approx(expected, actual):
		return true
	return _fail("%s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _fail(message: String) -> bool:
	if not _failed:
		_failed = true
		PlayerAssistSettings.auto_reload_switch = _original_auto_reload_switch
		GlobalVariables.ui = null
		push_error("FAIL: player active skill characterization: " + message)
		get_tree().quit(1)
	return false
