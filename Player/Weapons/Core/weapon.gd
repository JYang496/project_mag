extends Node2D
class_name Weapon

enum RangeMode {
	UNSPECIFIED,
	FIXED_DISTANCE,
	FIXED_LIFETIME,
	BEAM_LENGTH,
	ATTACHED_RADIUS,
}

const DEFAULT_PROJECTILE_LIFETIME_SEC: float = 2.5
const WeaponFireFeedbackPlayerScript := preload("res://Player/Weapons/Feedback/weapon_fire_feedback_player.gd")
const WeaponTriggerRuntimeType := preload("res://Player/Weapons/Core/weapon_trigger_runtime.gd")
const WeaponSkillRuntimeType := preload("res://Player/Weapons/Core/weapon_skill_runtime.gd")
const SUPPORT_STAT_PROFILE := preload("res://Player/Weapons/Core/support_weapon_stat_profile.tres")

#region Runtime State
@onready var modules: WeaponModuleContainer = $Modules
var branch_runtime: WeaponBranchRuntime = WeaponBranchRuntime.new()
var heat_runtime: WeaponHeatController = WeaponHeatController.new()
var stat_pipeline: WeaponStatPipeline = WeaponStatPipeline.new()
var plugin_dispatcher: WeaponPluginDispatcher = WeaponPluginDispatcher.new()
var ammo_controller: WeaponAmmoController = WeaponAmmoController.new()
var passive_controller: WeaponPassiveController = WeaponPassiveController.new()
var trigger_runtime = WeaponTriggerRuntimeType.new()
var skill_runtime = WeaponSkillRuntimeType.new()
var fuse_visual_controller: WeaponFuseVisualController = WeaponFuseVisualController.new()
var fire_feedback_player = WeaponFireFeedbackPlayerScript.new()
@export_range(1, 8, 1) var module_slot_capacity: int = 3
@export var weapon_skills: Array[WeaponSkillDefinition] = []
@export_flags(
	"physical",
	"energy",
	"fire",
	"freeze",
	"heat",
	"charge",
	"auto_fire"
) var base_trait_flags: int = 0
@onready var sprite: Sprite2D = $Sprite
@onready var fuse_sprite_holder: FuseSpriteHolder = get_node_or_null("FuseSprites")
const PASSIVE_SCOPE_BODY: StringName = &"body"
const PASSIVE_SCOPE_GLOBAL: StringName = &"global"
const LAST_HIT_WEAPON_META: StringName = &"_last_player_weapon_hit_id"
const LAST_HIT_WEAPON_TIME_META: StringName = &"_last_player_weapon_hit_msec"
const ENERGY_RELEASE_ATTACK_META: StringName = &"_global_energy_release_attack"
const ENERGY_RELEASE_SPENT_META: StringName = &"_global_energy_release_spent"
const ENERGY_RELEASE_MULTIPLIER_META: StringName = &"_global_energy_release_multiplier"
const ENERGY_ATTACK_GROUP_META: StringName = &"_global_energy_attack_group"
const HEAT_SNAPSHOT_META: StringName = &"_bipolar_heat_snapshot"
const AUTOMATIC_AIM_TARGET_META: StringName = &"_player_assist_auto_aim_target"
const DELIVERY_PROJECTILE: StringName = DamageDeliveryType.PROJECTILE
const DELIVERY_MELEE_CONTACT: StringName = DamageDeliveryType.MELEE_CONTACT
const DELIVERY_BEAM: StringName = DamageDeliveryType.BEAM
const DELIVERY_AREA: StringName = DamageDeliveryType.AREA
const DELIVERY_FLAG_ORDER: Array[StringName] = DamageDeliveryType.ALL

# Common variables for weapons
var level : int
const MAX_FUSE_LEVEL: int = 3
const FALLBACK_MAX_WEAPON_LEVEL: int = 9
var max_level: int = FALLBACK_MAX_WEAPON_LEVEL
var _fuse_internal : int = 1
var heat_core: Heat
var heat_per_shot: float = 1.0
var heat_max_value: float = 100.0
var heat_cool_rate: float = 20.0
var heat_opposition_resistance: float = 0.0
@export_enum("main", "support") var weapon_role: String = "support"
@export var fire_feedback_profile: Resource
@export var range_mode: RangeMode = RangeMode.UNSPECIFIED
@export var configured_attack_range: float = 0.0
@export var projectile_lifetime_sec: float = 0.0
@export_range(1.0, 1440.0, 1.0) var turn_speed_degrees_per_second: float = 360.0
@export_flags("projectile", "melee_contact", "beam", "area") var delivery_type_flags: int = 0
@export_flags("summon", "trap", "support", "movement") var weapon_capability_flags: int = 0
var runtime_delivery_additions: Dictionary = {}
var runtime_delivery_suppressions: Dictionary = {}
var runtime_capability_additions: Dictionary = {}
var runtime_capability_suppressions: Dictionary = {}
@export var magazine_capacity: int = 50
@export var reload_duration_sec: float = 3.0
var _energy_release_attack_active: bool = false
var _energy_release_damage_multiplier: float = 1.0
var _energy_release_spent: float = 0.0
var _energy_attack_sequence: int = 0
var _active_energy_attack_group_id: StringName = StringName()
var _energy_pool_owner: Node
var current_ammo: int = 0
var is_reloading: bool = false
var reload_time_left: float = 0.0
var cooldown_timer: Timer
var is_on_cooldown: bool = false
var fuse : int:
	get:
		return _fuse_internal
	set(value):
		_fuse_internal = clampi(value, 1, MAX_FUSE_LEVEL)
		_apply_fuse_sprite()

signal weapon_role_changed(next_role: String)
signal shoot()
@warning_ignore("unused_signal")
signal passive_triggered(event_name: StringName, detail: Dictionary)
signal weapon_event_emitted(event: WeaponEvent)
@warning_ignore("unused_signal")
signal weapon_reload_completed(weapon: Weapon)
@warning_ignore("unused_signal")
signal support_refreshed_by_reload(weapon: Weapon)
#endregion

func get_aim_forward() -> Vector2:
	return Vector2.RIGHT.rotated(rotation - deg_to_rad(90.0)).normalized()

func turn_toward_world_position(target_position: Vector2, delta: float, speed_multiplier: float = 1.0) -> bool:
	var desired_direction := global_position.direction_to(target_position).normalized()
	if desired_direction == Vector2.ZERO:
		return false
	var target_rotation := desired_direction.angle() + deg_to_rad(90.0)
	var max_step := deg_to_rad(maxf(turn_speed_degrees_per_second, 0.0)) * maxf(speed_multiplier, 0.0) * maxf(delta, 0.0)
	rotation = rotate_toward(rotation, target_rotation, max_step)
	return true

#region Level And Data
func _init() -> void:
	branch_runtime.setup(self)
	stat_pipeline.setup(self)
	plugin_dispatcher.setup(self)
	ammo_controller.setup(self)
	passive_controller.setup(self)
	trigger_runtime.setup(self)
	skill_runtime.setup(self)
	fuse_visual_controller.setup(self)
	fire_feedback_player.setup(self)

func set_level(_lv):
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
	return WeaponLevelDataResolver.get_data_max_level(self, FALLBACK_MAX_WEAPON_LEVEL)
#endregion

#region Fuse Visuals
func _apply_fuse_sprite() -> void:
	fuse_visual_controller.apply_fuse_sprite()

func _load_fuse_sprites() -> bool:
	return fuse_visual_controller.load_fuse_sprites()
#endregion

#region Plugin Dispatch And Hit Events
func notify_projectile_spawned(projectile: Node2D) -> void:
	var event := WeaponEvent.create(WeaponEvent.PROJECTILE_SPAWNED, self)
	event.projectile = projectile
	emit_weapon_event(event)

func on_hit_target(target: Node) -> void:
	_handle_hit_target(target)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	_handle_hit_target(target, Attack.normalize_damage_type(damage_type))

func _handle_hit_target(target: Node, damage_type: StringName = StringName()) -> void:
	var event := WeaponEvent.create(WeaponEvent.HIT_CONFIRMED, self)
	event.target = target
	if damage_type != StringName():
		event.detail["damage_type"] = damage_type
	emit_weapon_event(event)
	trigger_runtime.on_hit(target)
	if target != null and is_instance_valid(target):
		target.set_meta(LAST_HIT_WEAPON_META, get_instance_id())
		target.set_meta(LAST_HIT_WEAPON_TIME_META, Time.get_ticks_msec())
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("_broadcast_weapon_passive_event"):
		var detail := {
			"source_weapon": self,
			"target": target,
			"source_role": weapon_role
		}
		if damage_type != StringName():
			detail["damage_type"] = damage_type
		PlayerData.player.call("_broadcast_weapon_passive_event", &"on_hit", detail)

func on_damage_applied(target: Node, data: DamageData, result: DamageResult) -> void:
	_accumulate_global_weapon_energy(data, result)
	var damage_event := WeaponEvent.create(WeaponEvent.DAMAGE_DEALT, self).with_context(data.action_context)
	damage_event.target = target
	damage_event.damage_data = data
	damage_event.damage_result = result
	emit_weapon_event(damage_event)
	if result.is_critical:
		var critical_event := WeaponEvent.create(WeaponEvent.CRITICAL_HIT, self).with_context(data.action_context)
		critical_event.target = target
		critical_event.damage_data = data
		critical_event.damage_result = result
		emit_weapon_event(critical_event)
	if result.killed:
		var kill_event := WeaponEvent.create(WeaponEvent.TARGET_KILLED, self).with_context(data.action_context)
		kill_event.target = target
		kill_event.damage_data = data
		kill_event.damage_result = result
		emit_weapon_event(kill_event)
		var death_position := Vector2.ZERO
		if target is Node2D:
			death_position = (target as Node2D).global_position
		dispatch_passive_event(&"on_enemy_killed", {
			"source_weapon": self,
			"enemy": target,
			"target": target,
			"position": death_position,
			"event": kill_event,
			"_suppress_default_emit": true,
		})

func _accumulate_global_weapon_energy(data: DamageData, result: DamageResult) -> void:
	if data == null or result == null or not result.applied or result.health_damage <= 0:
		return
	if data.source_category != DamageData.SOURCE_PLAYER_WEAPON:
		return
	if data.damage_kind != DamageData.KIND_DIRECT or data.suppress_reactive_effects:
		return
	if Attack.normalize_damage_type(result.damage_type) != Attack.TYPE_ENERGY:
		return
	if not has_weapon_trait(WeaponTrait.ENERGY):
		return
	if _is_energy_release_source(data.source_node):
		return
	var player := data.source_player
	if player == null or not is_instance_valid(player):
		player = DamageManager.resolve_source_player(self)
	if player == null or not is_instance_valid(player) or not player.has_method("add_global_weapon_energy"):
		return
	_energy_pool_owner = player
	var gain := get_energy_gain_per_damage_event()
	player.call("add_global_weapon_energy", gain, data.source_node)

func get_energy_full_fire_passive_id() -> StringName:
	var branch_passive_id := branch_runtime.get_energy_full_fire_passive_id()
	if branch_passive_id != StringName():
		return branch_passive_id
	return &"energy_full_fire_triggered"

func get_energy_full_fire_display_name() -> String:
	var branch_display_name := branch_runtime.get_energy_full_fire_display_name()
	if not branch_display_name.is_empty():
		return branch_display_name
	return "Full-Energy Release"

func get_energy_full_fire_status() -> Dictionary:
	var player := _resolve_energy_pool_player()
	var current := 0.0
	var maximum := 100.0
	if player != null and is_instance_valid(player):
		if player.has_method("get_global_weapon_energy"):
			current = maxf(float(player.call("get_global_weapon_energy")), 0.0)
		if player.has_method("get_global_weapon_energy_max"):
			maximum = maxf(float(player.call("get_global_weapon_energy_max")), 1.0)
	var ratio := clampf(current / maximum, 0.0, 1.0)
	var ready := current >= maximum - 0.001
	return {
		"id": str(get_energy_full_fire_passive_id()),
		"display_name": get_energy_full_fire_display_name(),
		"state": "ready_pending_action" if ready else "charging",
		"progress": ratio,
		"progress_role": "global_energy",
		"current": current,
		"required": maximum,
		"ready": ready,
		"condition_visible": true,
		"condition_progress": ratio,
		"condition_thresholds": [],
		"trigger_hint": "fire_at_full_global_energy",
		"refresh_hint": "automatic_after_full_energy_attack",
		"charge_based": false,
		"energy_full_fire_cycle": true,
	}

func prepare_energy_release_attack() -> Dictionary:
	_energy_attack_sequence += 1
	_active_energy_attack_group_id = StringName("%d:%d" % [get_instance_id(), _energy_attack_sequence])
	_energy_release_attack_active = false
	_energy_release_damage_multiplier = 1.0
	_energy_release_spent = 0.0
	if is_support_weapon():
		return {"triggered": false, "spent": 0.0, "multiplier": 1.0}
	if not has_weapon_trait(WeaponTrait.ENERGY):
		return {"triggered": false, "spent": 0.0, "multiplier": 1.0}
	var player := _resolve_energy_pool_player()
	if player == null or not is_instance_valid(player) or not player.has_method("consume_all_global_weapon_energy"):
		return {"triggered": false, "spent": 0.0, "multiplier": 1.0}
	var max_energy := 1.0
	if player.has_method("get_global_weapon_energy_max"):
		max_energy = maxf(float(player.call("get_global_weapon_energy_max")), 1.0)
	var current_energy := 0.0
	if player.has_method("get_global_weapon_energy"):
		current_energy = maxf(float(player.call("get_global_weapon_energy")), 0.0)
	var special_state := _prepare_special_energy_release_attack(player, current_energy, max_energy)
	if not special_state.is_empty():
		return special_state
	if current_energy < max_energy - 0.001:
		return {"triggered": false, "spent": 0.0, "multiplier": 1.0}
	_energy_release_spent = maxf(float(player.call("consume_all_global_weapon_energy")), 0.0)
	if _energy_release_spent > 0.0:
		var release_ratio := clampf(_energy_release_spent / max_energy, 0.0, 1.0)
		return activate_energy_release_attack(
			_energy_release_spent,
			1.0 + release_ratio * get_energy_release_bonus_at_full()
		)
	return {"triggered": false, "spent": 0.0, "multiplier": 1.0}

func _prepare_special_energy_release_attack(
	_player: Node,
	_current_energy: float,
	_max_energy: float
) -> Dictionary:
	return {}

func activate_energy_release_attack(
	spent: float,
	damage_multiplier: float,
	detail: Dictionary = {}
) -> Dictionary:
	_energy_release_spent = maxf(spent, 0.0)
	_energy_release_damage_multiplier = maxf(damage_multiplier, 1.0)
	_energy_release_attack_active = true
	var event_detail := {
		"trigger": "full_energy_attack_fired",
		"energy_spent": _energy_release_spent,
		"damage_multiplier": _energy_release_damage_multiplier,
	}
	event_detail.merge(detail, true)
	emit_passive_trigger(&"global_energy_release_attack", event_detail, PASSIVE_SCOPE_GLOBAL)
	var release_event := WeaponEvent.create(WeaponEvent.SHARED_RESOURCE_RELEASE, self)
	release_event.detail = event_detail
	emit_weapon_event(release_event)
	return {
		"triggered": true,
		"spent": _energy_release_spent,
		"multiplier": _energy_release_damage_multiplier,
		"release_mode": event_detail.get("release_mode", &"instant"),
	}

func is_energy_release_attack_active() -> bool:
	return _energy_release_attack_active

func get_energy_release_spent() -> float:
	return _energy_release_spent

func finish_energy_release_attack() -> void:
	_energy_release_attack_active = false
	_energy_release_damage_multiplier = 1.0
	_energy_release_spent = 0.0
	_active_energy_attack_group_id = StringName()

func apply_energy_release_marker(attack_node: Node) -> void:
	if attack_node == null or not is_instance_valid(attack_node):
		return
	if _active_energy_attack_group_id != StringName():
		attack_node.set_meta(ENERGY_ATTACK_GROUP_META, _active_energy_attack_group_id)
	else:
		attack_node.remove_meta(ENERGY_ATTACK_GROUP_META)
	if not _energy_release_attack_active:
		attack_node.remove_meta(ENERGY_RELEASE_ATTACK_META)
		attack_node.remove_meta(ENERGY_RELEASE_SPENT_META)
		attack_node.remove_meta(ENERGY_RELEASE_MULTIPLIER_META)
		return
	attack_node.set_meta(ENERGY_RELEASE_ATTACK_META, true)
	attack_node.set_meta(ENERGY_RELEASE_SPENT_META, _energy_release_spent)
	attack_node.set_meta(ENERGY_RELEASE_MULTIPLIER_META, _energy_release_damage_multiplier)

func get_energy_gain_per_damage_event() -> float:
	var branch_value := branch_runtime.get_energy_gain_per_damage_event()
	if branch_value >= 0.0:
		return branch_value
	return 6.0

func get_energy_release_bonus_at_full() -> float:
	var branch_value := branch_runtime.get_energy_release_bonus_at_full()
	if branch_value >= 0.0:
		return branch_value
	return 0.75

func _is_energy_release_source(source_node: Node) -> bool:
	return source_node != null and is_instance_valid(source_node) \
		and bool(source_node.get_meta(ENERGY_RELEASE_ATTACK_META, false))

func _resolve_energy_pool_player() -> Node:
	if _energy_pool_owner != null and is_instance_valid(_energy_pool_owner):
		return _energy_pool_owner
	var resolved := DamageManager.resolve_source_player(self)
	if resolved != null and is_instance_valid(resolved):
		_energy_pool_owner = resolved
		return resolved
	if PlayerData.player != null and is_instance_valid(PlayerData.player) \
			and PlayerData.player.has_method("consume_all_global_weapon_energy"):
		_energy_pool_owner = PlayerData.player
		return PlayerData.player
	return null

func notify_main_weapon_fired() -> void:
	if not is_main_weapon():
		return
	var fired_event := WeaponEvent.create(WeaponEvent.PRIMARY_ATTACK_FIRED, self)
	emit_weapon_event(fired_event)
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("_broadcast_weapon_passive_event"):
		PlayerData.player.call("_broadcast_weapon_passive_event", &"on_main_weapon_fired", {
			"source_weapon": self,
			"_suppress_default_emit": true,
		})

func play_fire_feedback(direction: Vector2 = Vector2.ZERO) -> bool:
	if fire_feedback_profile == null:
		return false
	if fire_feedback_player == null:
		fire_feedback_player = WeaponFireFeedbackPlayerScript.new()
		fire_feedback_player.setup(self)
	return fire_feedback_player.play(
		fire_feedback_profile,
		direction,
		_should_play_weapon_audio_feedback(),
		is_main_weapon()
	)

func play_hit_feedback(target: Node = null) -> bool:
	if fire_feedback_profile == null:
		return false
	if not _should_play_weapon_audio_feedback():
		return false
	if fire_feedback_player == null:
		fire_feedback_player = WeaponFireFeedbackPlayerScript.new()
		fire_feedback_player.setup(self)
	if not fire_feedback_player.has_method("play_hit"):
		return false
	return fire_feedback_player.play_hit(fire_feedback_profile, target)

func _should_play_weapon_audio_feedback() -> bool:
	return is_main_weapon() and has_delivery_type(DELIVERY_PROJECTILE)

func get_fire_feedback_direction() -> Vector2:
	return Vector2.RIGHT.rotated(global_rotation)

func get_muzzle_global_position() -> Vector2:
	var muzzle := get_node_or_null("Muzzle") as Node2D
	if muzzle != null:
		return muzzle.global_position
	return global_position
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

func get_auto_fire_target_origin() -> Vector2:
	return global_position

func set_automatic_aim_target(target_position: Vector2) -> void:
	set_meta(AUTOMATIC_AIM_TARGET_META, target_position)

func clear_automatic_aim_target() -> void:
	if has_meta(AUTOMATIC_AIM_TARGET_META):
		remove_meta(AUTOMATIC_AIM_TARGET_META)

func get_effective_attack_range() -> float:
	match range_mode:
		RangeMode.FIXED_DISTANCE, RangeMode.BEAM_LENGTH, RangeMode.ATTACHED_RADIUS:
			return maxf(configured_attack_range, 0.0)
		RangeMode.FIXED_LIFETIME:
			return maxf(_get_range_reference_speed() * projectile_lifetime_sec, 0.0)
	var legacy_attack_range: Variant = get("attack_range")
	if legacy_attack_range != null:
		return maxf(float(legacy_attack_range), 0.0)
	return 0.0

func get_effective_projectile_lifetime() -> float:
	if range_mode == RangeMode.FIXED_DISTANCE:
		return maxf(configured_attack_range / maxf(_get_range_reference_speed(), 1.0), 0.01)
	if range_mode == RangeMode.FIXED_LIFETIME:
		return maxf(projectile_lifetime_sec, 0.01)
	if projectile_lifetime_sec > 0.0:
		return projectile_lifetime_sec
	return DEFAULT_PROJECTILE_LIFETIME_SEC

func _get_range_reference_speed() -> float:
	var speed_value: Variant = get("speed")
	if speed_value != null:
		return maxf(float(speed_value), 0.0)
	return 0.0

func get_auto_fire_target_range() -> float:
	var effective_range := get_effective_attack_range()
	if effective_range > 0.0:
		return effective_range
	if has_method("_get_effective_attack_range"):
		return maxf(float(call("_get_effective_attack_range")), 1.0)
	var attack_range_value: Variant = get("attack_range")
	if attack_range_value != null:
		return maxf(float(attack_range_value), 1.0)
	var auto_fire_range_value: Variant = get("auto_fire_range")
	if auto_fire_range_value != null:
		return maxf(float(auto_fire_range_value), 1.0)
	return INF

func find_auto_fire_target() -> Node2D:
	return find_closest_enemy(get_auto_fire_target_origin(), get_auto_fire_target_range())
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
	_load_fuse_sprites()
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
	trigger_runtime.update(delta)
	skill_runtime.update(delta)
	_process_weapon_role_effects(delta)

func _process_weapon_role_effects(delta: float) -> void:
	if is_main_weapon():
		_process_main_weapon_effect(delta)
		return
	_process_support_weapon_effect(delta)

func _process_main_weapon_effect(_delta: float) -> void:
	pass

func _process_support_weapon_effect(_delta: float) -> void:
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

func get_primary_fire_ammo_cost() -> int:
	return 1

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
func configure_heat(per_shot: float, max_value: float, cool_rate: float) -> void:
	heat_runtime.configure(per_shot, max_value, cool_rate)

func register_shot_heat(multiplier: float = 1.0) -> void:
	heat_runtime.register_shot(multiplier)

func get_runtime_heat_per_shot() -> float:
	return heat_per_shot * get_role_stat_multiplier(&"heat_generation")

func get_runtime_heat_generation(base_amount: float) -> float:
	return base_amount * get_role_stat_multiplier(&"heat_generation")

func get_heat_ratio() -> float:
	return heat_runtime.get_heat_ratio()

func get_signed_heat_ratio() -> float:
	return heat_runtime.get_signed_heat_ratio()

func get_heat_gauge_ratio() -> float:
	return heat_runtime.get_heat_gauge_ratio()

func get_fire_alignment() -> float:
	return heat_runtime.get_fire_alignment()

func get_freeze_alignment() -> float:
	return heat_runtime.get_freeze_alignment()

func get_heat_zone() -> StringName:
	return heat_runtime.get_heat_zone()

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

func apply_heat_snapshot_marker(attack_node: Node) -> void:
	if attack_node == null or not is_instance_valid(attack_node):
		return
	attack_node.set_meta(HEAT_SNAPSHOT_META, capture_heat_snapshot())

func capture_heat_snapshot() -> Dictionary:
	var amplifier := 1.0
	if PlayerData.player != null and is_instance_valid(PlayerData.player) \
			and PlayerData.player.has_method("get_heat_alignment_amplifier"):
		amplifier = maxf(float(PlayerData.player.call("get_heat_alignment_amplifier")), 1.0)
	return {
		"signed_ratio": get_signed_heat_ratio(),
		"alignment_amplifier": amplifier,
		"weapon_ordinary_multiplier": get_total_ordinary_damage_multiplier(),
		"captured_at_msec": Time.get_ticks_msec(),
	}

func get_combat_resource_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if has_heat_system():
		slots.append(_build_heat_resource_slot())
	var ammo_slot := _build_ammo_resource_slot()
	if not ammo_slot.is_empty():
		slots.append(ammo_slot)
	return slots

func _build_heat_resource_slot() -> Dictionary:
	var heat_max := Heat.MAX_HEAT
	var heat_value := clampf(get_heat_value(), Heat.MIN_HEAT, Heat.MAX_HEAT)
	var ratio := get_heat_gauge_ratio()
	var signed_percent := int(round(heat_value))
	var zone := get_heat_zone()
	var state := zone
	var priority := 40
	if absf(heat_value) >= 90.0:
		priority = 80
	var short_text := "%+d" % signed_percent
	var hot := maxf(get_signed_heat_ratio(), 0.0)
	var cold := maxf(-get_signed_heat_ratio(), 0.0)
	var accessible_zone := _get_accessible_heat_zone_name(zone)
	var tooltip := "Heat: %+d | %s\nDamage %+.0f%% | Move %+.0f%% | Fire rate %+.0f%% | Reload time %+.0f%%\nElemental damage uses Heat when the attack is created; sustained attacks lock their initial Heat." % [
		signed_percent,
		accessible_zone,
		hot * Player.HEAT_GLOBAL_DAMAGE_BONUS_AT_FULL * 100.0,
		-hot * Player.HEAT_MOVE_SPEED_PENALTY_AT_FULL * 100.0,
		cold * Player.COLD_ATTACK_SPEED_BONUS_AT_FULL * 100.0,
		cold * Player.COLD_RELOAD_DURATION_PENALTY_AT_FULL * 100.0,
	]
	if LocalizationManager != null:
		tooltip = LocalizationManager.tr_format("ui.hud.heat.tooltip", {
			"heat": "%+d" % signed_percent,
			"zone": accessible_zone,
			"damage": "%+.0f" % (hot * Player.HEAT_GLOBAL_DAMAGE_BONUS_AT_FULL * 100.0),
			"move": "%+.0f" % (-hot * Player.HEAT_MOVE_SPEED_PENALTY_AT_FULL * 100.0),
			"fire_rate": "%+.0f" % (cold * Player.COLD_ATTACK_SPEED_BONUS_AT_FULL * 100.0),
			"reload": "%+.0f" % (cold * Player.COLD_RELOAD_DURATION_PENALTY_AT_FULL * 100.0),
		}, tooltip)
	return {
		"id": "%s_heat" % str(get_instance_id()),
		"type": &"heat",
		"display_name": "Heat",
		"current": heat_value,
		"max": heat_max,
		"min": Heat.MIN_HEAT,
		"ratio": ratio,
		"signed_ratio": get_signed_heat_ratio(),
		"state": state,
		"short_text": short_text,
		"tooltip": tooltip,
		"priority": priority,
		"visibility": "active_weapon",
	}

func _get_accessible_heat_zone_name(zone: StringName) -> String:
	var key := "ui.hud.heat.zone.neutral"
	var fallback := "NEUTRAL"
	match zone:
		&"extreme_cold", &"deep_cold":
			key = "ui.hud.heat.zone.extreme_cold"
			fallback = "EXTREME COLD"
		&"cold":
			key = "ui.hud.heat.zone.cold"
			fallback = "COLD"
		&"hot":
			key = "ui.hud.heat.zone.hot"
			fallback = "HOT"
		&"high_heat", &"extreme_heat":
			key = "ui.hud.heat.zone.extreme_hot"
			fallback = "EXTREME HOT"
	if LocalizationManager != null:
		return LocalizationManager.tr_key(key, fallback)
	return fallback

func _build_ammo_resource_slot() -> Dictionary:
	var status := get_ammo_status()
	if not bool(status.get("enabled", false)):
		return {}
	var current := maxi(int(status.get("current", 0)), 0)
	var max_ammo := maxi(int(status.get("max", 0)), 0)
	if max_ammo <= 0:
		return {}
	var is_reloading := bool(status.get("is_reloading", false))
	var reload_left := maxf(float(status.get("reload_left", 0.0)), 0.0)
	var ratio := clampf(float(current) / float(max_ammo), 0.0, 1.0)
	var state := &"normal"
	var priority := 40
	var short_text := ""
	if is_reloading:
		state = &"reloading"
		priority = 60
		short_text = "%.1fs" % reload_left
	elif current <= maxi(1, int(ceil(float(max_ammo) * 0.25))):
		state = &"warning"
		priority = 80
		short_text = "%d/%d" % [current, max_ammo]
	return {
		"id": "%s_ammo" % str(get_instance_id()),
		"type": &"ammo",
		"display_name": "Ammo",
		"current": current,
		"max": max_ammo,
		"ratio": ratio,
		"state": state,
		"short_text": short_text,
		"tooltip": "Ammo: %d/%d%s" % [current, max_ammo, " (Reloading %.1fs)" % reload_left if is_reloading else ""],
		"priority": priority,
		"visibility": "active_weapon",
	}
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

func _get_modules_container() -> WeaponModuleContainer:
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
	var module_multiplier := stat_pipeline.get_runtime_stat_value("damage", 1.0)
	var external_multiplier := stat_pipeline.get_total_external_damage_mul()
	var ordinary_multiplier := maxf(1.0 + (module_multiplier - 1.0) + (external_multiplier - 1.0), 0.05)
	var runtime_damage := maxf(base_damage_value, 0.0) * ordinary_multiplier
	if _energy_release_attack_active:
		runtime_damage *= maxf(_energy_release_damage_multiplier, 1.0)
	runtime_damage *= get_role_stat_multiplier(&"damage")
	return maxi(1, int(round(runtime_damage)))

func get_runtime_damage() -> int:
	assert(false, "%s must implement get_runtime_damage()" % get_script().resource_path)
	return 0

func get_runtime_attack_cooldown() -> float:
	assert(false, "%s must implement get_runtime_attack_cooldown()" % get_script().resource_path)
	return 1.0

func get_role_stat_multiplier(stat_name: StringName) -> float:
	if is_main_weapon():
		return 1.0
	match stat_name:
		&"damage":
			return SUPPORT_STAT_PROFILE.damage_multiplier
		&"attack_cooldown":
			return SUPPORT_STAT_PROFILE.cooldown_multiplier
		&"heat_generation":
			return SUPPORT_STAT_PROFILE.heat_generation_multiplier
	return 1.0

func get_total_ordinary_damage_multiplier() -> float:
	return stat_pipeline.get_total_ordinary_damage_multiplier()

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
	var total_arc_deg := minf(12.0 * float(effective_count - 1), 60.0)
	var step := deg_to_rad(total_arc_deg) / float(effective_count - 1)
	return WeaponBranchBehavior.build_centered_spread_directions(direction, effective_count, step)

func apply_external_damage_mul(source_id: StringName, mul: float) -> void:
	stat_pipeline.apply_external_damage_mul(source_id, mul)

func remove_external_damage_mul(source_id: StringName) -> void:
	stat_pipeline.remove_external_damage_mul(source_id)

func get_total_external_damage_mul() -> float:
	return stat_pipeline.get_total_external_damage_mul()
#endregion

#region Passive Event Output
func emit_weapon_event(event: WeaponEvent) -> void:
	assert(event != null)
	event.source_weapon = self
	plugin_dispatcher.dispatch_event(event)
	weapon_event_emitted.emit(event)

func receive_external_weapon_event(event: WeaponEvent) -> void:
	assert(event != null)
	assert(event.source_weapon == self)
	emit_weapon_event(event)

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
	trigger_runtime.clear_for_weapon_exit()
	skill_runtime.clear_for_weapon_exit()
	fuse_visual_controller.clear_for_weapon_exit()
	branch_runtime.clear_for_weapon_exit()
	heat_runtime.clear_for_weapon_exit()
	stat_pipeline.clear_for_weapon_exit()
	_energy_pool_owner = null
#endregion

#region Weapon Role And Input
func set_weapon_role(next_role: String) -> void:
	var normalized := "main" if str(next_role).to_lower() == "main" else "support"
	if weapon_role == normalized:
		return
	var old_role := weapon_role
	weapon_role = normalized
	_on_weapon_role_changed(weapon_role)
	if weapon_role == "main":
		trigger_runtime.on_entered_main(old_role)
		_on_enter_main_weapon_role()
	else:
		trigger_runtime.on_entered_support(old_role)
		_on_enter_support_weapon_role()
	weapon_role_changed.emit(weapon_role)

func is_main_weapon() -> bool:
	return weapon_role == "main"

func is_support_weapon() -> bool:
	return weapon_role == "support"

func _on_weapon_role_changed(_next_role: String) -> void:
	pass

func _on_enter_main_weapon_role() -> void:
	pass

func _on_enter_support_weapon_role() -> void:
	pass

func has_entry_trigger_ready() -> bool:
	return trigger_runtime.has_entry_charge()

func consume_entry_trigger() -> bool:
	return trigger_runtime.consume_entry_charge()

func is_support_trigger_ready() -> bool:
	return trigger_runtime.is_support_charge_ready()

func get_support_trigger_progress() -> float:
	return trigger_runtime.get_support_charge_progress()

func consume_support_trigger() -> bool:
	return trigger_runtime.consume_support_charge()

func clear_timed_effects_for_prepare() -> void:
	finish_energy_release_attack()
	skill_runtime.clear_active()
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

func request_automatic_fire() -> bool:
	return false

func prepare_automatic_aim(_delta: float) -> void:
	pass

func stop_automatic_fire() -> void:
	pass

func request_weapon_skill() -> bool:
	return skill_runtime.request()

func get_weapon_skill_status() -> Dictionary:
	return skill_runtime.get_status()

func allows_held_attack_on_battle_entry() -> bool:
	return false

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
	if is_support_weapon():
		_on_support_passive_event(event_name, detail)
	else:
		_on_main_passive_event(event_name, detail)

func _on_support_passive_event(event_name: StringName, detail: Dictionary) -> void:
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

#region Weapon Passive State

func get_passive_status() -> Dictionary:
	return passive_controller.get_passive_status()

func with_passive_charge_status(status: Dictionary) -> Dictionary:
	return passive_controller.with_passive_charge_status(status)

func is_passive_ready() -> bool:
	return passive_controller.is_passive_ready()

func consume_passive_charge() -> void:
	passive_controller.consume_charge()

func add_passive_charges(amount: int = 1) -> int:
	return passive_controller.add_passive_charges(amount)

func consume_all_passive_charges() -> int:
	return passive_controller.consume_all_passive_charges()

func refresh_passive_on_reload() -> void:
	passive_controller.refresh_passive_on_reload()

func get_passive_max_charges() -> int:
	return 1

func _refresh_passive_on_reload() -> void:
	refresh_passive_on_reload()

func force_skill_cooldowns_ready() -> void:
	passive_controller.force_ready()
	skill_runtime.force_ready()
#endregion
