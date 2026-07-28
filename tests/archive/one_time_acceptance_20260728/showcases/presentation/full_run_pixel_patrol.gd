# Archived 2026-07-28: release-specific full-run screenshot patrol.
extends Node

const WORLD_SCENE := preload("res://World/world.tscn")

var _world: Node
var _output_dir := ""


func _ready() -> void:
	print("PIXEL_PATROL: boot")
	_output_dir = OS.get_environment("PIXEL_PATROL_OUTPUT_DIR")
	if _output_dir.is_empty():
		push_error("PIXEL_PATROL_OUTPUT_DIR is required.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_reset_runtime()
	PhaseManager.current_level = 3
	PhaseManager.phase = PhaseManager.PREPARE
	PlayerAssistSettings.set_auto_aim_continuous_fire(true)
	_world = WORLD_SCENE.instantiate()
	add_child(_world)
	print("PIXEL_PATROL: world instantiated")
	if not await _wait_for_world_ready():
		push_error("Full-run pixel patrol could not reach a ready world.")
		await _finish(2)
		return
	var player := PlayerData.player as Player
	if player != null:
		player.create_weapon("13")
		player.create_weapon("21")
	await _capture("01_prepare")
	print("PIXEL_PATROL: captured prepare")
	var player_spawner := _world.find_child("PlayerSpawner", true, false)
	if player_spawner == null:
		push_error("Full-run pixel patrol could not find PlayerSpawner.")
		await _finish(2)
		return
	player_spawner.call("_start_battle_stage")
	await get_tree().process_frame
	var enemy_spawner := _world.find_child("EnemySpawner", true, false)
	if enemy_spawner == null:
		push_error("Full-run pixel patrol could not find EnemySpawner.")
		await _finish(2)
		return
	Input.action_press("ATTACK")
	for tick in range(4):
		enemy_spawner.call("_on_timer_timeout")
		await get_tree().create_timer(0.35).timeout
	await get_tree().create_timer(1.0).timeout
	await _capture("02_battle_open")
	print("PIXEL_PATROL: captured battle open")
	_select_weapon(player, "13")
	for tick in range(8):
		enemy_spawner.call("_on_timer_timeout")
		await get_tree().create_timer(0.22).timeout
	await get_tree().create_timer(1.2).timeout
	_show_enemy_hp_bars()
	await _capture("03_flamethrower_combat")
	print("PIXEL_PATROL: captured flamethrower combat")
	_select_weapon(player, "21")
	await get_tree().create_timer(1.2).timeout
	_show_enemy_hp_bars()
	await _capture("04_glacier_combat")
	print("PIXEL_PATROL: captured glacier combat")
	Input.action_release("ATTACK")
	var effective_timeout := maxi(PhaseManager.battle_time + 1, 1)
	enemy_spawner.call("finish_battle_with_victory", maxi(PhaseManager.current_level, 0), effective_timeout)
	await get_tree().create_timer(2.0).timeout
	await _capture("05_return_prepare")
	print("PIXEL_PATROL: captured return prepare")
	await _finish(0)


func _wait_for_world_ready() -> bool:
	for frame in range(240):
		if frame > 0 and frame % 60 == 0:
			print("PIXEL_PATROL: waiting for world frame %d" % frame)
		var player: Node = PlayerData.player as Node
		var camera_ready := (
			get_viewport().get_camera_2d() != null
			or get_viewport().get_camera_3d() != null
		)
		var board := _world.get_node_or_null("Board")
		if (
			player != null
			and is_instance_valid(player)
			and player.is_inside_tree()
			and camera_ready
			and board != null
			and board.get_child_count() > 0
		):
			await get_tree().process_frame
			return true
		await get_tree().process_frame
	return false


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	_save_viewport_image("%s.png" % name)
	if OS.get_environment("PIXEL_PATROL_CAPTURE_STABILITY") != "1":
		return
	for frame_index in range(3):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_viewport_image("%s_stability_%02d.png" % [name, frame_index + 1])


func _save_viewport_image(filename: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var output_path := _output_dir.path_join(filename)
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Full-run pixel patrol screenshot failed: %s" % output_path)


func _select_weapon(player: Player, weapon_id: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	var weapon := player.call("_find_equipped_weapon_by_id", weapon_id) as Weapon
	var index := PlayerData.player_weapon_list.find(weapon)
	if index >= 0:
		PlayerData.set_main_weapon_index(index)


func _show_enemy_hp_bars() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("_ensure_enemy_hp_bar"):
			continue
		var hp_bar := enemy.call("_ensure_enemy_hp_bar") as EnemyHpBar
		if hp_bar != null:
			hp_bar.show_for(5.0)


func _reset_runtime() -> void:
	BattleContractManager.unbind_combat_port()
	BattleContractManager.reset_persistent_state()
	PhaseManager.reset_runtime_state()
	RewardDraftRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PlayerData.reset_runtime_state()
	GlobalVariables.reset_runtime_state()


func _finish(exit_code: int) -> void:
	Input.action_release("ATTACK")
	SaveManager.clear_run()
	_reset_runtime()
	await get_tree().process_frame
	get_tree().quit(exit_code)
