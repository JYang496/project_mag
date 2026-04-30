extends CharacterBody2D
class_name Player

const SHARED_HEAT_POOL_SCRIPT := preload("res://Player/Weapons/Heat/shared_heat_pool.gd")
const DAMAGE_PIPELINE_SCRIPT := preload("res://Utility/damage/damage_pipeline.gd")
const DAMAGE_PROFILE_SCRIPT := preload("res://Utility/damage/damage_profile.gd")
const FLOATING_STATUS_HINT_MANAGER_SCRIPT := preload("res://Player/Mechas/scripts/floating_status_hint_manager.gd")
const PLAYER_STATUS_MODIFIER_SYSTEM_SCRIPT := preload("res://Player/Mechas/scripts/player_status_modifier_system.gd")
const PLAYER_ELEMENTAL_EFFECT_SYSTEM_SCRIPT := preload("res://Player/Mechas/scripts/player_elemental_effect_system.gd")
const PLAYER_MOVEMENT_SYSTEM_SCRIPT := preload("res://Player/Mechas/scripts/player_movement_system.gd")
const PLAYER_CAMERA_SYSTEM_SCRIPT := preload("res://Player/Mechas/scripts/player_camera_system.gd")

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
const ENERGY_MARK_RATIO: float = 0.10
const ENERGY_MARK_DURATION_SEC: float = 6.0
const ENERGY_MARK_MAX_HP_RATIO: float = 0.40
const ENERGY_MARK_TRIGGER_COOLDOWN_SEC: float = 2.0
const AUTO_LOOT_DURATION_SEC: float = 2.0
const AUTO_LOOT_TICK_SEC: float = 0.2
const AUTO_LOOT_GRAB_RADIUS: float = 2500.0
const COLLECT_AREA_TOP_PADDING: float = 0.0
var weapon_orbit_states: Dictionary = {}
var _base_detect_shape_size := Vector2.ZERO
var _base_camera_zoom := Vector2.ONE
var _camera_zoom_target := Vector2.ONE
var _camera_offset_target := Vector2.ZERO
var _base_hurtbox_shape_size := Vector2.ZERO
var _base_hurtbox_shape_position := Vector2.ZERO
var _hurtbox_shape_base_cached: bool = false
var _shared_heat_pool: SharedHeatPool
var _shared_heat_signature: String = ""
var _incoming_damage_pipeline: DamagePipeline
var _incoming_damage_profile: DamageProfile
var _passive_time_tick_accum: float = 0.0
enum MechaVisualState {
	IDLE,
	MOVING
}
var _mecha_visual_state: int = MechaVisualState.IDLE
var _last_mecha_facing_direction: Vector2 = Vector2(-1.0, 1.0)
var _current_move_animation: StringName = StringName()
var _last_visual_position: Vector2 = Vector2.ZERO
@export var camera_zoom_lerp_speed: float = 1.0
@export var rest_phase_camera_zoom_factor: float = 1.5
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
@export var reload_block_hint_interval_sec: float = 0.35
@export var status_hint_throttle_sec: float = 0.45
@export var default_active_skill_path: String = "res://Player/Skills/bullet_time"
@export var player_max_energy: float = 100.0
@export var player_energy_regen_per_sec: float = 8.0
var _player_energy: float = 100.0
var _last_weapon_skill_fail_reason: String = ""
var _last_player_skill_fail_reason: String = ""
var _last_phase: String = ""
var _auto_loot_running: bool = false
var _board_generator_ref: Node = null
var _reload_block_hint_ready_at_msec: int = 0
var _last_move_input_dir: Vector2 = Vector2.ZERO
var _last_move_input_msec: int = -1
var _last_face_horizontal_sign: int = -1
var _last_face_vertical_sign: int = 1
var _last_move_anim_is_top: bool = false
const ELITE_HIT_SLOW_SOURCE_ID: StringName = &"elite_hit_stagger"
var _elite_hit_slow_until_msec: int = 0
var PlayerData = null
var _status_hint_manager
var _status_modifier_system
var _elemental_effect_system
var _movement_system
var _camera_system
var _suppress_status_hints: bool = false
# Signals
signal active_skill()
signal player_active_skill()
signal weapon_active_skill()
signal coin_collected()

func _ready():
	PlayerData = get_node_or_null("/root/PlayerData")
	if PlayerData == null:
		push_error("PlayerData autoload missing.")
		return
	PlayerData.player = self
	_incoming_damage_pipeline = DAMAGE_PIPELINE_SCRIPT.new() as DamagePipeline
	_setup_incoming_damage_profile()
	_shared_heat_pool = SHARED_HEAT_POOL_SCRIPT.new() as SharedHeatPool
	if _shared_heat_pool == null:
		push_warning("Failed to initialize SharedHeatPool.")
	_setup_default_active_skill()
	_ensure_input_actions()
	_player_energy = player_max_energy
	mecha_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_resize_mecha_sprite()
	_setup_mecha_move_sprite()
	_last_visual_position = global_position
	_cache_camera_zoom_base()
	_camera_zoom_target = _base_camera_zoom
	_cache_detect_shape_base()
	_update_vision_effect()
	_sync_weapon_orbit_states(true)
	update_grab_radius()
	custom_ready()
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
	_ensure_movement_system()
	_ensure_camera_system()

# overwrite the function on child class
func custom_ready():
	create_weapon("1")

func _physics_process(delta):
	_sanitize_weapon_list_and_roles()
	_process_combat_input(delta)
	_sync_weapon_orbit_states()
	_update_shared_heat_pool(delta)
	_update_incoming_elemental_effects(delta)
	_regen_energy(delta)
	_update_passive_time_tick(delta)
	_update_collect_area_anchor_to_screen_top()
	if _movement_system != null and _movement_system.has_method("tick"):
		_movement_system.call("tick", delta)
	else:
		movement(delta)
	move_and_slide()
	distance_mouse_player = get_global_mouse_position() - global_position
	_update_mecha_visual_state(distance_mouse_player)
	_update_weapon_orbits(delta)
	if _camera_system != null and _camera_system.has_method("tick"):
		_camera_system.call("tick", delta)
	else:
		_update_camera_zoom_smooth(delta)
		_update_camera_lookahead(delta)
	_update_collect_area_anchor_to_screen_top()
	_constrain_to_board_traversable_area()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("SKILL_PLAYER") or event.is_action_pressed("SKILL"):
		_try_cast_player_active_skill()
	if event.is_action_pressed("SKILL_WEAPON"):
		_try_reload_main_weapon()

func _setup_default_active_skill() -> void:
	if active_skill_holder == null:
		push_warning("ActiveSkill node is missing, default active skill will not be loaded.")
		return
	if active_skill_holder.get_child_count() > 0:
		return
	var scene_path := default_active_skill_path
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"
	var scene_resource := load(scene_path)
	var skill_scene := scene_resource as PackedScene
	if skill_scene == null:
		push_warning("Failed to load default active skill scene: %s" % scene_path)
		return
	var skill_instance := skill_scene.instantiate()
	if not (skill_instance is Skills):
		push_warning("Default active skill must inherit Skills: %s" % scene_path)
		return
	active_skill_holder.add_child(skill_instance)

func create_weapon(item_id, level := 1):
	# Create a new weapon when assign string, otherwise node.
	var weapon: Weapon
	var incoming_weapon_id := ""
	if item_id is String:
		incoming_weapon_id = DataHandler.resolve_weapon_id_for_standalone(str(item_id))
		var weapon_def := DataHandler.read_weapon_data(incoming_weapon_id) as WeaponDefinition
		if weapon_def == null:
			push_warning("create_weapon failed: weapon id %s not found." % str(item_id))
			return
		var existing_by_id := _find_owned_weapon_by_id(incoming_weapon_id)
		if existing_by_id != null:
			var duplicate_result := _apply_duplicate_weapon_upgrade(existing_by_id, incoming_weapon_id)
			_notify_weapon_duplicate_result(existing_by_id, incoming_weapon_id, duplicate_result)
			_refresh_weapon_related_ui()
			return
		weapon = weapon_def.scene.instantiate() as Weapon
		if weapon == null:
			push_warning("create_weapon failed: weapon scene instantiate returned null for id %s." % incoming_weapon_id)
			return
		weapon.level = int(level)
	else:
		# Parameter is weapon node instead of String, common case when get weapon from inventory.
		weapon = item_id as Weapon
		if weapon == null or not is_instance_valid(weapon):
			push_warning("create_weapon failed: invalid weapon instance input.")
			return
		incoming_weapon_id = DataHandler.get_weapon_id_from_instance(weapon)
		if incoming_weapon_id != "":
			var existing_owned_weapon := _find_owned_weapon_by_id(incoming_weapon_id)
			if existing_owned_weapon != null and existing_owned_weapon != weapon:
				var duplicate_result_instance := _apply_duplicate_weapon_upgrade(existing_owned_weapon, incoming_weapon_id)
				_consume_duplicate_weapon_instance(weapon, existing_owned_weapon)
				_notify_weapon_duplicate_result(existing_owned_weapon, incoming_weapon_id, duplicate_result_instance)
				_refresh_weapon_related_ui()
				return

	# Put weapon into inventory if weapon list is full.
	if PlayerData.player_weapon_list.size() >= PlayerData.max_weapon_num:
		if len(InventoryData.inventory_slots) < InventoryData.INVENTORY_MAX_SLOTS:
			InventoryData.inventory_slots.append(weapon)
		_refresh_weapon_related_ui()
		return

	equppied_weapons.add_child(weapon)
	weapon.position = Vector2.ZERO
	PlayerData.player_weapon_list.append(weapon)
	if PlayerData.player_weapon_list.size() == 1:
		PlayerData.set_main_weapon_index(0)
	_apply_weapon_roles()
	_sync_weapon_orbit_states(true)
	_rebuild_shared_heat_pool()
	_refresh_weapon_related_ui()

func _find_owned_weapon_by_id(weapon_id: String) -> Weapon:
	var normalized_id := str(weapon_id).strip_edges()
	if normalized_id == "":
		return null
	for equipped_weapon_ref in PlayerData.player_weapon_list:
		var equipped_weapon := equipped_weapon_ref as Weapon
		if equipped_weapon == null or not is_instance_valid(equipped_weapon):
			continue
		if DataHandler.get_weapon_id_from_instance(equipped_weapon) == normalized_id:
			return equipped_weapon
	for inventory_weapon_ref in InventoryData.inventory_slots:
		var inventory_weapon := inventory_weapon_ref as Weapon
		if inventory_weapon == null or not is_instance_valid(inventory_weapon):
			continue
		if DataHandler.get_weapon_id_from_instance(inventory_weapon) == normalized_id:
			return inventory_weapon
	return null

func _apply_duplicate_weapon_upgrade(existing_weapon: Weapon, incoming_weapon_id: String) -> Dictionary:
	if existing_weapon == null or not is_instance_valid(existing_weapon):
		return {"result": "invalid", "value": 0}
	var previous_fuse := int(existing_weapon.fuse)
	var max_fuse: int = max(1, int(existing_weapon.FINAL_MAX_FUSE))
	if previous_fuse < max_fuse:
		existing_weapon.fuse = previous_fuse + 1
		var clamped_level := clampi(int(existing_weapon.level), 1, int(existing_weapon.max_level))
		if existing_weapon.has_method("set_level"):
			existing_weapon.call("set_level", clamped_level)
		else:
			existing_weapon.level = clamped_level
			if existing_weapon.has_method("calculate_status"):
				existing_weapon.call("calculate_status")
		_try_prompt_branch_selection(existing_weapon)
		return {"result": "fuse", "value": int(existing_weapon.fuse)}
	var previous_level := int(existing_weapon.level)
	var max_level := int(existing_weapon.max_level)
	if previous_level < max_level:
		var next_level := previous_level + 1
		if existing_weapon.has_method("set_level"):
			existing_weapon.call("set_level", next_level)
		else:
			existing_weapon.level = next_level
			if existing_weapon.has_method("calculate_status"):
				existing_weapon.call("calculate_status")
		return {"result": "level", "value": int(existing_weapon.level)}
	var converted_gold := _convert_duplicate_weapon_to_gold(incoming_weapon_id)
	return {"result": "convert", "gold": converted_gold}

func _consume_duplicate_weapon_instance(duplicate_weapon: Weapon, keep_weapon: Weapon = null) -> void:
	if duplicate_weapon == null or not is_instance_valid(duplicate_weapon) or duplicate_weapon == keep_weapon:
		return
	if duplicate_weapon.modules != null:
		for child in duplicate_weapon.modules.get_children():
			var module_node := child as Module
			if module_node == null:
				continue
			var module_copy := module_node.duplicate() as Module
			if module_copy:
				InventoryData.obtain_module(module_copy)
	PlayerData.player_weapon_list.erase(duplicate_weapon)
	InventoryData.inventory_slots.erase(duplicate_weapon)
	if duplicate_weapon.get_parent() != null:
		duplicate_weapon.queue_free()
	else:
		duplicate_weapon.free()

func _convert_duplicate_weapon_to_gold(weapon_id: String) -> int:
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	var base_price := 0
	if weapon_def != null:
		base_price = max(0, int(weapon_def.price))
	var converted_gold: int = max(6, base_price * 2)
	PlayerData.player_gold += converted_gold
	return converted_gold

func _notify_weapon_duplicate_result(existing_weapon: Weapon, weapon_id: String, result: Dictionary) -> void:
	var ui := GlobalVariables.ui
	if ui == null or not is_instance_valid(ui) or not ui.has_method("show_item_message"):
		return
	var resolved_id := str(weapon_id).strip_edges()
	var fallback_name := LocalizationManager.get_weapon_name_from_node(existing_weapon)
	var weapon_name := LocalizationManager.get_weapon_name_by_id(resolved_id, fallback_name)
	var result_type := str(result.get("result", ""))
	var message := ""
	match result_type:
		"fuse":
			var fuse_value := int(result.get("value", max(1, int(existing_weapon.fuse))))
			message = LocalizationManager.tr_format(
				"ui.weapon.duplicate.fuse_up",
				{"name": weapon_name, "fuse": fuse_value},
				"Duplicate %s reinforced to Fuse %d" % [weapon_name, fuse_value]
			)
		"level":
			var level_value := int(result.get("value", max(1, int(existing_weapon.level))))
			message = LocalizationManager.tr_format(
				"ui.weapon.duplicate.level_up",
				{"name": weapon_name, "level": level_value},
				"Duplicate %s upgraded to Lv.%d" % [weapon_name, level_value]
			)
		"convert":
			var gold_value := int(result.get("gold", 0))
			message = LocalizationManager.tr_format(
				"ui.weapon.duplicate.convert",
				{"name": weapon_name, "gold": gold_value},
				"Duplicate %s converted to +%d Gold" % [weapon_name, gold_value]
			)
		_:
			return
	ui.show_item_message(message, 1.8)

func _refresh_weapon_related_ui() -> void:
	var ui := GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	if ui.has_method("update_inventory"):
		ui.update_inventory()
	if ui.has_method("update_upg"):
		ui.update_upg()
	if ui.has_method("update_gf"):
		ui.update_gf()
	if ui.has_method("refresh_border"):
		ui.refresh_border()

func _try_prompt_branch_selection(weapon: Weapon) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var ui := GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	if not ui.has_method("request_weapon_branch_selection"):
		return
	ui.request_weapon_branch_selection(weapon)

func swap_weapon_position(weapon1, weapon2) -> void:
	if weapon1 == weapon2:
		return
	var slot1_index = PlayerData.player_weapon_list.find(weapon1)
	var slot2_index = PlayerData.player_weapon_list.find(weapon2)
	var temp = PlayerData.player_weapon_list[slot1_index]
	PlayerData.player_weapon_list[slot1_index] = PlayerData.player_weapon_list[slot2_index]
	PlayerData.player_weapon_list[slot2_index] = temp
	if PlayerData.main_weapon_index == slot1_index:
		PlayerData.main_weapon_index = slot2_index
	elif PlayerData.main_weapon_index == slot2_index:
		PlayerData.main_weapon_index = slot1_index
	PlayerData.on_select_weapon = PlayerData.main_weapon_index
	_apply_weapon_roles()
	_sync_weapon_orbit_states(true)
	_rebuild_shared_heat_pool()

func _process_combat_input(delta: float) -> void:
	var main_weapon := get_main_weapon()
	if main_weapon == null:
		return
	var pressed := Input.is_action_pressed("ATTACK")
	var just_pressed := Input.is_action_just_pressed("ATTACK")
	var just_released := Input.is_action_just_released("ATTACK")
	if pressed:
		_try_show_reload_block_hint(main_weapon)
	if main_weapon.has_method("handle_primary_input"):
		main_weapon.call("handle_primary_input", pressed, just_pressed, just_released, delta)

func _try_show_reload_block_hint(main_weapon: Weapon) -> void:
	if main_weapon == null or not is_instance_valid(main_weapon):
		return
	if not main_weapon.has_method("uses_ammo_system") or not bool(main_weapon.call("uses_ammo_system")):
		return
	var reloading_variant: Variant = main_weapon.get("is_reloading")
	if reloading_variant == null or not bool(reloading_variant):
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec < _reload_block_hint_ready_at_msec:
		return
	_reload_block_hint_ready_at_msec = now_msec + int(maxf(reload_block_hint_interval_sec, 0.05) * 1000.0)
	var hint_text := "正在换弹中"
	if LocalizationManager and LocalizationManager.has_method("tr_key"):
		hint_text = LocalizationManager.tr_key("ui.hud.reloading_now", "正在换弹中")
	_spawn_player_floating_hint(hint_text)

func _spawn_player_floating_hint(text: String) -> void:
	_ensure_status_hint_manager()
	if _status_hint_manager == null:
		return
	_status_hint_manager.enqueue_raw_hint(text)

func notify_weapon_status_change(stat_type: StringName, source_id: StringName, is_gain: bool) -> void:
	_notify_status_hint(&"weapon", stat_type, source_id, is_gain)

func _notify_status_hint(owner: StringName, stat_type: StringName, source_id: StringName, is_gain: bool) -> void:
	if _suppress_status_hints:
		return
	_ensure_status_hint_manager()
	if _status_hint_manager == null:
		return
	_status_hint_manager.notify_status_hint(owner, stat_type, source_id, is_gain)

func clear_timed_statuses_for_prepare() -> void:
	_suppress_status_hints = true
	if _status_hint_manager != null and is_instance_valid(_status_hint_manager):
		_status_hint_manager.clear_all()
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
		_status_hint_manager.setup(self, floating_hint_duration_sec, floating_hint_rise_px, status_hint_throttle_sec)
		return
	_status_hint_manager = FLOATING_STATUS_HINT_MANAGER_SCRIPT.new() as FloatingStatusHintManager
	if _status_hint_manager == null:
		return
	_status_hint_manager.name = "FloatingStatusHintManager"
	add_child(_status_hint_manager)
	_status_hint_manager.setup(self, floating_hint_duration_sec, floating_hint_rise_px, status_hint_throttle_sec)

func _ensure_status_modifier_system() -> void:
	if _status_modifier_system != null:
		_status_modifier_system.setup(self)
		return
	_status_modifier_system = PLAYER_STATUS_MODIFIER_SYSTEM_SCRIPT.new()
	if _status_modifier_system == null:
		return
	_status_modifier_system.setup(self)

func _ensure_elemental_effect_system() -> void:
	if _elemental_effect_system == null:
		_elemental_effect_system = PLAYER_ELEMENTAL_EFFECT_SYSTEM_SCRIPT.new()
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

func _sanitize_weapon_list_and_roles() -> void:
	var valid_weapons: Array = []
	for weapon in PlayerData.player_weapon_list:
		if is_instance_valid(weapon):
			valid_weapons.append(weapon)
	PlayerData.player_weapon_list = valid_weapons
	PlayerData.sanitize_main_weapon_index()
	if valid_weapons.size() == 1:
		PlayerData.main_weapon_index = 0
	_apply_weapon_roles()

func _apply_weapon_roles() -> void:
	for i in range(PlayerData.player_weapon_list.size()):
		var weapon: Variant = PlayerData.player_weapon_list[i]
		if weapon == null or not is_instance_valid(weapon):
			continue
		if weapon.has_method("set_weapon_role"):
			weapon.call("set_weapon_role", "main" if i == PlayerData.main_weapon_index else "offhand")

func get_main_weapon() -> Weapon:
	if PlayerData.player_weapon_list.is_empty():
		return null
	PlayerData.sanitize_main_weapon_index()
	var idx: int = int(PlayerData.main_weapon_index)
	if idx < 0 or idx >= PlayerData.player_weapon_list.size():
		return null
	var weapon: Variant = PlayerData.player_weapon_list[idx]
	if weapon is Weapon:
		return weapon as Weapon
	return null

func get_offhand_weapons() -> Array:
	var result: Array = []
	for i in range(PlayerData.player_weapon_list.size()):
		if i == PlayerData.main_weapon_index:
			continue
		var weapon: Variant = PlayerData.player_weapon_list[i]
		if weapon and is_instance_valid(weapon):
			result.append(weapon)
	return result

func can_switch_main_weapon() -> bool:
	return PlayerData.can_switch_main_weapon()

func try_shift_main_weapon(step: int) -> bool:
	if not can_switch_main_weapon():
		return false
	var old_main := get_main_weapon()
	PlayerData.shift_main_weapon(step)
	_apply_weapon_roles()
	var new_main := get_main_weapon()
	_broadcast_weapon_passive_event(&"on_main_swapped", {
		"old_main": old_main,
		"new_main": new_main
	})
	return true

func _broadcast_weapon_passive_event(event_name: StringName, detail: Dictionary = {}) -> void:
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if weapon.has_method("dispatch_passive_event"):
			weapon.call("dispatch_passive_event", event_name, detail)

func _update_passive_time_tick(delta: float) -> void:
	_passive_time_tick_accum += maxf(delta, 0.0)
	if _passive_time_tick_accum < 1.0:
		return
	_passive_time_tick_accum = 0.0
	_broadcast_weapon_passive_event(&"on_time_tick", {})

func notify_enemy_killed_nearby(enemy: Node = null) -> void:
	_broadcast_weapon_passive_event(&"on_enemy_killed_nearby", {
		"enemy": enemy
	})

func _try_cast_player_active_skill() -> void:
	player_active_skill.emit()
	active_skill.emit()
	_last_player_skill_fail_reason = ""

func _try_cast_main_weapon_active_skill() -> void:
	var main_weapon := get_main_weapon()
	if main_weapon == null:
		_last_weapon_skill_fail_reason = "no_main_weapon"
		return
	if not main_weapon.has_method("request_weapon_active"):
		_last_weapon_skill_fail_reason = "unsupported"
		return
	var result_variant: Variant = main_weapon.call("request_weapon_active")
	if result_variant is Dictionary:
		var result := result_variant as Dictionary
		if bool(result.get("ok", false)):
			weapon_active_skill.emit()
			_last_weapon_skill_fail_reason = ""
		else:
			_last_weapon_skill_fail_reason = str(result.get("reason", "condition"))
			_broadcast_weapon_passive_event(&"on_main_active_cast_failed", {
				"reason": _last_weapon_skill_fail_reason
			})
	else:
		_last_weapon_skill_fail_reason = "condition"

func _try_reload_main_weapon() -> void:
	if PhaseManager != null and PhaseManager.has_method("current_state"):
		if str(PhaseManager.current_state()) != str(PhaseManager.BATTLE):
			return
	var main_weapon := get_main_weapon()
	if main_weapon == null:
		return
	if not main_weapon.has_method("request_reload"):
		return
	main_weapon.call("request_reload")

func _ensure_input_actions() -> void:
	_ensure_input_action("SKILL_PLAYER", [KEY_SPACE])
	_ensure_input_action("SKILL_WEAPON", [KEY_R])

func _ensure_input_action(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if InputMap.action_get_events(action_name).is_empty():
		for keycode in keycodes:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action_name, ev)

func get_current_energy() -> float:
	return _player_energy

func get_max_energy() -> float:
	return maxf(player_max_energy, 1.0)

func consume_energy(amount: float) -> bool:
	var required := maxf(amount, 0.0)
	if _player_energy < required:
		return false
	_player_energy -= required
	return true

func add_energy(amount: float) -> void:
	_player_energy = clampf(_player_energy + maxf(amount, 0.0), 0.0, get_max_energy())

func _regen_energy(delta: float) -> void:
	if player_energy_regen_per_sec <= 0.0:
		return
	add_energy(player_energy_regen_per_sec * maxf(delta, 0.0))

func get_last_weapon_skill_fail_reason() -> String:
	return _last_weapon_skill_fail_reason

func get_weapon_active_cd_remaining() -> float:
	var weapon := get_main_weapon()
	if weapon == null:
		return 0.0
	if not weapon.has_method("get_weapon_active_cd_remaining"):
		return 0.0
	return float(weapon.call("get_weapon_active_cd_remaining"))

func get_weapon_active_cd_ratio() -> float:
	var weapon := get_main_weapon()
	if weapon == null:
		return 0.0
	if not weapon.has_method("get_weapon_active_cd_ratio"):
		return 0.0
	return float(weapon.call("get_weapon_active_cd_ratio"))

func movement(delta):
	if moveto_enabled:
		_update_auto_navigation(delta)
	elif movement_enabled:
		var allow_manual_input := true
		if PhaseManager != null and PhaseManager.has_method("current_state"):
			allow_manual_input = str(PhaseManager.current_state()) != str(PhaseManager.PREPARE)
		if allow_manual_input:
			var mov: Vector2 = _resolve_buffered_move_input() + extra_direction
			var speed: float = (PlayerData.player_speed + PlayerData.player_bonus_speed) * get_total_move_speed_mul()
			var target_velocity: Vector2 = mov.normalized() * speed if mov.length_squared() > 0.0001 else Vector2.ZERO
			var is_turning: bool = velocity.length_squared() > 1.0 and target_velocity.length_squared() > 1.0 and velocity.dot(target_velocity) < 0.0
			var accel: float = move_accel if target_velocity.length_squared() > 0.0 else move_decel
			if is_turning:
				accel *= (1.0 - clampf(move_turn_penalty, 0.0, 0.9))
			velocity = velocity.move_toward(target_velocity, maxf(accel, 0.0) * maxf(delta, 0.0))
		else:
			velocity = velocity.move_toward(Vector2.ZERO, maxf(move_decel, 0.0) * maxf(delta, 0.0))
	else:
		velocity = velocity.move_toward(Vector2.ZERO, maxf(move_decel, 0.0) * maxf(delta, 0.0))
	
	distance_mouse_player = get_global_mouse_position() - global_position
	_update_mecha_visual_state(distance_mouse_player)
	_update_weapon_orbits(delta)

func _update_auto_navigation(delta: float) -> void:
	var to_dest: Vector2 = moveto_dest - global_position
	var distance_to_dest: float = to_dest.length()
	var reach_distance: float = maxf(3.0, velocity.length() * 0.03)
	if distance_to_dest <= reach_distance:
		global_position = moveto_dest
		velocity = Vector2.ZERO
		moveto_enabled = false
		movement_enabled = true
		moveto_dest = Vector2.ZERO
		return
	var speed: float = (PlayerData.player_speed + PlayerData.player_bonus_speed) * get_total_move_speed_mul()
	var target_velocity: Vector2 = to_dest.normalized() * speed
	velocity = velocity.move_toward(target_velocity, maxf(move_accel, 0.0) * maxf(delta, 0.0))

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
	if _movement_system != null and _movement_system.has_method("start_auto_nav"):
		_movement_system.call("start_auto_nav", dest)
		return
	movement_enabled = false
	moveto_enabled = true
	moveto_dest = dest

func stop_auto_nav() -> void:
	if _movement_system != null and _movement_system.has_method("stop_auto_nav"):
		_movement_system.call("stop_auto_nav")
		return
	movement_enabled = true
	moveto_enabled = false
	moveto_dest = Vector2.ZERO
	velocity = Vector2.ZERO

func is_auto_nav_active() -> bool:
	if _movement_system != null and _movement_system.has_method("is_auto_navigating"):
		return bool(_movement_system.call("is_auto_navigating"))
	return moveto_enabled

func configure_auto_nav_speed_mul(speed_mul: float) -> void:
	if _movement_system != null and _movement_system.has_method("configure_auto_nav_speed_mul"):
		_movement_system.call("configure_auto_nav_speed_mul", speed_mul)

func set_restarea_camera_control_enabled(enabled: bool, snap_target: Vector2 = Vector2.ZERO, snap_now: bool = false) -> void:
	if _camera_system != null and _camera_system.has_method("set_restarea_control_enabled"):
		_camera_system.call("set_restarea_control_enabled", enabled, snap_target, snap_now)

func move_restarea_camera_to(target_global: Vector2, speed_mul: float = 1.0) -> void:
	if _camera_system != null and _camera_system.has_method("move_restarea_camera_to"):
		_camera_system.call("move_restarea_camera_to", target_global, speed_mul)

func configure_restarea_camera_motion(min_speed: float, max_speed: float, speed_curve: float) -> void:
	if _camera_system != null and _camera_system.has_method("configure_restarea_camera_motion"):
		_camera_system.call("configure_restarea_camera_motion", min_speed, max_speed, speed_curve)

func is_restarea_camera_close_to(target_global: Vector2, tolerance: float) -> bool:
	if _camera_system != null and _camera_system.has_method("is_restarea_camera_close_to"):
		return bool(_camera_system.call("is_restarea_camera_close_to", target_global, tolerance))
	return false

func get_restarea_camera_world_position() -> Vector2:
	if _camera_system != null and _camera_system.has_method("get_camera_world_position"):
		return _camera_system.call("get_camera_world_position")
	return global_position

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
	if _camera_system != null and _camera_system.has_method("update_zoom_target_by_vision"):
		_camera_system.call("update_zoom_target_by_vision", vision_mul)
		return
	if player_camera == null:
		return
	if _base_camera_zoom == Vector2.ZERO:
		_base_camera_zoom = Vector2.ONE
	var zoom_factor := 1.0 / maxf(vision_mul, 0.05)
	_camera_zoom_target = _base_camera_zoom * zoom_factor * _get_phase_camera_zoom_factor()

func _get_phase_camera_zoom_factor() -> float:
	if PhaseManager != null and PhaseManager.has_method("current_state"):
		if str(PhaseManager.current_state()) == str(PhaseManager.PREPARE):
			return clampf(rest_phase_camera_zoom_factor, 0.2, 2.0)
	return 1.0

func _update_camera_zoom_smooth(delta: float) -> void:
	if player_camera == null:
		return
	var t := clampf(camera_zoom_lerp_speed * delta, 0.0, 1.0)
	player_camera.zoom = player_camera.zoom.lerp(_camera_zoom_target, t)
	_update_collect_area_anchor_to_screen_top()

func _update_camera_lookahead(delta: float) -> void:
	if player_camera == null:
		return
	if PhaseManager != null and PhaseManager.has_method("current_state"):
		if str(PhaseManager.current_state()) == str(PhaseManager.PREPARE):
			var reset_t := clampf(maxf(camera_lookahead_lerp_speed, 0.0) * maxf(delta, 0.0), 0.0, 1.0)
			_camera_offset_target = Vector2.ZERO
			player_camera.offset = player_camera.offset.lerp(Vector2.ZERO, reset_t)
			return
	var speed := velocity.length()
	var max_speed := maxf((PlayerData.player_speed + PlayerData.player_bonus_speed) * get_total_move_speed_mul(), 1.0)
	var speed_ratio := clampf(speed / max_speed, 0.0, 1.0)
	if speed_ratio < clampf(camera_lookahead_min_speed_ratio, 0.0, 1.0):
		speed_ratio = 0.0
	var move_dir := velocity.normalized() if speed > 0.01 else Vector2.ZERO
	_camera_offset_target = move_dir * maxf(camera_lookahead_distance, 0.0) * speed_ratio
	var t := clampf(maxf(camera_lookahead_lerp_speed, 0.0) * maxf(delta, 0.0), 0.0, 1.0)
	player_camera.offset = player_camera.offset.lerp(_camera_offset_target, t)

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
		if weapon.get_parent() != equppied_weapons:
			equppied_weapons.add_child(weapon)
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
		var velocity: float = state.get("velocity", 0.0)
		var offset: float = state.get("offset", 0.0)
		var target_angle := wrapf(base_angle + offset, -PI, PI)
		var angle_diff := _shortest_angle(current_angle, target_angle)
		velocity += clamp(angle_diff * ORBIT_ACCEL, -ORBIT_ACCEL, ORBIT_ACCEL) * delta
		velocity = clamp(velocity, -ORBIT_MAX_SPEED, ORBIT_MAX_SPEED)
		velocity = lerp(velocity, 0.0, clamp(ORBIT_FRICTION * delta, 0.0, 1.0))
		current_angle = wrapf(current_angle + velocity * delta, -PI, PI)
		state["angle"] = current_angle
		state["velocity"] = velocity
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
	if PhaseManager.current_state() == PhaseManager.GAMEOVER:
		return
	if _incoming_damage_pipeline == null:
		_incoming_damage_pipeline = DAMAGE_PIPELINE_SCRIPT.new() as DamagePipeline
	if _incoming_damage_profile == null:
		_setup_incoming_damage_profile()
	var result := _incoming_damage_pipeline.apply_incoming_damage(self, attack, _incoming_damage_profile)
	if not result.applied:
		return
	_apply_elite_hit_slow_if_needed(attack)
	if PlayerData.testing_keep_hp_above_zero and PlayerData.player_hp <= 0:
		PlayerData.player_hp = 1
	if PlayerData.player_hp <= 0:
		PhaseManager.enter_gameover()
		return
	print(self, PlayerData.player_hp)

func _apply_elite_hit_slow_if_needed(attack: Attack) -> void:
	if attack == null or _is_attack_from_player(attack):
		return
	if not _is_attack_from_elite_or_boss(attack):
		return
	var duration_msec := int(maxf(elite_hit_slow_duration_sec, 0.0) * 1000.0)
	if duration_msec <= 0:
		return
	_elite_hit_slow_until_msec = Time.get_ticks_msec() + duration_msec
	apply_move_speed_mul(ELITE_HIT_SLOW_SOURCE_ID, clampf(elite_hit_slow_mul, 0.05, 1.0))
	_clear_elite_hit_slow_after_delay(_elite_hit_slow_until_msec)

func _clear_elite_hit_slow_after_delay(token_until_msec: int) -> void:
	await get_tree().create_timer(maxf(elite_hit_slow_duration_sec, 0.0)).timeout
	if not is_inside_tree():
		return
	if token_until_msec != _elite_hit_slow_until_msec:
		return
	remove_move_speed_mul(ELITE_HIT_SLOW_SOURCE_ID)

func _is_attack_from_player(attack: Attack) -> bool:
	if attack == null:
		return false
	return attack.is_from_player()

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
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.clear_expired_scorch()

func _apply_scorch_on_fire_hit(fire_damage: int, source_node: Node = null, source_player: Node = null) -> void:
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.apply_scorch_on_fire_hit(fire_damage, source_node, source_player)

func _get_scorch_stack_cap(hp_ratio: float) -> int:
	if hp_ratio <= 0.5:
		return 3
	if hp_ratio <= 0.75:
		return 2
	return 1

func _clear_expired_frost() -> void:
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.clear_expired_frost()

func _apply_frost_on_freeze_hit() -> void:
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.apply_frost_on_freeze_hit()

func _refresh_frost_move_slow() -> void:
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.refresh_frost_move_slow()

func _clear_expired_energy_mark() -> void:
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.clear_expired_energy_mark()

func _apply_energy_mark_on_energy_hit(energy_damage: int) -> void:
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.apply_energy_mark_on_energy_hit(energy_damage)

func _try_trigger_energy_mark_burst(reference_attack: Attack) -> void:
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.try_trigger_energy_mark_burst(reference_attack)

func _apply_scorch_dot_tick(dot_damage: int) -> void:
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.apply_scorch_dot_tick(dot_damage)

func _update_incoming_elemental_effects(delta: float) -> void:
	_ensure_elemental_effect_system()
	if _elemental_effect_system == null:
		return
	_elemental_effect_system.update_incoming_elemental_effects(_incoming_damage_pipeline, _incoming_damage_profile, delta)

func _setup_incoming_damage_profile() -> void:
	var profile := DAMAGE_PROFILE_SCRIPT.new() as DamageProfile
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
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.on_profile_apply_frost_slow(move_multiplier)

func _profile_on_clear_frost_slow() -> void:
	_ensure_elemental_effect_system()
	if _elemental_effect_system != null:
		_elemental_effect_system.on_profile_clear_frost_slow()


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
	if area.is_in_group("collectables") and area is Coin:
		var value: int = area.collect()
		value = apply_loot_bonus(value, &"coin")
		PlayerData.player_gold += value
		PlayerData.round_coin_collected += value
		PlayerData.run_gold_earned += value
		coin_collected.emit()


func _on_collect_chip_area_area_entered(area) -> void:
	if area.is_in_group("collectables") and area is Chip:
		var value: int = area.collect()
		value = apply_loot_bonus(value, &"chip")
		PlayerData.player_exp += value
		PlayerData.round_chip_collected += value


func _on_grab_area_area_entered(area):
	if area.is_in_group("collectables"):
		if area is Coin:
			area.target = collect_area
		elif area is Chip:
			area.target = self


func _on_phase_changed(new_phase: String) -> void:
	var previous_phase := _last_phase
	_last_phase = new_phase
	_update_vision_effect()
	if new_phase == PhaseManager.PREPARE:
		clear_timed_statuses_for_prepare()
		_instant_reload_all_weapons()
		_force_all_skills_ready()
	if new_phase == PhaseManager.PREPARE and previous_phase == PhaseManager.BATTLE:
		_run_battle_end_auto_collect()
		return
	if new_phase == PhaseManager.BATTLE and _auto_loot_running:
		_auto_loot_running = false
		_restore_collect_ranges_after_auto_loot()

func _ensure_movement_system() -> void:
	if _movement_system != null:
		_movement_system.setup(self)
		return
	_movement_system = PLAYER_MOVEMENT_SYSTEM_SCRIPT.new()
	if _movement_system != null:
		_movement_system.setup(self)

func _ensure_camera_system() -> void:
	if _camera_system != null:
		_camera_system.setup(self, player_camera)
		return
	_camera_system = PLAYER_CAMERA_SYSTEM_SCRIPT.new()
	if _camera_system != null:
		_camera_system.setup(self, player_camera)

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
	if not collect_area:
		return
	for collectable in get_tree().get_nodes_in_group("collectables"):
		if not is_instance_valid(collectable):
			continue
		if collectable is Coin:
			collectable.target = collect_area
		elif collectable is Chip:
			collectable.target = self


func _run_battle_end_auto_collect() -> void:
	if _auto_loot_running:
		return
	_auto_loot_running = true
	_expand_collect_ranges_for_auto_loot()
	var elapsed := 0.0
	while elapsed < AUTO_LOOT_DURATION_SEC and _auto_loot_running and is_inside_tree():
		_process_auto_loot_grab_overlaps()
		await get_tree().create_timer(AUTO_LOOT_TICK_SEC).timeout
		elapsed += AUTO_LOOT_TICK_SEC
	_restore_collect_ranges_after_auto_loot()
	_auto_loot_running = false


func _expand_collect_ranges_for_auto_loot() -> void:
	var grab_circle := grab_radius.shape as CircleShape2D
	if grab_circle:
		grab_circle.radius = AUTO_LOOT_GRAB_RADIUS


func _restore_collect_ranges_after_auto_loot() -> void:
	update_grab_radius()


func _process_auto_loot_grab_overlaps() -> void:
	if grab_area == null or not is_instance_valid(grab_area):
		return
	for area in grab_area.get_overlapping_areas():
		if area == null or not is_instance_valid(area):
			continue
		_on_grab_area_area_entered(area)


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
	if _status_hint_manager != null and is_instance_valid(_status_hint_manager):
		_status_hint_manager.clear_all()

func _update_shared_heat_pool(delta: float) -> void:
	if _shared_heat_pool == null:
		return
	var next_signature := _build_shared_heat_signature()
	if next_signature != _shared_heat_signature:
		_shared_heat_signature = next_signature
		_rebuild_shared_heat_pool()
	_shared_heat_pool.cool_down(delta)

func _rebuild_shared_heat_pool() -> void:
	if _shared_heat_pool == null:
		return
	_shared_heat_pool.configure_from_weapons(PlayerData.player_weapon_list)
	_shared_heat_signature = _build_shared_heat_signature()

func mark_shared_heat_pool_dirty() -> void:
	_shared_heat_signature = ""

func get_shared_heat_pool() -> SharedHeatPool:
	return _shared_heat_pool

func _build_shared_heat_signature() -> String:
	var keys: PackedStringArray = []
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		var contributes := false
		if weapon.has_method("has_heat_trait"):
			contributes = bool(weapon.call("has_heat_trait"))
		elif weapon.has_method("has_heat_system"):
			contributes = bool(weapon.call("has_heat_system"))
		if not contributes:
			continue
		var max_heat: float = 0.0
		var cool_rate: float = 0.0
		if weapon.get("heat_max_value") != null:
			max_heat = float(weapon.get("heat_max_value"))
		if weapon.get("heat_cool_rate") != null:
			cool_rate = float(weapon.get("heat_cool_rate"))
		keys.append("%s:%.4f:%.4f" % [str(weapon.get_instance_id()), max_heat, cool_rate])
	keys.sort()
	return "|".join(keys)

func get_total_heat_value() -> float:
	if _shared_heat_pool == null:
		return 0.0
	return float(_shared_heat_pool.heat_value)

func get_total_heat_max() -> float:
	if _shared_heat_pool == null:
		return 0.0
	if not _shared_heat_pool.has_contributors():
		return 0.0
	return float(_shared_heat_pool.max_heat)

func get_total_heat_ratio() -> float:
	if _shared_heat_pool == null or not _shared_heat_pool.has_contributors():
		return 0.0
	return _shared_heat_pool.get_ratio()
