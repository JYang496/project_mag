extends Module
# Applies bleed on hit; bleeding targets take periodic physical damage while moving.

var ITEM_NAME := "Bleed Edge"

@export var duration_lv1: float = 2.4
@export var duration_lv2: float = 3.0
@export var duration_lv3: float = 3.8
@export var tick_interval_sec: float = 0.35
@export var move_threshold: float = 6.0
@export var damage_lv1: int = 2
@export var damage_lv2: int = 3
@export var damage_lv3: int = 4

var _bleed_runtime: Dictionary = {}

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()
	_bleed_runtime.clear()

func _physics_process(_delta: float) -> void:
	if _bleed_runtime.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var remove_ids: Array[int] = []
	for target_id_variant in _bleed_runtime.keys():
		var target_id: int = int(target_id_variant)
		var entry_variant: Variant = _bleed_runtime.get(target_id, null)
		if not (entry_variant is Dictionary):
			remove_ids.append(target_id)
			continue
		var entry: Dictionary = entry_variant
		var target_ref: WeakRef = entry.get("target_ref", null)
		var target: Node2D = target_ref.get_ref() as Node2D if target_ref != null else null
		if target == null or not is_instance_valid(target):
			remove_ids.append(target_id)
			continue
		if now_msec >= int(entry.get("expires_at_msec", 0)):
			remove_ids.append(target_id)
			continue
		var last_tick_msec: int = int(entry.get("last_tick_msec", 0))
		if now_msec - last_tick_msec < int(maxf(tick_interval_sec, 0.05) * 1000.0):
			continue
		var last_pos: Vector2 = entry.get("last_pos", target.global_position)
		var moved_dist: float = target.global_position.distance_to(last_pos)
		entry["last_pos"] = target.global_position
		entry["last_tick_msec"] = now_msec
		_bleed_runtime[target_id] = entry
		if moved_dist < maxf(move_threshold, 0.0):
			continue
		_apply_bleed_tick(target, entry)
	for target_id in remove_ids:
		_bleed_runtime.erase(target_id)

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	if not (target is Node2D):
		return
	var target2d := target as Node2D
	var target_id: int = target.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	_bleed_runtime[target_id] = {
		"target_ref": weakref(target2d),
		"source_weapon_ref": weakref(source_weapon) if source_weapon != null else null,
		"expires_at_msec": now_msec + int(maxf(_get_duration(), 0.1) * 1000.0),
		"last_tick_msec": now_msec,
		"last_pos": target2d.global_position,
	}

func _apply_bleed_tick(target: Node, entry: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	var source_weapon_ref: WeakRef = entry.get("source_weapon_ref", null)
	var source_weapon: Weapon = source_weapon_ref.get_ref() as Weapon if source_weapon_ref != null else null
	var owner_player: Node = DamageManager.resolve_source_player(source_weapon)
	var base_damage: int = _get_tick_damage()
	if owner_player != null and is_instance_valid(owner_player) and owner_player.has_method("compute_outgoing_damage"):
		base_damage = max(1, int(owner_player.call("compute_outgoing_damage", base_damage)))
	var damage_data := DamageData.new().setup(
		base_damage,
		Attack.TYPE_PHYSICAL,
		{"amount": 0, "angle": Vector2.ZERO},
		source_weapon,
		owner_player
	)
	DamageManager.apply_to_target(target, damage_data)

func _get_duration() -> float:
	match module_level:
		3:
			return maxf(0.0, duration_lv3)
		2:
			return maxf(0.0, duration_lv2)
		_:
			return maxf(0.0, duration_lv1)

func _get_tick_damage() -> int:
	match module_level:
		3:
			return max(1, damage_lv3)
		2:
			return max(1, damage_lv2)
		_:
			return max(1, damage_lv1)
