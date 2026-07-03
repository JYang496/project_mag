extends Node
class_name FloatingStatusHintManager

var _host: Node2D
var _floating_hint_duration_sec: float = 1.0
var _floating_hint_rise_px: float = 26.0
var _status_hint_throttle_sec: float = 0.9
var _status_hint_queue_interval_sec: float = 1.0

var _status_hint_ready_at_msec: Dictionary = {}
var _status_hint_state_by_source: Dictionary = {}
var _status_hint_queue: Array[Dictionary] = []
var _is_status_hint_playing: bool = false
var _raw_hint_ready_at_msec: Dictionary = {}
var _queued_raw_hint_keys: Dictionary = {}

func setup(
	host: Node2D,
	floating_hint_duration_sec: float,
	floating_hint_rise_px: float,
	status_hint_throttle_sec: float,
	status_hint_queue_interval_sec: float
) -> void:
	_host = host
	_floating_hint_duration_sec = maxf(floating_hint_duration_sec, 0.05)
	_floating_hint_rise_px = maxf(floating_hint_rise_px, 0.0)
	_status_hint_throttle_sec = maxf(status_hint_throttle_sec, 0.05)
	_status_hint_queue_interval_sec = maxf(status_hint_queue_interval_sec, 0.05)

func enqueue_raw_hint(text: String) -> void:
	enqueue_keyed_raw_hint(text, StringName(), 0.0)

func enqueue_keyed_raw_hint(text: String, hint_key: StringName, throttle_sec: float = -1.0) -> void:
	var message := text.strip_edges()
	if message == "":
		return
	if hint_key != StringName():
		if _queued_raw_hint_keys.has(hint_key):
			return
		var now_msec := Time.get_ticks_msec()
		var ready_at := int(_raw_hint_ready_at_msec.get(hint_key, 0))
		if now_msec < ready_at:
			return
		var throttle := throttle_sec
		if throttle < 0.0:
			throttle = _status_hint_throttle_sec
		_raw_hint_ready_at_msec[hint_key] = now_msec + int(maxf(throttle, 0.0) * 1000.0)
		_queued_raw_hint_keys[hint_key] = true
	_status_hint_queue.append({
		"text": message,
		"key": hint_key,
		"created_at_msec": Time.get_ticks_msec(),
	})
	_try_play_next_status_hint()

func notify_status_hint(status_owner: StringName, stat_type: StringName, source_id: StringName, is_gain: bool) -> void:
	if source_id == StringName():
		return
	var meta := _status_hint_meta(stat_type)
	if meta.is_empty():
		return
	var family := StringName(str(meta.get("family", "")))
	var polarity := int(meta.get("polarity", 0))
	if family == StringName() or polarity == 0:
		return
	var state_key := "%s|%s|%s" % [str(status_owner), str(family), str(source_id)]
	var prev_state := int(_status_hint_state_by_source.get(state_key, 0))
	if is_gain:
		if prev_state == polarity:
			return
		if prev_state != 0 and prev_state != polarity:
			var prev_type := _status_type_from_family_state(family, prev_state)
			if prev_type != StringName():
				_emit_status_hint(status_owner, prev_type, source_id, false)
		_status_hint_state_by_source[state_key] = polarity
		_emit_status_hint(status_owner, stat_type, source_id, true)
		return
	if prev_state == 0:
		return
	var loss_type := _status_type_from_family_state(family, prev_state)
	_status_hint_state_by_source.erase(state_key)
	if loss_type == StringName():
		loss_type = stat_type
	_emit_status_hint(status_owner, loss_type, source_id, false)

func clear_all() -> void:
	_status_hint_queue.clear()
	_status_hint_ready_at_msec.clear()
	_status_hint_state_by_source.clear()
	_raw_hint_ready_at_msec.clear()
	_queued_raw_hint_keys.clear()
	_is_status_hint_playing = false

func _emit_status_hint(status_owner: StringName, stat_type: StringName, source_id: StringName, is_gain: bool) -> void:
	var status_label := _resolve_status_hint_label(stat_type)
	if status_label == "":
		return
	var now_msec := Time.get_ticks_msec()
	var throttle_msec := int(_status_hint_throttle_sec * 1000.0)
	var hint_key := "%s|%s|%s|%s" % [str(status_owner), str(stat_type), str(source_id), "gain" if is_gain else "loss"]
	var ready_at := int(_status_hint_ready_at_msec.get(hint_key, 0))
	if now_msec < ready_at:
		return
	_status_hint_ready_at_msec[hint_key] = now_msec + throttle_msec
	var prefix_key := "ui.status_hint.gain_prefix" if is_gain else "ui.status_hint.loss_prefix"
	var prefix_fallback := "Gained" if is_gain else "Lost"
	var prefix := LocalizationManager.tr_key(prefix_key, prefix_fallback)
	enqueue_raw_hint(LocalizationManager.tr_format(
		"ui.status_hint.message",
		{"prefix": prefix, "status": status_label},
		"%s: %s" % [prefix, status_label]
	))

func _try_play_next_status_hint() -> void:
	if _is_status_hint_playing:
		return
	if _status_hint_queue.is_empty():
		return
	var next_item: Dictionary = _status_hint_queue.pop_front() as Dictionary
	var next_key := StringName(next_item.get("key", StringName()))
	if next_key != StringName():
		_queued_raw_hint_keys.erase(next_key)
	var next_text: String = str(next_item.get("text", "")).strip_edges()
	if next_text == "":
		_try_play_next_status_hint()
		return
	_is_status_hint_playing = true
	_schedule_next_status_hint_slot()
	_spawn_player_floating_hint(next_text)

func _schedule_next_status_hint_slot() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var tree := _host.get_tree()
	if tree == null:
		return
	var wait_time := minf(_status_hint_queue_interval_sec, _floating_hint_duration_sec)
	tree.create_timer(wait_time).timeout.connect(func() -> void:
		if _host == null or not is_instance_valid(_host):
			return
		if _host.is_queued_for_deletion() or not _host.is_inside_tree():
			return
		_is_status_hint_playing = false
		_try_play_next_status_hint()
	, CONNECT_ONE_SHOT)

func _spawn_player_floating_hint(text: String) -> void:
	var message := text.strip_edges()
	if message == "":
		_on_status_hint_playback_finished()
		return
	if _host == null or not is_instance_valid(_host):
		_on_status_hint_playback_finished()
		return
	if _host.is_queued_for_deletion() or not _host.is_inside_tree():
		_on_status_hint_playback_finished()
		return
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.z_as_relative = false
	label.z_index = 200
	_host.add_child.call_deferred(label)
	var min_size := label.get_combined_minimum_size()
	label.size = Vector2(maxf(min_size.x + 18.0, 96.0), maxf(min_size.y + 6.0, 26.0))
	label.position = Vector2(-label.size.x * 0.5, -80.0 - label.size.y * 0.5)
	var tween := _host.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - _floating_hint_rise_px, _floating_hint_duration_sec)
	tween.tween_property(label, "modulate:a", 0.0, _floating_hint_duration_sec)
	tween.finished.connect(func() -> void:
		if label and is_instance_valid(label):
			label.queue_free()
		_on_status_hint_playback_finished()
	)

func _on_status_hint_playback_finished() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	if _host.is_queued_for_deletion() or not _host.is_inside_tree():
		return

func _status_hint_meta(stat_type: StringName) -> Dictionary:
	match stat_type:
		&"move_speed_up":
			return {"family": &"move_speed", "polarity": 1}
		&"move_speed_down":
			return {"family": &"move_speed", "polarity": -1}
		&"vision_up":
			return {"family": &"vision", "polarity": 1}
		&"vision_down":
			return {"family": &"vision", "polarity": -1}
		&"damage_up":
			return {"family": &"damage", "polarity": 1}
		&"damage_down":
			return {"family": &"damage", "polarity": -1}
		&"attack_speed_up":
			return {"family": &"attack_speed", "polarity": 1}
		&"attack_speed_down":
			return {"family": &"attack_speed", "polarity": -1}
		&"spread_down":
			return {"family": &"spread", "polarity": 1}
		&"spread_up":
			return {"family": &"spread", "polarity": -1}
		&"weapon_damage_up":
			return {"family": &"weapon_damage", "polarity": 1}
		&"weapon_damage_down":
			return {"family": &"weapon_damage", "polarity": -1}
		_:
			return {}

func _status_type_from_family_state(family: StringName, state: int) -> StringName:
	match family:
		&"move_speed":
			return &"move_speed_up" if state > 0 else &"move_speed_down"
		&"vision":
			return &"vision_up" if state > 0 else &"vision_down"
		&"damage":
			return &"damage_up" if state > 0 else &"damage_down"
		&"attack_speed":
			return &"attack_speed_up" if state > 0 else &"attack_speed_down"
		&"spread":
			return &"spread_down" if state > 0 else &"spread_up"
		&"weapon_damage":
			return &"weapon_damage_up" if state > 0 else &"weapon_damage_down"
		_:
			return StringName()

func _resolve_status_hint_label(stat_type: StringName) -> String:
	var fallbacks := {
		&"move_speed_up": "Movement Speed Up",
		&"move_speed_down": "Movement Speed Down",
		&"vision_up": "Vision Up",
		&"vision_down": "Vision Down",
		&"damage_up": "Damage Up",
		&"damage_down": "Damage Down",
		&"attack_speed_up": "Attack Speed Up",
		&"attack_speed_down": "Attack Speed Down",
		&"spread_down": "Spread Reduced",
		&"spread_up": "Spread Increased",
		&"weapon_damage_up": "Weapon Damage Up",
		&"weapon_damage_down": "Weapon Damage Down",
	}
	var fallback := str(fallbacks.get(stat_type, ""))
	return LocalizationManager.tr_key("ui.status_hint.%s" % stat_type, fallback) if fallback != "" else ""
