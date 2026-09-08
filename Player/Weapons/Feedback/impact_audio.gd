extends RefCounted

## Small cached transients. No gameplay random numbers or persistent audio nodes.
static var _streams: Dictionary = {}

static func play_flight(projectile: Projectile, flavor: String) -> void:
	if not projectile.is_inside_tree() or PhaseManager.current_state() != PhaseManager.BATTLE:
		return
	var scene := projectile.get_tree().current_scene
	if scene == null or scene.is_queued_for_deletion():
		return
	var now := Time.get_ticks_msec()
	if now < int(scene.get_meta(&"flight_audio_next", 0)) or projectile.get_tree().get_nodes_in_group(&"weapon_flight_voice").size() >= 2:
		return
	scene.set_meta(&"flight_audio_next", now + 120)
	var key := "flight:" + flavor
	if not _streams.has(key):
		var wave := AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = 22050
		var samples := PackedByteArray()
		samples.resize(7938)
		for index in range(3969):
			var t := float(index) / 22050.0
			var progress := float(index) / 3968.0
			var carrier := sin(TAU * (950.0 * t - 1700.0 * t * t))
			if flavor == "rocket_launcher":
				carrier = sin(TAU * 170.0 * t) * 0.5 + sin(TAU * 730.0 * t) * sin(TAU * 1270.0 * t) * 0.5
			var envelope := sin(PI * progress) * (1.0 - progress)
			samples.encode_s16(index * 2, int(carrier * envelope * 11000.0))
		wave.data = samples
		_streams[key] = wave
	var voice := preload("res://Player/Weapons/Feedback/transient_weapon_voice.gd").new()
	voice.stream = _streams[key]
	voice.bus = "SFX"
	voice.volume_db = -29.0
	voice.max_distance = 650.0
	projectile.add_child(voice)
	voice.add_to_group(&"weapon_flight_voice")
	voice.play()

static func stream_for(type: StringName) -> AudioStreamWAV:
	var key := "%s:false" % type
	if not _streams.has(key):
		_streams[key] = _make_stream(type, false)
	return _streams[key] as AudioStreamWAV

static func play(owner: Node2D, at: Vector2, type: StringName, explosion: bool) -> void:
	var voices := owner.get_tree().get_nodes_in_group(&"weapon_impact_voice")
	if voices.size() >= 4:
		return
	var now := Time.get_ticks_msec()
	if now < int(owner.get_meta(&"impact_audio_next", 0)):
		return
	owner.set_meta(&"impact_audio_next", now + (85 if explosion else 65))
	var key := "%s:%s" % [type, explosion]
	if not _streams.has(key):
		_streams[key] = _make_stream(type, explosion)
	var voice := preload("res://Player/Weapons/Feedback/transient_weapon_voice.gd").new()
	voice.stream = _streams[key]
	voice.bus = "SFX"
	voice.volume_db = -22.0 if explosion else -28.0
	voice.pitch_scale = 0.97 + float(now % 5) * 0.015
	voice.max_distance = 850.0
	owner.add_child(voice)
	voice.global_position = at
	voice.add_to_group(&"weapon_impact_voice")
	voice.play()

static func _make_stream(type: StringName, explosion: bool) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count := 3528 if explosion else 1543
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var frequency := 710.0
	if type == Attack.TYPE_ENERGY:
		frequency = 1050.0
	elif type == Attack.TYPE_FREEZE:
		frequency = 1450.0
	elif type == Attack.TYPE_FIRE:
		frequency = 340.0
	for index in range(count):
		var t := float(index) / 22050.0
		var progress := float(index) / float(count)
		var envelope := minf(t / 0.002, 1.0) * pow(1.0 - progress, 3.0)
		var tone := sin(TAU * frequency * t) * sin(TAU * frequency * 1.41 * t)
		if explosion:
			tone = sin(TAU * (100.0 * t - 170.0 * t * t)) * 0.7 + tone * 0.3
		bytes.encode_s16(index * 2, int(tone * envelope * 18000.0))
	wave.data = bytes
	return wave
