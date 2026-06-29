# Test Scene Inventory

Date: 2026-06-27

Scope: post-migration classification. The former legacy test scenes have been moved into `tests/`.

This inventory classifies every migrated `.tscn` scene so future cleanup can distinguish long-term regression coverage from probes, showcases, archive material, and deletion candidates. The classification remains conservative: scenes that might be one-off probes are marked `archive_candidate`, not `delete_candidate`, until a follow-up pass proves they have no remaining coverage value.

## Decision Labels

| Decision | Meaning |
| --- | --- |
| `migrate` | Keep as a regression or focused verification scene and move into the future `tests/` tree. |
| `migrate_benchmark` | Keep as measurement tooling and move under `tests/benchmarks/**`; do not mix with regression gates. |
| `migrate_fixture` | Keep as shared test fixture and move before dependent scenes. |
| `archive_candidate` | Likely manual, showcase, smoke, probe, or legacy coverage; preserve for now, then review after stronger regression coverage exists. |
| `delete_candidate` | Safe to delete after proving no references, no unique coverage, and passing Godot validation. None are marked this way in this first pass. |

## Summary

| Decision | Scene count |
| --- | ---: |
| `migrate` | 38 |
| `migrate_benchmark` | 4 |
| `migrate_fixture` | 1 |
| `archive_candidate` | 9 |
| `delete_candidate` | 0 |
| Total classified `.tscn` scenes | 52 |

## Scene Classification

| Scene | Family | Primary script / runner | Decision | Proposed destination | Notes |
| --- | --- | --- | --- | --- | --- |
| `tests/scenes/weapon/auto_fire_weapon_switch_test.tscn` | weapon/combat | `run_auto_fire_weapon_switch_test_headless.gd` | `migrate` | `tests/scenes/weapon/` | Regression coverage for auto-fire weapon switching behavior. |
| `tests/scenes/reward/battle_drop_storage_test.tscn` | reward/equipment | `run_battle_drop_storage_test_headless.gd` | `migrate` | `tests/scenes/reward/` | Regression coverage for battle-drop storage flow. |
| `tests/scenes/ui/branch_select_panel_ui_test.tscn` | UI | `run_branch_select_panel_ui_test_headless.gd` | `migrate` | `tests/scenes/ui/` | UI regression scene; keep scene-backed validation. |
| `tests/scenes/cell/cell_effect_runtime_test.tscn` | cell | `run_cell_effect_runtime_test_headless.gd` | `migrate` | `tests/scenes/cell/` | Runtime contract test for cell effects. |
| `tests/scenes/cell/cell_task_combat_hud_test.tscn` | cell/UI | `run_cell_task_combat_hud_test_headless.gd` | `migrate` | `tests/scenes/cell/` | Recent task-HUD regression coverage; keep. |
| `tests/scenes/cell/cell_task_module_runtime_test.tscn` | cell/reward | `run_cell_task_module_runtime_test_headless.gd` | `migrate` | `tests/scenes/cell/` | Runtime contract coverage for task modules. |
| `tests/scenes/weapon/dash_blade_offhand_auto_attack_test.tscn` | weapon/combat | `run_dash_blade_offhand_auto_attack_test_headless.gd` | `migrate` | `tests/scenes/weapon/` | Weapon regression coverage; depends on shared dummy enemy fixture. |
| `tests/archive/benchmarks/dps_benchmark.tscn` | benchmark/dps | `dps_benchmark.gd` | `archive_candidate` | `tests/archive/benchmarks/` or remove after review | Older DPS benchmark surface; compare against `real_combat_dps_benchmark` before keeping. |
| `tests/fixtures/enemies/dps_test_dummy_enemy.tscn` | fixture/enemy | `dps_test_dummy_enemy.gd` | `migrate_fixture` | `tests/fixtures/enemies/` | Shared fixture used by weapon, heat, benchmark, and combat tests. Move before dependents. |
| `tests/probes/enemy/enemy_spike_turret_behavior_probe.tscn` | enemy/probe | `run_enemy_spike_turret_behavior_headless.gd` | `archive_candidate` | `tests/probes/enemy/` | Probe-style scene. Keep until there is equivalent formal enemy behavior coverage. |
| `tests/scenes/enemy/enemy_support_behavior_test.tscn` | enemy | `run_enemy_support_behavior_headless.gd` | `migrate` | `tests/scenes/enemy/` | Enemy behavior regression coverage. |
| `tests/scenes/reward/equipment_pickup_queue_test.tscn` | reward/equipment | `run_equipment_pickup_queue_test_headless.gd` | `migrate` | `tests/scenes/reward/` | Recent queue contract coverage; keep. |
| `tests/scenes/ui/gameover_stats_ui_test.tscn` | UI | `gameover_stats_ui_test.gd` | `migrate` | `tests/scenes/ui/` | Scene-backed UI regression, with separate headless runner loading it. |
| `tests/scenes/weapon/heat_passive_test.tscn` | weapon/combat | `heat_passive_test.gd` | `migrate` | `tests/scenes/weapon/` | Core heat/passive regression fixture and scene; several runners load it. |
| `tests/scenes/ui/hud_dirty_refresh_test.tscn` | UI | `hud_dirty_refresh_test.gd` | `migrate` | `tests/scenes/ui/` | Performance/dirty-refresh UI regression. |
| `tests/probes/world/infinite_mode_smoke_test.tscn` | world/smoke | `infinite_mode_smoke_test.gd` | `archive_candidate` | `tests/probes/world/` | Smoke check. Keep runnable until broader world startup coverage replaces it. |
| `tests/probes/economy/kill_gold_drop_probe.tscn` | economy/probe | `run_kill_gold_drop_probe_headless.gd` | `archive_candidate` | `tests/probes/economy/` | Low-risk first migration slice from sequence 07; probe-style but useful for Utility spawn/economy moves. |
| `tests/showcases/weapon/laser_branch_showcase.tscn` | weapon/showcase | `laser_branch_showcase.gd` | `archive_candidate` | `tests/showcases/weapon/` | Manual/showcase surface, not a strict regression gate. |
| `tests/scenes/reward/loot_rarity_reward_test.tscn` | reward | `run_loot_rarity_reward_test_headless.gd` | `migrate` | `tests/scenes/reward/` | Reward rarity contract coverage; keep. |
| `tests/probes/weapon/machine_gun_spread_probe.tscn` | weapon/probe | `run_machine_gun_spread_probe_headless.gd` | `archive_candidate` | `tests/probes/weapon/` | Probe-style scene; keep until centered-spread regression coverage is confirmed elsewhere. |
| `tests/scenes/ui/management_ui_polish_test.tscn` | UI | `run_management_ui_polish_test_headless.gd` | `migrate` | `tests/scenes/ui/` | UI regression for management polish. |
| `tests/scenes/weapon/on_hit_module_lifecycle_test.tscn` | weapon/module | `run_on_hit_module_lifecycle_test_headless.gd` | `migrate` | `tests/scenes/weapon/` | Module lifecycle regression. |
| `tests/scenes/weapon/plasma_lance_rift_test.tscn` | weapon/combat | `plasma_lance_rift_test.gd` | `migrate` | `tests/scenes/weapon/` | Weapon branch behavior coverage; depends on `heat_passive_test.tscn`. |
| `tests/scenes/world/player_assist_settings_test.tscn` | player/settings | `run_player_assist_settings_test_headless.gd` | `migrate` | `tests/scenes/world/` | Player assist persistence/settings regression. |
| `tests/scenes/weapon/player_stat_module_test.tscn` | player/module | `run_player_stat_module_test_headless.gd` | `migrate` | `tests/scenes/weapon/` | Player stat module regression. |
| `tests/scenes/spawn/ranged_spawn_limits_test.tscn` | spawn/enemy | `run_ranged_spawn_limits_test.gd` | `migrate` | `tests/scenes/spawn/` | Spawn limit regression; note runner does not use `_headless` suffix. |
| `tests/showcases/ui/rarity_ui_showcase.tscn` | UI/showcase | `rarity_ui_showcase.gd` | `archive_candidate` | `tests/showcases/ui/` | Showcase scene for rarity UI. Keep separate from automated regression gates. |
| `tests/benchmarks/dps/real_combat_dps_benchmark.tscn` | benchmark/dps | `real_combat_dps_benchmark.gd` | `migrate_benchmark` | `tests/benchmarks/dps/` | Current real-combat DPS report generator. |
| `tests/benchmarks/dps/real_combat_module_output_benchmark.tscn` | benchmark/dps | `real_combat_module_output_benchmark.gd` | `migrate_benchmark` | `tests/benchmarks/dps/` | Inherits from `real_combat_dps_benchmark.tscn`; move with base scene. |
| `tests/benchmarks/dps/real_combat_single_weapon_repeat_benchmark.tscn` | benchmark/dps | `real_combat_single_weapon_repeat_benchmark.gd` | `migrate_benchmark` | `tests/benchmarks/dps/` | Weapon-specific balance benchmark. |
| `tests/probes/rest_area/rest_area_current_cell_probe.tscn` | rest-area/probe | `rest_area_current_cell_probe.gd` | `archive_candidate` | `tests/probes/rest_area/` | Probe-style scene; preserve until RestArea regression coverage is reviewed. |
| `tests/scenes/world/rest_area_start_battle_confirmation_chain_test.tscn` | rest-area/world | `run_rest_area_start_battle_confirmation_chain_test_headless.gd` | `migrate` | `tests/scenes/world/` | RestArea flow regression. |
| `tests/scenes/world/rest_area_task_management_blocking_test.tscn` | rest-area/world | `run_rest_area_task_management_blocking_test_headless.gd` | `migrate` | `tests/scenes/world/` | RestArea blocking contract coverage. |
| `tests/scenes/world/rest_area_zone_hint_test.tscn` | rest-area/world | `run_rest_area_zone_hint_test_headless.gd` | `migrate` | `tests/scenes/world/` | RestArea zone hint regression. |
| `tests/scenes/world/secondary_menu_world_blocking_contract_test.tscn` | world/UI | `run_secondary_menu_world_blocking_contract_test_headless.gd` | `migrate` | `tests/scenes/world/` | World interaction blocking contract coverage. |
| `tests/scenes/ui/shop_sell_flow_test.tscn` | UI/shop | `run_shop_sell_flow_test_headless.gd` | `migrate` | `tests/scenes/ui/` | Shop sell flow regression. |
| `tests/scenes/spawn/spawn_boundary_projection_test.tscn` | spawn/cell | `run_spawn_boundary_projection_test_headless.gd` | `migrate` | `tests/scenes/spawn/` | Spawn boundary projection regression. |
| `tests/scenes/world/startup_feature_test_loadout.tscn` | world/startup | `run_startup_feature_test_loadout_headless.gd` | `migrate` | `tests/scenes/world/` | Startup loadout regression. |
| `tests/scenes/weapon/synergy_module_test.tscn` | weapon/module | `run_synergy_module_test_headless.gd` | `migrate` | `tests/scenes/weapon/` | Module synergy regression; depends on shared weapon/enemy fixture scripts. |
| `tests/scenes/reward/task_reward_flow_test.tscn` | reward/cell | `run_task_reward_flow_test_headless.gd` | `migrate` | `tests/scenes/reward/` | Task reward flow regression. |
| `tests/scenes/reward/temporary_module_lifecycle_test.tscn` | reward/module | `run_temporary_module_lifecycle_test_headless.gd` | `migrate` | `tests/scenes/reward/` | Temporary module lifecycle regression. |
| `tests/scenes/ui/temporary_module_settlement_dialog_test.tscn` | UI/reward | `run_temporary_module_settlement_dialog_test_headless.gd` | `migrate` | `tests/scenes/ui/` | Settlement dialog regression. |
| `tests/scenes/world/threaded_world_load_test.tscn` | world/startup | `run_threaded_world_load_test_headless.gd` | `migrate` | `tests/scenes/world/` | Threaded load regression. |
| `tests/scenes/ui/unified_modal_behavior_test.tscn` | UI/modal | `run_unified_modal_behavior_test_headless.gd` | `migrate` | `tests/scenes/ui/` | Modal behavior contract coverage. |
| `tests/scenes/ui/upgrade_preview_refresh_test.tscn` | UI/reward | `run_upgrade_preview_refresh_test_headless.gd` | `migrate` | `tests/scenes/ui/` | Upgrade preview refresh regression. |
| `tests/scenes/weapon/weapon_auto_fuse_test.tscn` | weapon/module | `run_weapon_auto_fuse_test_headless.gd` | `migrate` | `tests/scenes/weapon/` | Weapon auto-fuse regression. |
| `tests/scenes/weapon/weapon_fire_feedback_test.tscn` | weapon/UI | `run_weapon_fire_feedback_test_headless.gd` | `migrate` | `tests/scenes/weapon/` | Weapon fire feedback regression. |
| `tests/benchmarks/weapon_formula/weapon_formula_benchmark.tscn` | benchmark/weapon_formula | `weapon_formula_benchmark.gd` | `migrate_benchmark` | `tests/benchmarks/weapon_formula/` | Formula benchmark; depends on dummy enemy fixture. |
| `tests/showcases/weapon/weapon_fuse_manual_test.tscn` | weapon/manual | `weapon_fuse_manual_test.gd` | `archive_candidate` | `tests/showcases/weapon/` | Manual verification scene; keep out of automated gates unless assertions are added. |
| `tests/scenes/weapon/weapon_numeric_module_test.tscn` | weapon/module | `run_weapon_numeric_module_test_headless.gd` | `migrate` | `tests/scenes/weapon/` | Numeric module regression and shared reference point. |
| `tests/scenes/weapon/weapon_passive_charge_test.tscn` | weapon/passive | `run_weapon_passive_charge_test_headless.gd` | `migrate` | `tests/scenes/weapon/` | Passive charge contract coverage; keep. |
| `tests/scenes/ui/weapon_selector_layer_test.tscn` | UI/weapon | `run_weapon_selector_layer_test_headless.gd` | `migrate` | `tests/scenes/ui/` | Weapon selector UI/layer regression. |

## Archive Candidates To Review First

These scenes are the best candidates for eventual pruning, but they should not be deleted until a follow-up pass confirms replacement coverage:

- `tests/archive/benchmarks/dps_benchmark.tscn`: compare with `real_combat_dps_benchmark.tscn`.
- `tests/probes/enemy/enemy_spike_turret_behavior_probe.tscn`: decide whether enemy support behavior tests supersede it.
- `tests/probes/world/infinite_mode_smoke_test.tscn`: keep until world startup/load coverage is clearly stronger.
- `tests/probes/economy/kill_gold_drop_probe.tscn`: useful as the first migration slice and for Utility spawn/economy moves.
- `tests/showcases/weapon/laser_branch_showcase.tscn`: showcase/manual value only.
- `tests/probes/weapon/machine_gun_spread_probe.tscn`: confirm centered-spread tests supersede it before deleting.
- `tests/showcases/ui/rarity_ui_showcase.tscn`: showcase/manual value only.
- `tests/probes/rest_area/rest_area_current_cell_probe.tscn`: confirm RestArea regression tests supersede it before deleting.
- `tests/showcases/weapon/weapon_fuse_manual_test.tscn`: manual value only unless assertions are added.

## Next Cleanup Step

The migration itself is complete. The next useful pass is pruning, starting with `archive_candidate` scenes. Do not delete those scenes until replacement coverage is identified and Godot validation passes after removal.
