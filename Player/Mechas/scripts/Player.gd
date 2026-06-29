extends CharacterBody2D
class_name Player

const PLAYER_ASSIST_SYSTEM_SCRIPT := preload("res://Player/Mechas/scripts/player_assist_system.gd")
const PLAYER_ACTIVE_SKILL_RUNTIME_SCRIPT := preload("res://Player/Mechas/scripts/player_active_skill_runtime.gd")
const PLAYER_WEAPON_INVENTORY_RUNTIME_SCRIPT := preload("res://Player/Mechas/scripts/player_weapon_inventory_runtime.gd")
const PLAYER_WEAPON_PASSIVE_RUNTIME_SCRIPT := preload("res://Player/Mechas/scripts/player_weapon_passive_runtime.gd")

var extra_direction = Vector2.ZERO
@onready var equppied_weapons = $EquippedWeapons
@onready var equppied_augments = $EquippedAugments
@onready var mecha_sprite = $MechaSprite
@onready var mecha_move_sprite: AnimatedSprite2D = $MechaMoveSprite
@onready var player_camera: Camera2D = $Camera2D
@onready var collect_area = get_node("%CollectArea")
@onready var grab_area: Area2D = $GrabArea
@onready var grab_radius = $GrabArea/GrabShape
@onready var detect_area: Area2D = $DetectArea
@onready var detect_shape: CollisionShape2D = $DetectArea/CollisionShape2D
@onready var hurt_cd: Timer = $HurtCD
@onready var hurt_box: HurtBox = $HurtBox
@onready var hurt_box_shape_node: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var collision_cd: Timer = $CollisionCD
@onready var active_skill_holder: Node2D = $ActiveSkill


var movement_enabled = true
var moveto_enabled = false
var moveto_dest := Vector2.ZERO
var distance_mouse_player = 0
const TARGET_MECHA_SIZE = Vector2(96,96)
const MOVE_ANIMATION_TOP: StringName = &"move_top"
const MOVE_ANIMATION_BOTTOM: StringName = &"move_bottom"
const MECHA_DIRECTION_TEXTURES := {
	"top_left": preload("res://asset/images/characters/2b.png"),
	"bottom_left": preload("res://asset/images/characters/2f.png"),
	"top_right": preload("res://asset/images/characters/2b.png"),
	"bottom_right": preload("res://asset/images/characters/2f.png"),
}
var current_mecha_direction := ""
const ORBIT_RADIUS := Vector2(45, 30)
const ORBIT_ACCEL := 16.0
const ORBIT_MAX_SPEED := 8.0
const ORBIT_FRICTION := 6.0
const ORBIT_OFFSET := Vector2(0, -25)
const SCORCH_DURATION_SEC: float = 6.0
const SCORCH_DOT_RATIO_PER_STACK: float = 0.10
const SCORCH_DOT_TICK_SEC: float = 1.0
const FROST_DURATION_SEC: float = 6.0
const FROST_SLOW_PER_STACK: float = 0.04
const FROST_STACK_INTERVAL_SEC: float = 0.6
const FROST_MAX_STACKS: int = 5
const FROST_MOVE_SPEED_SOURCE: StringName = &"incoming_frost"
const HEAT_EXPANSION_END_CLAMP_RATIO: float = 0.8
const ENERGY_MARK_RATIO: float = 0.10
const ENERGY_MARK_DURATION_SEC: float = 6.0
const ENERGY_MARK_MAX_HP_RATIO: float = 0.40
const ENERGY_MARK_TRIGGER_COOLDOWN_SEC: float = 2.0
const AUTO_LOOT_DURATION_SEC: float = 2.0
const AUTO_LOOT_TICK_SEC: float = 0.2
const AUTO_LOOT_GRAB_RADIUS: float = 2500.0
const COLLECT_AREA_TOP_PADDING: float = 0.0
const HEAT_PREPARED_DAMAGE_SOURCE: StringName = &"heat_prepared_damage"
const HEAT_PREPARED_FLAT_DAMAGE_SOURCE: StringName = &"heat_prepared_flat_damage"
var weapon_orbit_states: Dictionary = {}
var _base_detect_shape_size := Vector2.ZERO
var _base_camera_zoom := Vector2.ONE
var _base_hurtbox_shape_size := Vector2.ZERO
var _base_hurtbox_shape_position := Vector2.ZERO
var _hurtbox_shape_base_cached: bool = false
var _incoming_damage_pipeline: DamagePipeline
var _incoming_damage_profile: DamageProfile
var _assist_system: RefCounted
enum MechaVisualState {
	IDLE,
	MOVING
}
var _mecha_visual_state: int = MechaVisualState.IDLE
var _last_mecha_facing_direction: Vector2 = Vector2(-1.0, 1.0)
var _current_move_animation: StringName = StringName()
var _last_visual_position: Vector2 = Vector2.ZERO
@export var camera_zoom_lerp_speed: float = 1.0
@export var battle_camera_view_mul: float = 0.8
@export var rest_phase_camera_zoom_factor: float = 1.4
@export var rest_camera_zoom_enter_duration: float = 0.42
@export var rest_camera_zoom_exit_duration: float = 0.30
@export var rest_camera_zoom_transition_enabled: bool = true
@export var move_accel: float = 2800.0
@export var move_decel: float = 3200.0
@export var move_turn_penalty: float = 0.15
@export var move_input_buffer_sec: float = 0.1
@export var camera_lookahead_distance: float = 18.0
@export var camera_lookahead_lerp_speed: float = 5.0
@export var camera_lookahead_min_speed_ratio: float = 0.2
@export var mecha_scale_reference_pixel_height: float = 1116.0
@export var idle_mecha_scale_multiplier: float = 0.7
@export var move_animation_scale_multiplier: float = 1.0
@export var face_axis_hysteresis: float = 0.08
@export var face_min_distance_px: float = 6.0
@export var move_anim_y_hysteresis: float = 0.08
@export var face_hysteresis_debug: bool = false
@export var hurtbox_bind_to_idle_sprite: bool = true
@export var elite_hit_slow_mul: float = 0.75
@export var elite_hit_slow_duration_sec: float = 0.06
@export var floating_hint_duration_sec: float = 1.0
@export var floating_hint_rise_px: float = 26.0
@export var reload_block_hint_interval_sec: float = 1.25
@export var status_hint_throttle_sec: float = 1.0
@export var status_hint_queue_interval_sec: float = 0.5
@export var default_active_skill_path: String = "res://Player/Skills/bullet_time"
@export var player_max_energy: float = 100.0
@export var player_energy_regen_per_sec: float = 8.0
@export var debug_weapon_passive_trigger_prints: bool = false
@export var debug_weapon_passive_trigger_event_prints: bool = false
var _last_phase: String = ""
var _board_generator_ref: Node = null
var _last_move_input_dir: Vector2 = Vector2.ZERO
var _last_move_input_msec: int = -1
var _last_face_horizontal_sign: int = -1
var _last_face_vertical_sign: int = 1
var _last_move_anim_is_top: bool = false
var _suppress_attack_until_released: bool = false
const ELITE_HIT_SLOW_SOURCE_ID: StringName = &"elite_hit_stagger"
var _tracked_weapon_exit_ids: Dictionary = {}
var _heat_prepared_until_msec: int = 0
var _heat_expansion_until_msec: int = 0
var _heat_expansion_max_mul: float = 1.0
var _plasma_lance_heat_feedback_until_msec: int = 0
var _plasma_lance_heat_feedback_threshold: float = 0.7
var _plasma_lance_heat_feedback_low_mul: float = 1.2
var _plasma_lance_heat_feedback_high_mul: float = 0.8
var PlayerData = null
var _weapon_inventory_runtime: RefCounted
var _weapon_passive_runtime: RefCounted
var _status_hint_manager
var _status_modifier_system
var _elemental_effect_system
var _movement_system: PlayerMovementSystem
var _camera_system: PlayerCameraSystem
var _shared_heat_system: PlayerSharedHeatSystem
var _loot_system: PlayerLootSystem
var _damage_reaction_system: PlayerDamageReactionSystem
var _active_skill_runtime: RefCounted
var _suppress_status_hints: bool = false
var _systems_strict_ready: bool = false
# Signals
@warning_ignore("unused_signal")
signal active_skill()
@warning_ignore("unused_signal")
signal player_active_skill()
@warning_ignore("unused_signal")
signal weapon_active_skill()
@warning_ignore("unused_signal")
signal coin_collected()

func _ensure_weapon_inventory_runtime() -> void:
	if _weapon_inventory_runtime == null:
		_weapon_inventory_runtime = PLAYER_WEAPON_INVENTORY_RUNTIME_SCRIPT.new()
	if _weapon_inventory_runtime != null:
		_weapon_inventory_runtime.setup(self)

func _ensure_weapon_passive_runtime() -> void:
	if _weapon_passive_runtime == null:
		_weapon_passive_runtime = PLAYER_WEAPON_PASSIVE_RUNTIME_SCRIPT.new()
	if _weapon_passive_runtime != null:
		_weapon_passive_runtime.setup(self)

func _ensure_active_skill_runtime() -> void:
	if _active_skill_runtime != null:
		_active_skill_runtime.setup(self)
		return
	_active_skill_runtime = PLAYER_ACTIVE_SKILL_RUNTIME_SCRIPT.new()
	if _active_skill_runtime != null:
		_active_skill_runtime.setup(self)

func _ready():
	PlayerData = get_node_or_null("/root/PlayerData")
	if PlayerData == null:
		push_error("PlayerData autoload missing.")
		return
	PlayerData.player = self
	_ensure_weapon_inventory_runtime()
	_ensure_weapon_passive_runtime()
	_connect_weapon_structure_signals()
	_incoming_damage_pipeline = DamagePipeline.new() as DamagePipeline
	_setup_incoming_damage_profile()
	_ensure_active_skill_runtime()
	_setup_default_active_skill()
	_ensure_input_actions()
	if _active_skill_runtime != null:
		_active_skill_runtime.reset_energy_to_max()
	mecha_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_resize_mecha_sprite()
	_setup_mecha_move_sprite()
	_last_visual_position = global_position
	_cache_camera_zoom_base()
	_cache_detect_shape_base()
	_update_vision_effect()
	_sync_weapon_orbit_states(true)
	update_grab_radius()
	custom_ready()
	_ensure_shared_heat_system()
	_rebuild_shared_heat_pool()
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))
	_last_phase = PhaseManager.current_state()
	var viewport := get_viewport()
	if viewport and not viewport.is_connected("size_changed", Callable(self, "_on_viewport_size_changed")):
		viewport.size_changed.connect(Callable(self, "_on_viewport_size_changed"))
	_update_collect_area_anchor_to_screen_top()
	_cache_hurtbox_shape_base()
	_sync_hurtbox_to_idle_sprite_scale()
	_ensure_status_hint_manager()
	_ensure_status_modifier_system()
	_ensure_elemental_effect_system()
	_ensure_damage_reaction_system()
	_ensure_movement_system()
	_ensure_camera_system()
	_ensure_loot_system()
	_ensure_assist_system()
	_systems_strict_ready = true
	if not _require_movement_system_or_halt():
		return
	if not _require_camera_system_or_halt():
		return
	_update_vision_effect()

# overwrite the function on child class
func custom_ready():
	create_weapon("1")

func _physics_process(delta):
	_refresh_weapon_structure_if_needed()
	_update_global_weapon_passives()
	_update_heat_statuses()
	_process_combat_input(delta)
	_update_shared_heat_pool(delta)
	_update_incoming_elemental_effects(delta)
	_regen_energy(delta)
	_update_passive_time_tick(delta)
	_update_collect_area_anchor_to_screen_top()
	if not _require_movement_system_or_halt():
		return
	_movement_system.tick(delta)
	move_and_slide()
	distance_mouse_player = get_global_mouse_position() - global_position
	_update_mecha_visual_state(distance_mouse_player)
	_update_weapon_orbits(delta)
	if not _require_camera_system_or_halt():
		return
	_camera_system.tick(delta)
	_update_collect_area_anchor_to_screen_top()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	_ensure_active_skill_runtime()
	if _active_skill_runtime != null:
		_active_skill_runtime.process_input_event(event)

func _setup_default_active_skill() -> void:
	_ensure_active_skill_runtime()
	if _active_skill_runtime != null:
		_active_skill_runtime.setup_default_active_skill()

func create_weapon(item_id, level := 1, auto_fuse := false):
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.create_weapon(item_id, level, auto_fuse)

func try_auto_fuse_weapon_obtain(weapon_id: String) -> Dictionary:
	_ensure_weapon_inventory_runtime()
	return _weapon_inventory_runtime.try_auto_fuse_weapon_obtain(weapon_id)

func predict_auto_fuse_weapon_obtain(weapon_id: String) -> Dictionary:
	_ensure_weapon_inventory_runtime()
	return _weapon_inventory_runtime.predict_auto_fuse_weapon_obtain(weapon_id)

func _has_branch_options_for_fuse(weapon: Weapon, target_fuse: int) -> bool:
	_ensure_weapon_inventory_runtime()
	return _weapon_inventory_runtime.has_branch_options_for_fuse(weapon, target_fuse)

func _find_equipped_weapon_by_id(weapon_id: String) -> Weapon:
	_ensure_weapon_inventory_runtime()
	return _weapon_inventory_runtime.find_equipped_weapon_by_id(weapon_id)

func _calculate_duplicate_weapon_gold(weapon_id: String) -> int:
	_ensure_weapon_inventory_runtime()
	return _weapon_inventory_runtime.calculate_duplicate_weapon_gold(weapon_id)

func _get_economy_config() -> EconomyConfig:
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data
	return EconomyConfig.new()

func _notify_weapon_duplicate_result(existing_weapon: Weapon, weapon_id: String, result: Dictionary) -> void:
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.notify_weapon_duplicate_result(existing_weapon, weapon_id, result)

func _refresh_weapon_related_ui() -> void:
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.refresh_weapon_related_ui()

func _try_prompt_branch_selection(weapon: Weapon, target_fuse: int = 0) -> void:
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.try_prompt_branch_selection(weapon, target_fuse)

func swap_weapon_position(weapon1, weapon2) -> void:
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.swap_weapon_position(weapon1, weapon2)

func _process_combat_input(delta: float) -> void:
	var main_weapon := get_main_weapon()
	if main_weapon == null:
		return
	var pressed := Input.is_action_pressed("ATTACK")
	var just_pressed := Input.is_action_just_pressed("ATTACK")
	var just_released := Input.is_action_just_released("ATTACK")
	if _suppress_attack_until_released:
		if pressed:
			pressed = false
			just_pressed = false
			just_released = false
		else:
			_suppress_attack_until_released = false
	if pressed:
		_try_show_reload_block_hint(main_weapon)
	var was_reloading_before_input := bool(main_weapon.get("is_reloading")) if main_weapon.get("is_reloading") != null else false
	var fired := false
	_ensure_assist_system()
	if _assist_system != null and pressed:
		_assist_system.process_combat_assist(main_weapon, true, delta)
	if main_weapon.has_method("handle_primary_input"):
		main_weapon.call("handle_primary_input", pressed, just_pressed, just_released, delta)
	elif pressed and main_weapon.has_method("request_primary_fire"):
		fired = bool(main_weapon.call("request_primary_fire"))
	if pressed and main_weapon.has_method("request_primary_fire"):
		fired = _did_manual_fire_start_reload(main_weapon, was_reloading_before_input)
	if _assist_system != null:
		if pressed:
			_assist_system.handle_post_fire(main_weapon, fired)
		else:
			_assist_system.process_combat_assist(main_weapon, pressed, delta)

func _try_show_reload_block_hint(main_weapon: Weapon) -> void:
	_ensure_active_skill_runtime()
	if _active_skill_runtime != null:
		_active_skill_runtime.try_show_reload_block_hint(main_weapon)

func _spawn_player_floating_hint(text: String) -> void:
	_ensure_status_hint_manager()
	if _status_hint_manager == null:
		return
	_status_hint_manager.enqueue_raw_hint(text)

func _spawn_keyed_player_floating_hint(text: String, hint_key: StringName, throttle_sec: float) -> void:
	_ensure_status_hint_manager()
	if _status_hint_manager == null:
		return
	if _status_hint_manager.has_method("enqueue_keyed_raw_hint"):
		_status_hint_manager.call("enqueue_keyed_raw_hint", text, hint_key, throttle_sec)
		return
	_status_hint_manager.enqueue_raw_hint(text)

func notify_weapon_status_change(stat_type: StringName, source_id: StringName, is_gain: bool) -> void:
	_notify_status_hint(&"weapon", stat_type, source_id, is_gain)

func _notify_status_hint(status_owner: StringName, stat_type: StringName, source_id: StringName, is_gain: bool) -> void:
	if _suppress_status_hints:
		return
	_ensure_status_hint_manager()
	if _status_hint_manager == null:
		return
	_status_hint_manager.notify_status_hint(status_owner, stat_type, source_id, is_gain)

func clear_timed_statuses_for_prepare() -> void:
	_suppress_status_hints = true
	if _status_hint_manager != null and is_instance_valid(_status_hint_manager):
		_status_hint_manager.clear_all()
	clear_global_weapon_passives()
	clear_heat_statuses()
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null and _elemental_effect_system.has_method("clear_timed_effects_for_prepare"):
		_elemental_effect_system.call("clear_timed_effects_for_prepare")
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if weapon.has_method("clear_timed_effects_for_prepare"):
			weapon.call("clear_timed_effects_for_prepare")
	_suppress_status_hints = false

func _ensure_status_hint_manager() -> void:
	if _status_hint_manager != null and is_instance_valid(_status_hint_manager):
		_status_hint_manager.setup(
			self,
			floating_hint_duration_sec,
			floating_hint_rise_px,
			status_hint_throttle_sec,
			status_hint_queue_interval_sec
		)
		return
	_status_hint_manager = FloatingStatusHintManager.new() as FloatingStatusHintManager
	if _status_hint_manager == null:
		return
	_status_hint_manager.name = "FloatingStatusHintManager"
	add_child(_status_hint_manager)
	_status_hint_manager.setup(
		self,
		floating_hint_duration_sec,
		floating_hint_rise_px,
		status_hint_throttle_sec,
		status_hint_queue_interval_sec
	)

func _ensure_status_modifier_system() -> void:
	if _status_modifier_system != null:
		_status_modifier_system.setup(self)
		return
	_status_modifier_system = PlayerStatusModifierSystem.new()
	if _status_modifier_system == null:
		return
	_status_modifier_system.setup(self)

func _ensure_elemental_effect_system() -> void:
	if _elemental_effect_system == null:
		_elemental_effect_system = PlayerElementalEffectSystem.new()
	if _elemental_effect_system == null:
		return
	_elemental_effect_system.setup(self)
	_elemental_effect_system.configure(
		SCORCH_DURATION_SEC,
		SCORCH_DOT_RATIO_PER_STACK,
		FROST_DURATION_SEC,
		FROST_SLOW_PER_STACK,
		FROST_STACK_INTERVAL_SEC,
		FROST_MAX_STACKS,
		FROST_MOVE_SPEED_SOURCE,
		ENERGY_MARK_RATIO,
		ENERGY_MARK_DURATION_SEC,
		ENERGY_MARK_MAX_HP_RATIO,
		ENERGY_MARK_TRIGGER_COOLDOWN_SEC
	)

func _ensure_assist_system() -> void:
	if _assist_system == null:
		_assist_system = PLAYER_ASSIST_SYSTEM_SCRIPT.new()
	if _assist_system != null:
		_assist_system.setup(self)

func _did_manual_fire_start_reload(main_weapon: Weapon, was_reloading_before_input: bool) -> bool:
	if main_weapon == null or not is_instance_valid(main_weapon):
		return false
	if not main_weapon.has_method("uses_ammo_system") or not bool(main_weapon.call("uses_ammo_system")):
		return false
	if was_reloading_before_input:
		return false
	return bool(main_weapon.get("is_reloading"))

func _refresh_weapon_structure_if_needed() -> void:
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.refresh_weapon_structure_if_needed()

func _sanitize_weapon_list() -> bool:
	_ensure_weapon_inventory_runtime()
	return _weapon_inventory_runtime.sanitize_weapon_list()

func _mark_weapon_structure_dirty(force_orbit_reset := false) -> void:
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.mark_weapon_structure_dirty(force_orbit_reset)

func _mark_weapon_roles_dirty() -> void:
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.mark_weapon_roles_dirty()

func _connect_weapon_structure_signals() -> void:
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.connect_weapon_structure_signals()

func _disconnect_weapon_structure_signals() -> void:
	if _weapon_inventory_runtime != null:
		_weapon_inventory_runtime.disconnect_weapon_structure_signals()

func _on_player_weapon_list_changed() -> void:
	_mark_weapon_structure_dirty(true)

func _on_main_weapon_index_changed(_old_index: int, _new_index: int, _step: int) -> void:
	_mark_weapon_roles_dirty()

func _sync_tracked_weapon_exit_signals() -> void:
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.sync_tracked_weapon_exit_signals()

func _on_tracked_weapon_tree_exiting(instance_id: int) -> void:
	if _weapon_inventory_runtime != null:
		_weapon_inventory_runtime.on_tracked_weapon_tree_exiting(instance_id)

func _apply_weapon_roles() -> void:
	_ensure_weapon_inventory_runtime()
	_weapon_inventory_runtime.apply_weapon_roles()

func get_main_weapon() -> Weapon:
	_ensure_weapon_inventory_runtime()
	return _weapon_inventory_runtime.get_main_weapon()

func get_offhand_weapons() -> Array:
	_ensure_weapon_inventory_runtime()
	return _weapon_inventory_runtime.get_offhand_weapons()

func can_switch_main_weapon() -> bool:
	_ensure_weapon_inventory_runtime()
	return _weapon_inventory_runtime.can_switch_main_weapon()

func try_shift_main_weapon(step: int) -> bool:
	_ensure_weapon_inventory_runtime()
	return _weapon_inventory_runtime.try_shift_main_weapon(step)

func mark_weapon_roles_dirty_for_assist() -> void:
	_mark_weapon_roles_dirty()

func refresh_weapon_structure_for_assist() -> void:
	_refresh_weapon_structure_if_needed()

func broadcast_weapon_passive_event_for_assist(event_name: StringName, detail: Dictionary = {}) -> void:
	_broadcast_weapon_passive_event(event_name, detail)

func _broadcast_weapon_passive_event(event_name: StringName, detail: Dictionary = {}) -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.broadcast_weapon_passive_event(event_name, detail)

func apply_global_weapon_passive_effect(source_id: StringName, stat_type: StringName, multiplier: float, duration_sec: float = 0.0, source_weapon: Weapon = null, include_source_weapon: bool = true) -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.apply_global_weapon_passive_effect(source_id, stat_type, multiplier, duration_sec, source_weapon, include_source_weapon)

func remove_global_weapon_passive_effect(source_id: StringName) -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.remove_global_weapon_passive_effect(source_id)

func clear_global_weapon_passives() -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.clear_global_weapon_passives()

func _update_global_weapon_passives() -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.update_global_weapon_passives()

func _sync_global_weapon_passive_source(source_id: StringName) -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.sync_global_weapon_passive_source(source_id)

func _apply_global_weapon_passive_to_weapon(source_id: StringName, effect: Dictionary, weapon: Weapon) -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.apply_global_weapon_passive_to_weapon(source_id, effect, weapon)

func _remove_global_weapon_passive_source(source_id: StringName) -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.remove_global_weapon_passive_source(source_id)

func _remove_global_weapon_passive_from_weapon(source_id: StringName, stat_type: StringName, weapon: Weapon) -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.remove_global_weapon_passive_from_weapon(source_id, stat_type, weapon)

func _effect_source_weapon_equals(effect: Dictionary, weapon: Weapon) -> bool:
	_ensure_weapon_passive_runtime()
	return _weapon_passive_runtime.effect_source_weapon_equals(effect, weapon)

func _effect_source_weapon_is_stale(effect: Dictionary) -> bool:
	_ensure_weapon_passive_runtime()
	return _weapon_passive_runtime.effect_source_weapon_is_stale(effect)

func _resolve_weapon_runtime_damage_for_global_effect(weapon: Weapon) -> int:
	_ensure_weapon_passive_runtime()
	return _weapon_passive_runtime.resolve_weapon_runtime_damage_for_global_effect(weapon)

func _debug_connect_weapon_passive_triggers() -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.debug_connect_weapon_passive_triggers()

func _debug_on_weapon_passive_triggered(event_name: StringName, detail: Dictionary, weapon: Weapon) -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.debug_on_weapon_passive_triggered(event_name, detail, weapon)

func _debug_is_weapon_passive_trigger_event(event_name: StringName) -> bool:
	_ensure_weapon_passive_runtime()
	return _weapon_passive_runtime.debug_is_weapon_passive_trigger_event(event_name)

func _update_passive_time_tick(delta: float) -> void:
	_ensure_weapon_passive_runtime()
	_weapon_passive_runtime.update_passive_time_tick(delta)

func notify_enemy_killed_nearby(enemy: Node = null) -> void:
	_broadcast_weapon_passive_event(&"on_enemy_killed_nearby", {
		"enemy": enemy
	})

func _try_cast_player_active_skill() -> void:
	_ensure_active_skill_runtime()
	if _active_skill_runtime != null:
		_active_skill_runtime.try_cast_player_active_skill()

func _try_cast_main_weapon_active_skill() -> void:
	_ensure_active_skill_runtime()
	if _active_skill_runtime != null:
		_active_skill_runtime.try_cast_main_weapon_active_skill()

func _try_reload_main_weapon() -> void:
	_ensure_active_skill_runtime()
	if _active_skill_runtime != null:
		_active_skill_runtime.try_reload_main_weapon()

func _ensure_input_actions() -> void:
	_ensure_active_skill_runtime()
	if _active_skill_runtime != null:
		_active_skill_runtime.ensure_input_actions()

func get_current_energy() -> float:
	_ensure_active_skill_runtime()
	if _active_skill_runtime == null:
		return player_max_energy
	return _active_skill_runtime.get_current_energy()

func get_max_energy() -> float:
	_ensure_active_skill_runtime()
	if _active_skill_runtime == null:
		return maxf(player_max_energy, 1.0)
	return _active_skill_runtime.get_max_energy()

func consume_energy(amount: float) -> bool:
	_ensure_active_skill_runtime()
	if _active_skill_runtime == null:
		return false
	return _active_skill_runtime.consume_energy(amount)

func add_energy(amount: float) -> void:
	_ensure_active_skill_runtime()
	if _active_skill_runtime != null:
		_active_skill_runtime.add_energy(amount)

func _regen_energy(delta: float) -> void:
	_ensure_active_skill_runtime()
	if _active_skill_runtime != null:
		_active_skill_runtime.regen_energy(delta)

func get_last_weapon_skill_fail_reason() -> String:
	_ensure_active_skill_runtime()
	if _active_skill_runtime == null:
		return ""
	return _active_skill_runtime.get_last_weapon_skill_fail_reason()

func get_weapon_active_cd_remaining() -> float:
	_ensure_active_skill_runtime()
	if _active_skill_runtime == null:
		return 0.0
	return _active_skill_runtime.get_weapon_active_cd_remaining()

func get_weapon_active_cd_ratio() -> float:
	_ensure_active_skill_runtime()
	if _active_skill_runtime == null:
		return 0.0
	return _active_skill_runtime.get_weapon_active_cd_ratio()

func apply_move_speed_mul(source_id: StringName, mul: float) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return
	_status_modifier_system.apply_move_speed_mul(source_id, mul)

func remove_move_speed_mul(source_id: StringName) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return
	_status_modifier_system.remove_move_speed_mul(source_id)

func get_total_move_speed_mul() -> float:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return 1.0
	return _status_modifier_system.get_total_move_speed_mul()

func apply_vision_mul(source_id: StringName, mul: float) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return
	_status_modifier_system.apply_vision_mul(source_id, mul)
	_update_vision_effect()

func remove_vision_mul(source_id: StringName) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system != null:
		_status_modifier_system.remove_vision_mul(source_id)
	_update_vision_effect()

func get_total_vision_mul() -> float:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return 1.0
	return _status_modifier_system.get_total_vision_mul()

func apply_damage_mul(source_id: StringName, mul: float) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return
	_status_modifier_system.apply_damage_mul(source_id, mul)

func remove_damage_mul(source_id: StringName) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return
	_status_modifier_system.remove_damage_mul(source_id)

func apply_heat_prepared(duration_sec: float = 10.0, damage_mul: float = 1.05, flat_damage_bonus: int = 1) -> void:
	var duration_msec := int(maxf(duration_sec, 0.05) * 1000.0)
	_heat_prepared_until_msec = Time.get_ticks_msec() + duration_msec
	apply_damage_mul(HEAT_PREPARED_DAMAGE_SOURCE, maxf(damage_mul, 0.05))
	apply_global_weapon_passive_effect(HEAT_PREPARED_FLAT_DAMAGE_SOURCE, &"damage_flat", float(maxi(flat_damage_bonus, 0)), duration_sec)
	_spawn_player_floating_hint("Heat Prepared")
	if debug_weapon_passive_trigger_prints:
		print("[HeatStatus] Heat Prepared duration=", duration_sec, " damage_mul=", damage_mul, " flat_damage=", flat_damage_bonus)

func has_heat_prepared() -> bool:
	return _heat_prepared_until_msec > 0 and Time.get_ticks_msec() < _heat_prepared_until_msec

func consume_heat_prepared() -> bool:
	_update_heat_statuses()
	if not has_heat_prepared():
		return false
	return true

func apply_heat_expansion(duration_sec: float = 8.0, max_heat_mul: float = 2.0) -> bool:
	var duration_msec := int(maxf(duration_sec, 0.05) * 1000.0)
	_update_heat_statuses()
	var was_active := has_heat_expansion()
	_heat_expansion_until_msec = Time.get_ticks_msec() + duration_msec
	_heat_expansion_max_mul = maxf(max_heat_mul, 1.0)
	_apply_heat_expansion_pool_multiplier(not was_active)
	_clamp_heat_expansion_to_soft_cap()
	_spawn_player_floating_hint("Heat Expansion")
	if debug_weapon_passive_trigger_prints:
		print("[HeatStatus] Heat Expansion duration=", duration_sec, " max_heat_mul=", _heat_expansion_max_mul, " scaled_current_heat=", not was_active)
	return not was_active

func has_heat_expansion() -> bool:
	return _heat_expansion_until_msec > 0 and Time.get_ticks_msec() < _heat_expansion_until_msec

func get_heat_expansion_max_multiplier() -> float:
	_update_heat_statuses()
	if not has_heat_expansion():
		return 1.0
	return _heat_expansion_max_mul

func has_heat_stabilized() -> bool:
	return has_heat_expansion()

func get_heat_stabilized_decay_mul() -> float:
	return 1.0

func get_heat_stabilized_cost_mul() -> float:
	return 1.0

func apply_plasma_lance_heat_feedback(duration_sec: float = 10.0, low_mul: float = 1.2, high_mul: float = 0.8, threshold: float = 0.7) -> void:
	var duration_msec := int(maxf(duration_sec, 0.05) * 1000.0)
	_plasma_lance_heat_feedback_until_msec = Time.get_ticks_msec() + duration_msec
	_plasma_lance_heat_feedback_low_mul = maxf(low_mul, 0.0)
	_plasma_lance_heat_feedback_high_mul = maxf(high_mul, 0.0)
	_plasma_lance_heat_feedback_threshold = clampf(threshold, 0.0, 1.0)
	_spawn_player_floating_hint("Heat Feedback")
	if debug_weapon_passive_trigger_prints:
		print("[HeatStatus] Plasma Lance Heat Feedback duration=", duration_sec, " threshold=", _plasma_lance_heat_feedback_threshold, " low_mul=", _plasma_lance_heat_feedback_low_mul, " high_mul=", _plasma_lance_heat_feedback_high_mul)

func has_plasma_lance_heat_feedback() -> bool:
	return _plasma_lance_heat_feedback_until_msec > 0 and Time.get_ticks_msec() < _plasma_lance_heat_feedback_until_msec

func get_plasma_lance_heat_feedback_remaining_sec() -> float:
	_update_heat_statuses()
	if not has_plasma_lance_heat_feedback():
		return 0.0
	return maxf(float(_plasma_lance_heat_feedback_until_msec - Time.get_ticks_msec()) / 1000.0, 0.0)

func get_heat_gain_multiplier() -> float:
	_update_heat_statuses()
	if not has_plasma_lance_heat_feedback():
		return 1.0
	var heat_ratio := get_total_heat_ratio()
	if heat_ratio <= _plasma_lance_heat_feedback_threshold:
		return _plasma_lance_heat_feedback_low_mul
	return _plasma_lance_heat_feedback_high_mul

func consume_shared_heat(amount: float) -> float:
	var spend_amount := maxf(amount, 0.0)
	if spend_amount <= 0.0:
		return 0.0
	var pool := get_shared_heat_pool()
	if pool == null:
		return 0.0
	var available := maxf(float(pool.heat_value), 0.0)
	var spent := minf(available, spend_amount)
	pool.heat_value = maxf(0.0, available - spent)
	if pool.heat_value < pool.max_heat:
		pool.overheated = false
	return spent

func clear_heat_statuses() -> void:
	_clear_heat_prepared()
	_end_heat_expansion(true)
	_plasma_lance_heat_feedback_until_msec = 0
	_plasma_lance_heat_feedback_threshold = 0.7
	_plasma_lance_heat_feedback_low_mul = 1.2
	_plasma_lance_heat_feedback_high_mul = 0.8

func _update_heat_statuses() -> void:
	var now_msec := Time.get_ticks_msec()
	if _heat_prepared_until_msec > 0 and now_msec >= _heat_prepared_until_msec:
		_clear_heat_prepared()
	if _heat_expansion_until_msec > 0 and now_msec >= _heat_expansion_until_msec:
		_end_heat_expansion(false)
	if _plasma_lance_heat_feedback_until_msec > 0 and now_msec >= _plasma_lance_heat_feedback_until_msec:
		_plasma_lance_heat_feedback_until_msec = 0

func _apply_heat_expansion_pool_multiplier(scale_current_heat: bool) -> void:
	_ensure_shared_heat_system()
	if _shared_heat_system == null:
		return
	_shared_heat_system.set_heat_max_multiplier(_heat_expansion_max_mul, scale_current_heat, true)

func _end_heat_expansion(clear_heat_value: bool) -> void:
	var had_expansion := _heat_expansion_until_msec > 0 or _heat_expansion_max_mul > 1.0
	_heat_expansion_until_msec = 0
	_heat_expansion_max_mul = 1.0
	if not had_expansion:
		return
	_ensure_shared_heat_system()
	if _shared_heat_system == null:
		return
	_shared_heat_system.set_heat_max_multiplier(1.0, false, true)
	var pool := get_shared_heat_pool()
	if pool == null:
		return
	if clear_heat_value:
		pool.heat_value = 0.0
		pool.overheated = false
		return
	_clamp_heat_expansion_to_soft_cap()

func _clamp_heat_expansion_to_soft_cap() -> void:
	var pool := get_shared_heat_pool()
	if pool == null:
		return
	var cap := maxf(float(pool.max_heat) * HEAT_EXPANSION_END_CLAMP_RATIO, 0.0)
	if float(pool.heat_value) > cap:
		pool.heat_value = cap
		pool.overheated = false

func _clear_heat_prepared() -> void:
	if _heat_prepared_until_msec <= 0:
		return
	_heat_prepared_until_msec = 0
	remove_damage_mul(HEAT_PREPARED_DAMAGE_SOURCE)
	remove_global_weapon_passive_effect(HEAT_PREPARED_FLAT_DAMAGE_SOURCE)

func register_low_hp_damage_bonus(source_id: StringName, min_hp_ratio: float, max_damage_mul: float) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return
	_status_modifier_system.register_low_hp_damage_bonus(source_id, min_hp_ratio, max_damage_mul)

func remove_low_hp_damage_bonus(source_id: StringName) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system != null:
		_status_modifier_system.remove_low_hp_damage_bonus(source_id)

func register_bonus_hit(source_id: StringName, chance: float, damage: int) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return
	_status_modifier_system.register_bonus_hit(source_id, chance, damage)

func remove_bonus_hit(source_id: StringName) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system != null:
		_status_modifier_system.remove_bonus_hit(source_id)

func register_loot_bonus(source_id: StringName, coin_chance: float, chip_chance: float, multiplier: int) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return
	_status_modifier_system.register_loot_bonus(source_id, coin_chance, chip_chance, multiplier)

func remove_loot_bonus(source_id: StringName) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system != null:
		_status_modifier_system.remove_loot_bonus(source_id)

func compute_outgoing_damage(base_damage: int) -> int:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return max(1, base_damage)
	return _status_modifier_system.compute_outgoing_damage(base_damage)

func apply_bonus_hit_if_needed(target: Node) -> void:
	_ensure_status_modifier_system()
	if _status_modifier_system != null:
		_status_modifier_system.apply_bonus_hit_if_needed(target)

func apply_loot_bonus(value: int, loot_type: StringName) -> int:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return max(0, value)
	return _status_modifier_system.apply_loot_bonus(value, loot_type)

func _get_low_hp_damage_mul() -> float:
	_ensure_status_modifier_system()
	if _status_modifier_system == null:
		return 1.0
	return _status_modifier_system.get_low_hp_damage_mul()


func start_auto_nav(dest: Vector2) -> void:
	if not _require_movement_system_or_halt():
		return
	_movement_system.start_auto_nav(dest)

func stop_auto_nav() -> void:
	if not _require_movement_system_or_halt():
		return
	_movement_system.stop_auto_nav()

func is_auto_nav_active() -> bool:
	if not _require_movement_system_or_halt():
		return false
	return _movement_system.is_auto_navigating()

func configure_auto_nav_speed_mul(speed_mul: float) -> void:
	if not _require_movement_system_or_halt():
		return
	_movement_system.configure_auto_nav_speed_mul(speed_mul)

func set_restarea_camera_control_enabled(enabled: bool, snap_target: Vector2 = Vector2.ZERO, snap_now: bool = false) -> void:
	if not _require_camera_system_or_halt():
		return
	_camera_system.set_restarea_control_enabled(enabled, snap_target, snap_now)

func move_restarea_camera_to(target_global: Vector2, speed_mul: float = 1.0) -> void:
	if not _require_camera_system_or_halt():
		return
	_camera_system.move_restarea_camera_to(target_global, speed_mul)

func configure_restarea_camera_motion(min_speed: float, max_speed: float, speed_curve: float) -> void:
	if not _require_camera_system_or_halt():
		return
	_camera_system.configure_restarea_camera_motion(min_speed, max_speed, speed_curve)

func is_restarea_camera_close_to(target_global: Vector2, tolerance: float) -> bool:
	if not _require_camera_system_or_halt():
		return false
	return _camera_system.is_restarea_camera_close_to(target_global, tolerance)

func get_restarea_camera_world_position() -> Vector2:
	if not _require_camera_system_or_halt():
		return global_position
	return _camera_system.get_camera_world_position()

func request_camera_shake(amount: float, source_global_position: Vector2 = Vector2.ZERO, max_distance: float = 900.0) -> void:
	if not _require_camera_system_or_halt():
		return
	_camera_system.request_camera_shake(amount, source_global_position, max_distance)

func get_camera_shake_trauma() -> float:
	if not _require_camera_system_or_halt():
		return 0.0
	return _camera_system.get_camera_shake_trauma()

func force_recover_battle_camera_zoom() -> void:
	if not _require_camera_system_or_halt():
		return
	var vision_mul := maxf(get_total_vision_mul(), 0.05)
	var battle_view_mul := maxf(battle_camera_view_mul, 0.05)
	var target_zoom := _base_camera_zoom * (1.0 / (vision_mul * battle_view_mul))
	_camera_system.force_zoom_now(target_zoom)

func update_grab_radius() -> void:
	grab_radius.shape.radius = PlayerData.total_grab_radius

func _cache_detect_shape_base() -> void:
	if detect_shape == null:
		return
	var rect := detect_shape.shape as RectangleShape2D
	if rect:
		_base_detect_shape_size = rect.size

func _cache_camera_zoom_base() -> void:
	if player_camera == null:
		return
	_base_camera_zoom = player_camera.zoom

func _update_vision_effect() -> void:
	var vision_mul := get_total_vision_mul()
	if detect_shape:
		var rect := detect_shape.shape as RectangleShape2D
		if rect:
			if _base_detect_shape_size == Vector2.ZERO:
				_base_detect_shape_size = rect.size
			rect.size = _base_detect_shape_size * vision_mul
	_update_camera_zoom_by_vision(vision_mul)
	if detect_area:
		detect_area.force_update_transform()
		_refresh_detected_enemies()

func _update_camera_zoom_by_vision(vision_mul: float) -> void:
	if not _require_camera_system_or_halt():
		return
	_camera_system.update_zoom_target_by_vision(vision_mul)

func _resolve_buffered_move_input() -> Vector2:
	var x_mov := Input.get_action_strength("RIGHT") - Input.get_action_strength("LEFT")
	var y_mov := Input.get_action_strength("DOWN") - Input.get_action_strength("UP")
	var raw_input := Vector2(x_mov, y_mov)
	var now_msec := Time.get_ticks_msec()
	if raw_input.length_squared() > 0.0001:
		_last_move_input_dir = raw_input.normalized()
		_last_move_input_msec = now_msec
		return raw_input
	if _last_move_input_msec > 0:
		var age_sec := float(now_msec - _last_move_input_msec) / 1000.0
		if age_sec <= maxf(move_input_buffer_sec, 0.0):
			return _last_move_input_dir
	return Vector2.ZERO

func _on_viewport_size_changed() -> void:
	_update_collect_area_anchor_to_screen_top()

func _get_board_generator() -> Node:
	if _board_generator_ref != null and is_instance_valid(_board_generator_ref):
		return _board_generator_ref
	var scene_root := get_tree().current_scene
	if scene_root:
		_board_generator_ref = scene_root.get_node_or_null("Board")
	return _board_generator_ref

func _constrain_to_board_traversable_area() -> void:
	var board := _get_board_generator()
	if board == null:
		return
	if not board.has_method("project_point_to_player_traversable_area"):
		return
	var projected: Variant = board.call("project_point_to_player_traversable_area", global_position)
	if not (projected is Vector2):
		return
	var projected_pos: Vector2 = projected as Vector2
	if projected_pos.distance_squared_to(global_position) <= 0.25:
		return
	global_position = projected_pos
	velocity = Vector2.ZERO

func _update_collect_area_anchor_to_screen_top() -> void:
	if collect_area == null or not is_instance_valid(collect_area):
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var world_top_left: Vector2 = viewport.get_canvas_transform().affine_inverse() * Vector2.ZERO
	var target_global := Vector2(
		global_position.x,
		world_top_left.y + COLLECT_AREA_TOP_PADDING
	)
	collect_area.global_position = target_global

func _refresh_detected_enemies() -> void:
	if detect_area == null:
		return
	var valid: Array = []
	for area in detect_area.get_overlapping_areas():
		if area and area.get_collision_layer_value(3):
			valid.append(area)
	PlayerData.detected_enemies = valid
	PlayerData.cloestest_enemy = get_closest_area_optimized(valid, self)

func _resize_mecha_sprite() -> void:
	if not mecha_sprite or not mecha_sprite.texture:
		return
	var tex_size: Vector2 = mecha_sprite.texture.get_size()
	if tex_size.x == 0 or tex_size.y == 0:
		return
	var uniform_scale := _get_mecha_uniform_scale()
	mecha_sprite.scale = Vector2.ONE * uniform_scale * clampf(idle_mecha_scale_multiplier, 0.1, 3.0)
	_sync_hurtbox_to_idle_sprite_scale()

func _setup_mecha_move_sprite() -> void:
	if mecha_move_sprite == null:
		push_warning("MechaMoveSprite is missing, movement animation disabled.")
		return
	mecha_move_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if mecha_move_sprite.sprite_frames == null:
		push_warning("MechaMoveSprite missing SpriteFrames resource.")
		return
	_resize_mecha_move_sprite(MOVE_ANIMATION_BOTTOM)
	_set_mecha_visual_state(MechaVisualState.IDLE)
	_update_mecha_direction(_last_mecha_facing_direction)

func _resize_mecha_move_sprite(animation_name: StringName) -> void:
	if mecha_move_sprite == null or mecha_move_sprite.sprite_frames == null:
		return
	var frames := mecha_move_sprite.sprite_frames
	if not frames.has_animation(animation_name):
		return
	if frames.get_frame_count(animation_name) <= 0:
		return
	var tex := frames.get_frame_texture(animation_name, 0)
	if tex == null:
		return
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x == 0 or tex_size.y == 0:
		return
	var uniform_scale := _get_mecha_uniform_scale()
	mecha_move_sprite.scale = Vector2.ONE * uniform_scale * clampf(move_animation_scale_multiplier, 0.1, 3.0)

func _get_mecha_uniform_scale() -> float:
	var ref_height := maxf(mecha_scale_reference_pixel_height, 1.0)
	return TARGET_MECHA_SIZE.y / ref_height

func _cache_hurtbox_shape_base() -> void:
	if _hurtbox_shape_base_cached:
		return
	if hurt_box_shape_node == null or not is_instance_valid(hurt_box_shape_node):
		return
	var rect_shape := hurt_box_shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	_base_hurtbox_shape_size = rect_shape.size
	_base_hurtbox_shape_position = hurt_box_shape_node.position
	_hurtbox_shape_base_cached = true

func _sync_hurtbox_to_idle_sprite_scale() -> void:
	if not hurtbox_bind_to_idle_sprite:
		return
	if mecha_sprite == null or not is_instance_valid(mecha_sprite):
		return
	_cache_hurtbox_shape_base()
	if not _hurtbox_shape_base_cached:
		return
	if hurt_box_shape_node == null or not is_instance_valid(hurt_box_shape_node):
		return
	var rect_shape := hurt_box_shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	var idle_scale: Vector2 = mecha_sprite.scale
	rect_shape.size = Vector2(
		_base_hurtbox_shape_size.x * idle_scale.x,
		_base_hurtbox_shape_size.y * idle_scale.y
	)
	hurt_box_shape_node.position = Vector2(
		_base_hurtbox_shape_position.x * idle_scale.x,
		_base_hurtbox_shape_position.y * idle_scale.y
	)

func _update_mecha_visual_state(direction: Vector2) -> void:
	var position_delta := global_position - _last_visual_position
	var moved_by_external_position := position_delta.length_squared() > 0.25
	var facing_direction := direction
	if moved_by_external_position and velocity.length_squared() <= 0.0001:
		facing_direction = position_delta
	if facing_direction == Vector2.ZERO:
		facing_direction = _last_mecha_facing_direction
	else:
		_last_mecha_facing_direction = facing_direction

	var is_auto_moving := moveto_enabled and global_position.distance_squared_to(moveto_dest) > 0.25
	var is_moving := velocity.length_squared() > 0.0001 or is_auto_moving or moved_by_external_position
	var target_state := MechaVisualState.MOVING if is_moving else MechaVisualState.IDLE
	_set_mecha_visual_state(target_state)

	if target_state == MechaVisualState.MOVING:
		_update_mecha_move_animation(facing_direction)
	else:
		_update_mecha_direction(facing_direction)
	_last_visual_position = global_position

func _set_mecha_visual_state(next_state: int) -> void:
	if _mecha_visual_state == next_state and mecha_sprite != null and mecha_move_sprite != null:
		return
	_mecha_visual_state = next_state
	var is_idle := _mecha_visual_state == MechaVisualState.IDLE
	if mecha_sprite != null:
		mecha_sprite.visible = is_idle
	if mecha_move_sprite != null:
		mecha_move_sprite.visible = not is_idle
		if is_idle:
			mecha_move_sprite.stop()

func _update_mecha_move_animation(direction: Vector2) -> void:
	if mecha_move_sprite == null:
		return
	mecha_move_sprite.flip_h = direction.x > 0.0
	var y_threshold: float = clampf(move_anim_y_hysteresis, 0.0, 0.5)
	var next_is_top := _last_move_anim_is_top
	if _last_move_anim_is_top:
		if direction.y > y_threshold:
			next_is_top = false
	else:
		if direction.y < -y_threshold:
			next_is_top = true
	_last_move_anim_is_top = next_is_top
	var animation_name: StringName = MOVE_ANIMATION_TOP if next_is_top else MOVE_ANIMATION_BOTTOM
	if _current_move_animation != animation_name:
		_current_move_animation = animation_name
		mecha_move_sprite.play(animation_name)
		_resize_mecha_move_sprite(animation_name)
		return
	if not mecha_move_sprite.is_playing():
		mecha_move_sprite.play(animation_name)

func _sync_weapon_orbit_states(force_reset := false) -> void:
	var weapons: Array = PlayerData.player_weapon_list
	var total: int = max(weapons.size(), 1)
	var base_angle := _get_mouse_angle()
	var formations := _get_formation_angle_offsets(weapons.size())
	for weapon_index in range(weapons.size()):
		var weapon = weapons[weapon_index]
		if not is_instance_valid(weapon):
			continue
		_attach_weapon_to_equipped_holder(weapon)
		var offset := TAU * float(weapon_index) / float(total)
		if weapon_index < formations.size():
			offset = formations[weapon_index]
		var state: Dictionary = weapon_orbit_states.get(weapon, {})
		if state.is_empty():
			state = {"angle": base_angle + offset, "velocity": 0.0, "offset": offset}
			weapon_orbit_states[weapon] = state
		else:
			if force_reset:
				state["angle"] = base_angle + offset
				state["velocity"] = 0.0
			state["offset"] = offset
	_remove_missing_weapon_states(weapons)

func _attach_weapon_to_equipped_holder(weapon: Weapon) -> void:
	if weapon.get_parent() == equppied_weapons:
		return
	if weapon.get_parent():
		weapon.reparent(equppied_weapons)
	else:
		equppied_weapons.add_child(weapon)

func _update_weapon_orbits(delta: float) -> void:
	if PlayerData.player_weapon_list.is_empty():
		return
	var base_angle := _get_mouse_angle()
	for weapon in PlayerData.player_weapon_list:
		if not is_instance_valid(weapon):
			continue
		var state: Dictionary = weapon_orbit_states.get(weapon, {})
		if state.is_empty():
			continue
		var current_angle: float = state.get("angle", base_angle)
		var angular_velocity: float = state.get("velocity", 0.0)
		var offset: float = state.get("offset", 0.0)
		var target_angle := wrapf(base_angle + offset, -PI, PI)
		var angle_diff := _shortest_angle(current_angle, target_angle)
		angular_velocity += clamp(angle_diff * ORBIT_ACCEL, -ORBIT_ACCEL, ORBIT_ACCEL) * delta
		angular_velocity = clamp(angular_velocity, -ORBIT_MAX_SPEED, ORBIT_MAX_SPEED)
		angular_velocity = lerp(angular_velocity, 0.0, clamp(ORBIT_FRICTION * delta, 0.0, 1.0))
		current_angle = wrapf(current_angle + angular_velocity * delta, -PI, PI)
		state["angle"] = current_angle
		state["velocity"] = angular_velocity
		weapon.position = _get_orbit_position(current_angle)

func _remove_missing_weapon_states(valid_weapons: Array) -> void:
	var to_remove: Array = []
	for weapon in weapon_orbit_states.keys():
		if not valid_weapons.has(weapon) or not is_instance_valid(weapon):
			to_remove.append(weapon)
	for weapon in to_remove:
		weapon_orbit_states.erase(weapon)

func _get_formation_angle_offsets(count: int) -> Array:
	match count:
		1:
			return [PI]
		2:
			return [PI / 2, -PI / 2]
		3:
			return [PI / 2, -PI / 2, PI]
		4:
			return [
				PI / 4,         # front left
				-PI / 4,        # front right
				PI - PI / 4,    # back left
				-PI + PI / 4    # back right
			]
		_:
			var offsets: Array = []
			if count <= 0:
				return offsets
			for i in range(count):
				offsets.append(TAU * float(i) / float(count))
			return offsets

func _get_mouse_angle() -> float:
	return global_position.direction_to(get_global_mouse_position()).angle()

func _get_orbit_position(angle: float) -> Vector2:
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	var denominator := sqrt(pow(ORBIT_RADIUS.y * cos_a, 2) + pow(ORBIT_RADIUS.x * sin_a, 2))
	if denominator == 0:
		return ORBIT_OFFSET
	var radius := (ORBIT_RADIUS.x * ORBIT_RADIUS.y) / denominator
	return Vector2(cos_a, sin_a) * radius + ORBIT_OFFSET

func _shortest_angle(from_angle: float, to_angle: float) -> float:
	return wrapf(to_angle - from_angle, -PI, PI)

func _update_mecha_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	var new_dir := _compute_stable_mecha_direction(direction)
	if new_dir == "" or new_dir == current_mecha_direction:
		return
	current_mecha_direction = new_dir
	mecha_sprite.flip_h = _last_face_horizontal_sign > 0
	if MECHA_DIRECTION_TEXTURES.has(new_dir):
		mecha_sprite.texture = MECHA_DIRECTION_TEXTURES[new_dir]
		_resize_mecha_sprite()

func _compute_stable_mecha_direction(direction: Vector2) -> String:
	var distance: float = direction.length()
	var threshold: float = clampf(face_axis_hysteresis, 0.0, 0.5)
	if distance >= maxf(face_min_distance_px, 0.0):
		var normalized: Vector2 = direction / distance
		# Schmitt trigger per-axis:
		# switch side only when crossing the opposite threshold band.
		if _last_face_horizontal_sign >= 0:
			if normalized.x < -threshold:
				_last_face_horizontal_sign = -1
		else:
			if normalized.x > threshold:
				_last_face_horizontal_sign = 1
		if _last_face_vertical_sign >= 0:
			if normalized.y < -threshold:
				_last_face_vertical_sign = -1
		else:
			if normalized.y > threshold:
				_last_face_vertical_sign = 1
		if face_hysteresis_debug:
			print("[FaceHys2] d=", snappedf(distance, 0.1), " n=", normalized, " hs=", _last_face_horizontal_sign, " vs=", _last_face_vertical_sign)
	elif face_hysteresis_debug:
		print("[FaceHys2] deadzone d=", snappedf(distance, 0.1), " keep hs=", _last_face_horizontal_sign, " vs=", _last_face_vertical_sign)
	if _last_face_horizontal_sign < 0:
		return "top_left" if _last_face_vertical_sign < 0 else "bottom_left"
	return "top_right" if _last_face_vertical_sign < 0 else "bottom_right"

# Player does not have death atm
func damaged(attack:Attack):
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.damaged(attack)

func _apply_elite_hit_slow_if_needed(attack: Attack) -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.apply_elite_hit_slow_if_needed(attack)

func _is_attack_from_player(attack: Attack) -> bool:
	return attack != null and attack.is_from_player()

func _is_attack_from_elite_or_boss(attack: Attack) -> bool:
	if attack == null or attack.source_node == null or not is_instance_valid(attack.source_node):
		return false
	var current: Node = attack.source_node
	while current != null:
		if current is EliteEnemy:
			return true
		if current.is_in_group("boss"):
			return true
		var is_boss_variant: Variant = current.get("is_boss")
		if is_boss_variant != null and bool(is_boss_variant):
			return true
		current = current.get_parent()
	return false

func _get_total_armor() -> int:
	return max(0, int(PlayerData.armor) + int(PlayerData.bonus_armor))

func _get_total_damage_reduction() -> float:
	return clampf(float(PlayerData.damage_reduction) * float(PlayerData.bonus_damage_reduction), 0.2, 5.0)

func _clear_expired_scorch() -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.clear_expired_scorch()

func _apply_scorch_on_fire_hit(fire_damage: int, source_node: Node = null, source_player: Node = null) -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.apply_scorch_on_fire_hit(fire_damage, source_node, source_player)

func _get_scorch_stack_cap(hp_ratio: float) -> int:
	_ensure_damage_reaction_system()
	if _damage_reaction_system == null:
		return 1
	return _damage_reaction_system.get_scorch_stack_cap(hp_ratio)

func _clear_expired_frost() -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.clear_expired_frost()

func _apply_frost_on_freeze_hit() -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.apply_frost_on_freeze_hit()

func _refresh_frost_move_slow() -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.refresh_frost_move_slow()

func _clear_expired_energy_mark() -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.clear_expired_energy_mark()

func _apply_energy_mark_on_energy_hit(energy_damage: int) -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.apply_energy_mark_on_energy_hit(energy_damage)

func _try_trigger_energy_mark_burst(reference_attack: Attack) -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.try_trigger_energy_mark_burst(reference_attack)

func _apply_scorch_dot_tick(dot_damage: int) -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.apply_scorch_dot_tick(dot_damage)

func _update_incoming_elemental_effects(delta: float) -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.update_incoming_elemental_effects(delta)

func _setup_incoming_damage_profile() -> void:
	var profile := DamageProfile.new() as DamageProfile
	profile.profile_id = &"player"
	profile.use_damage_reduction = true
	profile.use_armor = true
	profile.use_invuln = true
	profile.dot_bypasses_invuln = true
	profile.get_hp = Callable(self, "_profile_get_hp")
	profile.set_hp = Callable(self, "_profile_set_hp")
	profile.get_max_hp = Callable(self, "_profile_get_max_hp")
	profile.get_armor = Callable(self, "_profile_get_armor")
	profile.get_damage_reduction = Callable(self, "_profile_get_damage_reduction")
	profile.get_damage_taken_multiplier = Callable(self, "_profile_get_damage_taken_multiplier")
	profile.get_is_dead = Callable(self, "_profile_get_is_dead")
	profile.set_is_dead = Callable(self, "_profile_set_is_dead")
	profile.on_death = Callable(self, "_profile_on_death")
	profile.on_trigger_invuln = Callable(self, "_profile_on_trigger_invuln")
	profile.on_apply_frost_slow = Callable(self, "_profile_on_apply_frost_slow")
	profile.on_clear_frost_slow = Callable(self, "_profile_on_clear_frost_slow")
	_incoming_damage_profile = profile

func _profile_get_hp() -> int:
	return int(PlayerData.player_hp)

func _profile_set_hp(value: int) -> void:
	PlayerData.player_hp = int(value)

func _profile_get_max_hp() -> int:
	return max(1, int(PlayerData.player_max_hp))

func _profile_get_armor() -> int:
	return _get_total_armor()

func _profile_get_damage_reduction() -> float:
	return _get_total_damage_reduction()

func _profile_get_damage_taken_multiplier() -> float:
	return 1.0

func _profile_get_is_dead() -> bool:
	return PhaseManager.current_state() == PhaseManager.GAMEOVER or PlayerData.player_hp <= 0

func _profile_set_is_dead(value: bool) -> void:
	if not value:
		return
	if PlayerData.testing_keep_hp_above_zero:
		PlayerData.player_hp = max(1, int(PlayerData.player_hp))
		return
	PlayerData.player_hp = 0

func _profile_on_death(_attack: Attack) -> void:
	if PlayerData.testing_keep_hp_above_zero:
		PlayerData.player_hp = max(1, int(PlayerData.player_hp))
		return
	PhaseManager.enter_gameover()

func _profile_on_trigger_invuln() -> void:
	hurt_box.set_collision_layer_value(1,false)
	hurt_cd.start(PlayerData.hurt_cd)
	collision_cd.start(PlayerData.collision_cd)

func _profile_on_apply_frost_slow(move_multiplier: float, _duration_sec: float) -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.on_profile_apply_frost_slow(move_multiplier)

func _profile_on_clear_frost_slow() -> void:
	_ensure_damage_reaction_system()
	if _damage_reaction_system != null:
		_damage_reaction_system.on_profile_clear_frost_slow()


# When player is teleporting between zones, disable terrain collision. Enable when arrived.
func switch_terrain_collision(switch:bool):
	self.set_collision_mask_value(6,switch)


func set_hp_safety_for_testing(enabled: bool) -> void:
	PlayerData.set_hp_safety_for_testing(enabled)


func get_closest_area_optimized(area_list: Array, target_node: Node2D) -> Area2D:
	if area_list.is_empty():
		return null
		
	var closest_area = area_list[0]
	var shortest_distance = closest_area.global_position.distance_squared_to(target_node.global_position)
	
	for area in area_list:
		if not area is Area2D:
			continue
			
		var distance = area.global_position.distance_squared_to(target_node.global_position)
		if distance < shortest_distance:
			shortest_distance = distance
			closest_area = area
			
	return closest_area


func _on_collect_area_area_entered(area):
	_ensure_loot_system()
	if _loot_system != null:
		_loot_system.on_collect_area_entered(area)


func _on_collect_chip_area_area_entered(area) -> void:
	_ensure_loot_system()
	if _loot_system != null:
		_loot_system.on_collect_chip_area_entered(area)


func _on_grab_area_area_entered(area):
	_ensure_loot_system()
	if _loot_system != null:
		_loot_system.on_grab_area_entered(area)


func _on_phase_changed(new_phase: String) -> void:
	var previous_phase := _last_phase
	_last_phase = new_phase
	if new_phase == PhaseManager.BATTLE:
		_suppress_attack_until_released = Input.is_action_pressed("ATTACK")
	else:
		_suppress_attack_until_released = false
	_update_vision_effect()
	if not _require_camera_system_or_halt():
		return
	_camera_system.on_phase_changed()
	if new_phase == PhaseManager.PREPARE:
		clear_timed_statuses_for_prepare()
		_instant_reload_all_weapons()
		_force_all_skills_ready()
	_ensure_loot_system()
	if _loot_system != null:
		_loot_system.on_phase_changed(new_phase, previous_phase)

func _ensure_movement_system() -> void:
	if _movement_system != null:
		_movement_system.setup(self)
		return
	_movement_system = PlayerMovementSystem.new() as PlayerMovementSystem
	if _movement_system != null:
		_movement_system.setup(self)

func _ensure_camera_system() -> void:
	if _camera_system != null:
		if player_camera != null:
			var bound := _camera_system.has_camera_binding()
			if not bound:
				_camera_system.setup(self, player_camera)
		return
	_camera_system = PlayerCameraSystem.new() as PlayerCameraSystem
	if _camera_system != null:
		_camera_system.setup(self, player_camera)

func _ensure_shared_heat_system() -> void:
	if _shared_heat_system != null:
		_shared_heat_system.setup(self)
		return
	_shared_heat_system = PlayerSharedHeatSystem.new() as PlayerSharedHeatSystem
	if _shared_heat_system != null:
		_shared_heat_system.setup(self)

func _ensure_loot_system() -> void:
	if _loot_system != null:
		_loot_system.setup(self)
		return
	_loot_system = PlayerLootSystem.new() as PlayerLootSystem
	if _loot_system != null:
		_loot_system.setup(self)

func _ensure_damage_reaction_system() -> void:
	if _damage_reaction_system != null:
		_damage_reaction_system.setup(self)
		return
	_damage_reaction_system = PlayerDamageReactionSystem.new() as PlayerDamageReactionSystem
	if _damage_reaction_system != null:
		_damage_reaction_system.setup(self)

func _require_movement_system_or_halt() -> bool:
	if _movement_system == null:
		_ensure_movement_system()
	if _movement_system != null:
		return true
	if not _systems_strict_ready:
		return false
	push_error("PlayerMovementSystem missing. Halting Player physics.")
	set_physics_process(false)
	return false

func _require_camera_system_or_halt() -> bool:
	if _camera_system == null:
		_ensure_camera_system()
	if _camera_system != null:
		return true
	if not _systems_strict_ready:
		return false
	push_error("PlayerCameraSystem missing. Halting Player physics.")
	set_physics_process(false)
	return false

func _instant_reload_all_weapons() -> void:
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if weapon.has_method("refill_ammo_instantly"):
			weapon.call("refill_ammo_instantly")

func _force_all_skills_ready() -> void:
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if weapon.has_method("force_skill_cooldowns_ready"):
			weapon.call("force_skill_cooldowns_ready")
	if active_skill_holder == null or not is_instance_valid(active_skill_holder):
		return
	for child in active_skill_holder.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child.has_method("force_cooldown_ready"):
			child.call("force_cooldown_ready")


func _attract_all_coins() -> void:
	_ensure_loot_system()
	if _loot_system != null:
		_loot_system.attract_all_coins()


func _run_battle_end_auto_collect() -> void:
	_ensure_loot_system()
	if _loot_system != null:
		_loot_system.run_battle_end_auto_collect()


func _expand_collect_ranges_for_auto_loot() -> void:
	_ensure_loot_system()
	if _loot_system != null:
		_loot_system.expand_collect_ranges_for_auto_loot()


func _restore_collect_ranges_after_auto_loot() -> void:
	update_grab_radius()


func _process_auto_loot_grab_overlaps() -> void:
	_ensure_loot_system()
	if _loot_system != null:
		_loot_system.process_auto_loot_grab_overlaps()


func _on_detect_area_area_entered(area: Area2D) -> void:
	if not PlayerData.detected_enemies.has(area):
		PlayerData.detected_enemies.append(area)
		PlayerData.cloestest_enemy = get_closest_area_optimized(PlayerData.detected_enemies, self)


func _on_detect_area_area_exited(area: Area2D) -> void:
	if PlayerData.detected_enemies.has(area):
		PlayerData.detected_enemies.erase(area)
		PlayerData.cloestest_enemy = get_closest_area_optimized(PlayerData.detected_enemies, self)


func _on_hurt_cd_timeout() -> void:
	hurt_box.set_collision_layer_value(1,true)


func _on_collision_cd_timeout() -> void:
	pass

func _exit_tree() -> void:
	_disconnect_weapon_structure_signals()
	if _weapon_inventory_runtime != null:
		_weapon_inventory_runtime.clear_tracked_weapon_exit_ids()
	_tracked_weapon_exit_ids.clear()
	if _status_hint_manager != null and is_instance_valid(_status_hint_manager):
		_status_hint_manager.clear_all()

func _update_shared_heat_pool(delta: float) -> void:
	_ensure_shared_heat_system()
	if _shared_heat_system != null:
		_shared_heat_system.tick(delta)

func _rebuild_shared_heat_pool() -> void:
	_ensure_shared_heat_system()
	if _shared_heat_system != null:
		_shared_heat_system.rebuild()

func mark_shared_heat_pool_dirty() -> void:
	_ensure_shared_heat_system()
	if _shared_heat_system != null:
		_shared_heat_system.mark_dirty()

func get_shared_heat_pool() -> SharedHeatPool:
	_ensure_shared_heat_system()
	if _shared_heat_system == null:
		return null
	return _shared_heat_system.get_pool()

func get_total_heat_value() -> float:
	_ensure_shared_heat_system()
	if _shared_heat_system == null:
		return 0.0
	return _shared_heat_system.get_total_heat_value()

func get_total_heat_max() -> float:
	_ensure_shared_heat_system()
	if _shared_heat_system == null:
		return 0.0
	return _shared_heat_system.get_total_heat_max()

func get_total_heat_ratio() -> float:
	_ensure_shared_heat_system()
	if _shared_heat_system == null:
		return 0.0
	return _shared_heat_system.get_total_heat_ratio()

func get_selected_heat_decay_rate() -> float:
	_ensure_shared_heat_system()
	if _shared_heat_system == null:
		return 0.0
	return _shared_heat_system.get_selected_heat_decay_rate()

func get_effective_heat_decay_rate() -> float:
	_ensure_shared_heat_system()
	if _shared_heat_system == null:
		return 0.0
	return _shared_heat_system.get_effective_heat_decay_rate()

func get_selected_heat_decay_source_name() -> String:
	_ensure_shared_heat_system()
	if _shared_heat_system == null:
		return "None"
	return _shared_heat_system.get_selected_heat_decay_source_name()

func get_last_heat_decay_source_name() -> String:
	_ensure_shared_heat_system()
	if _shared_heat_system == null:
		return "None"
	return _shared_heat_system.get_last_heat_decay_source_name()
