extends Control

@export var mecha_id :int = 1

var mech_data: MechaDefinition
var mech_autosave: Dictionary = {}

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
	_refresh_mecha_data()
	update_labels()

func update_labels() -> void:
	_refresh_mecha_data()
	if mech_data == null or mech_autosave.is_empty():
		push_warning("MechaContainer failed to load mecha data for id=%s" % str(mecha_id))
		return
	var lvl_index = int(mech_autosave["current_level"]) - 1
	var crit_rate_value: float = mech_data.crit_rate[lvl_index]
	mecha_name.text = mech_data.display_name
	current_exp.text = "Exp: %s / %s" %[mech_autosave["current_exp"], mech_data["next_level_exp"][lvl_index]]
	current_level.text = "Level: %s / %s" % [mech_autosave["current_level"], mech_data["max_level"]]
	player_max_hp.text = "Max HP: %s" % [mech_data.player_max_hp[lvl_index]]
	player_speed.text = "Player speed: %s" % [mech_data.player_speed[lvl_index]]
	armor.text = "Armor: %s" % [mech_data.armor[lvl_index]]
	shield.text = "Shield: %s" % [mech_data.shield[lvl_index]]
	crit_rate.text = "Crit Rate: %s%%" % [String.num(crit_rate_value * 100.0, 1)]
	crit_damage.text = "Crit Damage: %s" % [mech_data.crit_damage[lvl_index]]
	grab_radius.text = "Grab Radius: %s" % [mech_data.grab_radius[lvl_index]]
	player_gold.text = "Gold: %s" % [mech_data.player_gold[lvl_index]]

func _on_mecha_select_update_on_select(id) -> void:
	mecha_id = int(id)
	update_labels()
	on_select_id = int(id)
	for mechaselect : MechaSelect in icon_container.get_children():
		mechaselect.on_select = true if mechaselect.mecha_id == on_select_id else false
		mechaselect.update()

func _on_new_game_erase_button_pressed() -> void:
	update_labels()

func _refresh_mecha_data() -> void:
	mech_data = DataHandler.read_mecha_data(str(mecha_id))
	mech_autosave = DataHandler.read_autosave_mecha_data(str(mecha_id))
