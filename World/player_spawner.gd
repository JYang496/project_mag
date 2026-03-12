extends Node2D

const START_BATTLE_BUTTON_SCRIPT = preload("res://World/start_battle_button.gd")

var start_up_status = {
	"player_speed":100.0,
	"player_max_hp":5,
	"hp_regen":0,
	"armor":0,
	"shield":0,
	"damage_reduction":1.0,
	"crit_rate":0.0,
	"crit_damage":1.0,
	"grab_radius":50.0,
	"player_gold":0,
}

var _cell_area : Area2D
var _player_inside_cell : bool = false
var _current_cell: Cell
var _highlight_active := false
var _start_battle_button: StartBattleButton

func _ready() -> void:
	PlayerData.player_weapon_list.clear()
	PlayerData.detected_enemies.clear()
	PlayerData.cloestest_enemy = null
	GlobalVariables.mech_data = DataHandler.read_mecha_data(str(PlayerData.select_mecha_id))
	GlobalVariables.autosave_data = DataHandler.read_autosave_mecha_data(str(PlayerData.select_mecha_id))
	PlayerData.round_coin_collected = 0
	PlayerData.round_chip_collected = 0
	var select_mecha_load = GlobalVariables.mech_data.scene
	set_start_up_status()
	var ins = select_mecha_load.instantiate()
	ins.global_position = global_position
	PlayerData.player = ins
	_player_inside_cell = true
	call_deferred("_add_player_to_root", ins)
	_setup_cell_monitor()
	_connect_phase_signals()
	_refresh_start_battle_button(PhaseManager.current_state())
	
func set_start_up_status():
	var lvl_index = int(GlobalVariables.autosave_data["current_level"]) - 1
	PlayerData.player_exp = int(GlobalVariables.autosave_data["current_exp"])
	PlayerData.player_level = int(GlobalVariables.autosave_data["current_level"])
	PlayerData.next_level_exp = int(GlobalVariables.mech_data.next_level_exp[lvl_index])
	PlayerData.player_speed = float(GlobalVariables.mech_data.player_speed[lvl_index])
	PlayerData.player_max_hp = int(GlobalVariables.mech_data.player_max_hp[lvl_index])
	PlayerData.player_hp = PlayerData.player_max_hp
	PlayerData.hp_regen = int(GlobalVariables.mech_data.hp_regen[lvl_index])
	PlayerData.armor = int(GlobalVariables.mech_data.armor[lvl_index])
	PlayerData.shield = int(GlobalVariables.mech_data.shield[lvl_index])
	PlayerData.damage_reduction = float(GlobalVariables.mech_data.damage_reduction[lvl_index])
	PlayerData.crit_rate = float(GlobalVariables.mech_data.crit_rate[lvl_index])
	PlayerData.crit_damage = float(GlobalVariables.mech_data.crit_damage[lvl_index])
	PlayerData.grab_radius = float(GlobalVariables.mech_data.grab_radius[lvl_index])
	PlayerData.player_gold = int(GlobalVariables.mech_data.player_gold[lvl_index])

func _setup_cell_monitor() -> void:
	var cell := _find_parent_cell()
	_current_cell = cell
	if cell:
		_cell_area = cell.get_node_or_null("Area2D")
	if _cell_area:
		_cell_area.body_entered.connect(_on_cell_area_body_entered)
		_cell_area.body_exited.connect(_on_cell_area_body_exited)
	_refresh_cell_highlight()

func _find_parent_cell() -> Cell:
	var current: Node = get_parent()
	while current:
		if current is Cell:
			return current
		current = current.get_parent()
	return null

func _connect_phase_signals() -> void:
	if not PhaseManager.is_connected("enter_reward_signal", Callable(self, "_on_enter_reward_phase")):
		PhaseManager.connect("enter_reward_signal", Callable(self, "_on_enter_reward_phase"))
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))

func _on_cell_area_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside_cell = true
		_try_enter_prepare_state()
		_refresh_cell_highlight()

func _on_cell_area_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside_cell = false
		_refresh_cell_highlight()

func _start_battle_stage() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	_remove_start_battle_button()
	if GlobalVariables.enemy_spawner:
		GlobalVariables.enemy_spawner.start_timer()
	PhaseManager.enter_battle()

func _on_enter_reward_phase() -> void:
	_try_enter_prepare_state()
	_refresh_cell_highlight()

func _try_enter_prepare_state() -> void:
	if not _player_inside_cell:
		return
	if PhaseManager.current_state() == PhaseManager.REWARD:
		PhaseManager.enter_prepare()
	_refresh_cell_highlight()

func _add_player_to_root(player_instance: Node) -> void:
	var root := get_tree().current_scene
	if root:
		root.add_child(player_instance)
	else:
		get_tree().root.add_child(player_instance)

func _on_phase_changed(new_phase: String) -> void:
	_refresh_cell_highlight(new_phase)
	_refresh_start_battle_button(new_phase)

func _refresh_cell_highlight(forced_state: String = "") -> void:
	if not _current_cell:
		return
	var state := forced_state if forced_state != "" else PhaseManager.current_state()
	var should_highlight := state == PhaseManager.BATTLE and _player_inside_cell
	if should_highlight:
		if _highlight_active:
			return
		_highlight_active = true
	else:
		if not _highlight_active:
			return
		_highlight_active = false

func _refresh_start_battle_button(forced_state: String = "") -> void:
	var state := forced_state if forced_state != "" else PhaseManager.current_state()
	if state == PhaseManager.PREPARE:
		_spawn_start_battle_button()
		return
	_remove_start_battle_button()

func _spawn_start_battle_button() -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	var target_cell := _find_player_current_cell(PlayerData.player.global_position)
	if target_cell == null:
		target_cell = _current_cell
	if target_cell == null:
		return
	var target_position := _get_cell_center_global(target_cell)
	if _start_battle_button and is_instance_valid(_start_battle_button):
		_start_battle_button.global_position = target_position
		return
	_start_battle_button = START_BATTLE_BUTTON_SCRIPT.new() as StartBattleButton
	if _start_battle_button == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = self
	if not _start_battle_button.is_connected("activated", Callable(self, "_on_start_battle_button_activated")):
		_start_battle_button.connect("activated", Callable(self, "_on_start_battle_button_activated"))
	scene_root.call_deferred("add_child", _start_battle_button)
	_start_battle_button.set_deferred("global_position", target_position)

func _remove_start_battle_button() -> void:
	if _start_battle_button and is_instance_valid(_start_battle_button):
		_start_battle_button.queue_free()
	_start_battle_button = null

func _on_start_battle_button_activated() -> void:
	_start_battle_stage()

func _find_player_current_cell(player_position: Vector2) -> Cell:
	var board := get_parent()
	if board == null:
		return null
	for child in board.get_children():
		var cell := child as Cell
		if cell == null:
			continue
		if _cell_contains_point(cell, player_position):
			return cell
	return null

func _cell_contains_point(cell: Cell, point: Vector2) -> bool:
	var capture_polygon: CollisionPolygon2D = cell.get_node_or_null("Area2D/CapturePolygon")
	if capture_polygon and not capture_polygon.polygon.is_empty():
		var local_point := capture_polygon.global_transform.affine_inverse() * point
		return Geometry2D.is_point_in_polygon(local_point, capture_polygon.polygon)
	var collision_shape: CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		var half_size := rectangle.size * 0.5 * collision_shape.scale.abs()
		var local_point := collision_shape.global_transform.affine_inverse() * point
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y
	return false

func _get_cell_center_global(cell: Cell) -> Vector2:
	var capture_polygon: CollisionPolygon2D = cell.get_node_or_null("Area2D/CapturePolygon")
	if capture_polygon and not capture_polygon.polygon.is_empty():
		var local_sum := Vector2.ZERO
		for p in capture_polygon.polygon:
			local_sum += p
		var centroid_local := local_sum / float(capture_polygon.polygon.size())
		return capture_polygon.global_transform * centroid_local
	return cell.global_position
