# Archived 2026-07-28: release-specific asset sizes, theme colors and filtering acceptance.
extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PixelArtPolicyType := preload("res://Visual/pixel_art_policy.gd")
const CellPresentationControllerType := preload("res://Board/Cells/cell_presentation_controller.gd")

class DummyActivationVisual:
	extends Node2D
	var configured := false
	var last_board_enabled := false
	var last_player_inside := false
	var last_has_task := false

	func configure(
		board_enabled: bool,
		player_inside: bool,
		has_task: bool,
		_cell_rect: Rect2
	) -> void:
		configured = true
		last_board_enabled = board_enabled
		last_player_inside = player_inside
		last_has_task = has_task

const EXACT_SIZE_ASSETS := {
	"res://asset/images/characters/pixel/idle_bottom.png": PixelArtPolicyType.PLAYER_FRAME_SIZE,
	"res://asset/images/characters/pixel/idle_top.png": PixelArtPolicyType.PLAYER_FRAME_SIZE,
	"res://asset/images/characters/ranger_drone.png": PixelArtPolicyType.PLAYER_SUPPORT_FRAME_SIZE,
	"res://asset/images/enemies/bomber.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/mine_crawler.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/mirror_caster.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/mirror_clone.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/mortar_turret.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/orbit_support.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/repair_unit.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/reward_enemy.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/rolling_ball.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/shield_core.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/tar_mine_crawler.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/wheel_cart.png": PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE,
	"res://asset/images/enemies/interceptor.png": PixelArtPolicyType.ENEMY_ELITE_FRAME_SIZE,
	"res://asset/images/enemies/rolling_ball_elite.png": PixelArtPolicyType.ENEMY_ELITE_FRAME_SIZE,
	"res://asset/images/loot/chip.png": PixelArtPolicyType.LOOT_STANDARD_FRAME_SIZE,
	"res://asset/images/loot/credit_coin_01.png": PixelArtPolicyType.LOOT_STANDARD_FRAME_SIZE,
	"res://asset/images/loot/credit_coin_02.png": PixelArtPolicyType.LOOT_STANDARD_FRAME_SIZE,
	"res://asset/images/loot/credit_coin_03.png": PixelArtPolicyType.LOOT_STANDARD_FRAME_SIZE,
	"res://asset/images/loot/credit_coin_04.png": PixelArtPolicyType.LOOT_STANDARD_FRAME_SIZE,
	"res://asset/images/loot/loot_box_closed.png": PixelArtPolicyType.LOOT_LARGE_FRAME_SIZE,
	"res://asset/images/loot/loot_box_open.png": PixelArtPolicyType.LOOT_LARGE_FRAME_SIZE,
	"res://asset/images/cells/default.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/corrosion.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/double_loot.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/jungle.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/low_hp_berserk.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/lucky_strike.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/regen.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/speed_boost.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/dirt1.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/dirt2.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/fact1.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/fact2.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/glass.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/gold1.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/gold2.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/ice.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/cells/lava.png": PixelArtPolicyType.BOARD_CELL_FRAME_SIZE,
	"res://asset/images/ui/rest_area/board_tactical.png": PixelArtPolicyType.SCENE_PROP_LARGE_FRAME_SIZE,
	"res://asset/images/ui/rest_area/purchase_shop.png": PixelArtPolicyType.SCENE_PROP_LARGE_FRAME_SIZE,
	"res://asset/images/ui/rest_area/upgrade_gunsmith.png": PixelArtPolicyType.SCENE_PROP_LARGE_FRAME_SIZE,
	"res://asset/images/ui/rest_area/warehouse_armory.png": PixelArtPolicyType.SCENE_PROP_LARGE_FRAME_SIZE,
	"res://Visual/Oblique/assets/board_support/unloaded_board_fragment_atlas.png": PixelArtPolicyType.SCENE_PROP_LARGE_FRAME_SIZE,
	"res://Visual/Oblique/assets/board_support/floating_board_skirt_atlas.png": PixelArtPolicyType.SCENE_PROP_LARGE_FRAME_SIZE,
	"res://asset/images/weapons/projectiles/chainsaw_spin_01.png": Vector2i(PixelArtPolicyType.PROJECTILE_LARGE_SIZE),
	"res://asset/images/weapons/projectiles/chainsaw_spin_02.png": Vector2i(PixelArtPolicyType.PROJECTILE_LARGE_SIZE),
	"res://asset/images/weapons/projectiles/chainsaw_spin_03.png": Vector2i(PixelArtPolicyType.PROJECTILE_LARGE_SIZE),
	"res://asset/images/weapons/projectiles/chainsaw_spin_04.png": Vector2i(PixelArtPolicyType.PROJECTILE_LARGE_SIZE),
	"res://asset/images/weapons/projectiles/chainsaw_spin_05.png": Vector2i(PixelArtPolicyType.PROJECTILE_LARGE_SIZE),
	"res://asset/images/weapons/projectiles/chainsaw_spin_06.png": Vector2i(PixelArtPolicyType.PROJECTILE_LARGE_SIZE),
}
const WEAPON_ASSET_PATHS := [
	"res://asset/images/weapons/blaster.png",
	"res://asset/images/weapons/cannon2.png",
	"res://asset/images/weapons/cannon3.png",
	"res://asset/images/weapons/chainsaw_launcher.png",
	"res://asset/images/weapons/dash_blade.png",
	"res://asset/images/weapons/flamethrower.png",
	"res://asset/images/weapons/glacier_projector.png",
	"res://asset/images/weapons/laser.png",
	"res://asset/images/weapons/machine_gun.png",
	"res://asset/images/weapons/mg2.png",
	"res://asset/images/weapons/orbit.png",
	"res://asset/images/weapons/pistol.png",
	"res://asset/images/weapons/plasma_lance.png",
	"res://asset/images/weapons/rocket_launcher.png",
	"res://asset/images/weapons/shotgun.png",
	"res://asset/images/weapons/sniper.png",
	"res://asset/images/weapons/spear_launcher.png",
]
const MODERN_UI_ASSETS := {
	"res://UI/themes/modern/weapon_slot_main.png": Vector2i(192, 144),
	"res://UI/themes/modern/weapon_slot_offhand.png": Vector2i(144, 144),
	"res://UI/themes/modern/heat_gauge.png": Vector2i(304, 304),
	"res://UI/themes/modern/heat_needle.png": Vector2i(304, 304),
}
const PIXEL_MODULE_ICON_PATHS := [
	"res://asset/images/modules/pixel/wmod_damage_up_stat.png",
	"res://asset/images/modules/pixel/wmod_pierce_stat.png",
	"res://asset/images/modules/pixel/wmod_projectile_speed_stat.png",
	"res://asset/images/modules/pixel/wmod_bullet_size_stat.png",
	"res://asset/images/modules/pixel/wmod_fast_reload.png",
	"res://asset/images/modules/pixel/wmod_expanded_magazine.png",
	"res://asset/images/modules/pixel/wmod_lifesteal_on_hit.png",
	"res://asset/images/modules/pixel/wmod_reload_speed_link.png",
]
const PIXEL_MODULE_SCENE_PATHS := [
	"res://Player/Weapons/Modules/wmod_damage_up_stat.tscn",
	"res://Player/Weapons/Modules/wmod_pierce_stat.tscn",
	"res://Player/Weapons/Modules/wmod_projectile_speed_stat.tscn",
	"res://Player/Weapons/Modules/wmod_bullet_size_stat.tscn",
	"res://Player/Weapons/Modules/wmod_fast_reload.tscn",
	"res://Player/Weapons/Modules/wmod_expanded_magazine.tscn",
	"res://Player/Weapons/Modules/wmod_lifesteal_on_hit.tscn",
	"res://Player/Weapons/Modules/wmod_reload_speed_link.tscn",
]
const ENEMY_VISUAL_SCALE_BY_SCENE := {
	"res://Npc/enemy/scenes/enemy_bomber.tscn": Vector2(1.5, 1.5),
	"res://Npc/enemy/scenes/enemy_interceptor.tscn": Vector2(1.125, 1.125),
	"res://Npc/enemy/scenes/enemy_mine_crawler.tscn": Vector2(0.875, 0.875),
	"res://Npc/enemy/scenes/enemy_mirror_caster.tscn": Vector2(1.25, 1.25),
	"res://Npc/enemy/scenes/enemy_mirror_clone.tscn": Vector2(0.75, 0.75),
	"res://Npc/enemy/scenes/enemy_mortar_turret.tscn": Vector2(1.75, 1.75),
	"res://Npc/enemy/scenes/enemy_orbit_support.tscn": Vector2(1.0, 1.0),
	"res://Npc/enemy/scenes/enemy_repair_unit.tscn": Vector2(1.125, 1.125),
	"res://Npc/enemy/scenes/enemy_rolling_ball.tscn": Vector2(1.0, 1.0),
	"res://Npc/enemy/scenes/enemy_rolling_ball_elite.tscn": Vector2(0.75, 0.75),
	"res://Npc/enemy/scenes/enemy_shield_core.tscn": Vector2(1.5, 1.5),
	"res://Npc/enemy/scenes/enemy_spike_turret.tscn": Vector2(1.0, 1.0),
	"res://Npc/enemy/scenes/enemy_tar_mine_crawler.tscn": Vector2(1.0, 1.0),
	"res://Npc/enemy/scenes/enemy_wheel_cart.tscn": Vector2(1.75, 1.75),
	"res://Npc/enemy/scenes/reward_enemy.tscn": Vector2(2.0, 2.0),
}

var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_project_settings()
	_test_policy_targets()
	_test_cell_presentation_policy()
	_test_all_module_icons()
	if _failed:
		print("FAIL: presentation asset integrity")
	else:
		print("PASS: presentation asset integrity")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _test_project_settings() -> void:
	_assert_equal(
		Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width")),
			int(ProjectSettings.get_setting("display/window/size/viewport_height"))
		),
		PixelArtPolicyType.LOGICAL_VIEWPORT_SIZE,
		"Logical viewport must match the gameplay presentation policy."
	)
	_assert_equal(
		"integer",
		String(ProjectSettings.get_setting("display/window/stretch/scale_mode")),
		"Window stretch must preserve the gameplay canvas scaling contract."
	)
	_assert_equal(
		CanvasItem.TEXTURE_FILTER_NEAREST,
		int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")),
		"Gameplay sprites may default to nearest-neighbour filtering; modern UI overrides this per control."
	)
	_assert_equal(
		true,
		bool(ProjectSettings.get_setting("rendering/textures/default_filters/use_nearest_mipmap_filter")),
		"Gameplay sprite mipmaps must select the nearest mip level; modern UI explicitly uses linear filtering."
	)

func _test_cell_presentation_policy() -> void:
	var controller = CellPresentationControllerType.new()
	var texture_root := Node2D.new()
	var activation := DummyActivationVisual.new()
	var task_marker := Node2D.new()
	controller.set_visuals_visible(
		false,
		texture_root,
		activation,
		task_marker,
		true
	)
	_assert_true(
		not texture_root.visible and not activation.visible and not task_marker.visible,
		"Cell presentation policy must hide every cell visual layer together."
	)
	controller.set_visuals_visible(
		true,
		texture_root,
		activation,
		task_marker,
		true
	)
	controller.configure_activation(
		activation,
		true,
		true,
		true,
		Rect2(Vector2.ZERO, Vector2(64.0, 64.0))
	)
	_assert_true(
		activation.configured
			and activation.last_board_enabled
			and activation.last_player_inside
			and activation.last_has_task,
		"Cell presentation controller must forward activation state."
	)
	controller.default_terrain_only = true
	_assert_equal(
		Cell.TerrainType.NONE,
		controller.resolve_profile_terrain(
			Cell.TerrainType.REGEN,
			Cell.TerrainType.NONE
		),
		"Default-terrain presentation mode must suppress profile terrain."
	)
	_assert_true(
		not controller.resolve_profile_aura(true)
			and not controller.allows_aura_modules(),
		"Default-terrain presentation mode must suppress aura visuals."
	)
	texture_root.free()
	activation.free()
	task_marker.free()


func _test_policy_targets() -> void:
	var targets := [
		Vector2(PixelArtPolicyType.PLAYER_FRAME_SIZE),
		Vector2(PixelArtPolicyType.PLAYER_SUPPORT_FRAME_SIZE),
		PixelArtPolicyType.PROJECTILE_STANDARD_SIZE,
		PixelArtPolicyType.PROJECTILE_CANNON_SIZE,
		PixelArtPolicyType.PROJECTILE_LARGE_SIZE,
		Vector2(PixelArtPolicyType.ENEMY_STANDARD_FRAME_SIZE),
		Vector2(PixelArtPolicyType.ENEMY_ELITE_FRAME_SIZE),
		Vector2(PixelArtPolicyType.LOOT_STANDARD_FRAME_SIZE),
		Vector2(PixelArtPolicyType.LOOT_LARGE_FRAME_SIZE),
		Vector2(PixelArtPolicyType.BOARD_CELL_FRAME_SIZE),
		Vector2(PixelArtPolicyType.SCENE_PROP_LARGE_FRAME_SIZE),
		Vector2(PixelArtPolicyType.EFFECT_SMALL_FRAME_SIZE),
		Vector2(PixelArtPolicyType.EFFECT_MEDIUM_FRAME_SIZE),
		Vector2(PixelArtPolicyType.EFFECT_LARGE_FRAME_SIZE),
		Vector2(PixelArtPolicyType.EFFECT_FLAME_SPRAY_FRAME_SIZE),
		Vector2(PixelArtPolicyType.EFFECT_GLACIER_SPRAY_FRAME_SIZE),
	]
	for target in targets:
		_assert_true(
			PixelArtPolicyType.is_integer_target_size(target),
			"Pixel-art target size must contain positive whole logical pixels: %s" % target
		)


func _test_player_animation_frames() -> void:
	for direction in ["bottom", "top"]:
		for frame_number in range(1, 9):
			var path := "res://asset/images/characters/pixel/move_%s_%02d.png" % [
				direction,
				frame_number,
			]
			_assert_image_size(path, PixelArtPolicyType.PLAYER_FRAME_SIZE)


func _test_exact_asset_sizes() -> void:
	for path in EXACT_SIZE_ASSETS:
		_assert_image_size(path, EXACT_SIZE_ASSETS[path] as Vector2i)
	for path in PIXEL_MODULE_ICON_PATHS:
		_assert_image_size(path, Vector2i(32, 32))
	for path in WEAPON_ASSET_PATHS:
		var weapon_texture := load(path) as Texture2D
		_assert_true(weapon_texture != null, "Weapon source must load: %s" % path)
		if weapon_texture != null:
			_assert_equal(
				PixelArtPolicyType.WEAPON_SOURCE_HEIGHT_PX,
				weapon_texture.get_height(),
				"Equipped weapon sources must be authored at their final 64px height: %s" % path
			)


func _test_runtime_visual_grain() -> void:
	for scene_path in ENEMY_VISUAL_SCALE_BY_SCENE:
		var enemy_scene := load(scene_path) as PackedScene
		var enemy := enemy_scene.instantiate() if enemy_scene != null else null
		_assert_true(enemy != null, "Representative enemy must instantiate: %s" % scene_path)
		if enemy == null:
			continue
		var body := enemy.get_node_or_null("Body") as Sprite2D
		_assert_true(body != null, "Representative enemy must expose a Body sprite: %s" % scene_path)
		if body != null:
			_assert_equal(
				ENEMY_VISUAL_SCALE_BY_SCENE[scene_path],
				body.extra_scale,
				"Enemy silhouette scale must match its authored HurtBox tier: %s" % scene_path
			)
			_assert_equal(
				CanvasItem.TEXTURE_FILTER_NEAREST,
				body.texture_filter,
				"Enemy sprites must use nearest filtering: %s" % scene_path
			)
		enemy.free()
	var spike_scene := load("res://Npc/enemy/scenes/enemy_spike_projectile.tscn") as PackedScene
	var spike := spike_scene.instantiate() if spike_scene != null else null
	_assert_true(spike != null, "Enemy spike projectile must instantiate.")
	if spike != null:
		var spike_sprite := spike.get_node("Sprite2D") as Sprite2D
		_assert_equal(Vector2(4, 4), spike_sprite.extra_scale, "Tiny hostile projectiles must compensate the hybrid canvas scale.")
		_assert_equal(CanvasItem.TEXTURE_FILTER_NEAREST, spike_sprite.texture_filter, "Hostile projectiles must use nearest filtering.")
		spike.free()
	var spray_scene_sizes := {
		"res://Player/Weapons/Effects/cone_spray_vfx.tscn": PixelArtPolicyType.EFFECT_FLAME_SPRAY_FRAME_SIZE,
		"res://Player/Weapons/Effects/glacier_spray_vfx.tscn": PixelArtPolicyType.EFFECT_GLACIER_SPRAY_FRAME_SIZE,
	}
	for effect_scene_path in spray_scene_sizes:
		var effect_scene := load(effect_scene_path) as PackedScene
		var effect := effect_scene.instantiate() if effect_scene != null else null
		_assert_true(effect != null, "Representative combat VFX must instantiate: %s" % effect_scene_path)
		if effect == null:
			continue
		var effect_sprite := effect.get_node("SprayRoot/Sprite") as AnimatedSprite2D
		_assert_equal(
			CanvasItem.TEXTURE_FILTER_NEAREST,
			effect_sprite.texture_filter,
			"Combat VFX must use nearest filtering: %s" % effect_scene_path
		)
		var effect_frame := effect_sprite.sprite_frames.get_frame_texture(effect_sprite.animation, 0)
		_assert_equal(
			spray_scene_sizes[effect_scene_path],
			Vector2i(effect_frame.get_size()),
			"Directional combat VFX must use its authored pixel tier: %s" % effect_scene_path
		)
		effect.free()
	for explosion_frame in range(1, 9):
		_assert_image_size(
			"res://asset/images/effects/explosion/explosion_%02d.png" % explosion_frame,
			PixelArtPolicyType.EFFECT_MEDIUM_FRAME_SIZE
		)
	var hp_bar_scene := load("res://UI/scenes/components/enemy_hp_bar.tscn") as PackedScene
	var hp_bar := hp_bar_scene.instantiate() as EnemyHpBar if hp_bar_scene != null else null
	_assert_true(hp_bar != null, "Enemy HP bar must instantiate.")
	if hp_bar != null:
		add_child(hp_bar)
		_assert_true(not hp_bar.z_as_relative, "Enemy HP bars must use an absolute foreground layer.")
		_assert_true(hp_bar.z_index > 1000, "Enemy HP bars must render above billboard enemies.")
		remove_child(hp_bar)
		hp_bar.free()


func _test_modern_ui_contract() -> void:
	var font := load("res://asset/fonts/NotoSansSC-Regular.ttf") as FontFile
	_assert_true(font != null, "Modern UI sans-serif font must load.")
	if font != null:
		_assert_equal(
			TextServer.FONT_ANTIALIASING_GRAY,
			font.antialiasing,
			"UI font must use grayscale antialiasing for clean CJK outlines."
		)
		_assert_true(
			not font.multichannel_signed_distance_field,
			"UI font must disable MSDF because the CJK outlines produce rendering artifacts."
		)
		_assert_equal(
			TextServer.HINTING_LIGHT,
			font.hinting,
			"UI font must use light hinting."
		)
		_assert_equal(
			TextServer.SUBPIXEL_POSITIONING_AUTO,
			font.subpixel_positioning,
			"UI font must use automatic subpixel positioning."
		)
	var theme := load("res://UI/themes/global_ui_theme.tres") as Theme
	_assert_true(theme != null, "Global modern UI theme must load.")
	if theme == null:
		return
	var panel_style := theme.get_stylebox(&"panel", &"Panel") as StyleBoxFlat
	_assert_true(panel_style != null, "Global modern UI theme must define Panel styling.")
	if panel_style != null:
		_assert_true(panel_style.bg_color.a >= 0.8, "Modern UI panels must retain a readable dark backing.")
		_assert_true(panel_style.border_color.b > panel_style.border_color.r, "Modern UI panel borders must use the cyan-blue information accent.")
		_assert_true(panel_style.border_width_left >= 2, "Modern UI panels must retain a visible technical border.")
	var button_style := theme.get_stylebox(&"normal", &"Button") as StyleBoxFlat
	_assert_true(button_style != null, "Global modern UI theme must define Button styling.")

	for asset_path in MODERN_UI_ASSETS:
		_assert_image_size(asset_path, MODERN_UI_ASSETS[asset_path] as Vector2i)

	var battle_hud_scene := load("res://UI/scenes/runtime/battle_hud.tscn") as PackedScene
	var battle_hud := battle_hud_scene.instantiate() if battle_hud_scene != null else null
	_assert_true(battle_hud != null, "Battle HUD must instantiate with modern assets.")
	if battle_hud != null:
		for slot_name in ["Slot0"]:
			var slot_texture := battle_hud.get_node("WeaponSelector/%s/Background" % slot_name) as TextureRect
			_assert_equal(
				Vector2i(192, 144),
				Vector2i(slot_texture.texture.get_size()),
				"Battle HUD main weapon slot must use the 2x antialiased modern source."
			)
			_assert_equal(CanvasItem.TEXTURE_FILTER_LINEAR, slot_texture.texture_filter, "Modern main weapon slot must use linear filtering.")
		for slot_name in ["Slot1", "Slot2", "Slot3"]:
			var slot_texture := battle_hud.get_node("WeaponSelector/%s/Background" % slot_name) as TextureRect
			_assert_equal(Vector2i(144, 144), Vector2i(slot_texture.texture.get_size()), "Battle HUD offhand slots must use 2x antialiased modern sources.")
			_assert_equal(CanvasItem.TEXTURE_FILTER_LINEAR, slot_texture.texture_filter, "Modern offhand weapon slots must use linear filtering.")
		var selector := battle_hud.get_node("WeaponSelector") as Control
		var main_slot := selector.get_node("Slot0") as Control
		_assert_true(main_slot.size.x > main_slot.size.y, "Main weapon slot must be visibly wider than offhand slots.")
		var previous_right := -INF
		for slot_name in ["Slot0", "Slot1", "Slot2", "Slot3"]:
			var slot := selector.get_node(slot_name) as Control
			_assert_true(slot.position.x >= previous_right + 8.0, "Horizontal weapon slots must not overlap and must keep an 8px gap: %s" % slot_name)
			previous_right = slot.position.x + slot.size.x
		battle_hud.free()

	var resource_meter := CombatResourceMeter.new()
	add_child(resource_meter)
	resource_meter.set_resource(&"heat", 0.65, &"warning")
	var gauge := resource_meter.get_node("HeatGauge") as TextureRect
	var needle := resource_meter.get_node("HeatNeedle") as TextureRect
	_assert_equal(Vector2i(304, 304), Vector2i(gauge.texture.get_size()), "Heat gauge must use a high-resolution modern source.")
	_assert_equal(Vector2i(304, 304), Vector2i(needle.texture.get_size()), "Heat needle must use a high-resolution modern source.")
	_assert_equal(CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, gauge.texture_filter, "Modern heat gauge must use linear mipmapped filtering.")
	_assert_equal(CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, needle.texture_filter, "Modern heat needle must use linear mipmapped filtering.")
	remove_child(resource_meter)
	resource_meter.free()

	var status_hud := PlayerStatusHud.new()
	add_child(status_hud)
	status_hud.set_health(70, 100, 30, 50)
	status_hud.set_energy(75.0, 125.0)
	_assert_equal(Vector2(420.0, 80.0), status_hud.custom_minimum_size, "Modern player status HUD must preserve its authored layout size.")
	_assert_true(status_hud.get_node_or_null("HpValue") is Label, "Modern player status HUD must use a clear sans-serif value label.")
	remove_child(status_hud)
	status_hud.free()

	for source_path in [
		"res://UI/scenes/runtime/battle_hud.tscn",
		"res://UI/scripts/weapon_selector.gd",
		"res://UI/scripts/components/combat_resource_meter.gd",
	]:
		var source := FileAccess.get_file_as_string(source_path)
		_assert_true(not source.contains("res://UI/themes/pixel/"), "Runtime UI must not reference the legacy pixel theme: %s" % source_path)
		_assert_true(not source.contains("heat_gauge_pixel"), "Runtime UI must not reference the legacy pixel heat gauge: %s" % source_path)

	for scene_path in PIXEL_MODULE_SCENE_PATHS:
		var module_scene := load(scene_path) as PackedScene
		var module := module_scene.instantiate() if module_scene != null else null
		_assert_true(module != null, "Common module scene must instantiate: %s" % scene_path)
		if module == null:
			continue
		var sprite := module.get_node_or_null("Sprite") as Sprite2D
		_assert_true(sprite != null and sprite.texture != null, "Common module must expose its pixel icon: %s" % scene_path)
		if sprite != null and sprite.texture != null:
			_assert_equal(Vector2i(32, 32), Vector2i(sprite.texture.get_size()), "Common module must use a 32x32 pixel icon: %s" % scene_path)
		module.free()


func _test_all_module_icons() -> void:
	var module_dir := DirAccess.open("res://Player/Weapons/Modules")
	_assert_true(module_dir != null, "Weapon module scene directory must open.")
	if module_dir == null:
		return
	var scene_filenames := module_dir.get_files()
	scene_filenames.sort()
	for filename in scene_filenames:
		if not filename.begins_with("wmod_") or filename.get_extension() != "tscn" or filename == "wmod_base.tscn":
			continue
		var scene_path := "res://Player/Weapons/Modules/%s" % filename
		var module_scene := load(scene_path) as PackedScene
		var module := module_scene.instantiate() if module_scene != null else null
		_assert_true(module != null, "Module scene must instantiate with its pixel icon: %s" % scene_path)
		if module == null:
			continue
		var sprite := module.get_node_or_null("Sprite") as Sprite2D
		_assert_true(sprite != null and sprite.texture != null, "Module must expose an icon texture: %s" % scene_path)
		if sprite != null and sprite.texture != null:
			_assert_true(
				sprite.texture.resource_path.begins_with("res://asset/images/modules/pixel/"),
				"Runtime module icon must use the generated pixel PNG, not its SVG source: %s" % scene_path
			)
			_assert_equal(
				Vector2i(32, 32),
				Vector2i(sprite.texture.get_size()),
				"Runtime module pixel icon must be 32x32: %s" % scene_path
			)
		module.free()


func _assert_image_size(path: String, expected_size: Vector2i) -> void:
	var image := Image.load_from_file(path)
	_assert_true(not image.is_empty(), "Pixel-art source must load: %s" % path)
	if image.is_empty():
		return
	_assert_equal(expected_size, image.get_size(), "Pixel-art source has the wrong density tier: %s" % path)


func _assert_equal(expected: Variant, actual: Variant, message: String) -> void:
	_assert_true(expected == actual, "%s Expected=%s Actual=%s" % [message, str(expected), str(actual)])


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
