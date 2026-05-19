# Project Optimization Audit

Date: 2026-05-18

Scope locked for this pass:

- Full-project layered audit.
- Report and roadmap only; no runtime code changes in this pass.
- Only code-backed findings are listed. Items that would require profiling are marked as follow-up validation, not as confirmed bottlenecks.

## Executive Summary

The highest-return optimization work is not a single micro-optimization. The project already has several extracted systems, tests, and benchmark scenes, but the runtime still has three structural pressure points:

1. Per-frame loops in `Player`, `Weapon`, UI, effects, and modules still do work that can be made event-driven or ticked less often.
2. Enemy lookup is repeatedly implemented as full `get_nodes_in_group("enemies")` scans across homing, modules, trails, and branch effects.
3. Data loading, UI refresh, and timed effects have maintainability issues that can be improved with focused system boundaries.

Recommended first milestone: reduce repeated enemy scans, then add one benchmark-backed check for many-enemy combat. That creates a measurement baseline for the rest of the roadmap.

## Priority Findings

### P1. Enemy search is repeated as full group scans in combat paths

Evidence:

- `Player/Weapons/Effects/enemy_seek_steer.gd:23-32` retargets from `_physics_process`; `_find_closest_valid_enemy()` scans `tree.get_nodes_in_group("enemies")` at `enemy_seek_steer.gd:49-74`.
- `Player/Weapons/Modules/wmod_runtime_utils.gd:46-58` exposes `get_nearby_enemies()` by scanning the whole enemy group.
- Other callers duplicate the same pattern, including `Player/Weapons/Modules/wmod_lightning_chain_on_hit.gd:51`, `Player/Weapons/Effects/frost_field_effect.gd:77`, `Utility/area_effect/trail_area_effect.gd:164`, and branch scripts such as `Player/Weapons/Branches/pistol_arc_branch.gd:37`.

Impact:

Each homing projectile or AoE/module effect can scan all enemies independently. This scales with `active effects * enemy count`, which is the wrong shape for a swarm/bullet-heavy game.

Recommendation:

Introduce one shared enemy query layer instead of direct group scans:

- Start small: an `EnemyRegistry` autoload that tracks alive enemies by signal/group entry and exposes `get_enemies_in_radius(origin, radius)`.
- If needed later, bucket enemies by grid cell or quadrant for radius queries.
- Convert high-frequency users first: `EnemySeekSteer`, `WeaponModuleRuntimeUtils.get_nearby_enemies()`, and persistent AoE/trail effects.

Verification:

- Add a benchmark case with many enemies plus homing/chain/frost effects.
- Confirm no behavior drift by running the existing heat/passive and formula checks after conversion.

### P1. UI refresh work runs every physics frame even when most values have not changed

Evidence:

- `UI/scripts/UI.gd:307-313` calls `hud_presenter.refresh_dynamic_texts()`, `_refresh_weapon_passive_panel()`, `_refresh_controls_hint_visibility()`, and `_update_rest_area_hover_hint_position()` every physics frame.
- `UI/scripts/components/hud_presenter.gd:66-72` refreshes HP, heat, ammo, weapon state, and general HUD values every call.
- `hud_presenter.gd:236-253` formats equipped/gold/energy/time text every refresh. Some labels cache text (`_last_heat_label_text`, `_last_ammo_label_text`, `_last_weapon_state_text`), but gold/resource/time/equipped text still get rebuilt each frame.
- `UI/scripts/weapon_selector.gd:53-54` independently updates slot cooldown progress every render frame.

Impact:

The HUD is doing repeated string formatting, localization lookups, dynamic calls, and passive panel refresh checks at physics frequency. Some values do need frequent updates, such as reload countdowns and cooldown fill. Many others are event-driven values: gold, equipped text, augments, passive metadata, controls hints, and phase-specific visibility.

Recommendation:

Split HUD refresh into three lanes:

- Event-driven: gold, inventory, augments, equipped weapon list, passive metadata, controls hint visibility.
- Low-frequency tick: battle time, reload text, heat/ammo labels if they require visible countdowns.
- Per-frame visual only: cursor/selector progress animations.

Verification:

- Add a lightweight UI headless test that changes gold/weapon/passive state and asserts labels update from signals.
- Use existing `World/Test/run_gameover_stats_ui_test_headless.gd` as a pattern for UI assertions.

### P1. Player.gd remains the main per-frame coordinator for many unrelated systems

Evidence:

- `Player/Mechas/scripts/Player.gd` is about 1800 lines.
- `Player.gd:199-221` runs weapon sanitation, global passives, heat status, combat input, weapon orbit sync, shared heat, elemental effects, energy regen, passive tick, collect-area anchoring, movement, visual state, weapon orbit movement, camera, and board constraint in one `_physics_process`.
- `Player.gd:199-221` calls `_update_collect_area_anchor_to_screen_top()` twice in the same frame.
- Existing extracted systems already exist (`player_loot_system.gd`, `player_shared_heat_system.gd`, `player_damage_reaction_system.gd`, etc.), but the main frame loop still owns broad orchestration.

Impact:

This makes optimization harder because unrelated systems share one frame loop and one owner. It also increases the chance that future gameplay changes add more per-frame work to `Player.gd` instead of becoming a bounded system with clear tick/update ownership.

Recommendation:

Continue the existing extraction pattern, but prioritize by frame-loop ownership:

- Move weapon-list sanitation and orbit state maintenance into a `PlayerWeaponRuntimeSystem`.
- Move combat input and active/reload requests into a small `PlayerCombatInputSystem`.
- Gate `_update_collect_area_anchor_to_screen_top()` behind viewport/camera/layout changes, or prove why it must run every frame and remove the duplicate call.
- Keep `Player.gd` as coordinator, but make each frame subsystem explicit and measurable.

Verification:

- After each extraction: `godot --headless --path . --check-only --quit`.
- For combat-sensitive changes: `godot --headless --path . --script res://World/Test/run_heat_passive_test_headless.gd`.

### P2. Timed module effects use many individual `_physics_process` loops

Evidence:

- Reload modules repeat the same active-until polling pattern:
  - `Player/Weapons/Modules/wmod_reload_damage_boost.gd:29-34`
  - `Player/Weapons/Modules/wmod_reload_move_boost.gd:29-34`
  - `Player/Weapons/Modules/wmod_reload_offhand_boost.gd:29-34`
  - `Player/Weapons/Modules/wmod_reload_shield_boost.gd:30-35`
- Other timed modules do the same style, such as `wmod_momentum_haste.gd:29-34` and `wmod_vampiric_surge.gd:27-38`.

Impact:

Each equipped timed module becomes another process callback even when it is inactive. The per-node cost may be small, but the pattern is duplicated and easy to multiply as more modules are added.

Recommendation:

Create a reusable timed-effect helper or base module:

- Register an expiration callback when the buff starts.
- Disable processing while inactive with `set_physics_process(false)`.
- For stacked effects such as `Vampiric Surge`, use one scheduler/timer or a sorted expiration queue rather than checking every frame forever.

Verification:

- Add module-level tests for "effect applies, expires, and clears on exit tree".
- Run `godot --headless --path . --check-only --quit` and a small combat smoke after moving the timer ownership.

### P2. AreaEffect always processes, even when only one-shot behavior is needed

Evidence:

- `Utility/area_effect/area_effect.gd:88-96` initializes visual nodes, starts a life timer, and applies current overlaps.
- `area_effect.gd:98-103` runs `_process()` for visual rotation, periodic damage, and debug drawing.
- `_apply_periodic_damage()` immediately returns if `tick_damage <= 0` or `tick_interval <= 0` at `area_effect.gd:162-171`.
- One-shot area effects are created by several weapons/branches, for example `Player/Weapons/cannon.gd:238`, `Player/Weapons/Branches/sniper_impact_burst_branch.gd:28`, and `Player/Weapons/Effects/explosion_effect.gd:31`.

Impact:

One-shot AoE nodes still get a process callback until their life timer expires unless processing is explicitly disabled elsewhere. Persistent damaging zones need ticking; instant explosions and visual-only areas often do not.

Recommendation:

Set processing based on feature flags:

- Enable `_process` only when `visual_rotation_speed_deg != 0`, `tick_damage > 0 and tick_interval > 0`, or debug draw is enabled.
- For periodic damage, prefer a `Timer` tick over frame accumulation when exact per-frame motion is not required.
- Keep overlap application event-driven through `area_entered` and the deferred initial overlap pass.

Verification:

- Add a focused scene/script test that instantiates one-shot and ticking `AreaEffect` variants and asserts `is_processing()` matches expected behavior.

### P2. Projectile runtime allocates per-shot child hitboxes and performs per-frame ray checks

Evidence:

- `Player/Weapons/Projectiles/projectile.gd:81-93` creates a new `RectangleShape2D` and instantiates a hitbox scene for each projectile init.
- `projectile.gd:95-101` moves projectile nodes every physics frame.
- `projectile.gd:200-207` builds a `PhysicsRayQueryParameters2D` and calls `intersect_ray()` during wall-contact checking.

Impact:

Projectile allocation and per-frame physics queries are common hot paths in this project. The actionable optimization is to decide which projectile classes actually require ray wall checks and which hitbox shapes can be reused safely.

Recommendation:

- Gate `_check_wall_contact()` behind a weapon/projectile flag so projectiles that do not need wall reporting avoid ray queries.
- Reuse immutable collision shapes where texture size does not change.

Verification:

- Use `World/Test/dps_benchmark.gd` or `weapon_formula_benchmark.gd` to compare projectile-heavy cases before/after.
- Add an assertion that projectiles which disable wall checks do not call the wall-hit path.

### P2. UI cards poll affordability every physics frame

Evidence:

- `UI/scripts/margin_item_card.gd:19-25` checks `PlayerData.player_gold < price` and sets the price label color every physics frame.
- `UI/scripts/margin_upgrade_card.gd:47-53` does the same for upgrade cards.

Impact:

These are small individually, but they are repeated across card instances and duplicate the same "gold changed" state check. The work is also unnecessary while the shop/upgrade panel is hidden.

Recommendation:

Emit or reuse a `player_gold_changed` signal from `PlayerData`, and update card affordability when:

- the card opens,
- gold changes,
- the card price/cost changes.

Verification:

- UI test: open cards, change gold, assert affordability/color changes exactly after the signal path.

### P2. DataHandler mixes directory scanning, hardcoded fallback manifests, and runtime access

Evidence:

- `autoload/DataHandler.gd:37-43` loads save, weapon data, branch data, passive branch data, mecha data, and economy data on ready.
- `DataHandler.gd:46-61`, `63-78`, `80-95`, and `97-110` each scan a directory, then fall back to a hardcoded resource list if the scan yields no data.
- The hardcoded weapon list includes legacy-looking names such as `rocket_luncher.tres` and `chainsaw_luncher.tres` at `DataHandler.gd:11` and `DataHandler.gd:13`, while directory scanning is the primary path.

Impact:

Startup cost is probably acceptable at current scale, but the maintainability risk is real: resource registration behavior depends on both filesystem contents and fallback arrays. This makes export failures and missing resources harder to diagnose.

Recommendation:

- Treat directory scanning as the single normal path.
- Move fallback manifests to test-only or explicit recovery code.
- Add a data integrity test that loads all weapon/mecha/branch/passive/economy resources, verifies IDs, and checks referenced scene paths.

Verification:

- New headless script: `World/Test/run_data_integrity_check_headless.gd`.
- Parse check after resource changes: `godot --headless --path . --check-only --quit`.

## Existing Strengths To Preserve

- The project already has useful headless checks, especially `World/Test/run_heat_passive_test_headless.gd`, `run_cone_spray_vfx_test_headless.gd`, `run_infinite_mode_smoke_test_headless.gd`, and `run_gameover_stats_ui_test_headless.gd`.
- Weapon passive/heat behavior has contract-style tests. Keep that pattern when optimizing systems that touch weapon state.
- Some UI code already caches label text (`HudPresenter` caches heat/ammo/weapon-state strings). Extend that pattern instead of replacing it wholesale.

## Recommended Roadmap

### Milestone 1: Reduce repeated enemy scans

1. Add an enemy registry/query service.
2. Move `EnemySeekSteer` and `WeaponModuleRuntimeUtils.get_nearby_enemies()` onto it.
3. Convert persistent AoE/trail/frost/chain effects.
4. Add a many-enemy benchmark case.

### Milestone 2: Make UI refresh event-driven

1. Add `PlayerData` change signals for gold/resource-like values that currently drive polling.
2. Split `HudPresenter.refresh_dynamic_texts()` into event, low-frequency, and per-frame visual paths.
3. Update item/upgrade cards from signals instead of `_physics_process`.
4. Add focused UI assertions for label changes.

### Milestone 3: Continue Player/Weapon frame-loop extraction

1. Extract weapon runtime/orbit ownership out of `Player.gd`.
2. Extract combat input dispatch out of `Player.gd`.
3. Move timed module expiration to a shared helper or scheduler.
4. Keep heat/passive tests running after every step.

## Baseline Verification Commands

Use these after optimization changes:

```powershell
godot --headless --path . --check-only --quit
godot --headless --path . --script res://World/Test/run_heat_passive_test_headless.gd
godot --headless --path . --script res://World/Test/run_infinite_mode_smoke_test_headless.gd
godot --headless --path . --script res://World/Test/run_gameover_stats_ui_test_headless.gd
godot --headless --path . --script res://World/Test/run_weapon_formula_benchmark_headless.gd
```
