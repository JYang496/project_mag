extends WeaponBranchBehavior
class_name ShotgunShatterBranch

@export var cooldown_multiplier: float = 0.62
@export var projectile_damage_multiplier: float = 0.42
@export var projectile_count: int = 6
@export var spread_arc_deg: float = 36.0
@export var shatter_damage_ratio: float = 0.25
@export var shatter_required_hits: int = 3
@export var shatter_window_sec: float = 0.12

var _target_window_hits: Dictionary = {}

func on_removed() -> void:
	_target_window_hits.clear()

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_projectile_damage_multiplier() -> float:
	return maxf(projectile_damage_multiplier, 0.05)

func get_projectile_count_override(_default_count: int = 1) -> int:
	return clampi(projectile_count, 1, 24)

func get_damage_type_override() -> StringName:
	return Attack.TYPE_FREEZE

func get_shot_directions(base_direction: Vector2, shot_count: int = -1) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	var count := projectile_count if shot_count < 0 else shot_count
	count = clampi(count, 1, 24)
	var normalized_base := base_direction.normalized()
	if count == 1:
		return [normalized_base]
	var spread_step := deg_to_rad(spread_arc_deg) / maxf(float(count - 1), 1.0)
	var start_offset := -deg_to_rad(spread_arc_deg) * 0.5
	for i in range(count):
		var angle := start_offset + spread_step * float(i)
		dirs.append(normalized_base.rotated(angle))
	return dirs

func on_target_hit(target: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if target == null or not is_instance_valid(target):
		return
	var target_id: int = target.get_instance_id()
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	var entry: Dictionary = _target_window_hits.get(target_id, {
		"window_start": now_sec,
		"hits": 0,
		"last_proc": -999.0,
	})
	var window_start: float = float(entry.get("window_start", now_sec))
	var hits: int = int(entry.get("hits", 0))
	var window_sec := maxf(shatter_window_sec, 0.01)
	if now_sec - window_start > window_sec:
		window_start = now_sec
		hits = 0
	hits += 1
	entry["window_start"] = window_start
	entry["hits"] = hits
	if hits >= max(1, shatter_required_hits):
		var last_proc: float = float(entry.get("last_proc", -999.0))
		if now_sec - last_proc >= window_sec:
			entry["last_proc"] = now_sec
			entry["hits"] = 0
			entry["window_start"] = now_sec
			_trigger_shatter(target)
	_target_window_hits[target_id] = entry

func _trigger_shatter(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var runtime_damage := 1
	if weapon.has_method("get_runtime_shot_damage"):
		runtime_damage = max(1, int(weapon.call("get_runtime_shot_damage")))
	var shatter_damage: int = max(1, int(round(float(runtime_damage) * maxf(shatter_damage_ratio, 0.0))))
	var damage_data: DamageData = DamageData.new().setup(
		shatter_damage,
		Attack.TYPE_FREEZE,
		{"amount": 0, "angle": Vector2.ZERO},
		weapon,
		DamageManager.resolve_source_player(weapon)
	)
	DamageManager.apply_to_target(target, damage_data)
