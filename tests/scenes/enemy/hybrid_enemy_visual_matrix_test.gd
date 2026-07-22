extends Node

const HybridView := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const BaseEnemyScene := preload("res://Npc/enemy/scenes/base_enemy.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

const ENEMY_SCENES: PackedStringArray = [
	"res://Npc/enemy/scenes/base_enemy.tscn",
	"res://Npc/enemy/scenes/elite_enemy.tscn",
	"res://Npc/enemy/scenes/dummy.tscn",
	"res://Npc/enemy/scenes/enemy_bomber.tscn",
	"res://Npc/enemy/scenes/enemy_interceptor.tscn",
	"res://Npc/enemy/scenes/enemy_mine_crawler.tscn",
	"res://Npc/enemy/scenes/enemy_mirror_caster.tscn",
	"res://Npc/enemy/scenes/enemy_mirror_clone.tscn",
	"res://Npc/enemy/scenes/enemy_mortar_turret.tscn",
	"res://Npc/enemy/scenes/enemy_orbit_support.tscn",
	"res://Npc/enemy/scenes/enemy_repair_unit.tscn",
	"res://Npc/enemy/scenes/enemy_rolling_ball.tscn",
	"res://Npc/enemy/scenes/enemy_rolling_ball_elite.tscn",
	"res://Npc/enemy/scenes/enemy_shield_core.tscn",
	"res://Npc/enemy/scenes/enemy_spike_turret.tscn",
	"res://Npc/enemy/scenes/enemy_tar_mine_crawler.tscn",
	"res://Npc/enemy/scenes/enemy_wheel_cart.tscn",
]

var _failed: bool = false
var _view: HybridGroundView3D

func _ready() -> void:
	var player := Node2D.new()
	player.name = "VisualMatrixPlayer"
	player.add_to_group(&"player")
	player.position = Vector2(200.0, 120.0)
	add_child(player)
	PlayerData.player = player
	_view = HybridView.new()
	_view.board_path = NodePath()
	add_child(_view)
	await get_tree().process_frame
	await get_tree().process_frame
	_validate_warning_layer_contract()
	for index in range(ENEMY_SCENES.size()):
		await _validate_enemy_scene(ENEMY_SCENES[index], index)
	PlayerData.player = null
	if _failed:
		print("FAIL hybrid enemy visual matrix")
	else:
		print("PASS hybrid enemy visual matrix (%d scenes)" % ENEMY_SCENES.size())
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, PlayerData.reset_runtime_state)
	_view = null

func _validate_warning_layer_contract() -> void:
	var warning := TargetWarning.new()
	warning.position = Vector2(40.0, 25.0)
	add_child(warning)
	_view.register_warning_circle(warning)
	_view.sync_late_visuals(0.0)
	var entries := _view.get("_area_meshes") as Dictionary
	var entry_variant: Variant = entries.get(warning.get_instance_id())
	_failed = _check(entry_variant is Dictionary, "circular attack warning must register a 3D mesh") or _failed
	if entry_variant is Dictionary:
		var entry := entry_variant as Dictionary
		var mesh := entry.get("mesh") as MeshInstance3D
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D if mesh != null else null
		var expected_position := _view.world_2d_to_3d(warning.global_position) + Vector3.UP * HybridView.DANGER_WARNING_HEIGHT
		_failed = _check(mesh != null and mesh.position.distance_to(expected_position) < 0.002, "circular attack warning must sit above ground areas") or _failed
		_failed = _check(material != null and material.render_priority == HybridView.DANGER_WARNING_RENDER_PRIORITY, "circular attack warning must render above ground areas") or _failed
	_failed = _check(HybridView.DANGER_WARNING_HEIGHT > HybridView.GROUND_AREA_HEIGHT + 0.006, "attack warnings must sit above beacon progress") or _failed
	_failed = _check(HybridView.DANGER_WARNING_RENDER_PRIORITY > HybridView.GROUND_AREA_RENDER_PRIORITY, "attack warnings must have higher material priority than contract areas") or _failed
	warning.queue_free()

func _validate_enemy_scene(scene_path: String, index: int) -> void:
	var packed := load(scene_path) as PackedScene
	_failed = _check(packed != null, "%s must load" % scene_path) or _failed
	if packed == null:
		return
	var enemy := packed.instantiate() as BaseEnemy
	_failed = _check(enemy != null, "%s root must inherit BaseEnemy" % scene_path) or _failed
	if enemy == null:
		return
	enemy.position = Vector2(-360.0 + float(index % 6) * 145.0, -180.0 + float(index / 6) * 130.0)
	add_child(enemy)
	await get_tree().process_frame
	await get_tree().process_frame
	var body := enemy.get_node_or_null("Body") as Sprite2D
	var shadow := enemy.get_node_or_null("GroundShadow") as CanvasItem
	_failed = _check(body != null, "%s must preserve Body" % scene_path) or _failed
	_failed = _check(shadow != null, "%s must inherit GroundShadow" % scene_path) or _failed
	if body != null:
		_failed = _check(body.has_method("set_screen_offset"), "%s Body must use BillboardVisual2D" % scene_path) or _failed
		var base_transform := body.get("_base_transform") as Transform2D
		var logical_footpoint := enemy.global_transform * base_transform.origin
		var expected_body := _view.project_world_to_canvas(logical_footpoint, get_viewport())
		_failed = _check(body.global_position.distance_to(expected_body) < 2.0, "%s Body footpoint projection mismatch" % scene_path) or _failed
	if shadow != null:
		var shadow_entries := _view.get("_shadow_meshes") as Dictionary
		var entry_variant: Variant = shadow_entries.get(shadow.get_instance_id())
		_failed = _check(entry_variant is Dictionary, "%s GroundShadow must register a 3D mesh" % scene_path) or _failed
		if entry_variant is Dictionary:
			var entry := entry_variant as Dictionary
			var mesh := entry.get("mesh") as MeshInstance3D
			var local_anchor := entry.get("local_anchor", Vector2.ZERO) as Vector2
			var expected_shadow := _view.world_2d_to_3d(enemy.global_transform * local_anchor) + Vector3.UP * 0.018
			# Self-moving enemies may advance by a sub-pixel between the late visual
			# sync and the process-frame signal observed by this test.
			_failed = _check(mesh != null and mesh.position.distance_to(expected_shadow) < 0.015, "%s GroundShadow anchor mismatch: actual=%s expected=%s" % [scene_path, mesh.position if mesh != null else Vector3.ZERO, expected_shadow]) or _failed
	var hp_bar := enemy.call("_ensure_enemy_hp_bar") as EnemyHpBar
	_failed = _check(hp_bar != null, "%s must create EnemyHpBar" % scene_path) or _failed
	if hp_bar != null:
		hp_bar.show_for(5.0)
		await get_tree().process_frame
		var expected_hp := _view.project_world_to_canvas(enemy.global_position, get_viewport())
		expected_hp += get_viewport().get_canvas_transform().basis_xform_inv(Vector2(0.0, enemy.hp_bar_vertical_offset))
		_failed = _check(hp_bar.global_position.distance_to(expected_hp) < 2.0, "%s EnemyHpBar anchor mismatch" % scene_path) or _failed
		_failed = _check(absf(hp_bar.global_rotation) < 0.001, "%s EnemyHpBar must remain horizontal" % scene_path) or _failed
	enemy.damage_feedback.play_hit_flash()
	await get_tree().process_frame
	var hit_overlay := body.get_node_or_null("HitFlashOverlay") as Sprite2D if body != null else null
	_failed = _check(hit_overlay != null, "%s must create HitFlashOverlay under Body" % scene_path) or _failed
	if hit_overlay != null and body != null:
		_failed = _check(_flash_matches_body(hit_overlay, body), "%s HitFlash must match Body" % scene_path) or _failed
	enemy.damage_feedback.start_warning_flash(Color.RED, 0.8, 0.2)
	await get_tree().process_frame
	var warning_overlay := body.get_node_or_null("WarningFlashOverlay") as Sprite2D if body != null else null
	_failed = _check(warning_overlay != null, "%s must create WarningFlashOverlay under Body" % scene_path) or _failed
	if warning_overlay != null and body != null:
		_failed = _check(_flash_matches_body(warning_overlay, body), "%s WarningFlash must initially match Body" % scene_path) or _failed
		enemy.position += Vector2(37.0, -21.0)
		await get_tree().process_frame
		_failed = _check(_flash_matches_body(warning_overlay, body), "%s WarningFlash must follow moving Body" % scene_path) or _failed
	await _validate_support_visuals(enemy, scene_path)
	_validate_dash_telegraph(enemy, scene_path)
	enemy.damage_feedback.stop_warning_flash()
	enemy.queue_free()
	await get_tree().process_frame

func _validate_dash_telegraph(enemy: BaseEnemy, scene_path: String) -> void:
	if not enemy is EnemyEliteRollingBall:
		return
	var telegraph := enemy.get_node_or_null("SkillWarningTelegraph") as SkillWarningTelegraph
	_failed = _check(telegraph != null, "%s must preserve SkillWarningTelegraph" % scene_path) or _failed
	if telegraph == null:
		return
	var direction := Vector2(0.8, -0.6).normalized()
	telegraph.show_dash_warning(enemy.global_position, direction, 420.0, 1.0, 34.0)
	telegraph.update_dash_warning(enemy.global_position, direction, 0.5)
	_view.register_dash_telegraph(telegraph)
	_view.sync_late_visuals(0.0)
	_failed = _check(not telegraph.visible, "%s legacy 2D dash telegraph must stay hidden" % scene_path) or _failed
	var entries := _view.get("_dash_telegraph_meshes") as Dictionary
	var entry_variant: Variant = entries.get(telegraph.get_instance_id())
	_failed = _check(entry_variant is Dictionary, "%s dash telegraph must register 3D meshes" % scene_path) or _failed
	if entry_variant is Dictionary:
		var entry := entry_variant as Dictionary
		var warning_mesh := entry.get("warning_mesh") as MeshInstance3D
		var warning_box := entry.get("warning_box") as BoxMesh
		var progress_mesh := entry.get("progress_mesh") as MeshInstance3D
		var progress_box := entry.get("progress_box") as BoxMesh
		var expected_midpoint := _view.world_2d_to_3d(enemy.global_position + direction * 210.0) + Vector3.UP * HybridView.DANGER_WARNING_HEIGHT
		_failed = _check(warning_mesh != null and warning_mesh.visible and warning_mesh.position.distance_to(expected_midpoint) < 0.002, "%s 3D dash warning position mismatch" % scene_path) or _failed
		var warning_material := entry.get("warning_material") as StandardMaterial3D
		_failed = _check(warning_material != null and warning_material.render_priority == HybridView.DANGER_WARNING_RENDER_PRIORITY, "%s dash warning must render above ground areas" % scene_path) or _failed
		_failed = _check(warning_box != null and absf(warning_box.size.x - 420.0 * _view.world_scale) < 0.002, "%s 3D dash warning length mismatch" % scene_path) or _failed
		_failed = _check(progress_mesh != null and progress_mesh.visible, "%s 3D dash progress must be visible" % scene_path) or _failed
		var progress_material := entry.get("progress_material") as StandardMaterial3D
		_failed = _check(progress_material != null and progress_material.render_priority == HybridView.DANGER_PROGRESS_RENDER_PRIORITY, "%s dash progress must have highest danger priority" % scene_path) or _failed
		_failed = _check(progress_box != null and absf(progress_box.size.x - 210.0 * _view.world_scale) < 0.002, "%s 3D dash progress length mismatch" % scene_path) or _failed
	telegraph.clear_warning()
	_view.sync_late_visuals(0.0)

func _validate_support_visuals(enemy: BaseEnemy, scene_path: String) -> void:
	if enemy.has_method("get_hybrid_aura_visual"):
		enemy.register_hybrid_support_visuals()
		_view.sync_late_visuals(0.0)
		var aura_entries := _view.get("_enemy_aura_meshes") as Dictionary
		var aura_variant: Variant = aura_entries.get(enemy.get_instance_id())
		_failed = _check(aura_variant is Dictionary, "%s aura must register 3D ground meshes" % scene_path) or _failed
		if aura_variant is Dictionary:
			var aura_entry := aura_variant as Dictionary
			var outline := aura_entry.get("outline") as MeshInstance3D
			var outline_mesh := aura_entry.get("outline_mesh") as TorusMesh
			var config := enemy.call("get_hybrid_aura_visual") as Dictionary
			var expected_position := _view.world_2d_to_3d(enemy.global_position) + Vector3.UP * 0.020
			var expected_radius := float(config.get("radius", 1.0)) * _view.world_scale
			_failed = _check(outline != null and outline.position.distance_to(expected_position) < 0.002, "%s aura center must follow logical footpoint" % scene_path) or _failed
			_failed = _check(outline_mesh != null and absf(outline_mesh.outer_radius - expected_radius) < 0.002, "%s aura radius must match 2D logic" % scene_path) or _failed
	if not enemy.has_method("get_hybrid_link_visuals"):
		return
	var target := BaseEnemyScene.instantiate() as BaseEnemy
	target.position = enemy.position + Vector2(95.0, 35.0)
	add_child(target)
	await get_tree().process_frame
	if enemy is EnemyRepairUnit:
		enemy.set("_heal_target", target)
	elif enemy is EnemyShieldCore:
		var protected_targets: Array[BaseEnemy] = [target]
		enemy.set("_protected_targets", protected_targets)
	enemy.register_hybrid_support_visuals()
	_view.sync_late_visuals(0.0)
	var link_entries := _view.get("_enemy_link_meshes") as Dictionary
	var prefix := "%d:%d:" % [enemy.get_instance_id(), target.get_instance_id()]
	var matching_entry: Dictionary = {}
	for key_variant in link_entries.keys():
		var key := str(key_variant)
		if key.begins_with(prefix):
			matching_entry = link_entries[key] as Dictionary
			break
	_failed = _check(not matching_entry.is_empty(), "%s target link must create a 3D segment" % scene_path) or _failed
	if not matching_entry.is_empty():
		var mesh := matching_entry.get("mesh") as MeshInstance3D
		var expected_midpoint := _view.world_2d_to_3d((enemy.global_position + target.global_position) * 0.5) + Vector3.UP * 0.025
		_failed = _check(mesh != null and mesh.position.distance_to(expected_midpoint) < 0.002, "%s target link midpoint mismatch" % scene_path) or _failed
	if enemy is EnemyRepairUnit:
		enemy.set("_heal_target", null)
	elif enemy is EnemyShieldCore:
		var empty_targets: Array[BaseEnemy] = []
		enemy.set("_protected_targets", empty_targets)
	_view.sync_late_visuals(0.0)
	target.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _flash_matches_body(overlay: Sprite2D, body: Sprite2D) -> bool:
	return overlay.get_parent() == body \
		and overlay.global_position.distance_to(body.global_position) < 0.01 \
		and overlay.global_scale.distance_to(body.global_scale) < 0.01 \
		and is_equal_approx(overlay.global_rotation, body.global_rotation) \
		and overlay.texture == body.texture \
		and overlay.flip_h == body.flip_h \
		and overlay.flip_v == body.flip_v \
		and overlay.offset == body.offset \
		and overlay.centered == body.centered

func _check(condition: bool, message: String) -> bool:
	if condition:
		return false
	push_error(message)
	return true
