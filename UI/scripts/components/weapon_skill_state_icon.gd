extends Control

const ICON_ATLAS := preload("res://UI/assets/hud_icons/weapon_skill_pictograms_atlas.png")
const ICON_SIZE := 32
const ICON_COLUMNS := 8
const ICON_INDEX := {
	"default": 0,
	"machine_gun_infinite_chain": 1,
	"charged_blaster_phase_echo": 2,
	"spear_phalanx": 3,
	"shotgun_double_discipline": 4,
	"orbit_proliferation": 5,
	"rocket_cluster_warhead": 6,
	"laser_refraction_matrix": 7,
	"chainsaw_cage": 8,
	"dash_rift": 9,
	"flame_moving_inferno": 10,
	"plasma_storm": 11,
	"glacier_white_frost_domain": 12,
	"cannon_siege_trajectory": 13,
	"sniper_lethal_aim": 14,
}

@onready var _disk: ColorRect = $Disk
@onready var _glyph: TextureRect = $Glyph

var state := "disabled"
var effect_id := ""
var progress := 0.0
var cooldown_progress := 1.0
var cooling := false
var energy_blocked := false
var active := false
var overheated := false

func _ready() -> void:
	_disk.material = _disk.material.duplicate()
	_glyph.material = _glyph.material.duplicate()
	_update_glyph_texture()
	_apply_shader_state()

func set_effect_id(value: String) -> void:
	if value == effect_id:
		return
	effect_id = value
	if is_node_ready():
		_update_glyph_texture()

func set_status(status: Dictionary) -> void:
	var next := "disabled"
	var available := bool(status.get("available", false))
	var next_cooling := float(status.get("cooldown_remaining", 0.0)) > 0.0
	var next_energy := not bool(status.get("has_energy", true)) and bool(status.get("unlock_ready", false))
	var next_progress := 1.0 if bool(status.get("unlock_ready", false)) else clampf(float(status.get("unlock_progress", 0.0)), 0.0, 1.0)
	var next_cooldown := clampf(float(status.get("cooldown_progress", 1.0)), 0.0, 1.0)
	var next_active := bool(status.get("active", false))
	var next_overheated := bool(status.get("overheated", false))
	if next_overheated:
		next = "overheat"
	elif available:
		next = "ready" if bool(status.get("ready", false)) else "building"
		if not bool(status.get("ready", false)):
			if next_cooling:
				next = "cooldown"
			elif next_energy:
				next = "energy"
	if state == next and is_equal_approx(progress, next_progress) \
			and is_equal_approx(cooldown_progress, next_cooldown) \
			and cooling == next_cooling and energy_blocked == next_energy \
			and active == next_active and overheated == next_overheated:
		return
	state = next
	progress = next_progress
	cooldown_progress = next_cooldown
	cooling = next_cooling
	energy_blocked = next_energy
	active = next_active
	overheated = next_overheated
	if is_node_ready():
		_apply_shader_state()

func _update_glyph_texture() -> void:
	var index := int(ICON_INDEX.get(effect_id, ICON_INDEX["default"]))
	var atlas := AtlasTexture.new()
	atlas.atlas = ICON_ATLAS
	atlas.region = Rect2(
		float(index % ICON_COLUMNS) * ICON_SIZE,
		float(index / ICON_COLUMNS) * ICON_SIZE,
		ICON_SIZE,
		ICON_SIZE
	)
	_glyph.texture = atlas

func _apply_shader_state() -> void:
	var disk_material := _disk.material as ShaderMaterial
	disk_material.set_shader_parameter("unlock_progress", progress)
	disk_material.set_shader_parameter("cooldown_progress", cooldown_progress)
	disk_material.set_shader_parameter("state", 2 if state == "ready" else (0 if state == "disabled" else 1))
	disk_material.set_shader_parameter("cooling", cooling)
	disk_material.set_shader_parameter("energy_blocked", energy_blocked)
	disk_material.set_shader_parameter("active", active)
	disk_material.set_shader_parameter("overheated", overheated)
	var glyph_material := _glyph.material as ShaderMaterial
	var glyph_color := Color("ffb18a") if overheated else (Color("f2f7f6") if state != "disabled" else Color("6c787d"))
	glyph_material.set_shader_parameter("icon_color", glyph_color)
