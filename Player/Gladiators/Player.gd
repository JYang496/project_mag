extends CharacterBody2D
class_name Player

var extra_direction = Vector2.ZERO
@onready var equppied_weapons = $EquippedWeapons
@onready var equppied_augments = $EquippedAugments
@onready var unique_weapons = $UniqueWeapon
@onready var mecha_sprite = $MechaSprite
@onready var collect_area = get_node("%CollectArea")
@onready var grab_radius = $GrabArea/GrabShape

var movement_enabled = true
var moveto_enabled = false
var moveto_dest := Vector2.ZERO
var distance_mouse_player = 0
const WEAPON_SLOTS = [[16,-24],[-16,-24],[16,24],[-16,24]]
var equppied_weapons_list : Array[String] = []


func _ready():
	update_grab_radius()
	# Init weapon slots
	for i in range(0,WEAPON_SLOTS.size()):
		equppied_weapons_list.append("0")


func _physics_process(delta):
	movement(delta)
	move_and_slide()

func getEquippedWeapons():
	return equppied_weapons_list

func create_weapon(item_id:String):
	# Find out available slot, if no available slots, return
	var available_slot = 0
	while available_slot < equppied_weapons_list.size() and equppied_weapons_list[available_slot] != "0":
		available_slot += 1
	if available_slot >= equppied_weapons_list.size():
		return
	
	var remote_transform = RemoteTransform2D.new()
	remote_transform.update_rotation = true
	equppied_weapons.add_child(remote_transform)
	var weapon = load(WeaponData.weapon_list.data[item_id]["res"]).instantiate()
	weapon.position.x = WEAPON_SLOTS[available_slot][0]
	weapon.position.y = WEAPON_SLOTS[available_slot][1]
	remote_transform.add_child(weapon)
	remote_transform.remote_path = weapon.get_path()
	equppied_weapons_list[available_slot] = item_id
	PlayerData.player_weapon_list.append(weapon)

func movement(delta):
	# TODO: get position to get random or mouse
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
	print(PlayerData.player_hp)


# When player is teleporting between zones, disable terrain collision. Enable when arrived.
func switch_terrain_collision(switch:bool):
	self.set_collision_mask_value(6,switch)

func _on_collect_area_area_entered(area):
	if area.is_in_group("collectables"):
		var value = area.collect()
		PlayerData.player_gold += value


func _on_grab_area_area_entered(area):
	if area.is_in_group("collectables"):
		area.target = collect_area
