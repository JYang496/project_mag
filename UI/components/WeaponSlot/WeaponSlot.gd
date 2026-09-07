extends Control
class_name WeaponSlot

const LEGACY_VIEW_SCRIPT := preload("res://UI/scripts/components/weapon_slot_view.gd")
const WEAPON_DISK_CENTER := Vector2(38.0, 111.0)

@onready var icon: TextureRect = $Icon
@onready var background: TextureRect = $Background
@onready var weapon_name_label: Label = get_node_or_null("WeaponName") as Label
@onready var level_label: Label = get_node_or_null("Level") as Label
@onready var heat_bar: ProgressBar = get_node_or_null("HeatBar") as ProgressBar
@onready var selected_overlay: Control = get_node_or_null("Selected") as Control
@onready var locked_overlay: Control = get_node_or_null("Locked") as Control
@onready var cooldown_overlay: ColorRect = get_node_or_null("CooldownOverlay") as ColorRect
@onready var overheat_overlay: ColorRect = get_node_or_null("OverheatOverlay") as ColorRect

var frame: Control:
	get:
		return _view.frame if _view != null else null

var _view
var _weapon: Variant = null
var _selected := false
var _locked := false
var _overheated := false
var _selection_tween: Tween
var _overheat_tween: Tween

func _ready() -> void:
	_update_visual_state()

func setup(slot_root: Control, missing_weapon_icon: Texture2D) -> void:
	if _view != null:
		return
	assert(slot_root == self, "WeaponSlot.setup must receive its owning slot")
	_view = LEGACY_VIEW_SCRIPT.new()
	_view.setup(self, missing_weapon_icon)

func set_weapon(weapon: Variant) -> void:
	_weapon = weapon if is_instance_valid(weapon) else null
	if _view != null:
		if _weapon == null:
			_view.show_empty()
		else:
			_view.show_weapon(_weapon)
	if weapon_name_label != null:
		weapon_name_label.text = _resolve_weapon_name(_weapon)
		weapon_name_label.visible = _weapon != null
	if _weapon != null:
		set_level(int(_weapon.get("level")))
	_update_visual_state()

func set_level(level: int) -> void:
	if level_label != null:
		level_label.text = "LV.%d" % maxi(level, 1)
		level_label.visible = _weapon != null

func set_heat(value: float, maximum: float = 1.0, overheated: bool = false) -> void:
	if heat_bar != null:
		heat_bar.max_value = maxf(maximum, 0.001)
		heat_bar.value = clampf(value, 0.0, heat_bar.max_value)
		heat_bar.visible = _weapon != null and maximum > 0.0
	if overheated != _overheated:
		_overheated = overheated
		if _overheated:
			play_overheat_animation()
	_update_visual_state()

func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	if _view != null:
		_view.set_role(_selected, null, null)
	if _selected:
		play_selected_animation()
	_update_visual_state()

func set_locked(locked: bool) -> void:
	_locked = locked
	_update_visual_state()

func set_cooldown(progress: float) -> void:
	if cooldown_overlay != null:
		cooldown_overlay.visible = _weapon != null and progress < 1.0
		cooldown_overlay.color.a = clampf(1.0 - progress, 0.0, 0.72)

func set_role(is_mainhand: bool, mainhand_texture: Texture2D, support_texture: Texture2D) -> void:
	_selected = is_mainhand
	if _view != null:
		_view.set_role(is_mainhand, mainhand_texture, support_texture)
	_update_visual_state()

func show_empty() -> void:
	set_weapon(null)

func show_weapon(weapon: Weapon) -> void:
	set_weapon(weapon)

func set_ammo_state(visible_value: bool, progress: float, fill: Color, track: Color) -> void:
	if _view != null:
		_view.set_ammo_state(visible_value, progress, fill, track)

func play_selected_animation() -> void:
	if _selection_tween != null:
		_selection_tween.kill()
	scale = Vector2(0.96, 0.96)
	_selection_tween = create_tween()
	_selection_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func play_overheat_animation() -> void:
	if _overheat_tween != null:
		_overheat_tween.kill()
	if overheat_overlay == null:
		return
	overheat_overlay.modulate.a = 1.0
	_overheat_tween = create_tween().set_loops(3)
	_overheat_tween.tween_property(overheat_overlay, "modulate:a", 0.35, 0.10)
	_overheat_tween.tween_property(overheat_overlay, "modulate:a", 1.0, 0.10)

func update_visual_state() -> void:
	_update_visual_state()

func _update_visual_state() -> void:
	if not is_node_ready():
		return
	if selected_overlay != null:
		selected_overlay.visible = _weapon != null and _selected
	if locked_overlay != null:
		locked_overlay.visible = _locked
	if overheat_overlay != null:
		overheat_overlay.visible = _weapon != null and _overheated
	icon.modulate.a = 0.35 if _locked else 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE if _locked else Control.MOUSE_FILTER_STOP

func _resolve_weapon_name(weapon: Variant) -> String:
	if weapon == null:
		return ""
	var display_name: Variant = weapon.get("weapon_name")
	if display_name != null and not str(display_name).is_empty():
		return str(display_name)
	return str(weapon.name).replace("_", " ")
