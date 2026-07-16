extends Control
class_name BattleHudView

signal initialized

@onready var weapon_selector: WeaponSelector = $WeaponSelector
@onready var hp_label: TextureRect = $HpLabel
@onready var hp_text: Label = $HpLabel/Hp
@onready var hp_bar: ProgressBar = $HpLabel/HpBar
@onready var gold_label: Label = $Gold
@onready var resource_label: Label = $Resource
@onready var time_label: Label = $Time

func _ready() -> void:
	initialized.emit()
