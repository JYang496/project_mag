extends CharacterBody2D
class_name Player

var extra_direction = Vector2.ZERO
@onready var equppied_weapons = $EquippedWeapons
@onready var equppied_augments = $EquippedAugments
@onready var unique_weapons = $UniqueWeapon
@onready var mecha_sprite = $MechaSprite
@onready var player_camera: Camera2D = $Camera2D
@onready var collect_area = get_node("%CollectArea")
@onready var grab_radius = $GrabArea/GrabShape
@onready var detect_area: Area2D = $DetectArea
@onready var detect_shape: CollisionShape2D = $DetectArea/CollisionShape2D
@onready var hurt_cd: Timer = $HurtCD
@onready var hurt_box: HurtBox = $HurtBox
@onready var collision_cd: Timer = $CollisionCD


var movement_enabled = true
var moveto_enabled = false
var moveto_dest := Vector2.ZERO
var distance_mouse_player = 0
var status_list = {}
const TARGET_MECHA_SIZE = Vector2(76,76)
const MECHA_DIRECTION_TEXTURES := {
	"top_left": preload("res://asset/images/characters/4_lb.png"),
	"bottom_left": preload("res://asset/images/characters/4_lf.png"),
	"top_right": preload("res://asset/images/characters/4_rb.png"),
	"bottom_right": preload("res://asset/images/characters/4_rf.png"),
}
var current_mecha_direction := ""
const ORBIT_RADIUS := Vector2(40, 20)
const ORBIT_ACCEL := 16.0
const ORBIT_MAX_SPEED := 8.0
const ORBIT_FRICTION := 6.0
const ORBIT_OFFSET := Vector2(0, -25)
var weapon_orbit_states: Dictionary = {}
var _move_speed_mul_modifiers: Dictionary = {}
var _vision_mul_modifiers: Dictionary = {}
var _damage_mul_modifiers: Dictionary = {}
var _low_hp_damage_modifiers: Dictionary = {}
var _bonus_hit_modifiers: Dictionary = {}
var _loot_bonus_modifiers: Dictionary = {}
var _base_detect_shape_size := Vector2.ZERO
var _base_camera_zoom := Vector2.ONE
var _camera_zoom_target := Vector2.ONE
@export var camera_zoom_lerp_speed: float = 6.0
# Signals
signal active_skill()
signal coin_collected()

func _ready():
	PlayerData.player = self
	mecha_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_resize_mecha_sprite()
	_cache_camera_zoom_base()
	_camera_zoom_target = _base_camera_zoom
	_cache_detect_shape_base()
	_update_vision_effect()
	_sync_weapon_orbit_states(true)
	update_grab_radius()
	custom_ready()
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))

# overwrite the function on child class
func custom_ready():
	create_weapon("1")

func _physics_process(delta):
	_sync_weapon_orbit_states()
	movement(delta)
	_update_camera_zoom_smooth(delta)
	overcharge(delta)
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ATTACK") and PlayerData.is_overcharged and PlayerData.overcharge_enable:
		if PlayerData.player_weapon_list.size() > 0:
			var select_index := PlayerData.on_select_weapon
			if select_index < 0 or select_index >= PlayerData.player_weapon_list.size():
				return
			var selected_weapon = PlayerData.player_weapon_list[select_index]
			if is_instance_valid(selected_weapon):
				selected_weapon.emit_signal("over_charge")
			PlayerData.overcharge_enable = false
	if event.is_action_pressed("SKILL"):
		active_skill.emit()
	if event.is_action_pressed("OVERCHARGE") and not PlayerData.is_overcharged and PlayerData.overcharge_enable:
		PlayerData.is_overcharging = true
	if event.is_action_released("OVERCHARGE"):
		PlayerData.is_overcharging = false

func overcharge(delta) ->void:
	if PlayerData.is_overcharging:
		PlayerData.overcharge_time += delta

func create_weapon(item_id, level := 1):
	var available_slot = 0
	
	# Create a new weapon when assign string, othervise node
	var weapon
	if item_id is String:
		var weapon_def = DataHandler.read_weapon_data(str(item_id))
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
	
	_sync_weapon_orbit_states(true)
	GlobalVariables.ui.refresh_border()

func swap_weapon_position(weapon1, weapon2) -> void:
	if weapon1 == weapon2:
		return
	var slot1_index = PlayerData.player_weapon_list.find(weapon1)
	var slot2_index = PlayerData.player_weapon_list.find(weapon2)
	var temp = PlayerData.player_weapon_list[slot1_index]
	PlayerData.player_weapon_list[slot1_index] = PlayerData.player_weapon_list[slot2_index]
	PlayerData.player_weapon_list[slot2_index] = temp
	_sync_weapon_orbit_states(true)

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
	unique_weapons.rotation = global_position.direction_to(get_global_mouse_position()).angle() + deg_to_rad(90)
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
	var total_mul := 1.0
	for mul in _damage_mul_modifiers.values():
		total_mul *= float(mul)
	total_mul *= _get_low_hp_damage_mul()
	return max(1, int(round(float(base_damage) * total_mul)))

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
	PlayerData.player_hp -= attack.damage
	if PlayerData.testing_keep_hp_above_zero and PlayerData.player_hp <= 0:
		PlayerData.player_hp = 1
	if PlayerData.player_hp <= 0:
		PhaseManager.enter_gameover()
		return
	hurt_box.set_collision_layer_value(1,false)
	#self.set_collision_mask_value(3,false)
	#self.set_collision_layer_value(1,false)
	hurt_cd.start(PlayerData.hurt_cd)
	collision_cd.start(PlayerData.collision_cd)
	print(self, PlayerData.player_hp)


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
		_attract_all_coins()


func _attract_all_coins() -> void:
	if not collect_area:
		return
	for collectable in get_tree().get_nodes_in_group("collectables"):
		if collectable is Coin and is_instance_valid(collectable):
			collectable.target = collect_area


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
