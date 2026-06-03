extends Node2D
class_name Weapon

@onready var modules: WeaponModules = $Modules
const HEAT_SCRIPT := preload("res://Player/Weapons/Heat/heat.gd")
var MAX_MODULE_NUMBER = 3
@onready var sprite: Sprite2D = $Sprite
@onready var fuse_sprite_holder: FuseSpriteHolder = get_node_or_null("FuseSprites")
@onready var _fuse_sprites_initialized = _load_fuse_sprites()
var on_hit_plugins: Array[Node] = []
var projectile_spawn_plugins: Array[Node] = []
var reload_duration_plugins: Array[Node] = []
var _passive_icd_msec: Dictionary = {}
var _external_damage_mul_modifiers: Dictionary = {}
const PASSIVE_SCOPE_BODY: StringName = &"body"
const PASSIVE_SCOPE_GLOBAL: StringName = &"global"

# Common variables for weapons
var level : int
var FINAL_MAX_FUSE : int = 3
var FINAL_MAX_LEVEL : int = 7
var max_level : int = FINAL_MAX_LEVEL
var _fuse_internal : int = 1
var fuse_sprites: Dictionary = {}
var branch_ids: Array[String] = []
var branch_definitions: Array[WeaponBranchDefinition] = []
var branch_behaviors: Array[WeaponBranchBehavior] = []
var branch_id: String = ""
var branch_definition: WeaponBranchDefinition
var branch_behavior: WeaponBranchBehavior
var _runtime_trait_overrides: Array[StringName] = []
var _last_stat_snapshot: Dictionary = {}
var _overheat_fire_bypass_sources: Array[Node] = []
var heat_core: Heat
var heat_per_shot: float = 1.0
var heat_max_value: float = 100.0
var heat_cool_rate: float = 20.0
@export_enum("main", "offhand") var weapon_role: String = "offhand"
@export var weapon_active_cooldown_sec: float = 8.0
@export_enum("none", "energy", "heat") var weapon_active_resource_type: String = "energy"
@export var weapon_active_resource_cost: float = 20.0
@export var weapon_active_hit_window_required_hits: int = 0
@export var weapon_active_hit_window_timeout_sec: float = 6.0
@export var weapon_active_hit_window_bonus_multiplier: float = 1.35
@export var magazine_capacity: int = 50
@export var reload_duration_sec: float = 6.0
var _weapon_active_cd_remaining: float = 0.0
var _weapon_active_hit_window_hits: int = 0
var _weapon_active_hit_window_expires_at_msec: int = 0
var _offhand_skill_ready: bool = true
var current_ammo: int = 0
var is_reloading: bool = false
var reload_time_left: float = 0.0
var fuse : int:
	get:
		return _fuse_internal
	set(value):
		_fuse_internal = clampi(value, 1, FINAL_MAX_FUSE)
		_apply_fuse_sprite()

signal weapon_role_changed(next_role: String)
signal weapon_active_status_changed(cooldown_remaining: float, ready: bool)
signal weapon_active_triggered(success: bool, reason: String)
signal passive_triggered(event_name: StringName, detail: Dictionary)
signal weapon_reload_completed(weapon: Weapon)
signal offhand_refreshed_by_reload(weapon: Weapon)

func set_level(lv):
	pass

func get_weapon_level_key(requested_level: Variant, data: Dictionary = {}) -> String:
	var source := data
	if source.is_empty():
		var weapon_data_variant: Variant = get("weapon_data")
		if weapon_data_variant is Dictionary:
			source = weapon_data_variant as Dictionary
	if source.is_empty():
		return str(maxi(int(requested_level), 1))
	var key := str(requested_level)
	if source.has(key):
		return key
	var fallback_key := str(clampi(int(requested_level), 1, source.size()))
	if source.has(fallback_key):
		return fallback_key
	if source.has("1"):
		return "1"
	var keys := source.keys()
	keys.sort()
	return str(keys[0])

func get_weapon_level_data(requested_level: Variant, data: Dictionary = {}) -> Dictionary:
	var source := data
	if source.is_empty():
		var weapon_data_variant: Variant = get("weapon_data")
		if weapon_data_variant is Dictionary:
			source = weapon_data_variant as Dictionary
	if source.is_empty():
		return {}
	var key := get_weapon_level_key(requested_level, source)
	var level_data: Variant = source.get(key, {})
	if level_data is Dictionary:
		return level_data as Dictionary
	return {}

func calculate_status() -> void:
	# Recompute derived runtime stats after module changes.
	refresh_max_level_from_data()
	if has_method("sync_stats"):
		call("sync_stats")
	validate_module_compatibility()
	_sync_heat_trait_state()
	_notify_shared_heat_pool_dirty()



func set_max_level(ml : int) -> void:
	max_level = maxi(int(ml), 1)

func get_max_level_for_fuse(_fuse_level: int) -> int:
	return get_weapon_max_level()

func get_weapon_max_level() -> int:
	var data_max := _get_weapon_data_max_level()
	if data_max > 0:
		return data_max
	return maxi(int(max_level), 1)

func refresh_max_level_from_data() -> void:
	max_level = get_weapon_max_level()

func _get_weapon_data_max_level() -> int:
	var weapon_data_variant: Variant = get("weapon_data")
	if not (weapon_data_variant is Dictionary):
		return maxi(int(FINAL_MAX_LEVEL), 1)
	var data := weapon_data_variant as Dictionary
	var best := 0
	for key_variant in data.keys():
		var key_text := str(key_variant)
		if not key_text.is_valid_int():
			continue
		best = maxi(best, int(key_text))
	return best

func _apply_fuse_sprite() -> void:
	if not sprite:
		return
	var tex: Texture2D = fuse_sprites.get(fuse, fuse_sprites.get(1))
	if tex:
		sprite.texture = tex
		var blade_sprite_node := get_node_or_null("BladeAnchor/BladeSprite")
		if blade_sprite_node is Sprite2D:
			(blade_sprite_node as Sprite2D).texture = tex

func _load_fuse_sprites() -> bool:
	fuse_sprites.clear()
	if fuse_sprite_holder:
		var overrides := fuse_sprite_holder.get_fuse_textures()
		for fuse_level in overrides.keys():
			var tex: Texture2D = overrides[fuse_level]
			if tex:
				fuse_sprites[fuse_level] = tex
	if fuse_sprites.is_empty() and sprite and sprite.texture:
		fuse_sprites[1] = sprite.texture
	_apply_fuse_sprite()
	return true

func register_on_hit_plugin(plugin: Node) -> void:
	if plugin and not on_hit_plugins.has(plugin):
		on_hit_plugins.append(plugin)

func unregister_on_hit_plugin(plugin: Node) -> void:
	on_hit_plugins.erase(plugin)

func register_projectile_spawn_plugin(plugin: Node) -> void:
	if plugin and not projectile_spawn_plugins.has(plugin):
		projectile_spawn_plugins.append(plugin)

func unregister_projectile_spawn_plugin(plugin: Node) -> void:
	projectile_spawn_plugins.erase(plugin)

func notify_projectile_spawned(projectile: Node2D) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	for i in range(projectile_spawn_plugins.size() - 1, -1, -1):
		var plugin := projectile_spawn_plugins[i]
		if plugin == null or not is_instance_valid(plugin):
			projectile_spawn_plugins.remove_at(i)
			continue
		if plugin.has_method("on_projectile_spawned"):
			plugin.call("on_projectile_spawned", self, projectile)

func register_reload_duration_plugin(plugin: Node) -> void:
	if plugin and not reload_duration_plugins.has(plugin):
		reload_duration_plugins.append(plugin)

func unregister_reload_duration_plugin(plugin: Node) -> void:
	reload_duration_plugins.erase(plugin)

func on_hit_target(target: Node) -> void:
	_handle_hit_target(target)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	_handle_hit_target(target, Attack.normalize_damage_type(damage_type))

func _handle_hit_target(target: Node, damage_type: StringName = StringName()) -> void:
	for plugin in on_hit_plugins:
		if is_instance_valid(plugin) and plugin.has_method("apply_on_hit"):
			plugin.apply_on_hit(self, target)
	_register_weapon_active_hit_window()
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("_broadcast_weapon_passive_event"):
		var detail := {
			"source_weapon": self,
			"target": target,
			"source_is_main": is_main_weapon()
		}
		if damage_type != StringName():
			detail["damage_type"] = damage_type
		PlayerData.player.call("_broadcast_weapon_passive_event", &"on_hit", detail)

func notify_main_weapon_fired() -> void:
	if not is_main_weapon():
		return
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("_broadcast_weapon_passive_event"):
		PlayerData.player.call("_broadcast_weapon_passive_event", &"on_main_weapon_fired", {
			"source_weapon": self,
			"_suppress_default_emit": true,
		})

func supports_projectiles() -> bool:
	return false

func supports_melee_contact() -> bool:
	return false

func _ready() -> void:
	refresh_max_level_from_data()
	_initialize_ammo_system()
	_migrate_legacy_branch_state()
	_apply_branch_behaviors_if_needed()
	_sync_heat_trait_state()
	_notify_shared_heat_pool_dirty()
	call_deferred("validate_module_compatibility")

func _physics_process(delta: float) -> void:
	_update_reload_state(delta)
	_update_heat_system(delta)
	_update_weapon_active_cooldown(delta)
	_update_weapon_active_hit_window()
	_process_weapon_role_effects(delta)

func _process_weapon_role_effects(delta: float) -> void:
	if is_main_weapon():
		_process_main_weapon_effect(delta)
		return
	_process_offhand_weapon_effect(delta)

func _process_main_weapon_effect(_delta: float) -> void:
	pass

func _process_offhand_weapon_effect(_delta: float) -> void:
	pass

func set_branch(new_branch_id: String) -> bool:
	return add_branch(new_branch_id)

func add_branch(new_branch_id: String) -> bool:
	var normalized_id := str(new_branch_id)
	if normalized_id == "":
		return false
	if has_branch(normalized_id):
		return false
	var scene_path := scene_file_path
	var branch_def: WeaponBranchDefinition = DataHandler.read_weapon_branch_definition(scene_path, normalized_id)
	if branch_def == null:
		return false
	if fuse < int(branch_def.unlock_fuse):
		return false
	if not is_branch_compatible_with_existing(branch_def):
		return false
	branch_ids.append(normalized_id)
	branch_definitions.append(branch_def)
	_apply_branch_behavior_for_definition(branch_def, normalized_id)
	_sync_legacy_branch_refs()
	if has_method("set_level") and level > 0:
		set_level(clampi(level, 1, max_level))
	return true

func restore_branch_ids(saved_branch_ids: Array) -> void:
	_clear_branch_behaviors()
	branch_ids.clear()
	branch_definitions.clear()
	branch_id = ""
	branch_definition = null
	for branch_id_variant in saved_branch_ids:
		if branch_ids.size() >= 2:
			push_warning("Skipping extra saved branch '%s' on weapon '%s'." % [str(branch_id_variant), name])
			continue
		var saved_branch_id := str(branch_id_variant).strip_edges()
		if saved_branch_id == "":
			continue
		var def := DataHandler.read_weapon_branch_definition(scene_file_path, saved_branch_id)
		if def == null:
			push_warning("Skipping missing saved branch '%s' on weapon '%s'." % [saved_branch_id, name])
			continue
		if int(fuse) < int(def.unlock_fuse):
			push_warning("Skipping saved branch '%s' because fuse %d is below unlock fuse %d." % [saved_branch_id, int(fuse), int(def.unlock_fuse)])
			continue
		if not is_branch_compatible_with_existing(def):
			push_warning("Skipping incompatible saved branch '%s' on weapon '%s'." % [saved_branch_id, name])
			continue
		branch_ids.append(saved_branch_id)
		branch_definitions.append(def)
		_apply_branch_behavior_for_definition(def, saved_branch_id)
	_sync_legacy_branch_refs()
	if has_method("set_level") and level > 0:
		set_level(clampi(level, 1, max_level))
	else:
		calculate_status()

func has_branch(check_branch_id: String) -> bool:
	var normalized_id := str(check_branch_id)
	if normalized_id == "":
		return false
	for existing_id in branch_ids:
		if str(existing_id) == normalized_id:
			return true
	return false

func get_branch_options() -> Array[WeaponBranchDefinition]:
	return get_available_branch_options()

func get_available_branch_options() -> Array[WeaponBranchDefinition]:
	return get_available_branch_options_for_fuse(fuse)

func get_available_branch_options_for_fuse(target_fuse: int) -> Array[WeaponBranchDefinition]:
	_migrate_legacy_branch_state()
	if not _can_choose_more_branches():
		return []
	var output: Array[WeaponBranchDefinition] = []
	var options := DataHandler.read_weapon_branch_options(scene_file_path, target_fuse)
	for def in options:
		if def == null:
			continue
		if has_branch(def.branch_id):
			continue
		if not is_branch_compatible_with_existing(def):
			continue
		output.append(def)
	return output

func is_branch_compatible_with_existing(candidate_def: WeaponBranchDefinition) -> bool:
	return get_branch_incompatibility_reason(candidate_def) == ""

func get_branch_incompatibility_reason(candidate_def: WeaponBranchDefinition) -> String:
	if candidate_def == null:
		return "invalid"
	var candidate_id := str(candidate_def.branch_id)
	if candidate_id == "":
		return "invalid"
	if has_branch(candidate_id):
		return "duplicate"
	for i in range(branch_ids.size()):
		var existing_id := str(branch_ids[i])
		if existing_id == "":
			continue
		var existing_def := _get_branch_definition_for_index(i, existing_id)
		if existing_def == null:
			continue
		if _branch_lists_id(candidate_def.incompatible_branch_ids, existing_id):
			return "incompatible"
		if _branch_lists_id(existing_def.incompatible_branch_ids, candidate_id):
			return "incompatible"
		if _branch_groups_overlap(candidate_def.exclusive_groups, existing_def.exclusive_groups):
			return "exclusive_group"
	return ""

func get_branch_behaviors() -> Array[WeaponBranchBehavior]:
	var output: Array[WeaponBranchBehavior] = []
	for behavior in branch_behaviors:
		if behavior and is_instance_valid(behavior):
			output.append(behavior)
	return output

func notify_branch_level_applied(applied_level: int) -> void:
	for behavior in get_branch_behaviors():
		behavior.on_level_applied(applied_level)

func notify_branch_weapon_shot(base_direction: Vector2) -> void:
	for behavior in get_branch_behaviors():
		behavior.on_weapon_shot(base_direction)

func notify_branch_target_hit(target: Node) -> void:
	for behavior in get_branch_behaviors():
		behavior.on_target_hit(target)

func notify_branch_passive_event(event_name: StringName, detail: Dictionary) -> void:
	for behavior in get_branch_behaviors():
		behavior.on_passive_event(event_name, detail)

func get_branch_shot_directions(base_direction: Vector2, shot_count: int = -1) -> Array[Vector2]:
	var directions: Array[Vector2] = [base_direction]
	for behavior in get_branch_behaviors():
		var next_directions: Array[Vector2] = []
		for direction in directions:
			var branch_dirs := behavior.get_shot_directions(direction, shot_count)
			if branch_dirs.is_empty():
				next_directions.append(direction)
			else:
				next_directions.append_array(branch_dirs)
		directions = next_directions
	return directions

func get_branch_cooldown_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_cooldown_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_projectile_damage_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_projectile_damage_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_projectile_hit_override(current_hits: int) -> int:
	var hits: int = max(1, current_hits)
	for behavior in get_branch_behaviors():
		hits = max(1, behavior.get_projectile_hit_override(hits))
	return hits

func get_branch_damage_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_damage_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_attack_range_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_attack_range_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_dash_speed_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_dash_speed_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_return_speed_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_return_speed_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_extra_heat_shot_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= clampf(behavior.get_extra_heat_shot_multiplier(), 0.0, 1.0)
	return clampf(multiplier, 0.0, 1.0)

func get_branch_orbit_spin_speed_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_orbit_spin_speed_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_pierce_damage_gain_per_hit() -> int:
	var total := 0
	for behavior in get_branch_behaviors():
		total += max(0, behavior.get_pierce_damage_gain_per_hit())
	return total

func get_branch_max_pierce_damage_stacks() -> int:
	var max_stacks := 0
	for behavior in get_branch_behaviors():
		max_stacks = max(max_stacks, behavior.get_max_pierce_damage_stacks())
	return max_stacks

func get_branch_damage_type_override(default_type: StringName = Attack.TYPE_PHYSICAL) -> StringName:
	var resolved_type := default_type
	for behavior in get_branch_behaviors():
		var next_type := Attack.normalize_damage_type(behavior.get_damage_type_override())
		if next_type != Attack.TYPE_PHYSICAL:
			resolved_type = next_type
	return resolved_type

func apply_branch_explosion_modifiers(config: ExplosionEffectConfig) -> void:
	for behavior in get_branch_behaviors():
		behavior.modify_explosion_config(config)

func _migrate_legacy_branch_state() -> void:
	if branch_ids.is_empty() and branch_id != "":
		branch_ids.append(branch_id)
	if branch_definitions.size() > branch_ids.size():
		branch_definitions.resize(branch_ids.size())
	for i in range(branch_ids.size()):
		var existing_id := str(branch_ids[i])
		if existing_id == "":
			continue
		if i < branch_definitions.size() and branch_definitions[i] != null:
			continue
		var def := DataHandler.read_weapon_branch_definition(scene_file_path, existing_id)
		if def == null:
			continue
		while branch_definitions.size() <= i:
			branch_definitions.append(null)
		branch_definitions[i] = def
	_sync_legacy_branch_refs()

func _can_choose_more_branches() -> bool:
	return branch_ids.size() < 2

func _can_add_branch(candidate_branch_id: String) -> bool:
	var candidate_def := DataHandler.read_weapon_branch_definition(scene_file_path, candidate_branch_id)
	if candidate_def == null:
		return false
	return is_branch_compatible_with_existing(candidate_def)

func _get_branch_definition_for_index(index: int, fallback_branch_id: String) -> WeaponBranchDefinition:
	if index >= 0 and index < branch_definitions.size():
		var existing_def := branch_definitions[index]
		if existing_def != null:
			return existing_def
	return DataHandler.read_weapon_branch_definition(scene_file_path, fallback_branch_id)

func _branch_lists_id(branch_id_list: PackedStringArray, lookup_id: String) -> bool:
	var normalized_lookup := str(lookup_id)
	if normalized_lookup == "":
		return false
	for item in branch_id_list:
		if str(item) == normalized_lookup:
			return true
	return false

func _branch_groups_overlap(a: PackedStringArray, b: PackedStringArray) -> bool:
	for group_a in a:
		var normalized_group := str(group_a).strip_edges()
		if normalized_group == "":
			continue
		for group_b in b:
			if normalized_group == str(group_b).strip_edges():
				return true
	return false

func _apply_branch_behaviors_if_needed(force_refresh: bool = false) -> void:
	_migrate_legacy_branch_state()
	if force_refresh:
		_clear_branch_behaviors()
	_adopt_existing_branch_behavior_children()
	for i in range(branch_ids.size()):
		var current_id := str(branch_ids[i])
		if current_id == "":
			continue
		if _has_branch_behavior(current_id):
			continue
		var def: WeaponBranchDefinition = null
		if i < branch_definitions.size():
			def = branch_definitions[i]
		if def == null:
			def = DataHandler.read_weapon_branch_definition(scene_file_path, current_id)
			if def != null:
				while branch_definitions.size() <= i:
					branch_definitions.append(null)
				branch_definitions[i] = def
		if def == null:
			continue
		_apply_branch_behavior_for_definition(def, current_id)
	_sync_legacy_branch_refs()

func _apply_branch_behavior_if_needed(force_refresh: bool = false) -> void:
	_apply_branch_behaviors_if_needed(force_refresh)

func _apply_branch_behavior_for_definition(def: WeaponBranchDefinition, id: String) -> void:
	if def == null or def.behavior_scene == null:
		return
	var behavior_instance := def.behavior_scene.instantiate() as WeaponBranchBehavior
	if behavior_instance == null:
		push_warning("Weapon branch '%s' behavior is not WeaponBranchBehavior on weapon '%s'." % [id, name])
		return
	behavior_instance.name = "Branch_%s" % id
	behavior_instance.set_meta("branch_id", id)
	branch_behaviors.append(behavior_instance)
	add_child(behavior_instance)
	behavior_instance.setup(self)
	behavior_instance.on_weapon_ready()
	_sync_legacy_branch_refs()

func _has_branch_behavior(id: String) -> bool:
	for behavior in branch_behaviors:
		if behavior and is_instance_valid(behavior) and str(behavior.get_meta("branch_id", "")) == id:
			return true
	return false

func _adopt_existing_branch_behavior_children() -> void:
	for child in get_children():
		var existing := child as WeaponBranchBehavior
		if existing == null or branch_behaviors.has(existing):
			continue
		var existing_id := str(existing.get_meta("branch_id", ""))
		if existing_id == "" and branch_ids.size() == 1:
			existing_id = branch_ids[0]
			existing.set_meta("branch_id", existing_id)
		if existing_id == "" or not branch_ids.has(existing_id):
			continue
		existing.setup(self)
		branch_behaviors.append(existing)

func _sync_legacy_branch_refs() -> void:
	branch_id = branch_ids[0] if not branch_ids.is_empty() else ""
	branch_definition = branch_definitions[0] if not branch_definitions.is_empty() else null
	branch_behavior = null
	for behavior in branch_behaviors:
		if behavior and is_instance_valid(behavior):
			branch_behavior = behavior
			break

func _clear_branch_behaviors() -> void:
	for behavior in branch_behaviors:
		if behavior and is_instance_valid(behavior):
			behavior.on_removed()
			behavior.queue_free()
	branch_behaviors.clear()
	_sync_legacy_branch_refs()

func _clear_branch_behavior() -> void:
	_clear_branch_behaviors()

func get_normalized_weapon_traits() -> Array[StringName]:
	var traits: Array[StringName] = []
	var modules_node := _get_modules_container()
	if modules_node and modules_node.has_method("get_normalized_weapon_traits"):
		traits = modules_node.get_normalized_weapon_traits()
	for runtime_trait in _runtime_trait_overrides:
		if not traits.has(runtime_trait):
			traits.append(runtime_trait)
	if supports_projectiles() and not traits.has(CombatTrait.PROJECTILE):
		traits.append(CombatTrait.PROJECTILE)
	if supports_melee_contact() and not traits.has(CombatTrait.MELEE):
		traits.append(CombatTrait.MELEE)
	return traits

func has_heat_trait() -> bool:
	return has_weapon_trait(CombatTrait.HEAT)

func has_heat_system() -> bool:
	if not has_heat_trait():
		return false
	var shared_pool := _get_shared_heat_pool()
	if shared_pool != null:
		return true
	return heat_core != null

func can_fire_with_heat() -> bool:
	var core := _get_active_heat_core()
	if core == null:
		return true
	if bool(core.overheated) and _has_overheat_fire_bypass():
		return true
	return core.can_fire()

func uses_ammo_system() -> bool:
	return false

func can_fire_with_ammo() -> bool:
	if not uses_ammo_system():
		return true
	if is_reloading:
		return false
	return current_ammo > 0

func apply_level_ammo(level_data: Dictionary) -> void:
	if level_data == null:
		return
	if not level_data.has("ammo"):
		return
	var next_mag := maxi(0, int(level_data.get("ammo", magazine_capacity)))
	if next_mag <= 0:
		return
	magazine_capacity = next_mag
	if uses_ammo_system():
		current_ammo = magazine_capacity
		is_reloading = false
		reload_time_left = 0.0

func consume_ammo(amount: int = 1) -> bool:
	if not uses_ammo_system():
		return true
	var consume_amount := maxi(amount, 0)
	if consume_amount <= 0:
		return true
	if current_ammo < consume_amount:
		return false
	current_ammo -= consume_amount
	return true

func request_reload() -> bool:
	if not uses_ammo_system():
		return false
	if is_reloading:
		return false
	var ammo_before := current_ammo
	var reload_duration := _get_effective_reload_duration()
	var spent_ratio := _get_spent_magazine_ratio()
	is_reloading = true
	reload_time_left = reload_duration
	dispatch_passive_event(&"on_reload_started", {
		"source_weapon": self,
		"ammo_before": ammo_before,
		"ammo_after": current_ammo,
		"magazine_capacity": max(0, magazine_capacity),
		"spent_ratio": spent_ratio,
		"reload_duration": reload_duration,
	})
	if reload_time_left <= 0.0:
		_finish_reload()
	return true

func _update_reload_state(delta: float) -> void:
	if not uses_ammo_system():
		return
	if not is_reloading:
		return
	reload_time_left = maxf(0.0, reload_time_left - maxf(delta, 0.0))
	if reload_time_left <= 0.0:
		_finish_reload()

func _finish_reload() -> void:
	if not uses_ammo_system():
		return
	var ammo_before := current_ammo
	var spent_ratio := _get_spent_magazine_ratio()
	current_ammo = max(0, magazine_capacity)
	is_reloading = false
	reload_time_left = 0.0
	_refresh_offhand_skill_on_reload()
	dispatch_passive_event(&"on_reload_finished", {
		"source_weapon": self,
		"ammo_before": ammo_before,
		"ammo_after": current_ammo,
		"magazine_capacity": max(0, magazine_capacity),
		"spent_ratio": spent_ratio,
	})
	weapon_reload_completed.emit(self)

func refill_ammo_instantly() -> void:
	if not uses_ammo_system():
		return
	current_ammo = max(0, magazine_capacity)
	is_reloading = false
	reload_time_left = 0.0

func get_ammo_status() -> Dictionary:
	return {
		"enabled": uses_ammo_system(),
		"current": current_ammo,
		"max": max(0, magazine_capacity),
		"is_reloading": is_reloading,
		"reload_left": reload_time_left,
	}

func _initialize_ammo_system() -> void:
	if not uses_ammo_system():
		current_ammo = 0
		is_reloading = false
		reload_time_left = 0.0
		return
	magazine_capacity = max(0, magazine_capacity)
	current_ammo = magazine_capacity
	is_reloading = false
	reload_time_left = 0.0

func register_overheat_fire_bypass(source: Node) -> void:
	if source == null:
		return
	if not _overheat_fire_bypass_sources.has(source):
		_overheat_fire_bypass_sources.append(source)

func unregister_overheat_fire_bypass(source: Node) -> void:
	_overheat_fire_bypass_sources.erase(source)

func _has_overheat_fire_bypass() -> bool:
	for i in range(_overheat_fire_bypass_sources.size() - 1, -1, -1):
		var source := _overheat_fire_bypass_sources[i]
		if source == null or not is_instance_valid(source):
			_overheat_fire_bypass_sources.remove_at(i)
	if _overheat_fire_bypass_sources.is_empty():
		return false
	for source in _overheat_fire_bypass_sources:
		if source and is_instance_valid(source):
			return true
	return false

func configure_heat(per_shot: float, max_value: float, cool_rate: float) -> void:
	heat_per_shot = maxf(per_shot, 0.0)
	heat_max_value = maxf(max_value, 1.0)
	heat_cool_rate = maxf(cool_rate, 0.0)
	_sync_heat_trait_state()
	if heat_core != null:
		heat_core.configure(heat_per_shot, heat_max_value, heat_cool_rate)
	_notify_shared_heat_pool_dirty()

func register_shot_heat(multiplier: float = 1.0) -> void:
	if not has_heat_trait():
		return
	var core := _get_active_heat_core()
	if core == null:
		return
	if core.has_method("add_heat_amount"):
		core.call("add_heat_amount", maxf(0.0, heat_per_shot * maxf(multiplier, 0.0)))
		return
	core.add_heat(multiplier)

func get_heat_ratio() -> float:
	var core := _get_active_heat_core()
	if core == null:
		return 0.0
	return core.get_ratio()

func get_heat_value() -> float:
	var core := _get_active_heat_core()
	if core == null:
		return 0.0
	return float(core.heat_value)

func get_heat_max_value() -> float:
	var core := _get_active_heat_core()
	if core == null:
		return 0.0
	if core.has_method("has_contributors") and not bool(core.call("has_contributors")):
		return 0.0
	return float(core.max_heat)

func get_heat_percent() -> int:
	var core := _get_active_heat_core()
	if core == null:
		return 0
	return core.get_percent()

func is_weapon_overheated() -> bool:
	var core := _get_active_heat_core()
	if core == null:
		return false
	return bool(core.overheated)

func lock_heat_value(value: float, duration_sec: float) -> void:
	var core := _get_active_heat_core()
	if core == null:
		return
	core.lock_to_value(value, duration_sec)

func get_explicit_weapon_traits() -> Array[StringName]:
	var modules_node := _get_modules_container()
	var traits: Array[StringName] = []
	if modules_node and modules_node.has_method("get_normalized_weapon_traits"):
		traits = modules_node.get_normalized_weapon_traits()
	for runtime_trait in _runtime_trait_overrides:
		if not traits.has(runtime_trait):
			traits.append(runtime_trait)
	return traits

func add_runtime_weapon_trait(trait_name: Variant) -> void:
	var normalized := CombatTrait.normalize(trait_name)
	if normalized == StringName():
		return
	if _runtime_trait_overrides.has(normalized):
		return
	_runtime_trait_overrides.append(normalized)
	calculate_status()

func remove_runtime_weapon_trait(trait_name: Variant) -> void:
	var normalized := CombatTrait.normalize(trait_name)
	if normalized == StringName():
		return
	if not _runtime_trait_overrides.has(normalized):
		return
	_runtime_trait_overrides.erase(normalized)
	calculate_status()

func clear_runtime_weapon_traits() -> void:
	if _runtime_trait_overrides.is_empty():
		return
	_runtime_trait_overrides.clear()
	calculate_status()

func _get_modules_container() -> WeaponModules:
	if modules != null and is_instance_valid(modules):
		return modules
	var resolved := get_node_or_null("Modules")
	if resolved is WeaponModules:
		modules = resolved as WeaponModules
		return modules
	return null

func has_weapon_trait(trait_name: Variant) -> bool:
	var normalized := CombatTrait.normalize(trait_name)
	if normalized == StringName():
		return false
	return get_normalized_weapon_traits().has(normalized)

func has_any_weapon_traits(required_traits: Array[StringName]) -> bool:
	if required_traits.is_empty():
		return true
	var traits := get_normalized_weapon_traits()
	for required_trait in required_traits:
		if traits.has(required_trait):
			return true
	return false

func has_any_explicit_weapon_traits(required_traits: Array[StringName]) -> bool:
	if required_traits.is_empty():
		return true
	var traits := get_explicit_weapon_traits()
	for required_trait in required_traits:
		if traits.has(required_trait):
			return true
	return false

func validate_module_compatibility() -> void:
	if modules == null:
		return
	for child in modules.get_children():
		var module_node := child as Module
		if module_node == null:
			continue
		module_node.weapon = self
		if module_node.can_apply_to_weapon(self):
			continue
		push_warning(
			"Module '%s' is incompatible with weapon '%s'; removing module." %
			[module_node.name, name]
		)
		module_node.call_deferred("queue_free")

func get_module_count() -> int:
	if modules == null:
		return 0
	var count := 0
	for child in modules.get_children():
		if child is Module:
			count += 1
	return count

func get_available_module_slots() -> int:
	return max(0, int(MAX_MODULE_NUMBER) - get_module_count())

func get_equipped_modules() -> Array[Module]:
	var output: Array[Module] = []
	if modules == null:
		return output
	for child in modules.get_children():
		var module_node := child as Module
		if module_node:
			output.append(module_node)
	return output

func build_stat_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	var tracked_stats: PackedStringArray = [
		"damage",
		"attack_cooldown",
		"projectile_hits",
		"speed",
		"size",
		"hp",
		"dash_speed",
		"return_speed",
		"attack_range",
		"heat_per_shot",
		"heat_max_value",
		"heat_cool_rate",
	]
	for stat_key in tracked_stats:
		if get(stat_key) != null:
			snapshot[stat_key] = float(get(stat_key))
	return snapshot

func get_last_stat_snapshot() -> Dictionary:
	return _last_stat_snapshot.duplicate(true)

func get_runtime_stat_value(stat_name: String, base_value: float) -> float:
	var sanitized_base := maxf(base_value, 0.0)
	var additive_total := 0.0
	var multiplier_delta_total := 0.0
	for module_node in get_equipped_modules():
		var base_eval := module_node.apply_stat_modifiers({stat_name: sanitized_base})
		var zero_eval := module_node.apply_stat_modifiers({stat_name: 0.0})
		var value_on_base := float(base_eval.get(stat_name, sanitized_base))
		var value_on_zero := float(zero_eval.get(stat_name, 0.0))
		additive_total += value_on_zero
		if sanitized_base > 0.0:
			var multiplier_component := (value_on_base - value_on_zero) / sanitized_base
			multiplier_delta_total += (multiplier_component - 1.0)
	var pre_mult_value := sanitized_base + additive_total
	var final_mult := maxf(0.0, 1.0 + multiplier_delta_total)
	return pre_mult_value * final_mult

func get_runtime_damage_value(base_damage_value: float) -> int:
	var runtime_damage := get_runtime_stat_value("damage", base_damage_value)
	runtime_damage *= get_total_external_damage_mul()
	return max(1, int(round(runtime_damage)))

func apply_external_damage_mul(source_id: StringName, mul: float) -> void:
	if source_id == StringName():
		return
	var clamped_mul := maxf(mul, 0.05)
	_external_damage_mul_modifiers[source_id] = clamped_mul
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("notify_weapon_status_change"):
		PlayerData.player.call(
			"notify_weapon_status_change",
			&"weapon_damage_up" if clamped_mul >= 1.0 else &"weapon_damage_down",
			source_id,
			true
		)

func remove_external_damage_mul(source_id: StringName) -> void:
	if _external_damage_mul_modifiers.has(source_id):
		var prev_mul := float(_external_damage_mul_modifiers.get(source_id, 1.0))
		_external_damage_mul_modifiers.erase(source_id)
		if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("notify_weapon_status_change"):
			PlayerData.player.call(
				"notify_weapon_status_change",
				&"weapon_damage_up" if prev_mul >= 1.0 else &"weapon_damage_down",
				source_id,
				false
			)

func get_total_external_damage_mul() -> float:
	var total := 1.0
	for mul in _external_damage_mul_modifiers.values():
		total *= float(mul)
	return maxf(total, 0.05)

func emit_passive_trigger(event_name: StringName, detail: Dictionary = {}, passive_scope: StringName = PASSIVE_SCOPE_BODY) -> void:
	var output := detail.duplicate(true) if detail != null else {}
	if not output.has("passive_id"):
		output["passive_id"] = str(event_name)
	if not output.has("trigger_type"):
		output["trigger_type"] = str(output.get("trigger", event_name))
	if not output.has("refresh_type"):
		output["refresh_type"] = str(output.get("refresh", ""))
	if not output.has("state_after_trigger"):
		output["state_after_trigger"] = "ready" if is_passive_ready() else "cooldown"
	if not output.has("passive_scope"):
		output["passive_scope"] = passive_scope
	passive_triggered.emit(event_name, output)

func get_projected_stats_with_module(module_instance: Module) -> Dictionary:
	var projected := build_stat_snapshot()
	if module_instance == null:
		return projected
	return module_instance.apply_stat_modifiers(projected)

func apply_module_stat_pipeline() -> void:
	_apply_dynamic_module_stats()

func _apply_dynamic_module_stats() -> void:
	if modules == null:
		_last_stat_snapshot = build_stat_snapshot()
		return
	var stats := build_stat_snapshot()
	for module_node in get_equipped_modules():
		stats = module_node.apply_stat_modifiers(stats)
	_apply_stat_snapshot(stats)
	_last_stat_snapshot = stats.duplicate(true)

func _apply_stat_snapshot(snapshot: Dictionary) -> void:
	if snapshot == null:
		return
	for stat_key in snapshot.keys():
		var stat_name := str(stat_key)
		if get(stat_name) == null:
			continue
		var current_value: Variant = get(stat_name)
		var next_value: Variant = snapshot[stat_key]
		if typeof(current_value) == TYPE_INT:
			set(stat_name, int(round(float(next_value))))
		else:
			set(stat_name, float(next_value))
	if get("cooldown_timer") != null and get("attack_cooldown") != null:
		var timer_variant: Variant = get("cooldown_timer")
		if timer_variant is Timer and float(get("attack_cooldown")) > 0.0:
			(timer_variant as Timer).wait_time = float(get("attack_cooldown"))
	if has_method("apply_size_multiplier") and get("size") != null:
		call("apply_size_multiplier", float(get("size")))
	if snapshot.has("heat_per_shot") or snapshot.has("heat_max_value") or snapshot.has("heat_cool_rate"):
		configure_heat(heat_per_shot, heat_max_value, heat_cool_rate)

func get_weapon_capabilities() -> Dictionary:
	return {
		"projectiles": supports_projectiles(),
		"melee_contact": supports_melee_contact(),
	}

func _sync_heat_trait_state() -> void:
	_notify_shared_heat_pool_dirty()
	var shared_pool := _get_shared_heat_pool()
	if shared_pool != null:
		heat_core = null
		return
	if has_heat_trait():
		if heat_core == null:
			heat_core = HEAT_SCRIPT.new() as Heat
		if heat_core != null:
			heat_core.configure(heat_per_shot, heat_max_value, heat_cool_rate)
		return
	heat_core = null

func _update_heat_system(delta: float) -> void:
	if _get_shared_heat_pool() != null:
		return
	if heat_core == null:
		return
	heat_core.cool_down(delta)

func _get_shared_heat_pool() -> Heat:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return null
	if not PlayerData.player.has_method("get_shared_heat_pool"):
		return null
	var pool: Variant = PlayerData.player.call("get_shared_heat_pool")
	if pool == null:
		return null
	return pool as Heat

func _get_active_heat_core() -> Heat:
	var shared_pool := _get_shared_heat_pool()
	if shared_pool != null:
		return shared_pool
	return heat_core

func _notify_shared_heat_pool_dirty() -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	if PlayerData.player.has_method("mark_shared_heat_pool_dirty"):
		PlayerData.player.call("mark_shared_heat_pool_dirty")

func _on_tree_exited() -> void:
	on_hit_plugins.clear()
	projectile_spawn_plugins.clear()
	reload_duration_plugins.clear()
	_overheat_fire_bypass_sources.clear()
	_passive_icd_msec.clear()
	_external_damage_mul_modifiers.clear()
	branch_behaviors.clear()
	branch_definitions.clear()
	branch_behavior = null
	branch_definition = null

func set_weapon_role(next_role: String) -> void:
	var normalized := "main" if str(next_role).to_lower() == "main" else "offhand"
	if weapon_role == normalized:
		return
	weapon_role = normalized
	_on_weapon_role_changed(weapon_role)
	if weapon_role == "main":
		_on_enter_main_weapon_role()
	else:
		_on_enter_offhand_weapon_role()
	weapon_role_changed.emit(weapon_role)

func is_main_weapon() -> bool:
	return weapon_role == "main"

func is_offhand_weapon() -> bool:
	return weapon_role != "main"

func _on_weapon_role_changed(_next_role: String) -> void:
	pass

func _on_enter_main_weapon_role() -> void:
	pass

func _on_enter_offhand_weapon_role() -> void:
	pass

func clear_timed_effects_for_prepare() -> void:
	_weapon_active_hit_window_hits = 0
	_weapon_active_hit_window_expires_at_msec = 0
	for module_node in get_equipped_modules():
		if module_node == null or not is_instance_valid(module_node):
			continue
		if module_node.has_method("clear_timed_effects_for_prepare"):
			module_node.call("clear_timed_effects_for_prepare")
	for behavior in get_branch_behaviors():
		if behavior.has_method("clear_timed_effects_for_prepare"):
			behavior.call("clear_timed_effects_for_prepare")

func can_run_active_behavior() -> bool:
	return is_main_weapon() and is_attack_phase_allowed()

func is_attack_phase_allowed() -> bool:
	if PhaseManager == null:
		return true
	if not PhaseManager.has_method("current_state"):
		return true
	return str(PhaseManager.current_state()) == str(PhaseManager.BATTLE)

func handle_primary_input(_pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	pass

func can_passive_trigger(passive_id: StringName, icd_sec: float) -> bool:
	if passive_id == StringName():
		return true
	var now_msec := Time.get_ticks_msec()
	var ready_at: int = int(_passive_icd_msec.get(passive_id, 0))
	if now_msec < ready_at:
		return false
	if icd_sec > 0.0:
		_passive_icd_msec[passive_id] = now_msec + int(icd_sec * 1000.0)
	return true

func dispatch_passive_event(event_name: StringName, detail: Dictionary = {}) -> void:
	if is_offhand_weapon():
		_on_offhand_passive_event(event_name, detail)
	else:
		_on_main_passive_event(event_name, detail)

func _on_offhand_passive_event(event_name: StringName, detail: Dictionary) -> void:
	_on_passive_event(event_name, detail)

func _on_main_passive_event(event_name: StringName, detail: Dictionary) -> void:
	_on_passive_event(event_name, detail)

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	if bool(detail.get("_suppress_default_emit", false)):
		return
	emit_passive_trigger(event_name, detail, PASSIVE_SCOPE_BODY)

func _get_spent_magazine_ratio() -> float:
	if magazine_capacity <= 0:
		return 0.0
	var spent: int = max(0, magazine_capacity - current_ammo)
	return clampf(float(spent) / float(magazine_capacity), 0.0, 1.0)

func _get_effective_reload_duration() -> float:
	var duration: float = maxf(reload_duration_sec, 0.0)
	if reload_duration_plugins.is_empty():
		return duration
	var final_multiplier: float = 1.0
	for i in range(reload_duration_plugins.size() - 1, -1, -1):
		var plugin := reload_duration_plugins[i]
		if plugin == null or not is_instance_valid(plugin):
			reload_duration_plugins.remove_at(i)
			continue
		if not plugin.has_method("get_reload_duration_multiplier"):
			continue
		final_multiplier *= maxf(float(plugin.call("get_reload_duration_multiplier", self, duration)), 0.05)
	return maxf(duration * final_multiplier, 0.0)

func request_weapon_active() -> Dictionary:
	if not is_attack_phase_allowed():
		weapon_active_triggered.emit(false, "phase")
		return {"ok": false, "reason": "phase"}
	if not is_main_weapon():
		weapon_active_triggered.emit(false, "not_main")
		return {"ok": false, "reason": "not_main"}
	if _weapon_active_cd_remaining > 0.0:
		weapon_active_triggered.emit(false, "cd")
		return {"ok": false, "reason": "cd"}
	if not _can_pay_weapon_active_resource():
		weapon_active_triggered.emit(false, "resource")
		return {"ok": false, "reason": "resource"}
	var damage_multiplier := _consume_weapon_active_hit_window_bonus()
	var executed := _execute_weapon_active(damage_multiplier)
	if not executed:
		weapon_active_triggered.emit(false, "condition")
		return {"ok": false, "reason": "condition"}
	_pay_weapon_active_resource()
	_weapon_active_cd_remaining = maxf(weapon_active_cooldown_sec, 0.0)
	weapon_active_status_changed.emit(_weapon_active_cd_remaining, _weapon_active_cd_remaining <= 0.0)
	weapon_active_triggered.emit(true, "")
	return {"ok": true, "reason": "", "damage_multiplier": damage_multiplier}

func _execute_weapon_active(_damage_multiplier: float) -> bool:
	return false

func get_weapon_active_cd_remaining() -> float:
	return maxf(_weapon_active_cd_remaining, 0.0)

func get_weapon_active_cd_ratio() -> float:
	if weapon_active_cooldown_sec <= 0.0:
		return 0.0
	return clampf(_weapon_active_cd_remaining / weapon_active_cooldown_sec, 0.0, 1.0)

func get_weapon_active_hit_window_progress() -> Dictionary:
	return {
		"hits": _weapon_active_hit_window_hits,
		"required_hits": max(0, weapon_active_hit_window_required_hits),
		"active": _weapon_active_hit_window_hits > 0 and _weapon_active_hit_window_expires_at_msec > Time.get_ticks_msec(),
	}

func get_passive_status() -> Dictionary:
	return {
		"id": "",
		"display_name": "",
		"state": "unavailable",
		"progress": 1.0 if is_passive_ready() else 0.0,
		"current": 1 if is_passive_ready() else 0,
		"required": 1,
		"ready": is_passive_ready(),
		"trigger_hint": "",
		"refresh_hint": "reload",
	}

func is_passive_ready() -> bool:
	return _offhand_skill_ready

func notify_passive_triggered(_cooldown_sec := 0.0) -> void:
	_offhand_skill_ready = false

func refresh_passive_on_reload() -> void:
	_offhand_skill_ready = true
	offhand_refreshed_by_reload.emit(self)

func notify_offhand_skill_triggered(cooldown_sec: float) -> void:
	notify_passive_triggered(cooldown_sec)

func get_offhand_skill_cd_progress() -> float:
	return 1.0 if is_passive_ready() else 0.0

func is_offhand_skill_ready() -> bool:
	return is_passive_ready()

func _refresh_offhand_skill_on_reload() -> void:
	refresh_passive_on_reload()

func force_skill_cooldowns_ready() -> void:
	_weapon_active_cd_remaining = 0.0
	_offhand_skill_ready = true
	weapon_active_status_changed.emit(0.0, true)

func _update_weapon_active_cooldown(delta: float) -> void:
	if _weapon_active_cd_remaining <= 0.0:
		return
	var previous := _weapon_active_cd_remaining
	_weapon_active_cd_remaining = maxf(0.0, _weapon_active_cd_remaining - maxf(delta, 0.0))
	if int(ceil(previous * 10.0)) != int(ceil(_weapon_active_cd_remaining * 10.0)):
		weapon_active_status_changed.emit(_weapon_active_cd_remaining, _weapon_active_cd_remaining <= 0.0)

func _register_weapon_active_hit_window() -> void:
	if weapon_active_hit_window_required_hits <= 0:
		return
	_weapon_active_hit_window_hits = mini(weapon_active_hit_window_required_hits, _weapon_active_hit_window_hits + 1)
	_weapon_active_hit_window_expires_at_msec = Time.get_ticks_msec() + int(maxf(weapon_active_hit_window_timeout_sec, 0.1) * 1000.0)

func _update_weapon_active_hit_window() -> void:
	if _weapon_active_hit_window_hits <= 0:
		return
	if Time.get_ticks_msec() < _weapon_active_hit_window_expires_at_msec:
		return
	_weapon_active_hit_window_hits = 0
	_weapon_active_hit_window_expires_at_msec = 0

func _consume_weapon_active_hit_window_bonus() -> float:
	if weapon_active_hit_window_required_hits <= 0:
		return 1.0
	var ready := _weapon_active_hit_window_hits >= weapon_active_hit_window_required_hits
	_weapon_active_hit_window_hits = 0
	_weapon_active_hit_window_expires_at_msec = 0
	if ready:
		return maxf(weapon_active_hit_window_bonus_multiplier, 1.0)
	return 1.0

func _can_pay_weapon_active_resource() -> bool:
	var normalized_type := str(weapon_active_resource_type).to_lower()
	if normalized_type == "none" or weapon_active_resource_cost <= 0.0:
		return true
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return false
	if normalized_type == "energy":
		if not PlayerData.player.has_method("get_current_energy"):
			return false
		return float(PlayerData.player.call("get_current_energy")) >= weapon_active_resource_cost
	if normalized_type == "heat":
		return get_heat_value() >= weapon_active_resource_cost
	return false

func _pay_weapon_active_resource() -> void:
	var normalized_type := str(weapon_active_resource_type).to_lower()
	if normalized_type == "none" or weapon_active_resource_cost <= 0.0:
		return
	if normalized_type == "energy":
		if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("consume_energy"):
			PlayerData.player.call("consume_energy", weapon_active_resource_cost)
		return
	if normalized_type == "heat":
		var core := _get_active_heat_core()
		if core == null:
			return
		core.heat_value = maxf(0.0, float(core.heat_value) - weapon_active_resource_cost)
		if float(core.heat_value) < float(core.max_heat):
			core.overheated = false
