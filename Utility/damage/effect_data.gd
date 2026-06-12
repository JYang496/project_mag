extends RefCounted
class_name EffectData

var source_node: Node
var target: Node
var effect_type: StringName = StringName()
var source_category: StringName = StringName()
var effect_delivery_type: StringName = StringName()
var detail: Dictionary = {}

func setup(
	source_node_value: Node,
	target_value: Node,
	effect_type_value: StringName,
	source_category_value: StringName,
	effect_delivery_type_value: StringName,
	detail_value: Dictionary = {}
) -> EffectData:
	source_node = source_node_value
	target = target_value
	effect_type = effect_type_value
	source_category = source_category_value
	effect_delivery_type = EffectDeliveryType.normalize(effect_delivery_type_value)
	detail = detail_value.duplicate(true)
	return self

func is_valid() -> bool:
	return source_category != StringName() and effect_delivery_type != StringName()
