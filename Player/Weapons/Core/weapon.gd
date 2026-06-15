extends Node2D
class_name Weapon

#region Runtime State
@onready var modules: WeaponModules = $Modules
var branch_runtime: WeaponBranchRuntime = WeaponBranchRuntime.new()
var heat_runtime: WeaponHeatController = WeaponHeatController.new()
var stat_pipeline: WeaponStatPipeline = WeaponStatPipeline.new()
var active_controller: WeaponActiveController = WeaponActiveController.new()
var plugin_dispatcher: WeaponPluginDispatcher = WeaponPluginDispatcher.new()
var ammo_controller: WeaponAmmoController = WeaponAmmoController.new()
var passive_controller: WeaponPassiveController = WeaponPassiveController.new()
var fuse_visual_controller: WeaponFuseVisualController = WeaponFuseVisualController.new()
var MAX_MODULE_NUMBER = 3
@onready var sprite: Sprite2D = $Sprite
@onready var fuse_sprite_holder: FuseSpriteHolder = get_node_or_null("FuseSprites")
@onready var _fuse_sprites_initialized = _load_fuse_sprites()
const PASSIVE_SCOPE_BODY: StringName = &"body"
const PASSIVE_SCOPE_GLOBAL: StringName = &"global"
const LAST_HIT_WEAPON_META: StringName = &"_last_player_weapon_hit_id"
const LAST_HIT_WEAPON_TIME_META: StringName = &"_last_player_weapon_hit_msec"
const DELIVERY_PROJECTILE: StringName = DamageDeliveryType.PROJECTILE
const DELIVERY_MELEE_CONTACT: StringName = DamageDeliveryType.MELEE_CONTACT
const DELIVERY_BEAM: StringName = DamageDeliveryType.BEAM
const DELIVERY_AREA: StringName = DamageDeliveryType.AREA
const DELIVERY_FLAG_ORDER: Array[StringName] = DamageDeliveryType.ALL

# Common variables for weapons
var level : int
var FINAL_MAX_FUSE : int = 3
var FINAL_MAX_LEVEL : int = 7
var max_level : int = FINAL_MAX_LEVEL
var _fuse_internal : int = 1
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
@export_flags("projectile", "melee_contact", "beam", "area") var delivery_type_flags: int = 0
@export_flags("summon", "trap", "support", "movement") var weapon_capability_flags: int = 0
var runtime_delivery_additions: Dictionary = {}
var runtime_delivery_suppressions: Dictionary = {}
var runtime_capability_additions: Dictionary = {}
var runtime_capability_suppressions: Dictionary = {}
@export var magazine_capacity: int = 50
@export var reload_duration_sec: float = 6.0
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
#endregion

#region Level And Data
func _init() -> void:
	branch_runtime.setup(self)
	stat_pipeline.setup(self)
	active_controller.setup(self)
	plugin_dispatcher.setup(self)
	ammo_controller.setup(self)
	passive_controller.setup(self)
	fuse_visual_controller.setup(self)

func set_level(lv):
	pass

func get_weapon_level_key(requested_level: Variant, data: Dictionary = {}) -> String:
	return WeaponLevelDataResolver.get_level_key(self, requested_level, data)

func get_weapon_level_data(requested_level: Variant, data: Dictionary = {}) -> Dictionary:
	return WeaponLevelDataResolver.get_level_data(self, requested_level, data)

func calculate_status() -> void:
	# Recompute derived runtime stats after module changes.
	refresh_max_level_from_data()
	if has_method("sync_stats"):
		call("sync_stats")
	ammo_controller.reconcile_capacity()
	validate_module_compatibility()
	_sync_heat_trait_state()

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
	return WeaponLevelDataResolver.get_data_max_level(self, FINAL_MAX_LEVEL)
#endregion

#region Fuse Visuals
func _apply_fuse_sprite() -> void:
	fuse_visual_controller.apply_fuse_sprite()

func _load_fuse_sprites() -> bool:
	return fuse_visual_controller.load_fuse_sprites()
#endregion

#region Plugin Dispatch And Hit Events
func register_on_hit_plugin(plugin: Node) -> void:
	plugin_dispatcher.register_on_hit_plugin(plugin)

func unregister_on_hit_plugin(plugin: Node) -> void:
	plugin_dispatcher.unregister_on_hit_plugin(plugin)

func register_projectile_spawn_plugin(plugin: Node) -> void:
	plugin_dispatcher.register_projectile_spawn_plugin(plugin)

func unregister_projectile_spawn_plugin(plugin: Node) -> void:
	plugin_dispatcher.unregister_projectile_spawn_plugin(plugin)

func notify_projectile_spawned(projectile: Node2D) -> void:
	plugin_dispatcher.notify_projectile_spawned(projectile)

func register_reload_duration_plugin(plugin: Node) -> void:
	plugin_dispatcher.register_reload_duration_plugin(plugin)

func unregister_reload_duration_plugin(plugin: Node) -> void:
	plugin_dispatcher.unregister_reload_duration_plugin(plugin)

func on_hit_target(target: Node) -> void:
	_handle_hit_target(target)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	_handle_hit_target(target, Attack.normalize_damage_type(damage_type))

func _handle_hit_target(target: Node, damage_type: StringName = StringName()) -> void:
	plugin_dispatcher.apply_on_hit_plugins(target)
	if target != null and is_instance_valid(target):
		target.set_meta(LAST_HIT_WEAPON_META, get_instance_id())
		target.set_meta(LAST_HIT_WEAPON_TIME_META, Time.get_ticks_msec())
	active_controller.register_hit_window()
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
#endregion

#region Capabilities And Enemy Queries
func supports_projectiles() -> bool:
	return has_explicit_delivery_type(DELIVERY_PROJECTILE)

func supports_melee_contact() -> bool:
	return has_explicit_delivery_type(DELIVERY_MELEE_CONTACT)

static func normalize_delivery_type(value: Variant) -> StringName:
	return DamageDeliveryType.normalize(value)

static func delivery_flags_to_types(mask: int) -> Array[StringName]:
	return DamageDeliveryType.flags_to_types(mask)

func get_explicit_delivery_types() -> Array[StringName]:
	return delivery_flags_to_types(delivery_type_flags)

func has_explicit_delivery_type(delivery_type: Variant) -> bool:
	var normalized := normalize_delivery_type(delivery_type)
	if normalized == StringName():
		return false
	return get_explicit_delivery_types().has(normalized)

func get_weapon_delivery_types() -> Array[StringName]:
	var output := get_explicit_delivery_types()
	for source_types in runtime_delivery_suppressions.values():
		for delivery_type in source_types:
			output.erase(delivery_type)
	for source_types in runtime_delivery_additions.values():
		for delivery_type in source_types:
			_append_delivery_type(output, delivery_type)
	return output

func has_delivery_type(delivery_type: Variant) -> bool:
	var normalized := normalize_delivery_type(delivery_type)
	if normalized == StringName():
		return false
	return get_weapon_delivery_types().has(normalized)

func _append_delivery_type(types: Array[StringName], delivery_type: StringName) -> void:
	if not types.has(delivery_type):
		types.append(delivery_type)

func add_runtime_delivery_type(source_id: StringName, delivery_type: Variant) -> void:
	var normalized := DamageDeliveryType.normalize(delivery_type)
	if normalized == StringName():
		return
	var values: Array = runtime_delivery_additions.get(source_id, [])
	if not values.has(normalized):
		values.append(normalized)
	runtime_delivery_additions[source_id] = values
	calculate_status()

func suppress_runtime_delivery_type(source_id: StringName, delivery_type: Variant) -> void:
	var normalized := DamageDeliveryType.normalize(delivery_type)
	if normalized == StringName():
		return
	var values: Array = runtime_delivery_suppressions.get(source_id, [])
	if not values.has(normalized):
		values.append(normalized)
	runtime_delivery_suppressions[source_id] = values
	calculate_status()

func clear_runtime_delivery_types(source_id: StringName) -> void:
	runtime_delivery_additions.erase(source_id)
	runtime_delivery_suppressions.erase(source_id)
	calculate_status()

func get_explicit_weapon_capabilities() -> Array[StringName]:
	return WeaponCapability.flags_to_capabilities(weapon_capability_flags)

func get_weapon_capabilities() -> Array[StringName]:
	var output := get_explicit_weapon_capabilities()
	for source_values in runtime_capability_suppressions.values():
		for capability in source_values:
			output.erase(capability)
	for source_values in runtime_capability_additions.values():
		for capability in source_values:
			if not output.has(capability):
				output.append(capability)
	return output

func has_weapon_capability(capability: Variant) -> bool:
	var normalized := WeaponCapability.normalize(capability)
	return normalized != StringName() and get_weapon_capabilities().has(normalized)

func has_any_weapon_capabilities(required: Array[StringName]) -> bool:
	if required.is_empty():
		return true
	for capability in required:
		if has_weapon_capability(capability):
			return true
	return false

func add_runtime_weapon_capability(source_id: StringName, capability: Variant) -> void:
	var normalized := WeaponCapability.normalize(capability)
	if normalized == StringName():
		return
	var values: Array = runtime_capability_additions.get(source_id, [])
	if not values.has(normalized):
		values.append(normalized)
	runtime_capability_additions[source_id] = values
	calculate_status()

func clear_runtime_weapon_capabilities(source_id: StringName) -> void:
	runtime_capability_additions.erase(source_id)
	runtime_capability_suppressions.erase(source_id)
	calculate_status()

func find_closest_enemy(origin: Vector2, radius: float = INF) -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var nearest: Node2D = null
	var nearest_dist_sq: float = INF
	var candidates: Array[Node2D] = []
	if is_inf(radius):
		candidates = WeaponModuleRuntimeUtils.get_enemy_candidates(tree)
	else:
		candidates = WeaponModuleRuntimeUtils.get_nearby_enemies(tree, origin, maxf(radius, 0.0))
	for enemy_ref in candidates:
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist_sq := origin.distance_squared_to(enemy.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy
	return nearest
#endregion

#region Lifecycle And Processing
func _initialize_branch_runtime() -> void:
	branch_runtime.setup(self)
	branch_runtime.name = "BranchRuntime"
	add_child(branch_runtime)

func _initialize_heat_runtime() -> void:
	heat_runtime.setup(self)
	heat_runtime.name = "HeatRuntime"
	add_child(heat_runtime)

func _ready() -> void:
	_initialize_branch_runtime()
	_initialize_heat_runtime()
	refresh_max_level_from_data()
	_initialize_ammo_system()
	branch_runtime.apply_branch_behaviors_if_needed()
	_sync_heat_trait_state()
	_notify_shared_heat_pool_dirty()
	call_deferred("validate_module_compatibility")

func _physics_process(delta: float) -> void:
	_update_reload_state(delta)
	_update_heat_system(delta)
	active_controller.update_cooldown(delta)
	active_controller.update_hit_window()
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
#endregion

#region Traits And Modules
func get_normalized_weapon_traits() -> Array[StringName]:
	return stat_pipeline.get_normalized_weapon_traits()

func has_heat_trait() -> bool:
	return has_weapon_trait(WeaponTrait.HEAT)
#endregion

#region Heat Gates
func has_heat_system() -> bool:
	return heat_runtime.has_heat_system()

func can_fire_with_heat() -> bool:
	return heat_runtime.can_fire()
#endregion

#region Ammo And Reload
func uses_ammo_system() -> bool:
	return false

func can_fire_with_ammo() -> bool:
	return ammo_controller.can_fire()

func apply_level_ammo(level_data: Dictionary) -> void:
	ammo_controller.apply_level_ammo(level_data)

func consume_ammo(amount: int = 1) -> bool:
	return ammo_controller.consume(amount)

func request_reload() -> bool:
	return ammo_controller.request_reload()

func _update_reload_state(delta: float) -> void:
	ammo_controller.update_reload_state(delta)

func _finish_reload() -> void:
	ammo_controller.finish_reload()

func refill_ammo_instantly() -> void:
	ammo_controller.refill_instantly()

func get_ammo_status() -> Dictionary:
	return ammo_controller.get_status()

func _initialize_ammo_system() -> void:
	ammo_controller.initialize_ammo_system()
#endregion

#region Heat Runtime
func register_overheat_fire_bypass(source: Node) -> void:
	heat_runtime.register_overheat_fire_bypass(source)

func unregister_overheat_fire_bypass(source: Node) -> void:
	heat_runtime.unregister_overheat_fire_bypass(source)

func _has_overheat_fire_bypass() -> bool:
	return heat_runtime.has_overheat_fire_bypass()

func configure_heat(per_shot: float, max_value: float, cool_rate: float) -> void:
	heat_runtime.configure(per_shot, max_value, cool_rate)

func register_shot_heat(multiplier: float = 1.0) -> void:
	heat_runtime.register_shot(multiplier)

func get_heat_ratio() -> float:
	return heat_runtime.get_heat_ratio()

func get_heat_value() -> float:
	return heat_runtime.get_heat_value()

func get_heat_max_value() -> float:
	return heat_runtime.get_heat_max_value()

func get_heat_percent() -> int:
	return heat_runtime.get_heat_percent()

func is_weapon_overheated() -> bool:
	return heat_runtime.is_overheated()

func lock_heat_value(value: float, duration_sec: float) -> void:
	heat_runtime.lock_heat_value(value, duration_sec)
#endregion

#region Traits And Module Stats
func get_explicit_weapon_traits() -> Array[StringName]:
	return stat_pipeline.get_explicit_weapon_traits()

func add_runtime_weapon_trait(source_id: StringName, trait_name: Variant) -> void:
	stat_pipeline.add_runtime_weapon_trait(source_id, trait_name)

func suppress_runtime_weapon_trait(source_id: StringName, trait_name: Variant) -> void:
	stat_pipeline.suppress_runtime_weapon_trait(source_id, trait_name)

func clear_runtime_weapon_traits(source_id: StringName) -> void:
	stat_pipeline.clear_runtime_weapon_traits(source_id)

func _get_modules_container() -> WeaponModules:
	return modules

func has_weapon_trait(trait_name: Variant) -> bool:
	return stat_pipeline.has_weapon_trait(trait_name)

func has_any_weapon_traits(required_traits: Array[StringName]) -> bool:
	return stat_pipeline.has_any_weapon_traits(required_traits)

func validate_module_compatibility() -> void:
	stat_pipeline.validate_module_compatibility()

func get_module_count() -> int:
	return stat_pipeline.get_module_count()

func get_available_module_slots() -> int:
	return stat_pipeline.get_available_module_slots()

func get_equipped_modules() -> Array[Module]:
	return stat_pipeline.get_equipped_modules()

func build_stat_snapshot() -> Dictionary:
	return stat_pipeline.build_stat_snapshot()

func get_last_stat_snapshot() -> Dictionary:
	return stat_pipeline.get_last_stat_snapshot()

func get_runtime_stat_value(stat_name: String, base_value: float) -> float:
	return stat_pipeline.get_runtime_stat_value(stat_name, base_value)

func get_runtime_damage_value(base_damage_value: float) -> int:
	return stat_pipeline.get_runtime_damage_value(base_damage_value)

func get_effective_magazine_capacity() -> int:
	return maxi(1, int(round(get_runtime_stat_value("magazine_capacity", float(magazine_capacity)))))

func get_effective_area_radius(base_radius: float) -> float:
	return maxf(1.0, get_runtime_stat_value("area_radius", base_radius))

func get_effective_knockback(base_knockback: float) -> float:
	return maxf(0.0, get_runtime_stat_value("knockback", base_knockback))

func get_effective_projectile_count(base_count: int) -> int:
	return maxi(1, int(round(get_runtime_stat_value("projectile_count", float(base_count)))))

func get_effective_cone_half_angle(base_angle_deg: float) -> float:
	return maxf(1.0, get_runtime_stat_value("cone_half_angle_deg", base_angle_deg))

func supports_multi_launcher_module() -> bool:
	return false

func get_module_shot_directions(base_direction: Vector2, base_count: int = 1) -> Array[Vector2]:
	var direction := base_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var effective_count := get_effective_projectile_count(base_count)
	if effective_count <= 1:
		return [direction]
	var directions: Array[Vector2] = []
	var total_arc_deg := minf(12.0 * float(effective_count - 1), 60.0)
	var start_angle := direction.angle() - deg_to_rad(total_arc_deg) * 0.5
	var step := deg_to_rad(total_arc_deg) / float(effective_count - 1)
	for index in range(effective_count):
		directions.append(Vector2.RIGHT.rotated(start_angle + step * float(index)).normalized())
	return directions

func apply_external_damage_mul(source_id: StringName, mul: float) -> void:
	stat_pipeline.apply_external_damage_mul(source_id, mul)

func remove_external_damage_mul(source_id: StringName) -> void:
	stat_pipeline.remove_external_damage_mul(source_id)

func get_total_external_damage_mul() -> float:
	return stat_pipeline.get_total_external_damage_mul()
#endregion

#region Passive Event Output
func emit_passive_trigger(event_name: StringName, detail: Dictionary = {}, passive_scope: StringName = PASSIVE_SCOPE_BODY) -> void:
	passive_controller.emit_passive_trigger(event_name, detail, passive_scope)
#endregion

#region Module Stat Pipeline
func get_projected_stats_with_module(module_instance: Module) -> Dictionary:
	return stat_pipeline.get_projected_stats_with_module(module_instance)

func apply_module_stat_pipeline() -> void:
	stat_pipeline.apply_module_stat_pipeline()

func _apply_dynamic_module_stats() -> void:
	stat_pipeline.apply_module_stat_pipeline()

func _apply_stat_snapshot(snapshot: Dictionary) -> void:
	stat_pipeline.apply_stat_snapshot(snapshot)

#endregion

#region Heat Integration
func _sync_heat_trait_state() -> void:
	heat_runtime.sync_trait_state()

func _update_heat_system(delta: float) -> void:
	heat_runtime.update(delta)

func _get_shared_heat_pool() -> Heat:
	return heat_runtime.get_shared_heat_pool()

func _get_active_heat_core() -> Heat:
	return heat_runtime.get_active_heat_core()

func _notify_shared_heat_pool_dirty() -> void:
	heat_runtime.notify_shared_heat_pool_dirty()
#endregion

#region Cleanup
func _on_tree_exited() -> void:
	plugin_dispatcher.clear_for_weapon_exit()
	ammo_controller.clear_for_weapon_exit()
	passive_controller.clear_for_weapon_exit()
	fuse_visual_controller.clear_for_weapon_exit()
	branch_runtime.clear_for_weapon_exit()
	heat_runtime.clear_for_weapon_exit()
	stat_pipeline.clear_for_weapon_exit()
	active_controller.clear_for_weapon_exit()
#endregion

#region Weapon Role And Input
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
	active_controller.clear_hit_window()
	for module_node in get_equipped_modules():
		if module_node == null or not is_instance_valid(module_node):
			continue
		if module_node.has_method("clear_timed_effects_for_prepare"):
			module_node.call("clear_timed_effects_for_prepare")
	for behavior in branch_runtime.get_branch_behaviors():
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
#endregion

#region Passive Dispatch
func can_passive_trigger(passive_id: StringName, icd_sec: float) -> bool:
	return passive_controller.can_passive_trigger(passive_id, icd_sec)

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
	passive_controller.on_passive_event(event_name, detail)
#endregion

#region Reload Metrics
func _get_spent_magazine_ratio() -> float:
	return ammo_controller.get_spent_magazine_ratio()

func _get_effective_reload_duration() -> float:
	return ammo_controller.get_effective_reload_duration()
#endregion

#region Weapon Active And Passive State
func request_weapon_active() -> Dictionary:
	return active_controller.request_weapon_active()

func _execute_weapon_active(_damage_multiplier: float) -> bool:
	return false

func get_weapon_active_cd_remaining() -> float:
	return active_controller.get_cooldown_remaining()

func get_weapon_active_cd_ratio() -> float:
	return active_controller.get_cooldown_ratio()

func get_weapon_active_hit_window_progress() -> Dictionary:
	return active_controller.get_hit_window_progress()

func get_passive_status() -> Dictionary:
	return passive_controller.get_passive_status()

func is_passive_ready() -> bool:
	return passive_controller.is_passive_ready()

func notify_passive_triggered(_cooldown_sec := 0.0) -> void:
	passive_controller.notify_passive_triggered(_cooldown_sec)

func refresh_passive_on_reload() -> void:
	passive_controller.refresh_passive_on_reload()

func notify_offhand_skill_triggered(cooldown_sec: float) -> void:
	notify_passive_triggered(cooldown_sec)

func get_offhand_skill_cd_progress() -> float:
	return passive_controller.get_offhand_skill_cd_progress()

func is_offhand_skill_ready() -> bool:
	return is_passive_ready()

func _refresh_offhand_skill_on_reload() -> void:
	refresh_passive_on_reload()

func force_skill_cooldowns_ready() -> void:
	passive_controller.force_ready()
	active_controller.force_ready()
#endregion
