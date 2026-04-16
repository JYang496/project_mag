extends CharacterBody2D
class_name Player

const SHARED_HEAT_POOL_SCRIPT := preload("res://Player/Weapons/Heat/shared_heat_pool.gd")
const DAMAGE_PIPELINE_SCRIPT := preload("res://Utility/damage/damage_pipeline.gd")
const DAMAGE_PROFILE_SCRIPT := preload("res://Utility/damage/damage_profile.gd")

var extra_direction = Vector2.ZERO
@onready var equppied_weapons = $EquippedWeapons
@onready var equppied_augments = $EquippedAugments
@onready var mecha_sprite = $MechaSprite
@onready var player_camera: Camera2D = $Camera2D
@onready var collect_area = get_node("%CollectArea")
@onready var grab_radius = $GrabArea/GrabShape
@onready var detect_area: Area2D = $DetectArea
@onready var detect_shape: CollisionShape2D = $DetectArea/CollisionShape2D
@onready var hurt_cd: Timer = $HurtCD
@onready var hurt_box: HurtBox = $HurtBox
@onready var collision_cd: Timer = $CollisionCD
@onready var active_skill_holder: Node2D = $ActiveSkill


var movement_enabled = true
var moveto_enabled = false
var moveto_dest := Vector2.ZERO
var distance_mouse_player = 0
var status_list = {}
const TARGET_MECHA_SIZE = Vector2(96,96)
const MECHA_DIRECTION_TEXTURES := {
	"top_left": preload("res://asset/images/characters/2b.png"),
	"bottom_left": preload("res://asset/images/characters/2f.png"),
	"top_right": preload("res://asset/images/characters/2b.png"),
	"bottom_right": preload("res://asset/images/characters/2f.png"),
}
var current_mecha_direction := ""
const ORBIT_RADIUS := Vector2(40, 20)
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
var weapon_orbit_states: Dictionary = {}
var _move_speed_mul_modifiers: Dictionary = {}
var _vision_mul_modifiers: Dictionary = {}
var _damage_mul_modifiers: Dictionary = {}
var _low_hp_damage_modifiers: Dictionary = {}
var _bonus_hit_modifiers: Dictionary = {}
var _loot_bonus_modifiers: Dictionary = {}
var _scorch_stacks: int = 0
var _scorch_expires_at_msec: int = 0
var _scorch_dot_damage_per_stack: int = 1
var _scorch_dot_accum_sec: float = 0.0
var _scorch_source_node: Node
var _scorch_source_player: Node
var _is_processing_scorch_dot: bool = false
var _frost_stacks: int = 0
var _frost_expires_at_msec: int = 0
var _frost_next_stack_at_msec: int = 0
var _energy_mark_value: int = 0
var _energy_mark_expires_at_msec: int = 0
var _energy_mark_trigger_ready_at_msec: int = 0
var _is_processing_energy_burst: bool = false
var _base_detect_shape_size := Vector2.ZERO
var _base_camera_zoom := Vector2.ONE
var _camera_zoom_target := Vector2.ONE
var _shared_heat_pool: SharedHeatPool
var _shared_heat_signature: String = ""
var _incoming_damage_pipeline: DamagePipeline
var _incoming_damage_profile: DamageProfile
var _passive_time_tick_accum: float = 0.0
@export var camera_zoom_lerp_speed: float = 6.0
@export var default_active_skill_path: String = "res://Player/Skills/bullet_time"
@export var player_max_energy: float = 100.0
@export var player_energy_regen_per_sec: float = 8.0
var _player_energy: float = 100.0
var _last_weapon_skill_fail_reason: String = ""
var _last_player_skill_fail_reason: String = ""
# Signals
signal active_skill()
signal player_active_skill()
signal weapon_active_skill()
signal coin_collected()

func _ready():
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
	movement(delta)
	_update_camera_zoom_smooth(delta)
	move_and_slide()

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
	var available_slot = 0
	
	# Create a new weapon when assign string, othervise node
	var weapon
	if item_id is String:
		var resolved_weapon_id := DataHandler.resolve_weapon_id_for_standalone(str(item_id))
		var weapon_def = DataHandler.read_weapon_data(resolved_weapon_id)
		if weapon_def == null:
			push_warning("create_weapon failed: weapon id %s not found." % str(item_id))
			return
		weapon = weapon_def.scene.instantiate()
		weapon.level = level
	else:
		# Parameter is weapon node instead of String, common case when get weapon from inventory
		weapon = item_id
	
	# Put weapon into inventory if weapon list is full
	if PlayerData.player_weapon_list.size() >= PlayerData.max_weapon_num: 
		if len(InventoryData.inventory_slots) < InventoryData.INVENTORY_MAX_SLOTS:
			InventoryData.inventory_slots.append(weapon)
		return
	
	available_slot = PlayerData.player_weapon_list.size()
	equppied_weapons.add_child(weapon)
	weapon.position = Vector2.ZERO
	PlayerData.player_weapon_list.append(weapon)
	if PlayerData.player_weapon_list.size() == 1:
		PlayerData.set_main_weapon_index(0)
	_apply_weapon_roles()
	_sync_weapon_orbit_states(true)
	_rebuild_shared_heat_pool()
	if GlobalVariables.ui != null:
		GlobalVariables.ui.refresh_border()

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
	if main_weapon.has_method("handle_primary_input"):
		main_weapon.call("handle_primary_input", pressed, just_pressed, just_released, delta)

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
	var idx := PlayerData.main_weapon_index
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
	if movement_enabled:
		var x_mov = Input.get_action_strength("RIGHT") - Input.get_action_strength("LEFT")
		var y_mov = Input.get_action_strength("DOWN") - Input.get_action_strength("UP")
		var mov = Vector2(x_mov,y_mov) + extra_direction
		var speed = (PlayerData.player_speed + PlayerData.player_bonus_speed) * get_total_move_speed_mul()
		velocity = mov.normalized() * speed
	else:
		velocity = Vector2.ZERO
	if moveto_enabled:
		self.global_position = self.global_position.move_toward(moveto_dest, delta * PlayerData.player_bonus_speed)
	
	distance_mouse_player = get_global_mouse_position() - global_position
	_update_mecha_direction(distance_mouse_player)
	_update_weapon_orbits(delta)

func apply_move_speed_mul(source_id: StringName, mul: float) -> void:
	if source_id == StringName():
		return
	_move_speed_mul_modifiers[source_id] = clampf(mul, 0.05, 10.0)

func remove_move_speed_mul(source_id: StringName) -> void:
	if _move_speed_mul_modifiers.has(source_id):
		_move_speed_mul_modifiers.erase(source_id)

func get_total_move_speed_mul() -> float:
	var total := 1.0
	for mul in _move_speed_mul_modifiers.values():
		total *= float(mul)
	return maxf(total, 0.05)

func apply_vision_mul(source_id: StringName, mul: float) -> void:
	if source_id == StringName():
		return
	_vision_mul_modifiers[source_id] = clampf(mul, 0.05, 10.0)
	_update_vision_effect()

func remove_vision_mul(source_id: StringName) -> void:
	if _vision_mul_modifiers.has(source_id):
		_vision_mul_modifiers.erase(source_id)
	_update_vision_effect()

func get_total_vision_mul() -> float:
	var total := 1.0
	for mul in _vision_mul_modifiers.values():
		total *= float(mul)
	return maxf(total, 0.05)

func apply_damage_mul(source_id: StringName, mul: float) -> void:
	if source_id == StringName():
		return
	_damage_mul_modifiers[source_id] = maxf(mul, 0.05)

func remove_damage_mul(source_id: StringName) -> void:
	if _damage_mul_modifiers.has(source_id):
		_damage_mul_modifiers.erase(source_id)

func register_low_hp_damage_bonus(source_id: StringName, min_hp_ratio: float, max_damage_mul: float) -> void:
	if source_id == StringName():
		return
	_low_hp_damage_modifiers[source_id] = {
		"min_hp_ratio": clampf(min_hp_ratio, 0.05, 1.0),
		"max_damage_mul": maxf(max_damage_mul, 1.0)
	}

func remove_low_hp_damage_bonus(source_id: StringName) -> void:
	if _low_hp_damage_modifiers.has(source_id):
		_low_hp_damage_modifiers.erase(source_id)

func register_bonus_hit(source_id: StringName, chance: float, damage: int) -> void:
	if source_id == StringName():
		return
	_bonus_hit_modifiers[source_id] = {
		"chance": clampf(chance, 0.0, 1.0),
		"damage": max(1, damage)
	}

func remove_bonus_hit(source_id: StringName) -> void:
	if _bonus_hit_modifiers.has(source_id):
		_bonus_hit_modifiers.erase(source_id)

func register_loot_bonus(source_id: StringName, coin_chance: float, chip_chance: float, multiplier: int) -> void:
	if source_id == StringName():
		return
	_loot_bonus_modifiers[source_id] = {
		"coin_chance": clampf(coin_chance, 0.0, 1.0),
		"chip_chance": clampf(chip_chance, 0.0, 1.0),
		"multiplier": max(2, multiplier)
	}

func remove_loot_bonus(source_id: StringName) -> void:
	if _loot_bonus_modifiers.has(source_id):
		_loot_bonus_modifiers.erase(source_id)

func compute_outgoing_damage(base_damage: int) -> int:
	var total_mul_delta := 0.0
	for mul in _damage_mul_modifiers.values():
		total_mul_delta += (float(mul) - 1.0)
	total_mul_delta += (_get_low_hp_damage_mul() - 1.0)
	var final_mul := maxf(0.0, 1.0 + total_mul_delta)
	return max(1, int(round(float(base_damage) * final_mul)))

func apply_bonus_hit_if_needed(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("damaged"):
		return
	for data in _bonus_hit_modifiers.values():
		var chance: float = float(data.get("chance", 0.0))
		var bonus_damage: int = int(data.get("damage", 1))
		if randf() <= chance:
			var bonus_attack := Attack.new()
			bonus_attack.damage = max(1, bonus_damage)
			bonus_attack.damage_type = Attack.TYPE_PHYSICAL
			bonus_attack.source_node = self
			bonus_attack.source_player = self
			target.damaged(bonus_attack)

func apply_loot_bonus(value: int, loot_type: StringName) -> int:
	var result: int = max(0, value)
	for data in _loot_bonus_modifiers.values():
		var chance: float = 0.0
		if loot_type == &"coin":
			chance = float(data.get("coin_chance", 0.0))
		elif loot_type == &"chip":
			chance = float(data.get("chip_chance", 0.0))
		if chance <= 0.0:
			continue
		if randf() <= chance:
			var multiplier: int = int(data.get("multiplier", 2))
			result *= max(2, multiplier)
	return result

func _get_low_hp_damage_mul() -> float:
	if _low_hp_damage_modifiers.is_empty():
		return 1.0
	var max_hp: float = maxf(float(PlayerData.player_max_hp), 1.0)
	var hp_ratio: float = float(PlayerData.player_hp) / max_hp
	var best_mul := 1.0
	for data in _low_hp_damage_modifiers.values():
		var min_ratio: float = clampf(float(data.get("min_hp_ratio", 0.25)), 0.05, 1.0)
		var max_mul: float = maxf(float(data.get("max_damage_mul", 1.0)), 1.0)
		if hp_ratio >= 1.0:
			continue
		var factor: float = clampf((1.0 - hp_ratio) / maxf(1.0 - min_ratio, 0.001), 0.0, 1.0)
		var computed_mul: float = lerpf(1.0, max_mul, factor)
		if computed_mul > best_mul:
			best_mul = computed_mul
	return best_mul


func move_to(dest:Vector2) -> void:
	movement_enabled = false
	moveto_enabled = true
	moveto_dest = dest

func arrived() -> void:
	movement_enabled = true
	moveto_enabled = false
	moveto_dest = Vector2.ZERO

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
	if player_camera == null:
		return
	if _base_camera_zoom == Vector2.ZERO:
		_base_camera_zoom = Vector2.ONE
	# Lower vision multiplier means stronger zoom-out (wider view).
	var zoom_factor := 1.0 / maxf(vision_mul, 0.05)
	_camera_zoom_target = _base_camera_zoom * zoom_factor

func _update_camera_zoom_smooth(delta: float) -> void:
	if player_camera == null:
		return
	var t := clampf(camera_zoom_lerp_speed * delta, 0.0, 1.0)
	player_camera.zoom = player_camera.zoom.lerp(_camera_zoom_target, t)

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
	var uniform_scale := minf(TARGET_MECHA_SIZE.x / tex_size.x, TARGET_MECHA_SIZE.y / tex_size.y)
	mecha_sprite.scale = Vector2.ONE * uniform_scale

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
	mecha_sprite.flip_h = direction.x > 0.0
	var new_dir := ""
	if direction.x < 0.0:
		new_dir = "top_left" if direction.y < 0.0 else "bottom_left"
	else:
		new_dir = "top_right" if direction.y < 0.0 else "bottom_right"
	if new_dir == "" or new_dir == current_mecha_direction:
		return
	current_mecha_direction = new_dir
	if MECHA_DIRECTION_TEXTURES.has(new_dir):
		mecha_sprite.texture = MECHA_DIRECTION_TEXTURES[new_dir]
		_resize_mecha_sprite()

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
	if PlayerData.testing_keep_hp_above_zero and PlayerData.player_hp <= 0:
		PlayerData.player_hp = 1
	if PlayerData.player_hp <= 0:
		PhaseManager.enter_gameover()
		return
	print(self, PlayerData.player_hp)

func _get_total_armor() -> int:
	return max(0, int(PlayerData.armor) + int(PlayerData.bonus_armor))

func _get_total_damage_reduction() -> float:
	return clampf(float(PlayerData.damage_reduction) * float(PlayerData.bonus_damage_reduction), 0.2, 5.0)

func _clear_expired_scorch() -> void:
	if _scorch_stacks <= 0:
		_scorch_stacks = 0
		_scorch_expires_at_msec = 0
		_scorch_dot_damage_per_stack = 1
		_scorch_dot_accum_sec = 0.0
		_scorch_source_node = null
		_scorch_source_player = null
		return
	if Time.get_ticks_msec() < _scorch_expires_at_msec:
		return
	_scorch_stacks = 0
	_scorch_expires_at_msec = 0
	_scorch_dot_damage_per_stack = 1
	_scorch_dot_accum_sec = 0.0
	_scorch_source_node = null
	_scorch_source_player = null

func _apply_scorch_on_fire_hit(fire_damage: int, source_node: Node = null, source_player: Node = null) -> void:
	var max_hp: float = maxf(float(PlayerData.player_max_hp), 1.0)
	var hp_ratio: float = clampf(float(max(PlayerData.player_hp, 0)) / max_hp, 0.0, 1.0)
	var stack_cap := _get_scorch_stack_cap(hp_ratio)
	if _scorch_stacks < stack_cap:
		_scorch_stacks += 1
	var per_stack_dot: int = max(1, int(round(float(max(1, fire_damage)) * SCORCH_DOT_RATIO_PER_STACK)))
	_scorch_dot_damage_per_stack = max(_scorch_dot_damage_per_stack, per_stack_dot)
	_scorch_source_node = source_node
	_scorch_source_player = source_player
	_scorch_expires_at_msec = Time.get_ticks_msec() + int(SCORCH_DURATION_SEC * 1000.0)

func _get_scorch_stack_cap(hp_ratio: float) -> int:
	if hp_ratio <= 0.5:
		return 3
	if hp_ratio <= 0.75:
		return 2
	return 1

func _clear_expired_frost() -> void:
	if _frost_stacks <= 0:
		_frost_stacks = 0
		_frost_expires_at_msec = 0
		_frost_next_stack_at_msec = 0
		remove_move_speed_mul(FROST_MOVE_SPEED_SOURCE)
		return
	if Time.get_ticks_msec() < _frost_expires_at_msec:
		return
	_frost_stacks = 0
	_frost_expires_at_msec = 0
	_frost_next_stack_at_msec = 0
	remove_move_speed_mul(FROST_MOVE_SPEED_SOURCE)

func _apply_frost_on_freeze_hit() -> void:
	var now_msec := Time.get_ticks_msec()
	if _frost_stacks < FROST_MAX_STACKS and now_msec >= _frost_next_stack_at_msec:
		_frost_stacks += 1
		_frost_next_stack_at_msec = now_msec + int(FROST_STACK_INTERVAL_SEC * 1000.0)
	_refresh_frost_move_slow()
	_frost_expires_at_msec = now_msec + int(FROST_DURATION_SEC * 1000.0)

func _refresh_frost_move_slow() -> void:
	if _frost_stacks <= 0:
		remove_move_speed_mul(FROST_MOVE_SPEED_SOURCE)
		return
	var move_mul := clampf(1.0 - float(_frost_stacks) * FROST_SLOW_PER_STACK, 0.05, 1.0)
	apply_move_speed_mul(FROST_MOVE_SPEED_SOURCE, move_mul)

func _clear_expired_energy_mark() -> void:
	if _energy_mark_value <= 0:
		_energy_mark_value = 0
		_energy_mark_expires_at_msec = 0
		return
	if Time.get_ticks_msec() < _energy_mark_expires_at_msec:
		return
	_energy_mark_value = 0
	_energy_mark_expires_at_msec = 0

func _apply_energy_mark_on_energy_hit(energy_damage: int) -> void:
	var gained_mark: int = max(0, int(round(float(max(0, energy_damage)) * ENERGY_MARK_RATIO)))
	if gained_mark <= 0:
		return
	var mark_cap: int = max(1, int(round(maxf(float(PlayerData.player_max_hp), 1.0) * ENERGY_MARK_MAX_HP_RATIO)))
	_energy_mark_value = mini(mark_cap, _energy_mark_value + gained_mark)
	_energy_mark_expires_at_msec = Time.get_ticks_msec() + int(ENERGY_MARK_DURATION_SEC * 1000.0)

func _try_trigger_energy_mark_burst(reference_attack: Attack) -> void:
	if _energy_mark_value <= 0:
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec < _energy_mark_trigger_ready_at_msec:
		return
	if PlayerData.player_hp >= _energy_mark_value:
		return
	var burst_damage := _energy_mark_value
	_energy_mark_value = 0
	_energy_mark_expires_at_msec = 0
	_energy_mark_trigger_ready_at_msec = now_msec + int(ENERGY_MARK_TRIGGER_COOLDOWN_SEC * 1000.0)
	if burst_damage <= 0:
		return
	var burst_attack := Attack.new()
	burst_attack.damage = burst_damage
	burst_attack.damage_type = Attack.TYPE_ENERGY
	if reference_attack != null:
		burst_attack.source_node = reference_attack.source_node
		burst_attack.source_player = reference_attack.source_player
	_is_processing_energy_burst = true
	damaged(burst_attack)
	_is_processing_energy_burst = false

func _apply_scorch_dot_tick(dot_damage: int) -> void:
	if dot_damage <= 0:
		return
	var dot_attack := Attack.new()
	dot_attack.damage = dot_damage
	dot_attack.damage_type = Attack.TYPE_FIRE
	dot_attack.source_node = _scorch_source_node
	dot_attack.source_player = _scorch_source_player
	_is_processing_scorch_dot = true
	damaged(dot_attack)
	_is_processing_scorch_dot = false

func _update_incoming_elemental_effects(delta: float) -> void:
	if _incoming_damage_pipeline == null or _incoming_damage_profile == null:
		return
	_incoming_damage_pipeline.process_periodic_effects(self, _incoming_damage_profile, delta)

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
	apply_move_speed_mul(FROST_MOVE_SPEED_SOURCE, move_multiplier)

func _profile_on_clear_frost_slow() -> void:
	remove_move_speed_mul(FROST_MOVE_SPEED_SOURCE)


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
	if new_phase == PhaseManager.PREPARE:
		return


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
