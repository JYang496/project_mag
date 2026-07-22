extends Node

const AUDIO_CONTROLS_SCENE_SCRIPT := preload("res://UI/scripts/components/audio_settings_controls.gd")

var _failed := false
var _original_master := 100.0
var _original_music := 100.0
var _original_sfx := 100.0
var _original_locale := "en"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_original_master = AudioSettings.master_volume_percent
	_original_music = AudioSettings.music_volume_percent
	_original_sfx = AudioSettings.sfx_volume_percent
	_original_locale = LocalizationManager.get_locale()

	_test_required_buses()
	_test_live_volume_application()
	_test_persistence()
	await _test_controls_sync()

	AudioSettings.set_master_volume(_original_master)
	AudioSettings.set_music_volume(_original_music)
	AudioSettings.set_sfx_volume(_original_sfx)
	LocalizationManager.set_locale(_original_locale)
	_finish()

func _test_required_buses() -> void:
	_assert_true(AudioServer.get_bus_index(&"Master") >= 0, "Master audio bus should exist.")
	_assert_true(AudioServer.get_bus_index(&"Music") >= 0, "Music audio bus should exist.")
	_assert_true(AudioServer.get_bus_index(&"SFX") >= 0, "SFX audio bus should exist.")

func _test_live_volume_application() -> void:
	AudioSettings.set_master_volume(73.0)
	AudioSettings.set_music_volume(41.0)
	AudioSettings.set_sfx_volume(0.0)
	_assert_near(73.0, AudioSettings.master_volume_percent, "Master percentage should update immediately.")
	_assert_near(41.0, AudioSettings.music_volume_percent, "Music percentage should update immediately.")
	_assert_near(0.0, AudioSettings.sfx_volume_percent, "SFX percentage should update immediately.")
	var master_index := AudioServer.get_bus_index(&"Master")
	var music_index := AudioServer.get_bus_index(&"Music")
	var sfx_index := AudioServer.get_bus_index(&"SFX")
	_assert_near(linear_to_db(0.73), AudioServer.get_bus_volume_db(master_index), "Master bus dB should match its percentage.", 0.02)
	_assert_near(linear_to_db(0.41), AudioServer.get_bus_volume_db(music_index), "Music bus dB should match its percentage.", 0.02)
	_assert_true(AudioServer.is_bus_mute(sfx_index), "A 0% SFX setting should mute the SFX bus.")

func _test_persistence() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(AudioSettings.SETTINGS_PATH)
	_assert_equal(OK, err, "Audio settings should be saved to user storage.")
	if err != OK:
		return
	_assert_near(73.0, float(cfg.get_value("audio", "master_volume_percent", -1.0)), "Saved master volume should match.")
	_assert_near(41.0, float(cfg.get_value("audio", "music_volume_percent", -1.0)), "Saved music volume should match.")
	_assert_near(0.0, float(cfg.get_value("audio", "sfx_volume_percent", -1.0)), "Saved SFX volume should match.")

func _test_controls_sync() -> void:
	var controls := AUDIO_CONTROLS_SCENE_SCRIPT.new() as VBoxContainer
	add_child(controls)
	await get_tree().process_frame
	var master_slider := controls.call("get_slider", &"Master") as HSlider
	var music_slider := controls.call("get_slider", &"Music") as HSlider
	var sfx_slider := controls.call("get_slider", &"SFX") as HSlider
	_assert_near(73.0, master_slider.value, "Master slider should reflect saved runtime state.")
	_assert_near(41.0, music_slider.value, "Music slider should reflect saved runtime state.")
	_assert_near(0.0, sfx_slider.value, "SFX slider should reflect saved runtime state.")
	sfx_slider.value = 58.0
	_assert_near(58.0, AudioSettings.sfx_volume_percent, "Moving the SFX slider should update AudioSettings.")
	_assert_true(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Raising SFX above 0% should unmute the bus.")
	LocalizationManager.set_locale("zh_CN")
	controls.call("refresh_texts")
	var master_label := controls.get_node("MasterVolumeRow").get_child(0) as Label
	var sfx_label := controls.get_node("SFXVolumeRow").get_child(0) as Label
	var music_label := controls.get_node("MusicVolumeRow").get_child(0) as Label
	_assert_equal("主音量", master_label.text, "Master volume label should localize to Chinese.")
	_assert_equal("音效音量", sfx_label.text, "SFX volume label should localize to Chinese.")
	_assert_equal("音乐音量", music_label.text, "Music volume label should localize to Chinese.")
	controls.queue_free()
	await get_tree().process_frame

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)

func _assert_equal(expected: Variant, actual: Variant, message: String) -> void:
	_assert_true(expected == actual, "%s Expected=%s Actual=%s" % [message, str(expected), str(actual)])

func _assert_near(expected: float, actual: float, message: String, tolerance := 0.01) -> void:
	_assert_true(absf(expected - actual) <= tolerance, "%s Expected=%.3f Actual=%.3f" % [message, expected, actual])

func _finish() -> void:
	if _failed:
		print("FAIL: audio settings")
	else:
		print("PASS: audio settings")
	get_tree().quit(1 if _failed else 0)
