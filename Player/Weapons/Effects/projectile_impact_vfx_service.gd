extends Node2D
class_name ProjectileImpactVfxService

## Presentation only: bounded records, no collision nodes, timers or gameplay RNG.
const LIMIT := 48
const GROUP := &"projectile_impact_vfx_service"
var _events: Array[Dictionary] = []
var _gates: Dictionary = {}

static func ensure(tree: SceneTree) -> Node:
	if tree == null or tree.current_scene == null:
		return null
	if PhaseManager.current_state() != PhaseManager.BATTLE or tree.current_scene.is_queued_for_deletion():
		return null
	var existing := tree.get_first_node_in_group(GROUP)
	if existing != null and not existing.is_queued_for_deletion():
		return existing
	var service = load("res://Player/Weapons/Effects/projectile_impact_vfx_service.gd").new()
	tree.current_scene.add_child(service)
	return service

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 65

static func damage_feedback(weapon: Node2D, target: Node, data: DamageData, result: DamageResult) -> void:
	if not result.applied or result.is_periodic or data.damage_kind == DamageData.KIND_PERIODIC:
		return
	if not is_instance_valid(target) or not target is Node2D or not weapon.is_inside_tree():
		return
	var id: String = weapon.get_script().resource_path.get_file().get_basename()
	if id not in ["machine_gun", "shotgun", "rocket_launcher", "cannon", "spear_launcher", "chainsaw_launcher", "orbit", "sniper", "laser", "charged_blaster", "flamethrower", "glacier_projector", "plasma_lance"]:
		return
	var service := ensure(weapon.get_tree())
	if service == null:
		return
	if id == "sniper" and result.killed and weapon.global_position.distance_to(target.global_position) >= float(weapon.get("far_hit_trigger_distance")):
		TimeImpactController.trigger_weapon_impact(&"sniper_far_kill")
	var source := data.source_node
	var contact_position: Vector2 = target.global_position
	var direction := weapon.global_position.direction_to(target.global_position)
	var behavior := &"stop"
	var tier := 0
	var empowered := false
	if is_instance_valid(source):
		if id == "laser" and source.has_method("get_presentation_contact_position"):
			contact_position = source.call("get_presentation_contact_position")
			direction = weapon.global_position.direction_to(contact_position)
		empowered = bool(source.get_meta(Weapon.ENERGY_RELEASE_ATTACK_META, false))
		if source is Projectile:
			empowered = source.presentation_empowered
			direction = source.get_meta(&"presentation_motion_direction", source.base_displacement.normalized())
			behavior = &"pierce" if source.hp > 1 else &"stop"
			if source.boundary_bounce_enabled:
				behavior = &"bounce"
			source.set_meta(&"presentation_hit", true)
			if id == "chainsaw_launcher" or behavior == &"bounce":
				source.set_meta(&"presentation_contact_frame", Engine.get_process_frames())
	if id in ["shotgun", "charged_blaster", "spear_launcher", "sniper"]:
		tier = 1
	if id in ["sniper", "spear_launcher"]:
		behavior = &"pierce"
	if id == "orbit":
		behavior = &"contact_arc"
	if id in ["cannon", "rocket_launcher"]:
		# One explosion at its origin; targets only get a small contact accent.
		tier = 0
	var continuous: bool = data.delivery_type == DamageDeliveryType.BEAM or id in ["flamethrower", "glacier_projector", "orbit"]
	var key := "%d:%d" % [weapon.get_instance_id(), target.get_instance_id()]
	service.play(contact_position, direction, result.damage_type, tier, behavior,
		{"critical": result.is_critical, "killed": result.killed, "empowered": empowered}, key, 100 if continuous else 55)

func play(at: Vector2, direction: Vector2, type: StringName, tier: int = 0,
	behavior: StringName = &"stop", flags: Dictionary = {}, key: String = "", cooldown_ms: int = 40) -> bool:
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		return false
	var now := Time.get_ticks_msec()
	if key != "" and now < int(_gates.get(key, 0)):
		return false
	if _events.size() >= LIMIT:
		return false
	if key != "":
		_gates[key] = now + cooldown_ms
	var lifetime := [0.075, 0.11, 0.18][clampi(tier, 0, 2)] as float
	if behavior == &"dissolve":
		lifetime = 0.07
	_events.append({"at": at, "direction": direction, "type": type, "tier": tier,
		"behavior": behavior, "flags": flags.duplicate(), "age": 0.0, "duration": lifetime})
	if behavior == &"explode" or flags.get("wall", false):
		preload("res://Player/Weapons/Feedback/impact_audio.gd").play(self, at, type, behavior == &"explode")
	queue_redraw()
	return true

func cleanup_for_battle_end() -> void:
	_events.clear()
	_gates.clear()
	queue_free()

func _process(delta: float) -> void:
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		cleanup_for_battle_end()
		return
	for index in range(_events.size() - 1, -1, -1):
		_events[index]["age"] += delta
		if _events[index]["age"] >= _events[index]["duration"]:
			_events.remove_at(index)
	var now := Time.get_ticks_msec()
	for key in _gates.keys():
		if now >= int(_gates[key]):
			_gates.erase(key)
	queue_redraw()

func _draw() -> void:
	var view := get_tree().get_first_node_in_group(&"hybrid_ground_view_3d")
	for event in _events:
		var at: Vector2 = event.at
		var direction: Vector2 = event.direction
		if view != null:
			if not view.call("can_project_world_point", at):
				continue
			direction = view.call("world_vector_to_screen", direction, at)
			at = view.call("project_world_to_canvas", at, get_viewport())
		at = to_local(at).round()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		direction = direction.normalized()
		var side := direction.orthogonal()
		var t: float = event.age / event.duration
		var color := Color("ffd19a")
		match event.type:
			Attack.TYPE_ENERGY: color = Color("70daff")
			Attack.TYPE_FIRE: color = Color("ff873d")
			Attack.TYPE_FREEZE: color = Color("a6edff")
		color.a = 1.0 - t
		var tier: int = event.tier
		var boost := 1.25 if event.flags.get("empowered", false) else 1.0
		var radius := (5.0 + tier * 9.0) * boost * (0.3 + t)
		if event.behavior not in [&"dissolve", &"satellite_recall"] and (event.flags.get("critical", false) or event.flags.get("killed", false)):
			# Offset the accent so piercing contacts never imply a stopped core.
			var accent := (at + side * 4.0).round()
			draw_line(accent - direction * 3.0, accent + direction * 3.0, Color(1, 1, 1, color.a), 1)
		if event.behavior == &"satellite_recall":
			var spread := roundf(9.0 * (1.0 - t))
			for sign_value in [-1.0, 1.0]:
				var panel: Vector2 = (at + direction * spread * sign_value).round()
				draw_line(at, panel, Color(0.69,0.78,0.82,color.a), 2)
				draw_rect(Rect2(panel-Vector2(3,4),Vector2(6,8)),Color(0.16,0.30,0.41,color.a))
			draw_rect(Rect2(at-Vector2(2,3),Vector2(4,6)),color)
			continue
		if event.behavior == &"contact_arc":
			draw_polyline(PackedVector2Array([(at-direction*10).round(),(at-direction*5+side*3).round(),at]),Color(0.45,0.95,1,color.a),1)
			continue
		if event.behavior == &"pierce":
			for sign_value in [-1.0, 1.0]:
				var offset: Vector2 = side * sign_value * (2.0 + t * 9.0) * boost
				draw_line((at + offset - direction * 6.0 * boost).round(), (at + offset + direction * 5.0 * boost).round(), color, 2.0)
				if event.flags.get("empowered", false):
					var outer: Vector2 = at + offset + side * sign_value * 3.0
					draw_line((outer - direction * 4.0).round(), (outer + direction * 2.0).round(), Color(color, color.a * 0.55), 1.0)
			continue
		if event.behavior == &"dissolve":
			if event.type == Attack.TYPE_ENERGY:
				var extent := roundf(6.0 * (1.0 - t))
				draw_line(at-direction*extent,at+direction*extent,color,1)
				draw_line(at-side*extent,at+side*extent,color,1)
				continue
			for index in range(3):
				var fragment := (at - direction * t * 9.0 + side * (index - 1) * t * 6.0).round()
				if event.type == Attack.TYPE_FREEZE:
					draw_line(fragment,(fragment+Vector2(2,3)).round(),color,1)
				elif event.type == Attack.TYPE_FIRE:
					draw_rect(Rect2(fragment+Vector2(0,-roundf(t*5)),Vector2(2,2)),color)
				else:
					draw_rect(Rect2(fragment, Vector2(2, 2)), color)
			continue
		if tier > 0 and event.behavior != &"bounce":
			draw_arc(at, roundf(radius), 0, TAU, 12, color, 1.0)
			for axis in [Vector2.RIGHT, Vector2.UP]:
				draw_line((at-axis*radius*0.5).round(),(at+axis*radius*0.5).round(),color,1)
		if tier == 2:
			for index in range(5):
				var ray := Vector2.RIGHT.rotated(index * TAU / 5.0)
				var debris := (at + ray * radius * 0.8 + Vector2(0, t*t*8)).round()
				var debris_color := Color(0.42,0.29,0.18,color.a) if event.flags.get("ground",false) else color
				draw_rect(Rect2(debris,Vector2(3,3)),debris_color)
				if event.behavior == &"explode" and t < 0.7:
					var cloud := (at + ray * radius * 0.3).round()
					draw_rect(Rect2(cloud-Vector2(3,3),Vector2(6,6)),Color(color, (1-t)*0.38))
			if t < 0.22:
				draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), Color.WHITE)
			if event.flags.get("ground", false):
				for index in range(5):
					var ray := Vector2.RIGHT.rotated(index * TAU / 5.0)
					draw_polyline(PackedVector2Array([at, (at + ray * 10 + ray.orthogonal() * 4).round(), (at + ray * 22).round()]), Color(0.18, 0.12, 0.1, color.a), 2)
		for index in range(3 + tier * 2):
			var ray := direction.rotated((index - (2 + tier * 2) * 0.5) * 0.65)
			var start := (at + ray * (2 + t * radius)).round()
			draw_line(start, (start + ray * (4 + tier * 2) * (1 - t)).round(), color, 2)
