extends WeaponBranchBehavior
class_name EnergyBoltsDelayedBurstBranch

@export_range(0.05, 5.0, 0.05) var delay_sec: float = 0.6
@export_range(1.0, 5.0, 0.05) var damage_multiplier: float = 1.25

var _pending_by_target: Dictionary = {}

func _process(_delta: float) -> void:
	var now_msec := Time.get_ticks_msec()
	for target_id_variant in _pending_by_target.keys():
		var target_id := int(target_id_variant)
		var group: Dictionary = _pending_by_target.get(target_id, {})
		if now_msec < int(group.get("due_msec", 0)):
			continue
		_pending_by_target.erase(target_id)
		_release_group(group)

func try_defer_energy_bolt_damage(
	_projectile: Projectile,
	target: Node,
	base_damage: int,
	damage_type: StringName,
	knock_back_data: Dictionary
) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var target_id := target.get_instance_id()
	var group: Dictionary = _pending_by_target.get(target_id, {})
	if group.is_empty():
		group = {
			"target": weakref(target),
			"due_msec": Time.get_ticks_msec() + int(round(maxf(delay_sec, 0.05) * 1000.0)),
			"marks": [],
		}
	var marks: Array = group.get("marks", [])
	marks.append({
		"damage": maxi(base_damage, 1),
		"damage_type": Attack.normalize_damage_type(damage_type),
		"knock_back": knock_back_data.duplicate(true),
	})
	group["marks"] = marks
	_pending_by_target[target_id] = group
	return true

func on_removed() -> void:
	_pending_by_target.clear()
	super.on_removed()

func _release_group(group: Dictionary) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var target_ref := group.get("target") as WeakRef
	var target := target_ref.get_ref() as Node if target_ref != null else null
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var mark_index := 0
	for mark_variant in group.get("marks", []):
		var mark: Dictionary = mark_variant
		var boosted_damage := maxi(1, int(round(
			float(mark.get("damage", 1))
			* maxf(damage_multiplier, 1.0)
			* get_fusion_enhancement_factor()
		)))
		var damage_data := DamageManager.build_damage_data(
			weapon,
			boosted_damage,
			Attack.normalize_damage_type(mark.get("damage_type", Attack.TYPE_ENERGY)),
			mark.get("knock_back", {}),
			DamageData.SOURCE_PLAYER_WEAPON,
			DamageDeliveryType.PROJECTILE
		)
		damage_data.dedupe_token = StringName("energy_delayed_burst_%d_%d_%d" % [
			get_instance_id(),
			target.get_instance_id(),
			mark_index,
		])
		DamageManager.apply_to_target(target, damage_data)
		mark_index += 1
