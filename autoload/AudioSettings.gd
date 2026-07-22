extends Node

signal volume_changed(bus_name: StringName, percent: float)

const SETTINGS_PATH := "user://audio_settings.cfg"
const MASTER_BUS: StringName = &"Master"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const DEFAULT_VOLUME_PERCENT := 100.0
const MIN_AUDIBLE_LINEAR := 0.0001

var master_volume_percent := DEFAULT_VOLUME_PERCENT
var music_volume_percent := DEFAULT_VOLUME_PERCENT
var sfx_volume_percent := DEFAULT_VOLUME_PERCENT

func _ready() -> void:
	_ensure_required_buses()
	load_settings()
	apply_all()

func set_master_volume(percent: float) -> void:
	_set_volume(MASTER_BUS, percent)

func set_music_volume(percent: float) -> void:
	_set_volume(MUSIC_BUS, percent)

func set_sfx_volume(percent: float) -> void:
	_set_volume(SFX_BUS, percent)

func get_volume_percent(bus_name: StringName) -> float:
	match bus_name:
		MASTER_BUS:
			return master_volume_percent
		MUSIC_BUS:
			return music_volume_percent
		SFX_BUS:
			return sfx_volume_percent
	return DEFAULT_VOLUME_PERCENT

func apply_all() -> void:
	_apply_bus_volume(MASTER_BUS, master_volume_percent)
	_apply_bus_volume(MUSIC_BUS, music_volume_percent)
	_apply_bus_volume(SFX_BUS, sfx_volume_percent)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume_percent = _normalize_percent(cfg.get_value("audio", "master_volume_percent", DEFAULT_VOLUME_PERCENT))
	music_volume_percent = _normalize_percent(cfg.get_value("audio", "music_volume_percent", DEFAULT_VOLUME_PERCENT))
	sfx_volume_percent = _normalize_percent(cfg.get_value("audio", "sfx_volume_percent", DEFAULT_VOLUME_PERCENT))

func save_settings() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume_percent", master_volume_percent)
	cfg.set_value("audio", "music_volume_percent", music_volume_percent)
	cfg.set_value("audio", "sfx_volume_percent", sfx_volume_percent)
	return cfg.save(SETTINGS_PATH)

func _set_volume(bus_name: StringName, percent: float) -> void:
	var normalized := _normalize_percent(percent)
	match bus_name:
		MASTER_BUS:
			master_volume_percent = normalized
		MUSIC_BUS:
			music_volume_percent = normalized
		SFX_BUS:
			sfx_volume_percent = normalized
		_:
			return
	_apply_bus_volume(bus_name, normalized)
	save_settings()
	volume_changed.emit(bus_name, normalized)

func _apply_bus_volume(bus_name: StringName, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var linear := percent / 100.0
	AudioServer.set_bus_mute(bus_index, is_zero_approx(linear))
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear, MIN_AUDIBLE_LINEAR)))

func _ensure_required_buses() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, MASTER_BUS)

func _normalize_percent(value: Variant) -> float:
	return clampf(float(value), 0.0, 100.0)
