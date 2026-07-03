extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const WEAPON_ID_MAIN := "1"
const WEAPON_ID_INVENTORY_ONLY := "5"

var _player: Player
var _ui: UI
var _test_layer: CanvasLayer
var _status_label: RichTextLabel
var _log_label: RichTextLabel
var _step_results: Dictionary = {}
var _last_log: PackedStringArray = []

func _ready() -> void:
	_build_test_overlay()
	_reset_test_rig()
	set_process(true)

func _process(_delta: float) -> void:
	_sync_test_overlay_visibility()
	_refresh_status()

func _build_test_overlay() -> void:
	_test_layer = CanvasLayer.new()
	_test_layer.name = "WeaponFuseManualTestOverlay"
	_test_layer.layer = 80
	add_child(_test_layer)

	var root := HBoxContainer.new()
	root.name = "Root"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 16.0
	root.offset_top = 16.0
	root.offset_right = -16.0
	root.offset_bottom = -16.0
	root.add_theme_constant_override("separation", 12)
	_test_layer.add_child(root)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(520, 0)
	root.add_child(left_panel)

	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_box)

	var title := Label.new()
	title.text = "Weapon Fuse Manual Test"
	title.add_theme_font_size_override("font_size", 24)
	left_box.add_child(title)

	var instructions := RichTextLabel.new()
	instructions.custom_minimum_size = Vector2(480, 310)
	instructions.fit_content = true
	instructions.bbcode_enabled = true
	instructions.text = _build_instruction_text()
	left_box.add_child(instructions)

	_add_button(left_box, "Reset test rig", Callable(self, "_reset_test_rig"))
	_add_button(left_box, "1. Obtain equipped duplicate: Fuse 1 -> 2", Callable(self, "_test_equipped_duplicate_fuse"))
	_add_button(left_box, "2. Obtain next duplicate: Fuse 2 -> 3", Callable(self, "_test_second_duplicate_fuse"))
	_add_button(left_box, "3. Max-fuse duplicate converts to gold", Callable(self, "_test_max_fuse_gold_conversion"))
	_add_button(left_box, "4. Inventory-only duplicate does not auto-fuse", Callable(self, "_test_inventory_only_duplicate"))
	_add_button(left_box, "5. Battle-time fuse queues branch panel", Callable(self, "_test_battle_deferred_branch_queue"))
	_add_button(left_box, "Choose first visible branch", Callable(self, "_choose_first_visible_branch"))

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right_panel)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_box)

	_status_label = RichTextLabel.new()
	_status_label.custom_minimum_size = Vector2(560, 310)
	_status_label.bbcode_enabled = true
	right_box.add_child(_status_label)

	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(560, 260)
	_log_label.bbcode_enabled = true
	right_box.add_child(_log_label)

func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(callback)
	parent.add_child(button)

func _build_instruction_text() -> String:
	return "\n".join([
		"[b]Purpose[/b]",
		"Use this scene to manually verify the new automatic weapon fuse flow.",
		"",
		"[b]Required checks[/b]",
		"1. Equipped duplicate raises fuse and does not change level.",
		"2. Each fuse increase queues a mandatory branch choice.",
		"3. Select a branch in the real branch panel, or press the helper button.",
		"4. Max-fuse duplicate converts to gold.",
		"5. Inventory-only duplicate reports not_applicable and does not auto-fuse.",
		"6. During battle, branch panel stays closed until returning to prepare.",
		"7. Smith UI has no Gear Fuse entry.",
		"",
		"[b]Expected interaction[/b]",
		"Run the buttons top to bottom. Watch PASS/FAIL on the right.",
		"When the branch panel appears, click a branch card to continue.",
	])

func _reset_test_rig() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()
	if _ui and is_instance_valid(_ui):
		_ui.queue_free()
	await get_tree().process_frame

	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	DataHandler.load_weapon_data()
	DataHandler.load_weapon_branch_data()
	DataHandler.load_economy_data()

	_ui = UI_SCENE.instantiate() as UI
	add_child(_ui)
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame

	_step_results.clear()
	_last_log.clear()
	_log("Test rig reset. Initial weapon should be Machine Gun at Fuse 1.")
	_refresh_status()

func _test_equipped_duplicate_fuse() -> void:
	var weapon := _get_main_weapon()
	if weapon == null:
		_fail("equipped_duplicate", "No equipped weapon.")
		return
	var previous_level := int(weapon.level)
	var outcome := _player.try_auto_fuse_weapon_obtain(WEAPON_ID_MAIN)
	var ok := str(outcome.get("result", "")) == "fused" and int(weapon.fuse) == 2 and int(weapon.level) == previous_level
	_record("equipped_duplicate", ok, "Expected Fuse 2 and unchanged level. Outcome=%s" % str(outcome))

func _test_second_duplicate_fuse() -> void:
	var weapon := _get_main_weapon()
	if weapon == null:
		_fail("second_duplicate", "No equipped weapon.")
		return
	if int(weapon.fuse) < 2:
		_fail("second_duplicate", "Run step 1 first.")
		return
	if _ui.has_pending_branch_selection():
		_log("A branch choice is pending. Choose a branch, then press step 2 again.")
		return
	var previous_level := int(weapon.level)
	var outcome := _player.try_auto_fuse_weapon_obtain(WEAPON_ID_MAIN)
	var ok := str(outcome.get("result", "")) == "fused" and int(weapon.fuse) == 3 and int(weapon.level) == previous_level
	_record("second_duplicate", ok, "Expected Fuse 3 and unchanged level. Outcome=%s" % str(outcome))

func _test_max_fuse_gold_conversion() -> void:
	var weapon := _get_main_weapon()
	if weapon == null:
		_fail("max_fuse_gold", "No equipped weapon.")
		return
	weapon.fuse = int(weapon.FINAL_MAX_FUSE)
	var before_gold := int(PlayerData.player_gold)
	var before_level := int(weapon.level)
	var outcome := _player.try_auto_fuse_weapon_obtain(WEAPON_ID_MAIN)
	var ok := str(outcome.get("result", "")) == "converted_to_gold" and int(PlayerData.player_gold) > before_gold and int(weapon.level) == before_level
	_record("max_fuse_gold", ok, "Expected gold increase and unchanged level. Outcome=%s" % str(outcome))

func _test_inventory_only_duplicate() -> void:
	var weapon_def := DataHandler.read_weapon_data(WEAPON_ID_INVENTORY_ONLY) as WeaponDefinition
	if weapon_def == null or weapon_def.scene == null:
		_fail("inventory_only", "Inventory-only weapon definition missing.")
		return
	var equipped_before := PlayerData.player_weapon_list.size()
	var outcome := _player.try_auto_fuse_weapon_obtain(WEAPON_ID_INVENTORY_ONLY)
	var ok := str(outcome.get("result", "")) == "not_applicable" and PlayerData.player_weapon_list.size() == equipped_before
	_record("inventory_only", ok, "Expected not_applicable and no equipped weapon fuse. Outcome=%s" % str(outcome))

func _test_battle_deferred_branch_queue() -> void:
	await _reset_test_rig()
	var weapon := _get_main_weapon()
	if weapon == null:
		_fail("battle_defer", "No equipped weapon.")
		return
	PhaseManager.enter_battle()
	var outcome := _player.try_auto_fuse_weapon_obtain(WEAPON_ID_MAIN)
	var panel_closed_in_battle := _ui.branch_select_panel != null and not _ui.branch_select_panel.visible
	PhaseManager.enter_prepare()
	await get_tree().process_frame
	await get_tree().process_frame
	var panel_open_after_prepare := _ui.branch_select_panel != null and _ui.branch_select_panel.visible
	var ok := str(outcome.get("result", "")) == "fused" and panel_closed_in_battle and panel_open_after_prepare
	_record("battle_defer", ok, "Expected queued branch panel to open after prepare. Outcome=%s" % str(outcome))

func _choose_first_visible_branch() -> void:
	if _ui == null or _ui.branch_select_panel == null or not _ui.branch_select_panel.visible:
		_log("No branch panel is currently visible.")
		return
	var panel := _ui.branch_select_panel
	if panel._branch_ids.is_empty():
		_log("Branch panel has no branch ids.")
		return
	panel._on_branch_button_pressed(str(panel._branch_ids[0]))
	_log("Selected first visible branch: %s" % str(panel._branch_ids[0] if not panel._branch_ids.is_empty() else "applied"))

func _sync_test_overlay_visibility() -> void:
	if _test_layer == null:
		return
	var branch_panel_visible := _ui != null and _ui.branch_select_panel != null and _ui.branch_select_panel.visible
	_test_layer.visible = not branch_panel_visible

func _get_main_weapon() -> Weapon:
	if PlayerData.player_weapon_list.is_empty():
		return null
	return PlayerData.player_weapon_list[0] as Weapon

func _record(key: String, ok: bool, detail: String) -> void:
	_step_results[key] = ok
	if ok:
		_log("[PASS] %s: %s" % [key, detail])
	else:
		_log("[FAIL] %s: %s" % [key, detail])

func _fail(key: String, detail: String) -> void:
	_record(key, false, detail)

func _log(line: String) -> void:
	_last_log.append(line)
	while _last_log.size() > 14:
		_last_log.remove_at(0)
	if _log_label:
		_log_label.text = "[b]Log[/b]\n" + "\n".join(_last_log)

func _refresh_status() -> void:
	if _status_label == null:
		return
	var weapon := _get_main_weapon()
	var lines: PackedStringArray = []
	lines.append("[b]Live State[/b]")
	lines.append("Phase: %s" % PhaseManager.current_state())
	lines.append("Gold: %d" % int(PlayerData.player_gold))
	lines.append("Equipped weapons: %d" % PlayerData.player_weapon_list.size())
	lines.append("Temporary modules: %d" % InventoryData.temporary_modules.size())
	if weapon:
		lines.append("Main weapon id: %s" % DataHandler.get_weapon_id_from_instance(weapon))
		lines.append("Main weapon fuse: %d / %d" % [int(weapon.fuse), int(weapon.FINAL_MAX_FUSE)])
		lines.append("Main weapon level: %d / %d" % [int(weapon.level), int(weapon.max_level)])
		lines.append("Selected branches: %s" % (", ".join(weapon.branch_runtime.branch_ids) if not weapon.branch_runtime.branch_ids.is_empty() else "none"))
	lines.append("Branch panel visible: %s" % str(_ui != null and _ui.branch_select_panel != null and _ui.branch_select_panel.visible))
	lines.append("Branch selection pending/blocking: %s" % str(_ui != null and _ui.has_pending_branch_selection()))
	lines.append("")
	lines.append("[b]Checklist Results[/b]")
	for key in ["equipped_duplicate", "second_duplicate", "max_fuse_gold", "inventory_only", "battle_defer"]:
		var value: Variant = _step_results.get(key, null)
		var text := "NOT RUN"
		if value != null:
			text = "PASS" if bool(value) else "FAIL"
		lines.append("%s: %s" % [key, text])
	_status_label.text = "\n".join(lines)
