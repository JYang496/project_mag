extends RefCounted
class_name BattleContractHudPresenter

const COMPACT_SIZE := Vector2(340.0, 64.0)
const EXPANDED_SIZE := Vector2(340.0, 112.0)
const INTRO_EXPANDED_SEC := 2.8
const COMPLETED_VISIBLE_SEC := 1.8

var panel: PanelContainer
var title: Label
var value: Label
var detail: Label
var progress: ProgressBar
var audio: AudioStreamPlayer
var _last_snapshot: Dictionary = {}
var _display_generation := 0
var _expanded := false

func bind(root: Control) -> void:
	panel = PanelContainer.new()
	panel.name = "BattleContractHud"
	panel.custom_minimum_size = COMPACT_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
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
	body.add_theme_constant_override("separation", 4)
	margin.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("8edcf2"))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.08, 0.12, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	header.add_child(title)
	value = Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", Color("d9f3f8"))
	header.add_child(value)
	detail = Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color("92adb5"))
	body.add_child(detail)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0.0, 5.0)
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _build_progress_style(Color(0.03, 0.10, 0.15, 0.9)))
	progress.add_theme_stylebox_override("fill", _build_progress_style(Color("4db8d1")))
	body.add_child(progress)
	root.add_child(panel)
	if root is Container:
		root.move_child(panel, 0)
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
	if panel == null:
		return
	if panel.get_parent() is Container:
		panel.size_flags_horizontal = Control.SIZE_SHRINK_END
		return
	panel.position = Vector2(maxf(16.0, viewport_size.x - panel.custom_minimum_size.x - 16.0), 16.0)

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
		"containment": title.modulate = Color("b45dce")
		"extraction": title.modulate = Color("63a8e8")
		"reward": title.modulate = Color("f0b833")
	progress.visible = false
	match id:
		"elimination":
			var current_batch := int(snapshot.get("current_batch", 1))
			var total_batches := maxi(int(snapshot.get("total_batches", 1)), 1)
			var killed_hp := maxi(int(snapshot.get("killed_hp", 0)), 0)
			var planned_hp := maxi(int(snapshot.get("planned_hp", 0)), 1)
			value.text = LocalizationManager.tr_format("battle_contract.hud.elimination", {"remaining": snapshot.get("remaining_enemies", 0), "current": current_batch, "total": total_batches}, "Remaining {remaining} · Wave {current}/{total}")
			detail.text = LocalizationManager.tr_key("battle_contract.hud.elimination.detail", "Eliminate all deployed targets")
			progress.visible = true
			progress.value = clampf(float(killed_hp) / float(planned_hp), 0.0, 1.0)
			_set_progress_color(Color("c94f5a"))
		"survival":
			var remaining := float(snapshot.get("remaining_sec", 0.0))
			var duration := maxf(float(snapshot.get("duration_sec", 1.0)), 1.0)
			value.text = LocalizationManager.tr_format("battle_contract.hud.survival", {"seconds": ceili(remaining), "threat": snapshot.get("threat_level", 1)}, "Time {seconds}s · Threat {threat}")
			detail.text = LocalizationManager.tr_key("battle_contract.hud.survival.detail", "Hold until the timer expires")
			progress.visible = true
			progress.value = clampf(remaining / duration, 0.0, 1.0)
			_set_progress_color(Color("4db8c8"))
		"operation":
			var ratio := clampf(float(snapshot.get("progress", 0.0)), 0.0, 1.0)
			value.text = LocalizationManager.tr_format("battle_contract.hud.operation", {"current": snapshot.get("current_beacon", 1), "total": snapshot.get("total_beacons", 2), "percent": int(round(ratio * 100.0))}, "Beacon {current}/{total} · {percent}%")
			if not bool(snapshot.get("player_inside", false)):
				detail.text = LocalizationManager.tr_key("battle_contract.hud.operation.enter", "Enter the tactical beacon area")
			elif int(snapshot.get("enemy_count", 0)) > 0:
				detail.text = LocalizationManager.tr_format("battle_contract.hud.operation.contested", {"count": snapshot.get("enemy_count", 0)}, "Contested by {count} enemies · charge slowed")
			else:
				detail.text = LocalizationManager.tr_key("battle_contract.hud.operation.capturing", "Securing beacon")
			progress.visible = true
			progress.value = ratio
			_set_progress_color(Color("e0bd55"))
		"containment":
			var ratio := clampf(float(snapshot.get("progress", 0.0)), 0.0, 1.0)
			value.text = LocalizationManager.tr_format("battle_contract.hud.containment", {"sealed": snapshot.get("sealed_count", 0), "total": snapshot.get("total_rifts", 3), "percent": int(round(ratio * 100.0))}, "Rifts {sealed}/{total} · {percent}%")
			if int(snapshot.get("active_rift", 0)) <= 0:
				detail.text = LocalizationManager.tr_key("battle_contract.hud.containment.enter", "Enter a rift area to begin sealing")
			elif int(snapshot.get("enemy_count", 0)) > 0:
				detail.text = LocalizationManager.tr_format("battle_contract.hud.containment.contested", {"count": snapshot.get("enemy_count", 0)}, "Contested by {count} enemies · sealing slowed")
			else:
				detail.text = LocalizationManager.tr_key("battle_contract.hud.containment.sealing", "Sealing rift")
			progress.visible = true
			progress.value = ratio
			_set_progress_color(Color("b45dce"))
		"extraction":
			if StringName(snapshot.get("phase", &"holding")) == &"holding":
				var remaining := float(snapshot.get("remaining_sec", 0.0))
				var duration := maxf(float(snapshot.get("duration_sec", 1.0)), 1.0)
				value.text = LocalizationManager.tr_format("battle_contract.hud.extraction.holding", {"seconds": ceili(remaining)}, "Extraction opens in {seconds}s")
				detail.text = LocalizationManager.tr_key("battle_contract.hud.extraction.hold", "Survive until the extraction signal is established")
				progress.visible = true
				progress.value = clampf(1.0 - remaining / duration, 0.0, 1.0)
			else:
				var ratio := clampf(float(snapshot.get("progress", 0.0)), 0.0, 1.0)
				value.text = LocalizationManager.tr_format("battle_contract.hud.extraction.active", {"percent": int(round(ratio * 100.0)), "count": snapshot.get("enemy_count", 0)}, "Extraction {percent}% · Enemies {count}")
				if not bool(snapshot.get("player_inside", false)):
					detail.text = LocalizationManager.tr_key("battle_contract.hud.extraction.enter", "Move to the extraction zone")
				elif int(snapshot.get("enemy_count", 0)) > 0:
					detail.text = LocalizationManager.tr_key("battle_contract.hud.extraction.contested", "Enemies are slowing extraction")
				else:
					detail.text = LocalizationManager.tr_key("battle_contract.hud.extraction.charging", "Hold position for extraction")
				progress.visible = true
				progress.value = ratio
			_set_progress_color(Color("63a8e8"))
		"reward":
			var remaining := float(snapshot.get("remaining_sec", 0.0))
			var duration := maxf(float(snapshot.get("duration_sec", 1.0)), 1.0)
			value.text = LocalizationManager.tr_format("battle_contract.hud.reward", {"enemies": snapshot.get("remaining_enemies", 0), "seconds": ceili(remaining)}, "Targets {enemies} · {seconds}s")
			detail.text = LocalizationManager.tr_key("battle_contract.hud.reward.detail", "Defeat every reward target before time expires")
			progress.visible = true
			progress.value = clampf(remaining / duration, 0.0, 1.0)
			_set_progress_color(Color("f0b833"))

func _on_state_changed(state: StringName) -> void:
	if state == BattleContractManager.ACTIVE:
		_show_temporarily_expanded(INTRO_EXPANDED_SEC)
	elif state in [BattleContractManager.IDLE, BattleContractManager.OFFERED]:
		_display_generation += 1
		panel.visible = false

func _on_completed(_snapshot: Dictionary) -> void:
	_display_generation += 1
	var generation := _display_generation
	panel.visible = true
	_set_expanded(true)
	title.text = LocalizationManager.tr_key("battle_contract.hud.completed", "Contract Complete")
	value.text = ""
	detail.text = ""
	progress.visible = false
	title.modulate = Color("e8c96a")
	_play_completion_tone()
	await panel.get_tree().create_timer(COMPLETED_VISIBLE_SEC).timeout
	if generation == _display_generation and BattleContractManager.state == BattleContractManager.COMPLETED:
		panel.visible = false

func _show_temporarily_expanded(duration_sec: float) -> void:
	_display_generation += 1
	var generation := _display_generation
	panel.visible = true
	_set_expanded(true)
	await panel.get_tree().create_timer(duration_sec).timeout
	if generation == _display_generation and BattleContractManager.state == BattleContractManager.ACTIVE:
		_set_expanded(false)

func _set_expanded(expanded: bool) -> void:
	if panel == null:
		return
	_expanded = expanded
	detail.visible = expanded
	panel.custom_minimum_size = EXPANDED_SIZE if expanded else COMPACT_SIZE
	var tween := panel.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16).from(0.82)

func _set_progress_color(color: Color) -> void:
	progress.add_theme_stylebox_override("fill", _build_progress_style(color))

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
