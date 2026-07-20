extends StatusEffect
class_name DotStatusEffect

var damage: int = 1
var damage_type: StringName = Attack.TYPE_PHYSICAL


func setup_dot_effect(
	tick_value: int,
	damage_value: int,
	damage_type_value: StringName = Attack.TYPE_PHYSICAL,
	effect_id_value: StringName = &"dot"
) -> DotStatusEffect:
	setup(effect_id_value if effect_id_value != StringName() else &"dot", tick_value)
	damage = max(1, damage_value)
	damage_type = Attack.normalize_damage_type(damage_type_value)
	return self


func merge_from(other: StatusEffect) -> void:
	if other == null or not (other is DotStatusEffect):
		return
	var typed_other := other as DotStatusEffect
	ticks_left = max(ticks_left, typed_other.ticks_left)
	# Damage, type, and ownership describe one payload and must be replaced
	# together. Mixing the strongest damage with a newer type or older source
	# makes feedback and kill attribution depend on application order.
	if typed_other.damage >= damage:
		damage = typed_other.damage
		damage_type = typed_other.damage_type
		source_player = typed_other.source_player
		source_node = typed_other.source_node


func apply_tick(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("damaged"):
		return
	var attack := Attack.new()
	attack.damage = damage
	attack.damage_type = damage_type
	attack.suppress_reactive_effects = true
	# Keep compatibility with both the current request semantics and the
	# transitional boolean periodic marker.
	if _has_property(attack, &"damage_kind"):
		attack.set(&"damage_kind", DamageData.KIND_PERIODIC)
	if _has_property(attack, &"invulnerability_policy"):
		attack.set(&"invulnerability_policy", DamageData.INVULN_BYPASS)
	if _has_property(attack, &"triggers_invulnerability"):
		attack.set(&"triggers_invulnerability", false)
	if _has_property(attack, &"is_periodic"):
		attack.set(&"is_periodic", true)
	if self.source_player != null and is_instance_valid(self.source_player):
		attack.source_player = self.source_player
	else:
		attack.source_player = null
	if self.source_node != null and is_instance_valid(self.source_node):
		attack.source_node = self.source_node
	else:
		attack.source_node = null
	target.damaged(attack)


static func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property in object.get_property_list():
		if StringName(property.get("name", StringName())) == property_name:
			return true
	return false


static func from_dot_payload(data: Variant) -> DotStatusEffect:
	var tick_value := 0
	var damage_value := 1
	var damage_type_value: StringName = Attack.TYPE_PHYSICAL
	var effect_id_value: StringName = &"dot"
	if data is Dictionary:
		tick_value = int((data as Dictionary).get("tick", 0))
		damage_value = int((data as Dictionary).get("damage", 1))
		damage_type_value = Attack.normalize_damage_type((data as Dictionary).get("damage_type", Attack.TYPE_PHYSICAL))
		effect_id_value = StringName((data as Dictionary).get("effect_id", &"dot"))
	return DotStatusEffect.new().setup_dot_effect(tick_value, damage_value, damage_type_value, effect_id_value)
