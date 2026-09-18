extends Node2D

const WARNING_SCENE := preload("res://Npc/enemy/scenes/target_warning.tscn")
const HIT_LABEL_SCENE := preload("res://UI/labels/hit_label.tscn")
const HUD_SCENE := preload("res://UI/components/PlayerStatusHud/PlayerStatusHud.tscn")
const WEAPON_SLOT_SCENE := preload("res://UI/components/WeaponSlot/WeaponSlot.tscn")
const SCREEN_OVERLAY := preload("res://Player/Mechas/scripts/player_damage_screen_overlay.gd")
const STATUS_MANAGER := preload("res://Player/Mechas/scripts/floating_status_hint_manager.gd")
const SHOWCASE_WEAPON := preload("res://tests/showcases/combat_feedback/showcase_weapon.gd")

var _elapsed := 0.0
var _feedback_elapsed := 0.0
var _warning_elapsed := 0.0
var _state_index := 0
var _hud: Control
var _weapon_slot: Control
var _screen_overlay: Control
var _status_host: Node2D
var _status_manager: Node

func _ready() -> void:
	queue_redraw()
	_build_ui_samples()
	_spawn_warning_samples()
	call_deferred("_spawn_feedback_samples")
	_capture_if_requested()

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	_feedback_elapsed += maxf(delta, 0.0)
	_warning_elapsed += maxf(delta, 0.0)
	if _feedback_elapsed >= 1.35:
		_feedback_elapsed = 0.0
		_spawn_feedback_samples()
		_cycle_player_state()
	if _warning_elapsed >= 1.55:
		_warning_elapsed = 0.0
		_spawn_warning_samples()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("07131a"))
	for x in range(0, 1280, 32):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.12, 0.25, 0.29, 0.18), 1.0)
	for y in range(0, 720, 32):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.12, 0.25, 0.29, 0.18), 1.0)
	# Deliberate combat clutter behind the feedback samples.
	for index in range(18):
		var center := Vector2(160 + index * 54, 285 + sin(index * 1.7) * 70)
		draw_circle(center, 5.0, Color(0.55, 0.72, 0.78, 0.55))
		draw_line(center - Vector2(24, 10), center + Vector2(22, 9), Color(0.31, 0.62, 0.70, 0.34), 2.0)

func _build_ui_samples() -> void:
	var fixed_layer := CanvasLayer.new()
	fixed_layer.layer = 90
	add_child(fixed_layer)
	var title := Label.new()
	title.position = Vector2(32, 20)
	title.text = "COMBAT FEEDBACK HIERARCHY · 1280 × 720"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("dffaff"))
	fixed_layer.add_child(title)
	var legend := Label.new()
	legend.position = Vector2(32, 54)
	legend.text = "Enemy danger / player preview     Damage / critical / status     Health / shield / ready / overheat"
	legend.add_theme_font_size_override("font_size", 13)
	legend.add_theme_color_override("font_color", Color("8fb1bb"))
	fixed_layer.add_child(legend)
	_hud = HUD_SCENE.instantiate()
	_hud.position = Vector2(790, 612)
	fixed_layer.add_child(_hud)
	_hud.call("set_health", 48, 100, 28, 100)
	_hud.call("set_skill_available", true)
	_hud.call("set_skill_cost", 50.0)
	_hud.call("set_energy", 50.0, 100.0)
	_hud.call("set_cooldown", 0.0, 4.0)
	_weapon_slot = WEAPON_SLOT_SCENE.instantiate()
	_weapon_slot.position = Vector2(1148, 574)
	fixed_layer.add_child(_weapon_slot)
	var dummy_weapon := SHOWCASE_WEAPON.new()
	_weapon_slot.add_child(dummy_weapon)
	_weapon_slot.call("set_weapon", dummy_weapon)
	_weapon_slot.call("set_heat", 86.0, 100.0, false)
	var survival_layer := CanvasLayer.new()
	survival_layer.layer = 80
	add_child(survival_layer)
	_screen_overlay = SCREEN_OVERLAY.new()
	survival_layer.add_child(_screen_overlay)
	_status_host = Node2D.new()
	_status_host.global_position = Vector2(630, 390)
	add_child(_status_host)
	_status_manager = STATUS_MANAGER.new()
	_status_host.add_child(_status_manager)
	_status_manager.call("setup", _status_host, 1.0, 26.0, 0.2, 0.5)

func _spawn_warning_samples() -> void:
	for item in get_tree().get_nodes_in_group(&"showcase_warning"):
		if is_instance_valid(item):
			item.queue_free()
	_spawn_enemy_warning(Vector2(220, 205), CombatFeedbackSpec.DangerLevel.CAUTION)
	_spawn_enemy_warning(Vector2(425, 205), CombatFeedbackSpec.DangerLevel.DANGER)
	_spawn_enemy_warning(Vector2(630, 205), CombatFeedbackSpec.DangerLevel.LETHAL)
	var preview := WARNING_SCENE.instantiate() as TargetWarning
	preview.add_to_group(&"showcase_warning")
	preview.position = Vector2(835, 205)
	preview.configure_player_preview(1.5, 62.0)
	add_child(preview)

func _spawn_enemy_warning(position_value: Vector2, level: CombatFeedbackSpec.DangerLevel) -> void:
	var warning := WARNING_SCENE.instantiate() as TargetWarning
	warning.add_to_group(&"showcase_warning")
	warning.position = position_value
	warning.configure_enemy_danger(1.5, 62.0, level)
	add_child(warning)

func _spawn_feedback_samples() -> void:
	_spawn_hit_label(Vector2(420, 430), {"final_damage": 18, "target_max_hp": 200})
	_spawn_hit_label(Vector2(535, 430), {"final_damage": 42, "target_max_hp": 200, "is_critical": true})
	_spawn_hit_label(Vector2(650, 430), {"final_damage": 5, "target_max_hp": 200, "is_periodic": true, "damage_type": Attack.TYPE_FIRE})
	_status_manager.call("enqueue_keyed_raw_hint", "GAINED: MOVE SPEED", &"showcase_positive", 0.1, CombatFeedbackSpec.FeedbackKind.STATUS_POSITIVE)
	_status_manager.call("enqueue_keyed_raw_hint", "LOST: ARMOR", &"showcase_negative", 0.1, CombatFeedbackSpec.FeedbackKind.STATUS_NEGATIVE)
	_screen_overlay.call("play_hit", Vector2(-0.85, 0.25), 0.74, Attack.TYPE_PHYSICAL, false)

func _spawn_hit_label(position_value: Vector2, data: Dictionary) -> void:
	var label := HIT_LABEL_SCENE.instantiate()
	label.position = position_value
	label.call("configure", data)
	add_child(label)

func _cycle_player_state() -> void:
	_state_index = (_state_index + 1) % 4
	match _state_index:
		0:
			_hud.call("set_health", 48, 100, 28, 100)
			_weapon_slot.call("set_heat", 55.0, 100.0, false)
		1:
			_hud.call("set_health", 34, 100, 14, 100)
			_weapon_slot.call("set_heat", 86.0, 100.0, false)
		2:
			_hud.call("set_health", 16, 100, 0, 100)
			_weapon_slot.call("set_heat", 100.0, 100.0, true)
		3:
			_hud.call("set_health", 48, 100, 0, 100)
			_weapon_slot.call("set_heat", 70.0, 100.0, false)

func _capture_if_requested() -> void:
	var capture_path := ""
	var capture_delay := 0.10
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-path="):
			capture_path = argument.trim_prefix("--capture-path=")
		elif argument.begins_with("--capture-delay="):
			capture_delay = maxf(float(argument.trim_prefix("--capture-delay=")), 0.0)
	if capture_path.is_empty():
		return
	await get_tree().process_frame
	if capture_delay > 0.0:
		await get_tree().create_timer(capture_delay).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	print("COMBAT_FEEDBACK_CAPTURE=%s ERROR=%d" % [capture_path, error])
	if _status_manager != null and is_instance_valid(_status_manager):
		_status_manager.call("clear_all")
	var projected_layer := get_tree().root.get_node_or_null("HybridWorldUi")
	if projected_layer != null:
		projected_layer.queue_free()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if error == OK else 1)
