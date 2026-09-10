extends AudioStreamPlayer2D

var weapon: Weapon
var flavor := "laser"
var _remaining := 0.0
var _level := 0.0
var _started := false
var _was_active := false
var _transition_voice: AudioStreamPlayer2D
var _start_stream: AudioStreamWAV
var _end_stream: AudioStreamWAV

func _ready() -> void:
	PhaseManager.phase_changed.connect(_on_phase_changed)
	bus = "SFX"
	max_distance = 850
	volume_db = -60
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wave.loop_begin = 0
	wave.loop_end = 4410
	var samples := PackedByteArray()
	samples.resize(8820)
	for index in range(4410):
		var t := float(index) / 22050.0
		var sample := sin(TAU * 220 * t) * 0.20 + sin(TAU * 660 * t) * 0.06
		if flavor == "flamethrower":
			sample = (sin(TAU * 85 * t) + sin(TAU * 535 * t) * sin(TAU * 915 * t)) * 0.18
		elif flavor == "charged_blaster":
			sample = sin(TAU * 145 * t) * 0.22 + sin(TAU * 435 * t) * 0.10
		samples.encode_s16(index * 2, int(sample * 32767))
	wave.data = samples
	stream = wave
	add_to_group(&"continuous_weapon_voice")
	_start_stream = _make_transition(true)
	_end_stream = _make_transition(false)
	_transition_voice = AudioStreamPlayer2D.new()
	_transition_voice.bus = "SFX"
	_transition_voice.volume_db = -27.0
	_transition_voice.max_distance = max_distance
	add_child(_transition_voice)

func _make_transition(starting: bool) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var duration := 0.06 if starting else 0.09
	var count := int(duration * 22050.0)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var base_frequency := 340.0 if flavor == "laser" else 190.0
	if flavor == "flamethrower":
		base_frequency = 110.0
	for index in range(count):
		var t := float(index) / 22050.0
		var progress := float(index) / float(count - 1)
		var phase := base_frequency * (0.6 * t + 0.6 * t * t / duration) if starting else base_frequency * (1.8 * t - 0.6 * t * t / duration)
		var sample := sin(TAU * phase)
		if flavor == "flamethrower":
			sample *= sin(TAU * 725.0 * t)
		var envelope := sin(PI * progress) * (1.0 - progress * 0.5)
		samples.encode_s16(index * 2, int(sample * envelope * 12000.0))
	wave.data = samples
	return wave

func _on_phase_changed(phase: String) -> void:
	if phase == PhaseManager.BATTLE:
		return
	_remaining = 0.0
	_level = 0.0
	_started = false
	_was_active = false
	stop()
	if is_instance_valid(_transition_voice):
		_transition_voice.stop()

func refresh() -> void:
	_remaining = 0.25
	_started = true

func _exit_tree() -> void:
	stop()
	stream = null
	if is_instance_valid(_transition_voice):
		_transition_voice.stop()
		_transition_voice.stream = null
	_start_stream = null
	_end_stream = null

func _process(delta: float) -> void:
	if not is_instance_valid(weapon) or not weapon.is_inside_tree():
		queue_free()
		return
	_remaining = maxf(0.0, _remaining - delta)
	var active := _remaining > 0.0
	if _started and flavor == "charged_blaster":
		active = bool(weapon.get("is_firing_beam"))
	if _started and flavor == "flamethrower":
		active = active or (bool(weapon.get("_primary_fire_held")) and bool(weapon.call("_can_maintain_held_flame_vfx")))
	if not weapon.is_attack_phase_allowed():
		_on_phase_changed("")
		return
	if active and not playing:
		var active_voices := 0
		for voice in get_tree().get_nodes_in_group(&"continuous_weapon_voice"):
			if voice is AudioStreamPlayer2D and voice.playing:
				active_voices += 1
		active = active_voices < 4
	if active != _was_active:
		_transition_voice.stream = _start_stream if active else _end_stream
		_transition_voice.play()
	_was_active = active
	_level = move_toward(_level, 1.0 if active else 0.0, delta / (0.06 if active else 0.09))
	if active and not playing:
		play()
	if _level <= 0.0:
		stop()
		_started = false
	var heat_intensity := 0.0
	if flavor == "flamethrower" and weapon.has_method("get_heat_ratio"):
		heat_intensity = clampf(float(weapon.call("get_heat_ratio")), 0.0, 1.0)
	volume_db = lerpf(-55, -19 + heat_intensity * 1.5, _level)
	pitch_scale = lerpf(0.72, 1.0 + heat_intensity * 0.10, _level)
