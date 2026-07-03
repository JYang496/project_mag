extends RefCounted

var hud_presenter: HudPresenter
var static_dirty := true
var hp_dirty := true
var inventory_dirty := true
var weapon_dirty := true
var _debug_counter = preload("res://UI/scripts/components/ui_refresh_debug_counter.gd").new()

func bind(p_presenter: HudPresenter) -> void:
	hud_presenter = p_presenter

func mark_hp_dirty() -> void:
	hp_dirty = true

func mark_inventory_dirty() -> void:
	inventory_dirty = true

func mark_weapon_dirty() -> void:
	weapon_dirty = true

func mark_all_dirty() -> void:
	static_dirty = true
	hp_dirty = true
	inventory_dirty = true
	weapon_dirty = true

func refresh_if_needed(delta: float) -> void:
	if hud_presenter == null:
		return
	if static_dirty:
		hud_presenter.refresh_static_texts()
		static_dirty = false
		hp_dirty = true
		inventory_dirty = true
		weapon_dirty = true
	if hp_dirty:
		hud_presenter.refresh_hp()
		_debug_counter.increment("hud_hp")
		hp_dirty = false
	if inventory_dirty:
		hud_presenter.refresh_inventory()
		_debug_counter.increment("hud_inventory")
		inventory_dirty = false
	if weapon_dirty:
		hud_presenter.refresh_weapon_state()
		hud_presenter.refresh_ammo()
		_debug_counter.increment("hud_weapon")
		weapon_dirty = false
	if hud_presenter.refresh_continuous(delta):
		_debug_counter.increment("hud_continuous")

func reset_debug_counts() -> void:
	_debug_counter.reset()

func increment_debug_count(key: String) -> void:
	_debug_counter.increment(key)

func get_debug_counts() -> Dictionary:
	return _debug_counter.snapshot()

func get_dirty_snapshot() -> Dictionary:
	return {
		"static": static_dirty,
		"hp": hp_dirty,
		"inventory": inventory_dirty,
		"weapon": weapon_dirty,
	}
