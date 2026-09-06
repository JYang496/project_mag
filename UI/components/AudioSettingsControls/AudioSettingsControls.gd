extends VBoxContainer

const ROW_SCENE := preload("res://UI/components/AudioVolumeRow/AudioVolumeRow.tscn")
const BUS_ORDER: Array[StringName] = [
	AudioSettings.MASTER_BUS,
	AudioSettings.SFX_BUS,
	AudioSettings.MUSIC_BUS,
]

var _rows: Dictionary = {}


func _ready() -> void:
	_build_rows()
	refresh_texts()
	refresh_values()
	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)
	if not AudioSettings.volume_changed.is_connected(_on_volume_changed):
		AudioSettings.volume_changed.connect(_on_volume_changed)


func refresh_texts() -> void:
	for bus_name in BUS_ORDER:
		var row := _rows.get(bus_name) as Control
		if row != null:
			row.call("set_label", _bus_label(bus_name))


func refresh_values() -> void:
	for bus_name in BUS_ORDER:
		var row := _rows.get(bus_name) as Control
		if row != null:
			row.call("set_value", AudioSettings.get_volume_percent(bus_name))


func get_slider(bus_name: StringName) -> HSlider:
	var row := _rows.get(bus_name) as Control
	return row.get_node("Slider") as HSlider if row != null else null


func _build_rows() -> void:
	if not _rows.is_empty():
		return
	for bus_name in BUS_ORDER:
		var row := ROW_SCENE.instantiate() as HBoxContainer
		row.name = "%sVolumeRow" % str(bus_name)
		add_child(row)
		row.call("set_data", bus_name, _bus_label(bus_name), AudioSettings.get_volume_percent(bus_name))
		row.connect("value_changed", _on_slider_value_changed)
		_rows[bus_name] = row


func _on_slider_value_changed(value: float, bus_name: StringName) -> void:
	match bus_name:
		AudioSettings.MASTER_BUS:
			AudioSettings.set_master_volume(value)
		AudioSettings.MUSIC_BUS:
			AudioSettings.set_music_volume(value)
		AudioSettings.SFX_BUS:
			AudioSettings.set_sfx_volume(value)


func _on_volume_changed(bus_name: StringName, percent: float) -> void:
	var row := _rows.get(bus_name) as Control
	if row != null:
		row.call("set_value", percent)


func _on_language_changed(_locale: String) -> void:
	refresh_texts()


func _bus_label(bus_name: StringName) -> String:
	match bus_name:
		AudioSettings.MASTER_BUS:
			return LocalizationManager.tr_key("ui.settings.volume.master", "Master Volume")
		AudioSettings.MUSIC_BUS:
			return LocalizationManager.tr_key("ui.settings.volume.music", "Music Volume")
		_:
			return LocalizationManager.tr_key("ui.settings.volume.sfx", "SFX Volume")
