extends Node2D
class_name TetherChainNetwork

const HYBRID_GROUND_REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")

var source_weapon: Weapon
var aim_direction := Vector2.RIGHT
var acquisition_range := 450.0
var acquisition_half_angle_deg := 42.0
var chain_range := 170.0
var max_chain_count := 2
var duration_sec := 1.0
var tick_interval_sec := 0.2
var primary_damage := 1
var secondary_damage_ratio := 0.65
var resonance_enabled := false
var resonance_ramp_per_tick := 0.14
var resonance_max_ticks := 5
var beam_width := 8.0
var profile: Dictionary = {}
var _elapsed_sec := 0.0
var _tick_elapsed_sec := 0.0
var _resonance_ticks := 0
var _primary_ref: WeakRef
var _links: Array[Dictionary] = []
var _primary_line: Line2D
var _chain_lines: Array[Line2D] = []

func setup(weapon: Weapon, config: Dictionary) -> TetherChainNetwork:
	source_weapon = weapon
	aim_direction = (config.get("direction", Vector2.RIGHT) as Vector2).normalized()
	acquisition_range = maxf(float(config.get("acquisition_range", 450.0)), 1.0)
	acquisition_half_angle_deg = clampf(float(config.get("acquisition_half_angle_deg", 42.0)), 0.0, 180.0)
	chain_range = maxf(float(config.get("chain_range", 170.0)), 1.0)
	max_chain_count = maxi(int(config.get("max_chain_count", 2)), 0)
	duration_sec = maxf(float(config.get("duration", 1.0)), 0.05)
	tick_interval_sec = maxf(float(config.get("tick_interval", 0.2)), 0.02)
	primary_damage = maxi(int(config.get("damage", 1)), 1)
	secondary_damage_ratio = maxf(float(config.get("secondary_damage_ratio", 0.65)), 0.0)
	resonance_enabled = bool(config.get("energy_resonance", false))
	resonance_ramp_per_tick = maxf(float(config.get("resonance_ramp_per_tick", 0.14)), 0.0)
	resonance_max_ticks = maxi(int(config.get("resonance_max_ticks", 5)), 0)
	beam_width = maxf(float(config.get("width", 8.0)), 1.0)
	profile = config.duplicate(true)
	return self

func _ready() -> void:
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	_create_connection_lines()
	_acquire_primary()
	_rebuild_links()
	_apply_tick()

func _physics_process(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	_elapsed_sec += step
	_tick_elapsed_sec += step
	if _elapsed_sec >= duration_sec:
		queue_free()
		return
	if _resolve_primary() == null:
		_acquire_primary()
	_rebuild_links()
	_sync_connection_lines()
	if _tick_elapsed_sec >= tick_interval_sec:
		_tick_elapsed_sec = fmod(_tick_elapsed_sec, tick_interval_sec)
		_apply_tick()
	queue_redraw()

func cleanup_for_battle_end() -> void:
	queue_free()

func _exit_tree() -> void:
	_unregister_connection_line(_primary_line)
	for line in _chain_lines:
		_unregister_connection_line(line)

func get_linked_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var primary: Node2D = _resolve_primary()
	if primary != null:
		targets.append(primary)
	for link in _links:
		var target := link.get("target", null) as Node2D
		if target != null and is_instance_valid(target):
			targets.append(target)
	return targets

func _acquire_primary() -> void:
	var origin: Vector2 = source_weapon.get_muzzle_global_position() if source_weapon != null else global_position
	var best: Node2D
	var best_distance: float = INF
	var max_angle: float = deg_to_rad(acquisition_half_angle_deg)
	for enemy in WeaponModuleRuntimeUtils.get_nearby_enemies(get_tree(), origin, acquisition_range):
		if not _is_valid_target(enemy):
			continue
		var offset: Vector2 = enemy.global_position - origin
		if offset.length_squared() <= 0.01 or absf(aim_direction.angle_to(offset.normalized())) > max_angle:
			continue
		if offset.length_squared() < best_distance:
			best_distance = offset.length_squared()
			best = enemy
	_primary_ref = weakref(best) if best != null else null

func _resolve_primary() -> Node2D:
	if _primary_ref == null:
		return null
	var target := _primary_ref.get_ref() as Node2D
	if not _is_valid_target(target):
		_primary_ref = null
		return null
	return target

func _rebuild_links() -> void:
	_links.clear()
	var current: Node2D = _resolve_primary()
	if current == null:
		return
	var used := {current.get_instance_id(): true}
	for _index in range(max_chain_count):
		var next: Node2D = _find_nearest_unique(current.global_position, used)
		if next == null:
			break
		_links.append({"from": current, "target": next})
		used[next.get_instance_id()] = true
		current = next
	_sync_connection_lines()

func _create_connection_lines() -> void:
	_primary_line = _create_connection_line(
		"PrimaryTether", Color(0.55, 0.82, 1.0, 0.92), beam_width
	)
	for index in range(max_chain_count):
		_chain_lines.append(_create_connection_line(
			"ChainTether%d" % index,
			Color(0.68, 0.48, 1.0, 0.82),
			maxf(beam_width * 0.65, 2.0)
		))
	call_deferred("_register_connection_lines")

func _create_connection_line(line_name: String, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.default_color = color
	line.width = width
	line.antialiased = false
	line.visible = false
	line.set_meta(&"hybrid_ground_visible", false)
	line.set_meta(&"hybrid_segment_style", &"beam")
	add_child(line)
	var flow := preload("res://Player/Weapons/Effects/beam_flow_visual.gd").new()
	flow.name = "FlowAccent"
	flow.chain = true
	flow.body_width = clampf(roundf(width), 2.0, 8.0)
	flow.body_color = Color(color, 0.28)
	flow.phase_offset = float(_chain_lines.size() + 1) * 0.14 if line_name != "PrimaryTether" else 0.0
	add_child(flow)
	line.set_meta(&"flow_accent", flow)
	return line

func _register_connection_lines() -> void:
	_register_connection_line(_primary_line)
	for line in _chain_lines:
		_register_connection_line(line)
	_sync_connection_lines()

func _register_connection_line(line: Line2D) -> void:
	if line == null or not is_instance_valid(line):
		return
	if HYBRID_GROUND_REGISTRATION.register(line, &"register_ground_segment"):
		line.visible = false

func _unregister_connection_line(line: Line2D) -> void:
	if line != null and is_instance_valid(line):
		HYBRID_GROUND_REGISTRATION.unregister(line)

func _sync_connection_lines() -> void:
	if _primary_line == null:
		return
	var primary := _resolve_primary()
	var has_primary := primary != null and source_weapon != null and is_instance_valid(source_weapon)
	_set_connection_line(
		_primary_line,
		source_weapon.get_muzzle_global_position() if has_primary else Vector2.ZERO,
		primary.global_position if has_primary else Vector2.ZERO,
		has_primary
	)
	for index in range(_chain_lines.size()):
		var has_link := index < _links.size()
		var from := _links[index].get("from", null) as Node2D if has_link else null
		var target := _links[index].get("target", null) as Node2D if has_link else null
		var valid := from != null and target != null and is_instance_valid(from) and is_instance_valid(target)
		_set_connection_line(
			_chain_lines[index],
			from.global_position if valid else Vector2.ZERO,
			target.global_position if valid else Vector2.ZERO,
			valid
		)

func _set_connection_line(line: Line2D, start: Vector2, end: Vector2, enabled: bool) -> void:
	var flow := line.get_meta(&"flow_accent") as Node2D
	flow.set("start", start)
	flow.set("finish", end)
	flow.set("active", enabled)
	line.points = PackedVector2Array([to_local(start), to_local(end)]) if enabled else PackedVector2Array()
	# Endpoints remain available to existing consumers; the bent canvas visual
	# owns both body and core so no straight strip cuts through its corners.
	line.set_meta(&"hybrid_ground_visible", false)
	line.visible = false

func _find_nearest_unique(origin: Vector2, used: Dictionary) -> Node2D:
	var best: Node2D
	var best_distance: float = INF
	for enemy in WeaponModuleRuntimeUtils.get_nearby_enemies(get_tree(), origin, chain_range):
		if not _is_valid_target(enemy) or used.has(enemy.get_instance_id()):
			continue
		var distance: float = origin.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

func _apply_tick() -> void:
	var primary: Node2D = _resolve_primary()
	if primary == null or source_weapon == null or not is_instance_valid(source_weapon):
		return
	var ramp: float = 1.0 + resonance_ramp_per_tick * float(_resonance_ticks) if resonance_enabled else 1.0
	_apply_damage(primary, maxi(1, int(round(float(primary_damage) * ramp))), true)
	for link in _links:
		var target := link.get("target", null) as Node2D
		if target != null and is_instance_valid(target):
			_apply_damage(target, maxi(1, int(round(float(primary_damage) * secondary_damage_ratio * ramp))), false)
	if resonance_enabled:
		_resonance_ticks = mini(_resonance_ticks + 1, resonance_max_ticks)

func _apply_damage(target: Node, amount: int, primary: bool) -> void:
	var data: DamageData = DamageManager.build_damage_data(
		self, amount, Attack.TYPE_ENERGY, {}, DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.BEAM, get_meta(Weapon.HEAT_SNAPSHOT_META) if has_meta(Weapon.HEAT_SNAPSHOT_META) else null
	)
	data.dedupe_token = StringName("charged_network_%d_%d_%d" % [get_instance_id(), _resonance_ticks, target.get_instance_id()])
	data.dedupe_window_sec = tick_interval_sec * 0.8
	var result: DamageResult = DamageManager.apply_to_target_result(target, data)
	if not result.applied:
		return
	var hit_profile: Dictionary = profile.duplicate(true)
	hit_profile["network_primary"] = primary
	hit_profile["network_link_count"] = _links.size()
	if source_weapon.has_method("on_beam_hit_target"):
		source_weapon.call("on_beam_hit_target", target, hit_profile, result.final_damage, self)
	if source_weapon.has_method("on_hit_target_with_damage_type"):
		source_weapon.call("on_hit_target_with_damage_type", target, Attack.TYPE_ENERGY)

func _is_valid_target(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	var dead: Variant = target.get("is_dead")
	return not (dead != null and bool(dead))

func _draw() -> void:
	pass
