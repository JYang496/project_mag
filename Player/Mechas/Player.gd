extends CharacterBody2D
class_name Player

var extra_direction = Vector2.ZERO
@onready var equppied_weapons = $EquippedWeapons
@onready var equppied_augments = $EquippedAugments
@onready var unique_weapons = $UniqueWeapon
@onready var mecha_sprite = $MechaSprite
@onready var collect_area = get_node("%CollectArea")
@onready var grab_radius = $GrabArea/GrabShape
@onready var ui : UI = get_tree().get_first_node_in_group("ui")

var movement_enabled = true
var moveto_enabled = false
var moveto_dest := Vector2.ZERO
var distance_mouse_player = 0
const WEAPON_SLOTS = [[-16,-24],[16,-24],[16,24],[-16,24]]

@export var start_up_status = {
	"player_speed":100.0,
	"player_max_hp":5,
	"hp_regen":0,
	"armor":0,
	"shield":0,
	"damage_reduction":1.0,
	"crit_rate":0.0,
	"crit_damage":1.0,
	"grab_radius":50.0,
	"player_gold":0,
}
# Signals
signal active_skill()

func _ready():
	set_start_up_status()
	update_grab_radius()
	custom_ready()

func set_start_up_status():
	PlayerData.player_speed = start_up_status["player_speed"]
	PlayerData.player_max_hp = start_up_status["player_max_hp"]
	PlayerData.player_hp = PlayerData.player_max_hp
	PlayerData.hp_regen = start_up_status["hp_regen"]
	PlayerData.armor = start_up_status["armor"]
	PlayerData.shield = start_up_status["shield"]
	PlayerData.damage_reduction = start_up_status["damage_reduction"]
	PlayerData.crit_rate = start_up_status["crit_rate"]
	PlayerData.crit_damage = start_up_status["crit_damage"]
	PlayerData.grab_radius = start_up_status["grab_radius"]
	PlayerData.player_gold = start_up_status["player_gold"]

# overwrite the function on child class
func custom_ready():
	create_weapon("1")

func _physics_process(delta):
	movement(delta)
	overcharge(delta)
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ATTACK") and PlayerData.is_overcharged and PlayerData.overcharge_enable:
		if PlayerData.player_weapon_list.size() > 0:
			PlayerData.player_weapon_list[PlayerData.on_select_weapon].emit_signal("over_charge")
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
		weapon = load(WeaponData.weapon_list.data[item_id]["res"]).instantiate()
		weapon.level = level
	else:
		# Parameter is weapon node instead of String, common case when get weapon from inventory
		weapon = item_id
	
	# Put weapon into inventory if weapon list is full
	if PlayerData.player_weapon_list.size() >= PlayerData.max_weapon_num: 
		if len(InventoryData.inventory_slots) < InventoryData.INVENTORY_MAX_SLOTS:
			InventoryData.inventory_slots.append(weapon)
		return
	
	clean_up_empty_remote_transform()
	
	available_slot = PlayerData.player_weapon_list.size()
	var remote_transform = RemoteTransform2D.new()
	remote_transform.update_rotation = true
	equppied_weapons.add_child(remote_transform)
	weapon.position.x = WEAPON_SLOTS[available_slot][0]
	weapon.position.y = WEAPON_SLOTS[available_slot][1]
	remote_transform.add_child(weapon)
	remote_transform.remote_path = weapon.get_path()
	PlayerData.player_weapon_list.append(weapon)
	
	# Update exist weapon position
	for weapon_index in PlayerData.player_weapon_list.size():
		PlayerData.player_weapon_list[weapon_index].position.x = WEAPON_SLOTS[weapon_index][0]
		PlayerData.player_weapon_list[weapon_index].position.y = WEAPON_SLOTS[weapon_index][1]
	
	ui.refresh_border()

func clean_up_empty_remote_transform() -> void:
	for node in equppied_weapons.get_children():
		if node is RemoteTransform2D and node.get_child_count() == 0:
			node.queue_free()
	

func swap_weapon_position(weapon1, weapon2) -> void:
	if weapon1 == weapon2:
		return
	var slot1_index = PlayerData.player_weapon_list.find(weapon1)
	var slot2_index = PlayerData.player_weapon_list.find(weapon2)
	var temp = PlayerData.player_weapon_list[slot1_index]
	PlayerData.player_weapon_list[slot1_index] = PlayerData.player_weapon_list[slot2_index]
	PlayerData.player_weapon_list[slot2_index] = temp
	for weapon_index in PlayerData.player_weapon_list.size():
		PlayerData.player_weapon_list[weapon_index].position.x = WEAPON_SLOTS[weapon_index][0]
		PlayerData.player_weapon_list[weapon_index].position.y = WEAPON_SLOTS[weapon_index][1]

func movement(delta):
	equppied_weapons.rotation = global_position.direction_to(get_global_mouse_position()).angle() + deg_to_rad(90)
	unique_weapons.rotation = global_position.direction_to(get_global_mouse_position()).angle() + deg_to_rad(90)
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
	if distance_mouse_player.x > 0 : 
		mecha_sprite.flip_h = false
	elif distance_mouse_player.x < 0 :
		mecha_sprite.flip_h = true


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

# Player does not have death atm
func damaged(attack:Attack):
	PlayerData.player_hp -= attack.damage
	print(self, PlayerData.player_hp)


# When player is teleporting between zones, disable terrain collision. Enable when arrived.
func switch_terrain_collision(switch:bool):
	self.set_collision_mask_value(6,switch)


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


func _on_collect_chip_area_area_entered(area) -> void:
	if area.is_in_group("collectables") and area is Chip:
		var value = area.collect()
		PlayerData.player_exp += value


func _on_grab_area_area_entered(area):
	if area.is_in_group("collectables"):
		if area is Coin:
			area.target = collect_area
		elif area is Chip:
			area.target = self


func _on_detect_area_area_entered(area: Area2D) -> void:
	if not PlayerData.detected_enemies.has(area):
		PlayerData.detected_enemies.append(area)
		PlayerData.cloestest_enemy = get_closest_area_optimized(PlayerData.detected_enemies, self)


func _on_detect_area_area_exited(area: Area2D) -> void:
	if PlayerData.detected_enemies.has(area):
		PlayerData.detected_enemies.erase(area)
		PlayerData.cloestest_enemy = get_closest_area_optimized(PlayerData.detected_enemies, self)
