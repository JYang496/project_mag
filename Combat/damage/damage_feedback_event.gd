extends RefCounted
class_name DamageFeedbackEvent

var final_damage: int = 0
var damage_type: StringName = Attack.TYPE_PHYSICAL
var target_max_hp: int = 0
var target_instance_id: int = 0
var feedback_batch_id: int = 0
var is_critical: bool = false
var is_periodic: bool = false
var is_killing_blow: bool = false
var damage_by_type: Dictionary = {}

func _init(
	resolved_damage: int = 0,
	resolved_type: StringName = Attack.TYPE_PHYSICAL
) -> void:
	final_damage = maxi(0, resolved_damage)
	damage_type = normalize_damage_type(resolved_type)
	if final_damage > 0:
		damage_by_type[damage_type] = final_damage

func merge(other: DamageFeedbackEvent) -> void:
	if other == null:
		return
	final_damage += maxi(0, other.final_damage)
	target_max_hp = maxi(target_max_hp, other.target_max_hp)
	target_instance_id = other.target_instance_id if other.target_instance_id > 0 else target_instance_id
	feedback_batch_id = other.feedback_batch_id if other.feedback_batch_id != 0 else feedback_batch_id
	is_critical = is_critical or other.is_critical
	is_periodic = is_periodic and other.is_periodic
	is_killing_blow = is_killing_blow or other.is_killing_blow
	for type_key in other.damage_by_type:
		var normalized_type := normalize_damage_type(type_key)
		damage_by_type[normalized_type] = (
			int(damage_by_type.get(normalized_type, 0))
			+ int(other.damage_by_type[type_key])
		)
	damage_type = _resolve_dominant_damage_type()

func duplicate_event() -> DamageFeedbackEvent:
	var copy = get_script().new(final_damage, damage_type)
	copy.target_max_hp = target_max_hp
	copy.target_instance_id = target_instance_id
	copy.feedback_batch_id = feedback_batch_id
	copy.is_critical = is_critical
	copy.is_periodic = is_periodic
	copy.is_killing_blow = is_killing_blow
	copy.damage_by_type = damage_by_type.duplicate()
	return copy

func apply_dictionary(values: Dictionary) -> DamageFeedbackEvent:
	final_damage = maxi(0, int(values.get("final_damage", values.get("damage", 0))))
	damage_type = normalize_damage_type(values.get("damage_type", Attack.TYPE_PHYSICAL))
	target_max_hp = maxi(0, int(values.get("target_max_hp", 0)))
	target_instance_id = int(values.get("target_instance_id", 0))
	feedback_batch_id = int(values.get("feedback_batch_id", 0))
	is_critical = bool(values.get("is_critical", false))
	is_periodic = bool(values.get("is_periodic", false))
	is_killing_blow = bool(values.get("is_killing_blow", false))
	damage_by_type.clear()
	if values.get("damage_by_type", null) is Dictionary:
		damage_by_type = (values["damage_by_type"] as Dictionary).duplicate()
	elif final_damage > 0:
		damage_by_type[damage_type] = final_damage
	damage_type = _resolve_dominant_damage_type()
	return self

static func normalize_damage_type(value: Variant) -> StringName:
	if StringName(str(value)) == &"mixed":
		return &"mixed"
	return Attack.normalize_damage_type(value)

func _resolve_dominant_damage_type() -> StringName:
	if final_damage <= 0:
		return Attack.TYPE_PHYSICAL
	var dominant_type := Attack.TYPE_PHYSICAL
	var dominant_damage := 0
	for type_key in damage_by_type:
		var type_damage := int(damage_by_type[type_key])
		if type_damage > dominant_damage:
			dominant_damage = type_damage
			dominant_type = normalize_damage_type(type_key)
	if float(dominant_damage) <= float(final_damage) * 0.5:
		return &"mixed"
	return dominant_type
