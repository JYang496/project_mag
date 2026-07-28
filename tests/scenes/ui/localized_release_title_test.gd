extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_test_localized_title()
	await _finish()

func _test_localized_title() -> void:
	var original_locale := LocalizationManager.get_locale()
	LocalizationManager.set_locale("en", false)
	_assert_equal("Protocol: Mag Arena", LocalizationManager.tr_key("ui.start.title", "Protocol: Mag Arena"), "English title should use the release name.")
	LocalizationManager.set_locale("zh_CN", false)
	_assert_equal("协议：磁核竞技场", LocalizationManager.tr_key("ui.start.title", "Protocol: Mag Arena"), "Chinese title should use the release name.")
	LocalizationManager.set_locale(original_locale, false)

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail(message)

func _assert_equal(expected: Variant, actual: Variant, message: String) -> void:
	_assert_true(expected == actual, "%s Expected=%s Actual=%s" % [message, str(expected), str(actual)])

func _fail(message: String) -> void:
	_failed = true
	push_error("FAIL: %s" % message)

func _finish() -> void:
	if _failed:
		print("FAIL: localized release title")
	else:
		print("PASS: localized release title")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)
