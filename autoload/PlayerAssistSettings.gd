extends Node

signal settings_changed

const SETTINGS_PATH := "user://player_assist_settings.cfg"

var auto_aim_continuous_fire: bool = false
var auto_reload_switch: bool = false

func _ready() -> void:
	load_settings()

func set_auto_aim_continuous_fire(enabled: bool) -> void:
	if auto_aim_continuous_fire == enabled:
		return
	auto_aim_continuous_fire = enabled
	save_settings()
	settings_changed.emit()

func set_auto_reload_switch(enabled: bool) -> void:
	if auto_reload_switch == enabled:
		return
	auto_reload_switch = enabled
	save_settings()
	settings_changed.emit()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	auto_aim_continuous_fire = bool(cfg.get_value("assist", "auto_aim_continuous_fire", false))
	auto_reload_switch = bool(cfg.get_value("assist", "auto_reload_switch", false))
	settings_changed.emit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("assist", "auto_aim_continuous_fire", auto_aim_continuous_fire)
	cfg.set_value("assist", "auto_reload_switch", auto_reload_switch)
	cfg.save(SETTINGS_PATH)
