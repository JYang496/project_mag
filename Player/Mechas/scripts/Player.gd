extends CharacterBody2D
class_name Player

var extra_direction = Vector2.ZERO
@onready var equppied_weapons = $EquippedWeapons
@onready var equppied_augments = $EquippedAugments
@onready var unique_weapons = $UniqueWeapon
@onready var mecha_sprite = $MechaSprite
@onready var collect_area = get_node("%CollectArea")
@onready var grab_radius = $GrabArea/GrabShape
@onready var hurt_cd: Timer = $HurtCD
@onready var hurt_box: HurtBox = $HurtBox
@onready var collision_cd: Timer = $CollisionCD


var movement_enabled = true
var moveto_enabled = false
var moveto_dest := Vector2.ZERO
var distance_mouse_player = 0
var status_list = {}
const TARGET_MECHA_SIZE = Vector2(48,48)
const MECHA_DIRECTION_TEXTURES := {
	"left": preload("res://asset/images/characters/l.png"),
	"bottom_left": preload("res://asset/images/characters/bl.png"),
	"bottom": preload("res://asset/images/characters/b.png"),
	"bottom_right": preload("res://asset/images/characters/br.png"),
	"right": preload("res://asset/images/characters/r.png"),
	"top_right": preload("res://asset/images/characters/fr.png"),
	"top": preload("res://asset/images/characters/f.png"),
	"top_left": preload("res://asset/images/characters/fl.png"),
}
var current_mecha_direction := ""
const ORBIT_RADIUS := Vector2(40, 20)
const ORBIT_ACCEL := 16.0
const ORBIT_MAX_SPEED := 8.0
const ORBIT_FRICTION := 6.0
const ORBIT_OFFSET := Vector2(0, -25)
var weapon_orbit_states: Dictionary = {}
# Signals
signal active_skill()
signal coin_collected()

func _ready():
	PlayerData.player = self
	_resize_mecha_sprite()
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
		var weapon_def = GlobalVariables.weapon_list[item_id]
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
		velocity = mov.normalized() * (PlayerData.player_speed + PlayerData.player_bonus_speed)
	else:
		velocity = Vector2.ZERO
	if moveto_enabled:
		self.global_position = self.global_position.move_toward(moveto_dest, delta * PlayerData.player_bonus_speed)
	
	distance_mouse_player = get_global_mouse_position() - global_position
	_update_mecha_direction(distance_mouse_player)
	unique_weapons.rotation = global_position.direction_to(get_global_mouse_position()).angle() + deg_to_rad(90)
	_update_weapon_orbits(delta)


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

func _resize_mecha_sprite() -> void:
	if not mecha_sprite or not mecha_sprite.texture:
		return
	var tex_size: Vector2 = mecha_sprite.texture.get_size()
	if tex_size.x == 0 or tex_size.y == 0:
		return
	mecha_sprite.scale = TARGET_MECHA_SIZE / tex_size

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
	var angle_deg = rad_to_deg(direction.angle())
	var new_dir := ""
	if angle_deg >= -22.5 and angle_deg < 22.5:
		new_dir = "right"
	elif angle_deg >= 22.5 and angle_deg < 67.5:
		new_dir = "top_right"
	elif angle_deg >= 67.5 and angle_deg < 112.5:
		new_dir = "top"
	elif angle_deg >= 112.5 and angle_deg < 157.5:
		new_dir = "top_left"
	elif angle_deg >= 157.5 or angle_deg < -157.5:
		new_dir = "left"
	elif angle_deg >= -157.5 and angle_deg < -112.5:
		new_dir = "bottom_left"
	elif angle_deg >= -112.5 and angle_deg < -67.5:
		new_dir = "bottom"
	elif angle_deg >= -67.5 and angle_deg < -22.5:
		new_dir = "bottom_right"
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
		var value = area.collect()
		PlayerData.player_gold += value
		PlayerData.round_coin_collected += value
		coin_collected.emit()


func _on_collect_chip_area_area_entered(area) -> void:
	if area.is_in_group("collectables") and area is Chip:
		var value = area.collect()
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
