extends Node2D

const LASER_SCENE := preload("res://Player/Weapons/Instances/laser.tscn")
const DUMMY_SCENE := preload("res://World/Test/dps_test_dummy_enemy.tscn")

var _laser: Weapon
var _status_label: RichTextLabel
var _log_label: RichTextLabel
var _log_lines: PackedStringArray = []
var _dummy_layer: Node2D

func _ready() -> void:
	DataHandler.load_weapon_branch_data()
	_build_overlay()
	_spawn_dummies()
	await _set_branch_mode([])

func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Overlay"
	canvas.layer = 80
	add_child(canvas)

	var root := HBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 16.0
	root.offset_top = 16.0
	root.offset_right = -16.0
	root.offset_bottom = -16.0
	root.add_theme_constant_override("separation", 12)
	canvas.add_child(root)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(430, 0)
	root.add_child(left_panel)

	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_box)

	var title := Label.new()
	title.text = "Laser Branch Showcase"
	title.add_theme_font_size_override("font_size", 24)
	left_box.add_child(title)

	var instructions := RichTextLabel.new()
	instructions.bbcode_enabled = true
	instructions.fit_content = true
	instructions.custom_minimum_size = Vector2(390, 210)
	instructions.text = "\n".join([
		"[b]Purpose[/b]",
		"Switch Laser branch combinations without entering the normal reward flow.",
		"",
		"[b]Buttons[/b]",
		"Use branch buttons to rebuild the Laser, then fire at the dummy row.",
		"Tracking Lens and Prism Splitter are intentionally compatible and can be active together.",
	])
	left_box.add_child(instructions)

	_add_button(left_box, "No branches", Callable(self, "_on_no_branches"))
	_add_button(left_box, "Tracking Lens only", Callable(self, "_on_tracking_only"))
	_add_button(left_box, "Prism Splitter only", Callable(self, "_on_prism_only"))
	_add_button(left_box, "Both branches", Callable(self, "_on_both_branches"))
	_add_button(left_box, "Fire Laser", Callable(self, "_on_fire_laser"))
	_add_button(left_box, "Reset Dummies", Callable(self, "_spawn_dummies"))

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right_panel)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_box)

	_status_label = RichTextLabel.new()
	_status_label.bbcode_enabled = true
	_status_label.custom_minimum_size = Vector2(520, 260)
	right_box.add_child(_status_label)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.custom_minimum_size = Vector2(520, 260)
	right_box.add_child(_log_label)

func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(callback)
	parent.add_child(button)

func _spawn_dummies() -> void:
	if _dummy_layer and is_instance_valid(_dummy_layer):
		_dummy_layer.queue_free()
	_dummy_layer = Node2D.new()
	_dummy_layer.name = "DummyLayer"
	add_child(_dummy_layer)
	for i in range(5):
		var dummy := DUMMY_SCENE.instantiate() as DpsTestDummyEnemy
		dummy.name = "LaserDummy%d" % i
		dummy.max_hp_value = 3000
		dummy.global_position = Vector2(650, 210 + i * 95)
		dummy.damage_received.connect(_on_dummy_damage_received)
		_dummy_layer.add_child(dummy)
	_log("Dummies reset.")

func _on_no_branches() -> void:
	await _set_branch_mode([])

func _on_tracking_only() -> void:
	await _set_branch_mode(["laser_tracking_lens"])

func _on_prism_only() -> void:
	await _set_branch_mode(["laser_prism_splitter"])

func _on_both_branches() -> void:
	await _set_branch_mode(["laser_tracking_lens", "laser_prism_splitter"])

func _set_branch_mode(branch_ids: Array) -> void:
	_clear_laser()
	_laser = LASER_SCENE.instantiate() as Weapon
	_laser.name = "ShowcaseLaser"
	_laser.global_position = Vector2(220, 400)
	add_child(_laser)
	await get_tree().process_frame
	_laser.set_level(5)
	_laser.fuse = 3
	for branch_id in branch_ids:
		var added := bool(_laser.branch_runtime.add_branch(str(branch_id)))
		_log("Add branch %s: %s" % [str(branch_id), "OK" if added else "FAILED"])
	_refresh_status()

func _clear_laser() -> void:
	if _laser and is_instance_valid(_laser):
		_laser.queue_free()
	_laser = null
	for child in get_tree().root.get_children():
		if child.name == "BeamBase":
			child.queue_free()

func _on_fire_laser() -> void:
	if _laser == null:
		return
	var profiles: Array = _laser.call("build_laser_beam_profiles", Vector2.RIGHT * 1000.0)
	_laser.call("fire_laser_toward", Vector2.RIGHT * 1000.0)
	_log("Fired %d beam profile(s): %s" % [profiles.size(), _summarize_profiles(profiles)])
	_refresh_status()

func _summarize_profiles(profiles: Array) -> String:
	var parts: PackedStringArray = []
	for profile_variant in profiles:
		var profile := profile_variant as Dictionary
		parts.append("%s dmg=%.2f width=%.2f angle=%.1f" % [
			str(profile.get("beam_tag", "main")),
			float(profile.get("damage_multiplier", 1.0)),
			float(profile.get("width_multiplier", 1.0)),
			float(profile.get("angle_offset_deg", 0.0)),
		])
	return "; ".join(parts)

func _on_dummy_damage_received(dummy: DpsTestDummyEnemy, amount: int, _attack: Attack, hp_after: int) -> void:
	_log("%s took %d damage, hp=%d" % [dummy.name, amount, hp_after])

func _refresh_status() -> void:
	if _status_label == null:
		return
	if _laser == null:
		_status_label.text = "No Laser spawned."
		return
	var profiles: Array = _laser.call("build_laser_beam_profiles", Vector2.RIGHT * 1000.0)
	var lines: PackedStringArray = []
	lines.append("[b]Live Laser[/b]")
	lines.append("Level: %d" % int(_laser.level))
	lines.append("Fuse: %d" % int(_laser.fuse))
	lines.append("Branches: %s" % (", ".join(_laser.branch_runtime.branch_ids) if not _laser.branch_runtime.branch_ids.is_empty() else "none"))
	lines.append("Runtime shot damage: %d" % int(_laser.call("get_runtime_shot_damage")))
	lines.append("Beam profiles: %d" % profiles.size())
	lines.append(_summarize_profiles(profiles))
	_status_label.text = "\n".join(lines)

func _log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > 12:
		_log_lines.remove_at(0)
	if _log_label:
		_log_label.text = "[b]Log[/b]\n" + "\n".join(_log_lines)
