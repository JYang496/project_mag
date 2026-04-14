# Reload Module Implementation Report

## Summary

This report documents the implementation of eight independent weapon modules for reload and projectile-path effects, plus a dedicated local test scene.

The original request was clarified to mean:

1. Projectile trail freeze AoE is one module.
2. Reload burst damage is one module.
3. Reload burst knockback is one module.
4. Reload-based self weapon damage buff is one module.
5. Reload-based player move speed buff is one module.
6. Reload-based temporary shield is one module.
7. Reload-based other-weapon damage buff is one module.
8. Reload speed bonus while another weapon is reloading is one module.

## Implemented Modules

All modules inherit `Module` and follow project naming rules.

### 1. Projectile Trail Freeze AoE

- Script: `Player/Weapons/Modules/wmod_trail_aoe_freeze.gd`
- Scene: `Player/Weapons/Modules/wmod_trail_aoe_freeze.tscn`
- Behavior:
  - Registers as a projectile spawn plugin.
  - Tracks spawned projectiles.
  - Spawns short-lived freeze `AreaEffect` zones along projectile travel path.
  - Damage and duration scale with `module_level`.

### 2. Reload Burst Damage

- Script: `Player/Weapons/Modules/wmod_reload_blast_damage.gd`
- Scene: `Player/Weapons/Modules/wmod_reload_blast_damage.tscn`
- Behavior:
  - Listens to weapon reload passive event.
  - On reload start, deals one burst of damage around the player.
  - Damage scales with spent magazine ratio.

### 3. Reload Burst Knockback

- Script: `Player/Weapons/Modules/wmod_reload_blast_knockback.gd`
- Scene: `Player/Weapons/Modules/wmod_reload_blast_knockback.tscn`
- Behavior:
  - Listens to weapon reload passive event.
  - On reload start, applies one knockback burst around the player.
  - Knockback scales with spent magazine ratio.

### 4. Reload Self Damage Boost

- Script: `Player/Weapons/Modules/wmod_reload_damage_boost.gd`
- Scene: `Player/Weapons/Modules/wmod_reload_damage_boost.tscn`
- Behavior:
  - On reload start, grants temporary bonus damage to the current weapon.
  - Bonus and duration scale with `module_level`.
  - Actual bonus magnitude scales with spent magazine ratio.

### 5. Reload Move Speed Boost

- Script: `Player/Weapons/Modules/wmod_reload_move_boost.gd`
- Scene: `Player/Weapons/Modules/wmod_reload_move_boost.tscn`
- Behavior:
  - On reload start, grants temporary player move speed.
  - Bonus and duration scale with `module_level`.
  - Actual bonus magnitude scales with spent magazine ratio.

### 6. Reload Shield Boost

- Script: `Player/Weapons/Modules/wmod_reload_shield_boost.gd`
- Scene: `Player/Weapons/Modules/wmod_reload_shield_boost.tscn`
- Behavior:
  - On reload start, grants temporary bonus shield.
  - Shield amount and duration scale with `module_level`.
  - Actual shield value scales with spent magazine ratio.

### 7. Reload Offhand Damage Boost

- Script: `Player/Weapons/Modules/wmod_reload_offhand_boost.gd`
- Scene: `Player/Weapons/Modules/wmod_reload_offhand_boost.tscn`
- Behavior:
  - On reload start, grants temporary damage bonus to the player's other weapons.
  - Bonus and duration scale with `module_level`.
  - Actual bonus magnitude scales with spent magazine ratio.

### 8. Reload Speed Link

- Script: `Player/Weapons/Modules/wmod_reload_speed_link.gd`
- Scene: `Player/Weapons/Modules/wmod_reload_speed_link.tscn`
- Behavior:
  - Registers as a reload duration plugin.
  - If another weapon is already reloading, current weapon reload duration is shortened.
  - Bonus scales with `module_level`.

## Shared Utility

- Script: `Player/Weapons/Modules/wmod_runtime_utils.gd`

Purpose:

- Centralizes common runtime helpers.
- Reduces duplicate logic across reload modules.
- Provides:
  - level-based value selection
  - spent ratio extraction
  - runtime weapon damage resolution
  - player weapon list access
  - nearby enemy collection

## Required Core Extensions

These modules could not be implemented cleanly without small generic extension points in base weapon code.

### `Player/Weapons/Core/weapon.gd`

Added:

- `projectile_spawn_plugins`
- `reload_duration_plugins`
- `register_projectile_spawn_plugin()`
- `unregister_projectile_spawn_plugin()`
- `notify_projectile_spawned()`
- `register_reload_duration_plugin()`
- `unregister_reload_duration_plugin()`
- reload passive event dispatch:
  - `on_reload_started`
  - `on_reload_finished`
- `_get_spent_magazine_ratio()`
- `_get_effective_reload_duration()`
- temporary weapon-local external damage multiplier support:
  - `apply_external_damage_mul()`
  - `remove_external_damage_mul()`
  - `get_total_external_damage_mul()`

Impact:

- Enables module-side reload hooks without editing every weapon.
- Enables weapon-local timed buffs without touching base stat resources.

### `Player/Weapons/weapon_ranger.gd`

Added:

- `notify_projectile_spawned(projectile)` call inside `apply_effects_on_projectile()`

Impact:

- Allows projectile-path modules to observe spawned projectiles without per-weapon edits.

## Localization Keys Added

Added to `data/localization/game_content.csv`:

- `module.wmod_trail_aoe_freeze.name`
- `module.wmod_reload_blast_damage.name`
- `module.wmod_reload_blast_knockback.name`
- `module.wmod_reload_damage_boost.name`
- `module.wmod_reload_move_boost.name`
- `module.wmod_reload_shield_boost.name`
- `module.wmod_reload_offhand_boost.name`
- `module.wmod_reload_speed_link.name`

## Test Scene

### Files

- `Utility/tests/reload_module_suite_test.gd`
- `Utility/tests/reload_module_suite_test.tscn`

### Coverage

The scene performs lightweight runtime checks for:

1. Trail module spawning freeze area effects on projectile path.
2. Reload burst damage affecting nearby enemies.
3. Reload burst knockback applying knockback payload.
4. Reload self-damage boost increasing and then restoring weapon damage.
5. Reload move speed boost increasing and then restoring player move speed.
6. Reload shield boost increasing and then removing bonus shield.
7. Reload offhand boost increasing and then restoring other weapon damage.
8. Reload speed link reducing reload duration when another weapon is already reloading.

### Test Style

- Consistent with existing `Utility/tests` pattern.
- Uses a simple `Label` output report and inline pass/fail logs.
- Avoids introducing external test frameworks.

## Compatibility Notes

- All modules use null checks and `is_instance_valid`.
- No existing weapon-specific scripts were modified beyond base extensibility points.
- Compatibility text formatting from `Module` base remains unchanged.
- The projectile trail module is restricted to ranged projectile weapons.
- Reload modules are currently configured as ranged-only modules to match the requested weapon behavior and avoid ambiguous melee reload cases.

## Known Limitations

1. No headless Godot executable was available in the current environment, so editor/runtime execution could not be verified locally.
2. The test scene is prepared and saved, but not executed in this session.
3. Existing unrelated workspace changes were left untouched.

## Recommended Next Step

Open and run:

- `Utility/tests/reload_module_suite_test.tscn`

Then verify:

- module scene instancing
- icon display in UI
- reload timing behavior
- overlapping timed buffs
- projectile path field spawn density
