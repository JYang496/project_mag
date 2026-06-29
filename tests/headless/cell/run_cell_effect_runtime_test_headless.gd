extends Node

var _phase_manager: Node
var _cell_effect_runtime: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	var tree := get_tree()
	_phase_manager = tree.root.get_node_or_null("PhaseManager")
	_cell_effect_runtime = tree.root.get_node_or_null("CellEffectRuntime")
	if _phase_manager == null or _cell_effect_runtime == null:
		_fail("CellEffectRuntimeTest: missing autoloads.")
		return
	_phase_manager.call("reset_runtime_state")
	_phase_manager.set("phase", "prepare")
	_phase_manager.set("current_level", 0)
	_cell_effect_runtime.call("reset_runtime_state")
	_cell_effect_runtime.call("load_definitions")
	var speed_def = _cell_effect_runtime.call("get_definition", "speed_1")
	var regen_def = _cell_effect_runtime.call("get_definition", "regen_1")
	if speed_def == null or regen_def == null:
		_fail("CellEffectRuntimeTest: missing speed_1 or regen_1 definition.")
		return
	var rewards: Array = _cell_effect_runtime.call("build_reward_options", 0, 3)
	if rewards.size() != 2:
		_fail("CellEffectRuntimeTest: expected 2 early reward families, got %d." % rewards.size())
		return
	_assert_reward_family_count(1, 2)
	_assert_reward_family_count(2, 3)
	_assert_reward_family_count(6, 3)
	_assert_reward_family_count(8, 3)
	_assert_reward_family_count(9, 3)
	var starting_effect_id := str(_cell_effect_runtime.call("grant_random_unlocked_effect", 0, 1))
	if starting_effect_id == "":
		_fail("CellEffectRuntimeTest: failed to grant a random starting effect.")
		return
	var starting_effect = _cell_effect_runtime.call("get_definition", starting_effect_id)
	if starting_effect == null:
		_fail("CellEffectRuntimeTest: random starting effect id is missing a definition.")
		return
	if int(starting_effect.get("unlock_level")) > 1:
		_fail("CellEffectRuntimeTest: random starting effect should be unlocked at level 1.")
		return
	if int(_cell_effect_runtime.call("get_owned_count", starting_effect_id)) != 1:
		_fail("CellEffectRuntimeTest: random starting effect should add exactly one inventory copy.")
		return
	_cell_effect_runtime.call("reset_runtime_state")
	if not bool(_cell_effect_runtime.call("grant_effect", "speed_1")):
		_fail("CellEffectRuntimeTest: failed to grant speed_1.")
		return
	if int(_cell_effect_runtime.call("get_available_count", "speed_1")) != 1:
		_fail("CellEffectRuntimeTest: speed_1 available count should be 1.")
		return
	var board_script := load("res://World/board_cell_generator.gd") as Script
	var board = board_script.new()
	board.name = "Board"
	board.cell_scene = load("res://Board/Cells/cell.tscn") as PackedScene
	tree.root.add_child(board)
	await tree.process_frame
	await tree.process_frame
	var result: Dictionary = _cell_effect_runtime.call("set_pending_effect", 5, "speed_1")
	if not bool(result.get("ok", false)):
		_fail("CellEffectRuntimeTest: failed to set pending effect: %s" % str(result))
		return
	if int(_cell_effect_runtime.call("get_available_count", "speed_1")) != 0:
		_fail("CellEffectRuntimeTest: pending effect should reserve inventory.")
		return
	_cell_effect_runtime.call("apply_to_board", board, true)
	var cell = board.call("get_cell_by_logical_id", 5)
	if cell == null:
		_fail("CellEffectRuntimeTest: missing cell 5.")
		return
	if int(cell.get("terrain_type")) != 3:
		_fail("CellEffectRuntimeTest: pending preview did not set speed terrain.")
		return
	if bool(cell.get("aura_enabled")):
		_fail("CellEffectRuntimeTest: pending preview should not enable aura logic.")
		return
	_cell_effect_runtime.call("commit_pending", board)
	if int(_cell_effect_runtime.call("get_owned_count", "speed_1")) != 0:
		_fail("CellEffectRuntimeTest: commit should consume speed_1.")
		return
	if str(_cell_effect_runtime.call("get_effect_for_cell", 5, false)) != "speed_1":
		_fail("CellEffectRuntimeTest: committed effect missing from cell 5.")
		return
	if int(cell.get("terrain_type")) != 3 or not bool(cell.get("aura_enabled")):
		_fail("CellEffectRuntimeTest: committed effect should enable speed aura.")
		return
	if not bool(_cell_effect_runtime.call("grant_effect", "regen_1")):
		_fail("CellEffectRuntimeTest: failed to grant regen_1.")
		return
	result = _cell_effect_runtime.call("set_pending_effect", 6, "regen_1")
	if not bool(result.get("ok", false)):
		_fail("CellEffectRuntimeTest: failed to set regen pending effect: %s" % str(result))
		return
	_cell_effect_runtime.call("commit_pending", board)
	if int(_cell_effect_runtime.call("get_owned_count", "speed_1")) != 0 or int(_cell_effect_runtime.call("get_owned_count", "regen_1")) != 0:
		_fail("CellEffectRuntimeTest: committed installed effects should not leave inventory copies.")
		return
	result = _cell_effect_runtime.call("swap_installed_effects", 5, 6)
	if not bool(result.get("ok", false)):
		_fail("CellEffectRuntimeTest: failed to swap installed effects: %s" % str(result))
		return
	if str(_cell_effect_runtime.call("get_effect_for_cell", 5, false)) != "regen_1":
		_fail("CellEffectRuntimeTest: cell 5 should receive regen_1 after swap.")
		return
	if str(_cell_effect_runtime.call("get_effect_for_cell", 6, false)) != "speed_1":
		_fail("CellEffectRuntimeTest: cell 6 should receive speed_1 after swap.")
		return
	if int(_cell_effect_runtime.call("get_owned_count", "speed_1")) != 0 or int(_cell_effect_runtime.call("get_owned_count", "regen_1")) != 0:
		_fail("CellEffectRuntimeTest: swapping installed effects should not mutate inventory.")
		return
	_cell_effect_runtime.call("apply_to_board", board, false)
	var swapped_cell = board.call("get_cell_by_logical_id", 6)
	if swapped_cell == null or int(swapped_cell.get("terrain_type")) != 3:
		_fail("CellEffectRuntimeTest: swapped board preview should move speed terrain to cell 6.")
		return
	board.queue_free()
	_cell_effect_runtime.call("reset_runtime_state")
	print("CellEffectRuntimeTest: PASS")
	tree.quit(0)

func _fail(message: String) -> void:
	push_error(message)
	if _cell_effect_runtime != null:
		_cell_effect_runtime.call("reset_runtime_state")
	get_tree().quit(1)

func _assert_reward_family_count(level_one_based: int, expected_option_count: int) -> void:
	var rewards: Array = _cell_effect_runtime.call("build_reward_options", level_one_based - 1, 3)
	if rewards.size() != expected_option_count:
		_fail("CellEffectRuntimeTest: level %d expected %d options, got %d." % [level_one_based, expected_option_count, rewards.size()])
		return
	var families := {}
	for reward in rewards:
		var effect_id := str(reward.get("cell_effect_id"))
		var definition = _cell_effect_runtime.call("get_definition", effect_id)
		if definition == null:
			_fail("CellEffectRuntimeTest: missing definition for reward %s." % effect_id)
			return
		var family := str(definition.call("get_family_id"))
		if families.has(family):
			_fail("CellEffectRuntimeTest: duplicate reward family '%s' at level %d." % [family, level_one_based])
			return
		families[family] = true
