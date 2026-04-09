extends Node2D
class_name Weapon

@onready var modules: WeaponModules = $Modules
const HEAT_SCRIPT := preload("res://Player/Weapons/Heat/heat.gd")
var MAX_MODULE_NUMBER = 3
@onready var sprite: Sprite2D = $Sprite
@onready var fuse_sprite_holder: FuseSpriteHolder = get_node_or_null("FuseSprites")
@onready var _fuse_sprites_initialized = _load_fuse_sprites()
var on_hit_plugins: Array[Node] = []
var _passive_icd_msec: Dictionary = {}

# Common variables for weapons
const FUSE_LEVEL_CAPS: Dictionary = {
	1: 3,
	2: 5,
	3: 7,
}
var level : int
var FINAL_MAX_FUSE : int = 3
var FINAL_MAX_LEVEL : int = 7
var max_level : int = FUSE_LEVEL_CAPS[1]
var _fuse_internal : int = 1
var fuse_sprites: Dictionary = {}
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
var _weapon_active_cd_remaining: float = 0.0
var _weapon_active_hit_window_hits: int = 0
var _weapon_active_hit_window_expires_at_msec: int = 0
var fuse : int:
	get:
		return _fuse_internal
	set(value):
		_fuse_internal = clampi(value, 1, FINAL_MAX_FUSE)
		max_level = get_max_level_for_fuse(_fuse_internal)
		_apply_fuse_sprite()

signal weapon_role_changed(next_role: String)
signal weapon_active_status_changed(cooldown_remaining: float, ready: bool)
signal weapon_active_triggered(success: bool, reason: String)
signal passive_triggered(event_name: StringName, detail: Dictionary)

func set_level(lv):
	pass

func calculate_status() -> void:
	# Recompute derived runtime stats after module changes.
	if has_method("sync_stats"):
		call("sync_stats")
	validate_module_compatibility()
	_sync_heat_trait_state()
	_notify_shared_heat_pool_dirty()



func set_max_level(ml : int):
	var fuse_cap: int = get_max_level_for_fuse(fuse)
	max_level = clampi(ml, 1, fuse_cap)

func get_max_level_for_fuse(fuse_level: int) -> int:
	return FUSE_LEVEL_CAPS.get(fuse_level, FINAL_MAX_LEVEL)

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

func on_hit_target(target: Node) -> void:
	for plugin in on_hit_plugins:
		if is_instance_valid(plugin) and plugin.has_method("apply_on_hit"):
			plugin.apply_on_hit(self, target)
	_register_weapon_active_hit_window()
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("_broadcast_weapon_passive_event"):
		PlayerData.player.call("_broadcast_weapon_passive_event", &"on_hit", {
			"source_weapon": self,
			"target": target,
			"source_is_main": is_main_weapon()
		})

func supports_projectiles() -> bool:
	return false

func supports_melee_contact() -> bool:
	return false

func _ready() -> void:
	_apply_branch_behavior_if_needed()
	_sync_heat_trait_state()
	_notify_shared_heat_pool_dirty()
	call_deferred("validate_module_compatibility")

func _physics_process(delta: float) -> void:
	_update_heat_system(delta)
	_update_weapon_active_cooldown(delta)
	_update_weapon_active_hit_window()

func set_branch(new_branch_id: String) -> bool:
	var normalized_id := str(new_branch_id)
	if normalized_id == "":
		return false
	var scene_path := scene_file_path
	var branch_def := DataHandler.read_weapon_branch_definition(scene_path, normalized_id)
	if branch_def == null:
		return false
	if fuse < int(branch_def.unlock_fuse):
		return false
	branch_id = normalized_id
	branch_definition = branch_def
	_apply_branch_behavior_if_needed(true)
	if has_method("set_level") and level > 0:
		set_level(level)
	return true

func get_branch_options() -> Array[WeaponBranchDefinition]:
	return DataHandler.read_weapon_branch_options(scene_file_path, fuse)

func _apply_branch_behavior_if_needed(force_refresh: bool = false) -> void:
	if branch_id == "":
		if force_refresh:
			_clear_branch_behavior()
		return
	if branch_definition == null or force_refresh:
		branch_definition = DataHandler.read_weapon_branch_definition(scene_file_path, branch_id)
	if branch_definition == null:
		if force_refresh:
			branch_id = ""
			_clear_branch_behavior()
		return
	if branch_definition.behavior_scene == null:
		if force_refresh:
			_clear_branch_behavior()
		return
	if branch_behavior == null:
		for child in get_children():
			var existing := child as WeaponBranchBehavior
			if existing:
				branch_behavior = existing
				branch_behavior.setup(self)
				break
	if branch_behavior and is_instance_valid(branch_behavior):
		if not force_refresh:
			return
		_clear_branch_behavior()
	var behavior_instance := branch_definition.behavior_scene.instantiate() as WeaponBranchBehavior
	if behavior_instance == null:
		push_warning("Weapon branch '%s' behavior is not WeaponBranchBehavior on weapon '%s'." % [branch_id, name])
		return
	branch_behavior = behavior_instance
	add_child(branch_behavior)
	branch_behavior.setup(self)
	branch_behavior.on_weapon_ready()

func _clear_branch_behavior() -> void:
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_removed()
		branch_behavior.queue_free()
	branch_behavior = null

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
	return max(1, int(round(get_runtime_stat_value("damage", base_damage_value))))

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
	_overheat_fire_bypass_sources.clear()
	_passive_icd_msec.clear()
	branch_behavior = null
	branch_definition = null

func set_weapon_role(next_role: String) -> void:
	var normalized := "main" if str(next_role).to_lower() == "main" else "offhand"
	if weapon_role == normalized:
		return
	weapon_role = normalized
	_on_weapon_role_changed(weapon_role)
	weapon_role_changed.emit(weapon_role)

func is_main_weapon() -> bool:
	return weapon_role == "main"

func is_offhand_weapon() -> bool:
	return weapon_role != "main"

func _on_weapon_role_changed(_next_role: String) -> void:
	pass

func can_run_active_behavior() -> bool:
	return is_main_weapon()

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
	passive_triggered.emit(event_name, detail)

func request_weapon_active() -> Dictionary:
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
