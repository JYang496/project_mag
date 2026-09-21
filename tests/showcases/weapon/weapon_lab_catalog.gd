extends RefCounted
class_name WeaponLabCatalog

const WEAPONS: Array[Dictionary] = [
	{"label": "01 机枪", "scene": preload("res://Player/Weapons/Instances/machine_gun.tscn")},
	{"label": "02 蓄力炮", "scene": preload("res://Player/Weapons/Instances/charged_blaster.tscn")},
	{"label": "03 长矛", "scene": preload("res://Player/Weapons/Instances/spear_launcher.tscn")},
	{"label": "04 霰弹枪", "scene": preload("res://Player/Weapons/Instances/shotgun.tscn")},
	{"label": "06 轨道卫星", "scene": preload("res://Player/Weapons/Instances/orbit.tscn")},
	{"label": "07 火箭筒", "scene": preload("res://Player/Weapons/Instances/rocket_launcher.tscn")},
	{"label": "08 激光器", "scene": preload("res://Player/Weapons/Instances/laser.tscn")},
	{"label": "09 电锯", "scene": preload("res://Player/Weapons/Instances/chainsaw_launcher.tscn")},
	{"label": "10 冲刺刀", "scene": preload("res://Player/Weapons/Instances/dash_blade.tscn")},
	{"label": "11 喷火器", "scene": preload("res://Player/Weapons/Instances/flamethrower.tscn")},
	{"label": "12 等离子矛", "scene": preload("res://Player/Weapons/Instances/plasma_lance.tscn")},
	{"label": "13 冰川投射器", "scene": preload("res://Player/Weapons/Instances/glacier_projector.tscn")},
	{
		"label": "14 迫击炮",
		"scene": preload("res://Player/Weapons/Instances/cannon.tscn"),
		"review_hint": "将鼠标指向一列靶机，检查四个落点是否由近及远、左右交错地推进。",
	},
	{"label": "15 狙击枪", "scene": preload("res://Player/Weapons/Instances/sniper.tscn")},
	{"label": "16 追踪能量弹", "scene": preload("res://Player/Weapons/Instances/energy_bolts.tscn"), "basic_only": true},
]
