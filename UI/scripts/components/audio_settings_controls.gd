extends VBoxContainer
class_name AudioSettingsControls

const BUS_ORDER: Array[StringName] = [
	AudioSettings.MASTER_BUS,
	AudioSettings.SFX_BUS,
	AudioSettings.MUSIC_BUS,
]

var _labels: Dictionary = {}
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _syncing := false

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_build_rows()
	refresh_texts()
	refresh_values()
	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)
	if not AudioSettings.volume_changed.is_connected(_on_volume_changed):
		AudioSettings.volume_changed.connect(_on_volume_changed)

func refresh_texts() -> void:
	for bus_name in BUS_ORDER:
		var label := _labels.get(bus_name) as Label
		if label != null:
			label.text = _bus_label(bus_name)

func refresh_values() -> void:
	_syncing = true
	for bus_name in BUS_ORDER:
		var percent := AudioSettings.get_volume_percent(bus_name)
		var slider := _sliders.get(bus_name) as HSlider
		if slider != null:
			slider.value = percent
		_update_value_label(bus_name, percent)
	_syncing = false

func get_slider(bus_name: StringName) -> HSlider:
	return _sliders.get(bus_name) as HSlider

func _build_rows() -> void:
	if not _sliders.is_empty():
		return
	for bus_name in BUS_ORDER:
		var row := HBoxContainer.new()
		row.name = "%sVolumeRow" % str(bus_name)
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var label := Label.new()
		label.custom_minimum_size = Vector2(112.0, 28.0)
		row.add_child(label)
		_labels[bus_name] = label
		var slider := HSlider.new()
		slider.name = "%sVolumeSlider" % str(bus_name)
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.custom_minimum_size = Vector2(132.0, 28.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_slider_value_changed.bind(bus_name))
		row.add_child(slider)
		_sliders[bus_name] = slider
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(48.0, 28.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		_value_labels[bus_name] = value_label

func _on_slider_value_changed(value: float, bus_name: StringName) -> void:
	_update_value_label(bus_name, value)
	if _syncing:
		return
	match bus_name:
		AudioSettings.MASTER_BUS:
			AudioSettings.set_master_volume(value)
		AudioSettings.MUSIC_BUS:
			AudioSettings.set_music_volume(value)
		AudioSettings.SFX_BUS:
			AudioSettings.set_sfx_volume(value)

func _on_volume_changed(bus_name: StringName, percent: float) -> void:
	var slider := _sliders.get(bus_name) as HSlider
	if slider == null:
		return
	_syncing = true
	slider.value = percent
	_update_value_label(bus_name, percent)
	_syncing = false

func _on_language_changed(_locale: String) -> void:
	refresh_texts()

func _update_value_label(bus_name: StringName, percent: float) -> void:
	var value_label := _value_labels.get(bus_name) as Label
	if value_label != null:
		value_label.text = "%d%%" % int(round(percent))

func _bus_label(bus_name: StringName) -> String:
	match bus_name:
		AudioSettings.MASTER_BUS:
			return LocalizationManager.tr_key("ui.settings.volume.master", "Master Volume")
		AudioSettings.MUSIC_BUS:
			return LocalizationManager.tr_key("ui.settings.volume.music", "Music Volume")
		_:
			return LocalizationManager.tr_key("ui.settings.volume.sfx", "SFX Volume")
