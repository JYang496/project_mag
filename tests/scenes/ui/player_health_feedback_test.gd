extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PLAYER_STATUS_HUD := preload("res://UI/scripts/components/player_status_hud.gd")

var _failed := false
var _hud: Control

func _ready() -> void:
	_hud = PLAYER_STATUS_HUD.new()
	add_child(_hud)
	await get_tree().process_frame
	_test_initial_and_duplicate_samples_stay_quiet()
	_test_damage_ghost_and_temporary_value()
	_test_immediate_damage_event_feedback()
	_test_healing_ghost()
	_test_max_health_change_shows_value_without_false_ghost()
	print("FAIL player health feedback" if _failed else "PASS player health feedback")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _test_initial_and_duplicate_samples_stay_quiet() -> void:
	_hud.set_health(100, 100)
	_expect(not _hud.is_hp_value_visible(), "initial health sync must not show the detail label")
	_expect(not _hud.has_health_ghost(), "initial health sync must not create a ghost")
	_hud.set_health(100, 100)
	_expect(not _hud.is_hp_value_visible(), "duplicate health sync must not retrigger the label")

func _test_damage_ghost_and_temporary_value() -> void:
	_hud.set_health(70, 100)
	_expect(_hud.is_hp_value_visible(), "damage must temporarily show the detailed value")
	_expect(_hud.has_health_ghost(), "damage must leave the previous health as a ghost")
	_expect(
		is_equal_approx(_hud.get_display_health_ratio(), 0.7)
			and is_equal_approx(_hud.get_ghost_health_ratio(), 1.0),
		"damage ghost must span from the new value to the previous value"
	)
	var label := _hud.get_node_or_null("HpValue") as Label
	_expect(label != null and label.text == "70 / 100", "damage label must show the updated X / X value")
	_hud.call("_process", 1.1)
	_expect(not _hud.is_hp_value_visible(), "detailed health value must hide after its short display")
	_expect(not _hud.has_health_ghost(), "damage ghost must finish catching up")

func _test_healing_ghost() -> void:
	_hud.set_health(90, 100)
	_expect(_hud.is_hp_value_visible(), "healing must temporarily show the detailed value")
	_expect(_hud.has_health_ghost(), "healing must animate the gained health region")
	_expect(
		is_equal_approx(_hud.get_display_health_ratio(), 0.7)
			and is_equal_approx(_hud.get_ghost_health_ratio(), 0.9),
		"healing ghost must span from the previous value to the new value"
	)
	_hud.call("_process", 1.1)
	_expect(
		is_equal_approx(_hud.get_display_health_ratio(), 0.9)
			and not _hud.has_health_ghost(),
		"healing fill must catch up to the new value"
	)

func _test_immediate_damage_event_feedback() -> void:
	_hud.play_damage_feedback({
		"final_damage": 12,
		"damage_type": Attack.TYPE_FIRE,
		"is_periodic": false,
		"is_heavy": true,
		"severity": 0.3,
		"current_hp": 30,
		"previous_hp": 42,
		"max_hp": 100,
	})
	var delta_label := _hud.get_node_or_null("DamageDelta") as Label
	_expect(delta_label != null and delta_label.visible, "damage event must show an immediate HUD delta")
	_expect(delta_label != null and delta_label.text == "-12!", "heavy damage must use the emphasized negative delta")
	_expect(_hud.get_damage_flash_strength() > 0.9, "crossing the warning threshold must strongly flash the health rail")
	_expect(_hud.scale.x >= 1.0, "damage feedback must start the HUD punch without shrinking the dock")
	_hud.call("_process", 0.4)
	_expect(_hud.get_damage_flash_strength() <= 0.01, "damage flash must decay instead of becoming a persistent overlay")

func _test_max_health_change_shows_value_without_false_ghost() -> void:
	_hud.set_health(180, 200)
	_expect(_hud.is_hp_value_visible(), "maximum-health changes must show the updated detail")
	_expect(not _hud.has_health_ghost(), "an unchanged health ratio must not create a false ghost")
	var label := _hud.get_node_or_null("HpValue") as Label
	_expect(label != null and label.text == "180 / 200", "maximum-health changes must refresh X / X")

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
