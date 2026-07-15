extends RefCounted
class_name BattleContractHudPresenter

var panel: PanelContainer
var title: Label
var value: Label
var progress: ProgressBar
var audio: AudioStreamPlayer
var _last_snapshot: Dictionary = {}

func bind(root: Control) -> void:
	panel = PanelContainer.new()
	panel.name = "BattleContractHud"
	panel.custom_minimum_size = Vector2(400, 108)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 50
	panel.add_theme_stylebox_override("panel", _build_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("8edcf2"))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.08, 0.12, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	body.add_child(title)
	value = Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 15)
	value.add_theme_color_override("font_color", Color("d9f3f8"))
	body.add_child(value)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0.0, 9.0)
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _build_progress_style(Color(0.03, 0.10, 0.15, 0.9)))
	progress.add_theme_stylebox_override("fill", _build_progress_style(Color("4db8d1")))
	body.add_child(progress)
	root.add_child(panel)
	audio = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.2
	audio.stream = stream
	root.add_child(audio)
	panel.visible = false
	BattleContractManager.state_changed.connect(_on_state_changed)
	BattleContractManager.contract_completed.connect(_on_completed)

func layout(viewport_size: Vector2) -> void:
	if panel != null: panel.position = Vector2((viewport_size.x - 400.0) * 0.5, 12.0)

func refresh() -> void:
	if panel == null or PhaseManager.current_state() != PhaseManager.BATTLE or BattleContractManager.state != BattleContractManager.ACTIVE: return
	var snapshot := BattleContractManager.runtime_snapshot
	if snapshot == _last_snapshot: return
	_last_snapshot = snapshot.duplicate(true)
	panel.visible = true
	var id := str(snapshot.get("contract_id", ""))
	title.text = LocalizationManager.tr_key("battle_contract.%s.name" % id, id.capitalize())
	panel.tooltip_text = LocalizationManager.tr_key("battle_contract.%s.description" % id, "")
	match id:
		"elimination": title.modulate = Color("c94f5a")
		"survival": title.modulate = Color("4db8c8")
		"operation": title.modulate = Color.WHITE
	progress.visible = false
	match id:
		"elimination": value.text = LocalizationManager.tr_format("battle_contract.hud.elimination", {"remaining": snapshot.get("remaining_enemies", 0), "current": snapshot.get("current_batch", 1), "total": snapshot.get("total_batches", 1)}, "Remaining {remaining} · Wave {current}/{total}")
		"survival": value.text = LocalizationManager.tr_format("battle_contract.hud.survival", {"seconds": ceili(float(snapshot.get("remaining_sec", 0.0))), "threat": snapshot.get("threat_level", 1)}, "Time {seconds}s · Threat {threat}")
		"operation":
			value.text = LocalizationManager.tr_format("battle_contract.hud.operation", {"current": snapshot.get("current_beacon", 1), "total": snapshot.get("total_beacons", 2)}, "Beacon {current}/{total}")
			progress.visible = true
			progress.value = clampf(float(snapshot.get("progress", 0.0)), 0.0, 1.0)

func _on_state_changed(state: StringName) -> void:
	if state in [BattleContractManager.IDLE, BattleContractManager.OFFERED]: panel.visible = false

func _on_completed(_snapshot: Dictionary) -> void:
	panel.visible = true
	title.text = LocalizationManager.tr_key("battle_contract.hud.completed", "Contract Complete")
	value.text = ""
	progress.visible = false
	title.modulate = Color("e8c96a")
	_play_completion_tone()

func _play_completion_tone() -> void:
	audio.play()
	var playback := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null: return
	for index in 2205:
		var sample := sin(TAU * (660.0 + 220.0 * float(index) / 2205.0) * float(index) / 22050.0) * 0.14
		playback.push_frame(Vector2(sample, sample))

func _build_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.11, 0.92)
	style.border_color = Color(0.25, 0.68, 0.82, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.04, 0.07, 0.55)
	style.shadow_size = 5
	return style

func _build_progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style
