extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const FLOATING_STATUS_HINT_MANAGER := preload("res://Player/Mechas/scripts/floating_status_hint_manager.gd")
const PROJECTED_UI := preload("res://Visual/Oblique/projected_world_ui_service.gd")
const PLAYER_STATUS_MODIFIER_SYSTEM := preload("res://Player/Mechas/scripts/player_status_modifier_system.gd")
const WEAPON_STAT_PIPELINE := preload("res://Player/Weapons/Core/weapon_stat_pipeline.gd")
const WEAPON_FIRE_CONTROLLER := preload("res://Player/Weapons/Components/weapon_fire_controller.gd")
const WEAPON_SPREAD_MODEL := preload("res://Player/Weapons/Components/weapon_spread_model.gd")

class StatusHintSpy:
	extends Node
	var notifications: Array[Dictionary] = []

	func _notify_status_hint(status_owner: StringName, stat_type: StringName, source_id: StringName, is_gain: bool) -> void:
		notifications.append({
			"owner": status_owner,
			"type": stat_type,
			"source": source_id,
			"is_gain": is_gain,
		})

	func notify_weapon_status_change(stat_type: StringName, source_id: StringName, is_gain: bool) -> void:
		_notify_status_hint(&"weapon", stat_type, source_id, is_gain)

var _failed := false
var _host: Node2D
var _manager
var _layer: CanvasLayer

func _ready() -> void:
	_test_neutral_multiplier_semantics()
	_test_neutral_weapon_multiplier_semantics()

	_host = Node2D.new()
	add_child(_host)
	_manager = FLOATING_STATUS_HINT_MANAGER.new()
	_host.add_child(_manager)
	_manager.setup(_host, 10.0, 26.0, 0.9, 1.0)
	await get_tree().process_frame

	_manager.enqueue_raw_hint("Lost: Movement Speed Up")
	_layer = PROJECTED_UI.ensure_layer(get_tree())
	var label := _find_hint_label()
	_expect(label != null and label.visible, "status hint must be visible before cleanup")
	var moved_to := Vector2(180.0, 60.0)
	_host.global_position = moved_to
	await get_tree().process_frame
	_expect(
		label != null and is_equal_approx(label.position.x, moved_to.x - label.size.x * 0.5),
		"status hint must follow the host's current projected position during playback"
	)

	get_tree().paused = true
	_manager.clear_all()
	_expect(label != null and not label.visible, "cleanup must hide an active hint even while the game tree is paused")

	get_tree().paused = false
	await get_tree().process_frame
	_expect(label == null or not is_instance_valid(label), "cleanup must free the active hint label")

	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
		await get_tree().process_frame
	_layer = null
	print("FAIL floating status hint cleanup" if _failed else "PASS floating status hint cleanup")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _test_neutral_multiplier_semantics() -> void:
	var spy := StatusHintSpy.new()
	add_child(spy)
	var system = PLAYER_STATUS_MODIFIER_SYSTEM.new()
	system.setup(spy)

	system.apply_move_speed_mul(&"neutral_speed", 1.0)
	_expect(spy.notifications.is_empty(), "a neutral 1.0 multiplier must not emit a gained status")
	_expect(is_equal_approx(system.get_total_move_speed_mul(), 1.0), "a neutral multiplier must not be registered")

	system.apply_move_speed_mul(&"changing_speed", 1.2)
	system.apply_move_speed_mul(&"changing_speed", 1.0)
	_expect(spy.notifications.size() == 2, "returning an active modifier to neutral must emit exactly gain then loss")
	if spy.notifications.size() == 2:
		_expect(bool(spy.notifications[0].get("is_gain", false)), "the non-neutral modifier must emit gain")
		_expect(not bool(spy.notifications[1].get("is_gain", true)), "returning to neutral must emit loss")
	_expect(is_equal_approx(system.get_total_move_speed_mul(), 1.0), "returning to neutral must remove the modifier")

func _test_neutral_weapon_multiplier_semantics() -> void:
	var original_player: Variant = PlayerData.player
	var spy := StatusHintSpy.new()
	add_child(spy)
	PlayerData.player = spy

	var weapon := Weapon.new()
	var damage_pipeline = WEAPON_STAT_PIPELINE.new()
	damage_pipeline.setup(weapon)
	damage_pipeline.apply_external_damage_mul(&"neutral_weapon_damage", 1.0)
	_expect(spy.notifications.is_empty(), "neutral weapon damage must not emit a gained status")
	damage_pipeline.apply_external_damage_mul(&"changing_weapon_damage", 1.2)
	damage_pipeline.apply_external_damage_mul(&"changing_weapon_damage", 1.0)
	_expect(spy.notifications.size() == 2, "weapon damage returning to neutral must emit gain then loss")
	_expect(is_equal_approx(damage_pipeline.get_total_external_damage_mul(), 1.0), "neutral weapon damage must be removed")
	spy.notifications.clear()

	var fire_weapon := Node.new()
	var fire_controller = WEAPON_FIRE_CONTROLLER.new()
	fire_controller.setup(fire_weapon)
	fire_controller.apply_external_attack_speed_mul(&"neutral_attack_speed", 1.0)
	_expect(spy.notifications.is_empty(), "neutral attack speed must not emit a gained status")
	fire_controller.apply_external_attack_speed_mul(&"changing_attack_speed", 1.2)
	fire_controller.apply_external_attack_speed_mul(&"changing_attack_speed", 1.0)
	_expect(spy.notifications.size() == 2, "attack speed returning to neutral must emit gain then loss")
	_expect(is_equal_approx(fire_controller.get_external_attack_speed_multiplier(), 1.0), "neutral attack speed must be removed")
	spy.notifications.clear()

	var spread_weapon := Node2D.new()
	var spread_model = WEAPON_SPREAD_MODEL.new()
	spread_model.setup(spread_weapon)
	spread_model.apply_external_spread_mul(&"neutral_spread", 1.0)
	_expect(spy.notifications.is_empty(), "neutral spread must not emit a gained status")
	spread_model.apply_external_spread_mul(&"changing_spread", 0.8)
	spread_model.apply_external_spread_mul(&"changing_spread", 1.0)
	_expect(spy.notifications.size() == 2, "spread returning to neutral must emit gain then loss")
	_expect(is_equal_approx(spread_model.get_external_spread_multiplier(), 1.0), "neutral spread must be removed")

	PlayerData.player = original_player
	weapon.free()
	fire_weapon.free()
	spread_weapon.free()

func _find_hint_label() -> Label:
	if _layer == null:
		return null
	for child in _layer.get_children():
		if child is Label:
			return child as Label
	return null

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
