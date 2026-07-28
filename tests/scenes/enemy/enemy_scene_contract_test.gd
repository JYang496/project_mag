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

	var body := enemy.get_node_or_null("Body") as Sprite2D
	_expect(body != null, "%s must preserve Body" % scene_path)
	_expect(enemy.get_node_or_null("GroundShadow") != null, "%s must preserve GroundShadow" % scene_path)

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
