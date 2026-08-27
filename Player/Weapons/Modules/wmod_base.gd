extends Node2D
class_name Module

# Weapon -> Modules -> Module
const RARITY_UTIL := preload("res://data/LootRarity.gd")
const MAX_LEVEL: int = 3

var weapon: Weapon
var _trigger_state := ModuleTriggerState.new()
var _is_bound: bool = false
@export var module_id: StringName = StringName()
@export var display_name: String = ""
@export var cost : int
@onready var sprite: Sprite2D = get_node_or_null("%Sprite") as Sprite2D
@export_range(1, MAX_LEVEL, 1) var module_level: int = 1
@export_enum("common", "rare", "epic") var rarity: String = "common"
@export_range(0.0, 1000000.0, 0.01) var drop_weight: float = 100.0
@export var module_tags: PackedStringArray = []
@export var level_effects: PackedStringArray = []
@export var stat_multipliers: Dictionary = {}
@export var stat_additives: Dictionary = {}
@export_flags(
	"physical",
	"energy",
	"fire",
	"freeze",
	"heat",
	"charge"
) var required_weapon_traits: int = 0
@export_flags("projectile", "melee_contact", "beam", "area") var required_delivery_types: int = 0
@export_flags("summon", "trap", "support", "movement") var required_weapon_capabilities: int = 0
@export_flags(
	"projectile_spawn",
	"hit",
	"damage_dealt",
	"area_damage",
	"beam_hit",
	"reload_start",
	"reload_duration",
	"kill",
	"skill_cast",
	"skill_finish"
) var required_hooks: int = 0
@export var trigger_spec: ModuleTriggerSpec

signal module_triggered(module: Module, event: WeaponEvent)

func _enter_tree() -> void:
	var owner_weapon := _resolve_weapon()
	if owner_weapon != null:
		bind_to_weapon(owner_weapon)

func _ready() -> void:
	var owner_weapon := _resolve_weapon()
	if owner_weapon != null and owner_weapon != weapon:
		bind_to_weapon(owner_weapon)

func _exit_tree() -> void:
	unbind_from_weapon()

func bind_to_weapon(target_weapon: Weapon) -> void:
	if _is_bound and weapon == target_weapon:
		return
	unbind_from_weapon()
	weapon = target_weapon
	var reason := get_incompatibility_reason(target_weapon)
	if reason != "":
		push_warning("Module '%s' is incompatible with weapon '%s': %s" % [name, target_weapon.name, reason])
		weapon = null
		return
	weapon.plugin_dispatcher.subscribe_module(self)
	_is_bound = true

func unbind_from_weapon() -> void:
	var previous_weapon := weapon
	if _is_bound:
		weapon.plugin_dispatcher.unsubscribe_module(self)
	if previous_weapon != null:
		on_weapon_unbound(previous_weapon)
	_is_bound = false
	weapon = null
	_trigger_state.clear()

func is_bound_to_weapon() -> bool:
	return _is_bound

func on_weapon_unbound(_previous_weapon: Weapon) -> void:
	pass

func can_apply_to_weapon(target_weapon: Weapon) -> bool:
	return get_incompatibility_reason(target_weapon) == ""

func get_incompatibility_reason(target_weapon: Weapon) -> String:
	if not target_weapon:
		return "Invalid weapon."
	var required_delivery := get_normalized_required_delivery_types()
	if not required_delivery.is_empty() and target_weapon.has_method("has_delivery_type"):
		var matched_delivery := false
		for delivery_type in required_delivery:
			if target_weapon.has_delivery_type(delivery_type):
				matched_delivery = true
				break
		if not matched_delivery:
			var delivery_names: PackedStringArray = []
			for required_delivery_type in required_delivery:
				delivery_names.append(str(required_delivery_type))
			return "Requires delivery type: %s" % ", ".join(delivery_names)
	var required_traits := get_normalized_required_weapon_traits()
	if target_weapon.has_method("has_any_weapon_traits"):
		if not target_weapon.has_any_weapon_traits(required_traits):
			var trait_names: PackedStringArray = []
			for required_trait_name in required_traits:
				trait_names.append(str(required_trait_name))
			if trait_names.is_empty():
				return "Weapon does not match required traits."
			return "Requires one of: %s" % ", ".join(trait_names)
	var required_capabilities := get_normalized_required_weapon_capabilities()
	if not required_capabilities.is_empty():
		if not target_weapon.has_method("has_any_weapon_capabilities") \
				or not target_weapon.has_any_weapon_capabilities(required_capabilities):
			return "Requires one of capabilities: %s" % ", ".join(PackedStringArray(required_capabilities))
	var hook_reason := get_hook_validation_error()
	if hook_reason != "":
		return hook_reason
	return ""

func get_subscribed_weapon_events() -> Array[StringName]:
	var events := ModuleHook.hooks_to_events(get_normalized_required_hooks())
	if trigger_spec != null:
		var event_type := StringName(trigger_spec.event_type)
		if not events.has(event_type):
			events.append(event_type)
	return events

func provides_modifier_channel(channel: StringName) -> bool:
	return channel == WeaponPluginDispatcher.RELOAD_DURATION_CHANNEL \
		and get_normalized_required_hooks().has(ModuleHook.RELOAD_DURATION) \
		and has_method("get_reload_duration_multiplier")

func handle_weapon_event(event: WeaponEvent) -> bool:
	if trigger_spec == null:
		return _handle_legacy_weapon_event(event)
	if not trigger_spec.matches(event) or not _trigger_state.can_trigger(trigger_spec, event):
		return false
	if not can_trigger_event(event) or not execute_trigger(event):
		return false
	_trigger_state.record_trigger(trigger_spec, event)
	module_triggered.emit(self, event)
	return true

func can_trigger_event(_event: WeaponEvent) -> bool:
	return true

func execute_trigger(_event: WeaponEvent) -> bool:
	return false

func _handle_legacy_weapon_event(event: WeaponEvent) -> bool:
	match event.type:
		WeaponEvent.HIT_CONFIRMED:
			if has_method("apply_on_hit"):
				call("apply_on_hit", weapon, event.target)
				return true
		WeaponEvent.DAMAGE_DEALT:
			if has_method("on_damage_dealt"):
				call("on_damage_dealt", weapon, event.target, event.damage_data, event.damage_result)
				return true
		WeaponEvent.PROJECTILE_SPAWNED:
			if has_method("on_projectile_spawned"):
				call("on_projectile_spawned", weapon, event.projectile)
				return true
		WeaponEvent.RELOAD_STARTED:
			if has_method("_on_weapon_passive_triggered"):
				call("_on_weapon_passive_triggered", &"on_reload_started", event.to_legacy_detail())
				return true
		WeaponEvent.TARGET_KILLED:
			if has_method("on_kill"):
				call("on_kill", weapon, event.target, event.damage_data, event.damage_result)
				return true
	return false

func get_normalized_module_tags() -> Array[StringName]:
	return ModuleTag.normalize_array(module_tags)

func get_effect_tags() -> Array[StringName]:
	var output: Array[StringName] = []
	var derived_tags := get_derived_trigger_tags()
	var has_trigger_source := not get_subscribed_weapon_events().is_empty() \
		or get_normalized_required_hooks().has(ModuleHook.RELOAD_DURATION)
	for tag in get_normalized_module_tags():
		# Legacy resources often repeat facts already declared by their Hook data.
		if derived_tags.has(tag) or (tag == &"trigger" and has_trigger_source):
			continue
		if not output.has(tag):
			output.append(tag)
	return output

func get_derived_trigger_tags() -> Array[StringName]:
	var output := ModuleHook.display_tags_for_events(get_subscribed_weapon_events())
	if get_normalized_required_hooks().has(ModuleHook.RELOAD_DURATION) and not output.has(&"reload"):
		output.append(&"reload")
	return output

func get_build_tags() -> Array[StringName]:
	var output := get_effect_tags()
	_append_unique_tags(output, get_derived_trigger_tags())
	_append_unique_tags(output, get_normalized_required_delivery_types())
	return output

func _append_unique_tags(target: Array[StringName], additions: Array[StringName]) -> void:
	for tag in additions:
		if tag != StringName() and not target.has(tag):
			target.append(tag)

func get_unknown_module_tags() -> Array[StringName]:
	var output: Array[StringName] = []
	for tag in get_normalized_module_tags():
		if not ModuleTag.CORE.has(tag):
			output.append(tag)
	return output

func get_normalized_required_weapon_traits() -> Array[StringName]:
	return WeaponTrait.flags_to_explicit_traits(required_weapon_traits)

func get_normalized_required_delivery_types() -> Array[StringName]:
	return DamageDeliveryType.flags_to_types(required_delivery_types)

func get_normalized_required_weapon_capabilities() -> Array[StringName]:
	return WeaponCapability.flags_to_capabilities(required_weapon_capabilities)

func get_normalized_required_hooks() -> Array[StringName]:
	return ModuleHook.flags_to_hooks(required_hooks)

func get_hook_validation_error() -> String:
	for hook in get_normalized_required_hooks():
		if hook == ModuleHook.RELOAD_DURATION:
			if not has_method("get_reload_duration_multiplier"):
				return "Declared modifier '%s' requires get_reload_duration_multiplier()." % hook
			continue
		var method_name: StringName = ModuleHook.METHOD_BY_HOOK.get(hook, StringName())
		if trigger_spec == null and (method_name == StringName() or not has_method(method_name)):
			return "Declared hook '%s' requires method %s()." % [hook, method_name]
	return ""

func resolve_primary_damage_delivery(source_weapon: Weapon = weapon) -> StringName:
	if source_weapon == null or not is_instance_valid(source_weapon):
		return StringName()
	var delivery_types := source_weapon.get_weapon_delivery_types()
	if delivery_types.is_empty():
		return StringName()
	return delivery_types[0]

func _resolve_weapon() -> Weapon:
	var current: Node = get_parent()
	while current:
		if current is Weapon:
			return current as Weapon
		current = current.get_parent()
	return null

func set_module_level(new_level: int) -> void:
	module_level = clampi(new_level, 1, MAX_LEVEL)

func increase_module_level(steps: int = 1) -> bool:
	var previous_level := module_level
	set_module_level(module_level + max(steps, 0))
	return module_level > previous_level

func get_module_display_name() -> String:
	if display_name != "":
		return display_name
	var item_name: Variant = get("ITEM_NAME")
	if item_name != null and str(item_name) != "":
		return str(item_name)
	return name

func get_stable_module_id() -> StringName:
	if module_id != StringName():
		return module_id
	if scene_file_path != "":
		return StringName(scene_file_path.get_file().get_basename())
	return StringName(name.to_snake_case())

func get_rarity() -> String:
	return RARITY_UTIL.normalize(rarity)

func get_drop_weight() -> float:
	return RARITY_UTIL.sanitize_weight(drop_weight, get_rarity())

func get_effective_multiplier(base_multiplier: float, per_level_bonus: float = 0.35) -> float:
	var level_scale := 1.0 + per_level_bonus * float(max(0, module_level - 1))
	if base_multiplier >= 1.0:
		return 1.0 + (base_multiplier - 1.0) * level_scale
	return maxf(0.05, 1.0 - (1.0 - base_multiplier) * level_scale)

func get_effective_additive(base_value: float, per_level_bonus: float = 0.5) -> float:
	var level_scale := 1.0 + per_level_bonus * float(max(0, module_level - 1))
	return base_value * level_scale

func configure_stat_modifiers() -> void:
	pass

func apply_stat_modifiers(stat_block: Dictionary) -> Dictionary:
	if stat_block == null:
		return {}
	configure_stat_modifiers()
	var output: Dictionary = stat_block.duplicate(true)
	for key_variant in stat_additives.keys():
		var key := str(key_variant)
		if not output.has(key):
			continue
		var base_add := float(stat_additives[key_variant])
		var final_add := get_effective_additive(base_add)
		output[key] = float(output[key]) + final_add
	for key_variant in stat_multipliers.keys():
		var key := str(key_variant)
		if not output.has(key):
			continue
		var base_multiplier := float(stat_multipliers[key_variant])
		var final_multiplier := get_effective_multiplier(base_multiplier)
		output[key] = float(output[key]) * final_multiplier
	return output

func get_effect_descriptions() -> PackedStringArray:
	configure_stat_modifiers()
	var descriptions: PackedStringArray = []
	var level_effect := get_level_effect_description()
	if level_effect != "":
		descriptions.append(level_effect)
	else:
		# Curated level copy is the semantic description of these stat modifiers.
		# Only synthesize implementation-level stat lines when no curated copy exists.
		for key_variant in stat_multipliers.keys():
			var key := str(key_variant)
			var raw_multiplier: float = float(stat_multipliers[key_variant])
			var final_multiplier: float = get_effective_multiplier(raw_multiplier)
			var delta_percent := (final_multiplier - 1.0) * 100.0
			var value_sign := "+" if delta_percent >= 0.0 else ""
			descriptions.append("%s %s%.0f%%" % [_format_stat_label(key), value_sign, delta_percent])
		for key_variant in stat_additives.keys():
			var key := str(key_variant)
			var raw_add: float = float(stat_additives[key_variant])
			var final_add: float = get_effective_additive(raw_add)
			var value_sign := "+" if final_add >= 0.0 else ""
			descriptions.append("%s %s%.1f" % [_format_stat_label(key), value_sign, final_add])
	_append_build_readability_descriptions(descriptions)
	return descriptions

func get_level_effect_description(level: int = module_level) -> String:
	var index := clampi(level, 1, MAX_LEVEL) - 1
	if index >= level_effects.size():
		return ""
	var fallback := str(level_effects[index]).strip_edges()
	return LocalizationManager.get_module_effect_description(self, level, fallback)

func with_level_effect_descriptions(descriptions: PackedStringArray) -> PackedStringArray:
	var output := PackedStringArray()
	var level_effect := get_level_effect_description()
	if level_effect != "":
		output.append(level_effect)
	output.append_array(descriptions)
	_append_build_readability_descriptions(output)
	return output

func _format_stat_label(stat_key: String) -> String:
	var pretty := stat_key.replace("_", " ")
	return LocalizationManager.get_module_term(StringName("stat.%s" % stat_key), pretty.capitalize())

func _append_build_readability_descriptions(descriptions: PackedStringArray) -> void:
	var tag_labels := _format_build_tags()
	if not tag_labels.is_empty():
		descriptions.append(LocalizationManager.tr_format(
			"ui.module.build_tags",
			{"tags": " / ".join(tag_labels)},
			"Build Tags: %s" % " / ".join(tag_labels)
		))
	var fit_labels := _format_install_targets()
	if not fit_labels.is_empty():
		descriptions.append(LocalizationManager.tr_format(
			"ui.module.best_on",
			{"targets": " / ".join(fit_labels)},
			"Best On: %s" % " / ".join(fit_labels)
		))
	var hook_labels := _format_required_hooks()
	if not hook_labels.is_empty():
		descriptions.append(LocalizationManager.tr_format(
			"ui.module.triggers",
			{"hooks": " / ".join(hook_labels)},
			"Triggers: %s" % " / ".join(hook_labels)
		))

func _format_build_tags() -> PackedStringArray:
	var labels := PackedStringArray()
	for tag in get_build_tags():
		var label := _format_taxonomy_label(tag)
		if label != "" and not labels.has(label):
			labels.append(label)
	var has_generic_buff_text := not level_effects.is_empty()
	has_generic_buff_text = has_generic_buff_text or not stat_multipliers.is_empty()
	has_generic_buff_text = has_generic_buff_text or not stat_additives.is_empty()
	if labels.is_empty() and has_generic_buff_text:
		labels.append(LocalizationManager.get_module_term(&"buff", "Buff"))
	return labels

func _format_install_targets() -> PackedStringArray:
	var labels := PackedStringArray()
	for required_trait in get_normalized_required_weapon_traits():
		var trait_label := _format_taxonomy_label(required_trait)
		if trait_label != "" and not labels.has(trait_label):
			labels.append(trait_label)
	for required_delivery in get_normalized_required_delivery_types():
		var delivery_label := _format_taxonomy_label(required_delivery)
		if delivery_label != "" and not labels.has(delivery_label):
			labels.append(delivery_label)
	for required_capability in get_normalized_required_weapon_capabilities():
		var capability_label := _format_taxonomy_label(required_capability)
		if capability_label != "" and not labels.has(capability_label):
			labels.append(capability_label)
	return labels

func _format_required_hooks() -> PackedStringArray:
	var labels := PackedStringArray()
	for hook in get_normalized_required_hooks():
		var label := _format_hook_label(hook)
		if label != "" and not labels.has(label):
			labels.append(label)
	return labels

func _format_hook_label(hook: StringName) -> String:
	match hook:
		ModuleHook.PROJECTILE_SPAWN:
			return LocalizationManager.get_module_term(&"hook.projectile_spawn", "Projectile spawn")
		ModuleHook.HIT:
			return LocalizationManager.get_module_term(&"hook.hit", "Weapon hit")
		ModuleHook.DAMAGE_DEALT:
			return LocalizationManager.get_module_term(&"hook.damage_dealt", "Damage dealt")
		ModuleHook.AREA_DAMAGE:
			return LocalizationManager.get_module_term(&"hook.area_damage", "Area damage")
		ModuleHook.BEAM_HIT:
			return LocalizationManager.get_module_term(&"hook.beam_hit", "Beam hit")
		ModuleHook.RELOAD_START:
			return LocalizationManager.get_module_term(&"hook.reload_start", "Reload start")
		ModuleHook.RELOAD_DURATION:
			return LocalizationManager.get_module_term(&"hook.reload_duration", "Reload duration")
		ModuleHook.KILL:
			return LocalizationManager.get_module_term(&"hook.kill", "Kill")
		ModuleHook.SKILL_CAST:
			return LocalizationManager.get_module_term(&"hook.skill_cast", "Skill cast")
		ModuleHook.SKILL_FINISH:
			return LocalizationManager.get_module_term(&"hook.skill_finish", "Skill finish")
		_:
			return _format_taxonomy_label(hook)

func _format_taxonomy_label(value: StringName) -> String:
	var key := StringName(str(value))
	var fallback := ""
	match key:
		"heat":
			fallback = "Heat"
		"mark":
			fallback = "Mark"
		"freeze":
			fallback = "Freeze"
		"reload":
			fallback = "Reload"
		"close":
			fallback = "Close"
		"area":
			fallback = "Area"
		"beam":
			fallback = "Beam"
		"projectile":
			fallback = "Projectile"
		"melee_contact":
			fallback = "Melee"
		"on_hit":
			fallback = "On Hit"
		"execute":
			fallback = "Execute"
		"defense":
			fallback = "Defense"
		"economy":
			fallback = "Economy"
		"physical":
			fallback = "Physical"
		"energy":
			fallback = "Energy"
		"fire":
			fallback = "Fire"
		"charge":
			fallback = "Charge"
		"summon":
			fallback = "Summon"
		"trap":
			fallback = "Trap"
		"support":
			fallback = "Support"
		"movement":
			fallback = "Movement"
		"buff":
			fallback = "Buff"
		"debuff":
			fallback = "Debuff"
		"dot":
			fallback = "DoT"
		"duration":
			fallback = "Duration"
		"stacking":
			fallback = "Stacking"
		"trigger":
			fallback = "Trigger"
		_:
			var pretty := str(value).replace("_", " ")
			fallback = pretty.capitalize()
	return LocalizationManager.get_module_term(key, fallback)
