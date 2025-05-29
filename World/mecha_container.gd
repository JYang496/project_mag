extends Control

@export var mecha_id :int = 1

@onready var mech_data = DataHandler.read_mecha_data(str(mecha_id))
@onready var mech_autosave = DataHandler.read_autosave_mecha_data(str(mecha_id))

@onready var icon_container: HBoxContainer = $Mechas/IconContainer

@onready var mecha_name: Label = $Mechas/ColorRect/mecha_name
@onready var current_exp: Label = $Mechas/ColorRect/current_exp
@onready var current_level: Label = $Mechas/ColorRect/current_level
@onready var player_max_hp: Label = $Mechas/ColorRect/VBoxContainer/player_max_hp
@onready var player_speed: Label = $Mechas/ColorRect/VBoxContainer/player_speed
@onready var armor: Label = $Mechas/ColorRect/VBoxContainer/armor
@onready var shield: Label = $Mechas/ColorRect/VBoxContainer/shield
@onready var crit_rate: Label = $Mechas/ColorRect/VBoxContainer2/crit_rate
@onready var crit_damage: Label = $Mechas/ColorRect/VBoxContainer2/crit_damage
@onready var grab_radius: Label = $Mechas/ColorRect/VBoxContainer2/grab_radius
@onready var player_gold: Label = $Mechas/ColorRect/VBoxContainer2/player_gold


@onready var on_select_id : int = 1
func _ready() -> void:
	for mechaselect : MechaSelect in icon_container.get_children():
		mechaselect.on_select = true if mechaselect.mecha_id == on_select_id else false
		mechaselect.update()

func update_labels() -> void:
	var lvl_index = int(mech_autosave["current_level"]) - 1
	mecha_name.text = mech_data["name"]
	current_exp.text = "Exp: %s / %s" %[mech_autosave["current_exp"], mech_data["next_level_exp"][lvl_index]]
	current_level.text = "Level: %s / %s" % [mech_autosave["current_level"], mech_data["max_level"]]
	player_max_hp.text = "Max HP: %s" % [mech_data["player_max_hp"][lvl_index]]
	player_speed.text = "Player speed: %s" % [mech_data["player_speed"][lvl_index]]
	armor.text = "Armor: %s" % [mech_data["armor"][lvl_index]]
	shield.text = "Shield: %s" % [mech_data["shield"][lvl_index]]
	crit_rate.text = "Crit Rate: %s" % [mech_data["crit_rate"][lvl_index]]
	crit_damage.text = "Crit Damage: %s" % [mech_data["crit_damage"][lvl_index]]
	grab_radius.text = "Grab Radius: %s" % [mech_data["grab_radius"][lvl_index]]
	player_gold.text = "Gold: %s" % [mech_data["player_gold"][lvl_index]]

func _on_mecha_select_update_on_select(id) -> void:
	mecha_id = int(id)
	mech_data = DataHandler.read_mecha_data(str(id))
	mech_autosave = DataHandler.read_autosave_mecha_data(str(id))
	update_labels()
	on_select_id = int(id)
	for mechaselect : MechaSelect in icon_container.get_children():
		mechaselect.on_select = true if mechaselect.mecha_id == on_select_id else false
		mechaselect.update()
	
