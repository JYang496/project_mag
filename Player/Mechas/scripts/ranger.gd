extends Player

const LONG_RANGE_DAMAGE_TYPE: StringName = Attack.TYPE_PHYSICAL

@export var long_range_threshold: float = 520.0
@export var bonus_lv1_3: float = 0.20
@export var bonus_lv4_6: float = 0.28
@export var bonus_lv7_10: float = 0.35
@export var same_target_icd_sec: float = 0.08

var _target_bonus_ready_at_msec: Dictionary = {}

func custom_ready() -> void:
	create_weapon("26")

func _broadcast_weapon_passive_event(event_name: StringName, detail: Dictionary = {}) -> void:
	super._broadcast_weapon_passive_event(event_name, detail)
	if event_name != &"on_hit":
		return
	_apply_long_range_bonus(detail)

func _apply_long_range_bonus(detail: Dictionary) -> void:
	var target: Node = detail.get("target", null) as Node
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	if not (target is Node2D):
		return
	var target2d := target as Node2D
	var distance_to_target := global_position.distance_to(target2d.global_position)
	if distance_to_target < maxf(long_range_threshold, 0.0):
		return

	var source_weapon: Node = detail.get("source_weapon", null) as Node
	if source_weapon == null or not is_instance_valid(source_weapon):
		return
	var source_weapon_as_weapon := source_weapon as Weapon
	if source_weapon_as_weapon == null:
		return

	var now_msec: int = Time.get_ticks_msec()
	var target_id: int = target2d.get_instance_id()
	var ready_at_msec: int = int(_target_bonus_ready_at_msec.get(target_id, 0))
	if now_msec < ready_at_msec:
		return
	_target_bonus_ready_at_msec[target_id] = now_msec + int(maxf(same_target_icd_sec, 0.0) * 1000.0)

	var base_damage := 1
	if source_weapon_as_weapon.has_method("get_runtime_shot_damage"):
		base_damage = max(1, int(source_weapon_as_weapon.call("get_runtime_shot_damage")))
	elif source_weapon_as_weapon.get("damage") != null:
		base_damage = max(1, int(source_weapon_as_weapon.get("damage")))

	var bonus_damage: int = max(1, int(round(float(base_damage) * _get_long_range_ratio())))
	var damage_data := DamageManager.build_damage_data(
		source_weapon_as_weapon,
		bonus_damage,
		LONG_RANGE_DAMAGE_TYPE,
		{"amount": 0, "angle": Vector2.ZERO}
	)
	DamageManager.apply_to_target(target2d, damage_data)
	_cleanup_target_icd(now_msec)

func _get_long_range_ratio() -> float:
	var level := clampi(int(PlayerData.player_level), 1, 10)
	if level >= 7:
		return maxf(bonus_lv7_10, 0.0)
	if level >= 4:
		return maxf(bonus_lv4_6, 0.0)
	return maxf(bonus_lv1_3, 0.0)

func _cleanup_target_icd(now_msec: int) -> void:
	if _target_bonus_ready_at_msec.is_empty():
		return
	var stale_ids: Array[int] = []
	for target_id_variant in _target_bonus_ready_at_msec.keys():
		var target_id := int(target_id_variant)
		if int(_target_bonus_ready_at_msec[target_id]) <= now_msec:
			stale_ids.append(target_id)
	for target_id in stale_ids:
		_target_bonus_ready_at_msec.erase(target_id)
