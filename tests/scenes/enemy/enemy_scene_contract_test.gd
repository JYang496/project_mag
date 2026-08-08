extends Node

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

const EXPECTED_DAMAGE_BY_SCENE := {
	"res://Npc/enemy/scenes/base_enemy.tscn": 0,
	"res://Npc/enemy/scenes/enemy_bomber.tscn": 2,
	"res://Npc/enemy/scenes/enemy_interceptor.tscn": 3,
	"res://Npc/enemy/scenes/enemy_mine_crawler.tscn": 1,
	"res://Npc/enemy/scenes/enemy_mirror_caster.tscn": 1,
	"res://Npc/enemy/scenes/enemy_mirror_clone.tscn": 1,
	"res://Npc/enemy/scenes/enemy_mortar_turret.tscn": 2,
	"res://Npc/enemy/scenes/enemy_orbit_support.tscn": 1,
	"res://Npc/enemy/scenes/enemy_repair_unit.tscn": 0,
	"res://Npc/enemy/scenes/enemy_rolling_ball.tscn": 1,
	"res://Npc/enemy/scenes/enemy_rolling_ball_elite.tscn": 2,
	"res://Npc/enemy/scenes/enemy_shield_core.tscn": 0,
	"res://Npc/enemy/scenes/enemy_spike_turret.tscn": 2,
	"res://Npc/enemy/scenes/enemy_tar_mine_crawler.tscn": 1,
	"res://Npc/enemy/scenes/enemy_wheel_cart.tscn": 2,
}

var _failed := false


func _ready() -> void:
	var player := Node2D.new()
	player.name = "EnemyContractPlayer"
	player.add_to_group(&"player")
	add_child(player)
	PlayerData.player = player

	for scene_path in ENEMY_SCENES:
		await _validate_enemy_scene(scene_path)

	PlayerData.player = null
	print(
		"FAIL enemy scene contract"
		if _failed
		else "PASS enemy scene contract (%d scenes)" % ENEMY_SCENES.size()
	)
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, PlayerData.reset_runtime_state)


func _validate_enemy_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "%s must load" % scene_path)
	if packed == null:
		return

	var enemy := packed.instantiate() as BaseEnemy
	_expect(enemy != null, "%s root must inherit BaseEnemy" % scene_path)
	if enemy == null:
		return
	add_child(enemy)
	await get_tree().process_frame
	if EXPECTED_DAMAGE_BY_SCENE.has(scene_path):
		_expect(
			enemy.damage == int(EXPECTED_DAMAGE_BY_SCENE[scene_path]),
			"%s damage must match the half-rounded-up balance value" % scene_path
		)

	var body := enemy.get_node_or_null("Body") as Sprite2D
	var ground_shadow := enemy.get_node_or_null("GroundShadow") as Node2D
	var hurt_collision := enemy.get_node_or_null("HurtBox/CollisionShape2D") as CollisionShape2D
	var affiliation_marker := enemy.get_node_or_null("AffiliationMarker") as Node2D
	_expect(body != null, "%s must preserve Body" % scene_path)
	_expect(
		body != null and body.has_method("get_unit_billboard_config"),
		"%s Body must expose the 3D unit billboard compatibility contract" % scene_path
	)
	_expect(ground_shadow != null, "%s must preserve GroundShadow" % scene_path)
	_expect(affiliation_marker != null, "%s must preserve AffiliationMarker" % scene_path)
	if affiliation_marker != null:
		var marker_line_width := float(affiliation_marker.get("line_width"))
		_expect(
			marker_line_width >= 1.0 and marker_line_width <= 1.25,
			"%s ground marker must keep the narrow 1.0-1.25px stroke: actual=%s" % [
				scene_path,
				marker_line_width,
			]
		)
		_expect(
			affiliation_marker.has_method("set_screen_offset"),
			"%s AffiliationMarker must use hybrid billboard projection" % scene_path
		)
		_expect(
			affiliation_marker.has_method("get_hybrid_ground_marker_config"),
			"%s AffiliationMarker must expose its ground visual configuration" % scene_path
		)
		if ground_shadow != null:
			var marker_transform := affiliation_marker.get("_base_transform") as Transform2D
			_expect(
				marker_transform.origin.is_equal_approx(ground_shadow.position),
				"%s AffiliationMarker must share GroundShadow logical anchor" % scene_path
			)
	var hurtbox_size := _collision_shape_size(hurt_collision)
	if hurtbox_size != Vector2.ZERO and affiliation_marker != null and ground_shadow is Polygon2D:
		var expected_shadow_size := Vector2(
			roundf(clampf(hurtbox_size.x * 1.10, 20.0, 52.0)),
			roundf(clampf(hurtbox_size.y * 0.45, 9.0, 24.0))
		)
		var shadow_size := _polygon_size(ground_shadow as Polygon2D)
		_expect(
			shadow_size.is_equal_approx(expected_shadow_size),
			"%s shadow size must derive from HurtBox: actual=%s expected=%s" % [
				scene_path,
				shadow_size,
				expected_shadow_size,
			]
		)
		var marker_config := affiliation_marker.call("get_hybrid_ground_marker_config") as Dictionary
		var marker_footprint := marker_config.get("footprint_size", Vector2.ZERO) as Vector2
		_expect(
			marker_footprint.is_equal_approx(shadow_size),
			"%s marker contour must exactly reuse GroundShadow size: marker=%s shadow=%s" % [
				scene_path,
				marker_footprint,
				shadow_size,
			]
		)

	if body != null:
		enemy.damage_feedback.play_hit_flash()
		await get_tree().process_frame
		_expect(
			body.get_node_or_null("HitFlashOverlay") is Sprite2D,
			"%s must create a hit feedback overlay" % scene_path
		)
		enemy.damage_feedback.start_warning_flash(Color.RED, 0.8, 0.2)
		await get_tree().process_frame
		var warning := body.get_node_or_null("WarningFlashOverlay") as Sprite2D
		_expect(warning != null and warning.visible, "%s must expose visible warning feedback" % scene_path)
		enemy.damage_feedback.stop_warning_flash()

	enemy.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _collision_shape_size(node: CollisionShape2D) -> Vector2:
	if node == null or node.shape == null:
		return Vector2.ZERO
	var size := Vector2.ZERO
	if node.shape is RectangleShape2D:
		size = (node.shape as RectangleShape2D).size
	elif node.shape is CircleShape2D:
		var diameter := (node.shape as CircleShape2D).radius * 2.0
		size = Vector2(diameter, diameter)
	elif node.shape is CapsuleShape2D:
		var capsule := node.shape as CapsuleShape2D
		size = Vector2(capsule.radius * 2.0, capsule.height)
	return size * node.scale.abs()


func _polygon_size(polygon: Polygon2D) -> Vector2:
	if polygon == null or polygon.polygon.is_empty():
		return Vector2.ZERO
	var bounds := Rect2(polygon.polygon[0], Vector2.ZERO)
	for point in polygon.polygon:
		bounds = bounds.expand(point)
	return bounds.size * polygon.scale.abs()
