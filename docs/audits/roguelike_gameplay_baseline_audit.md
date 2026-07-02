# Roguelike Gameplay Baseline Audit

Date: 2026-06-30
Scope: phase 0 of `docs/prompt/roguelike_gameplay_optimization_sequence.md`

This audit records the current gameplay baseline only. No gameplay scripts, resources, numeric values, or tests were changed.

## Files Read

Prompt and repo state:
- `docs/prompt/roguelike_gameplay_optimization_sequence.md`
- `git status --short`

Weapon resources and definitions:
- `data/WeaponDefinition.gd`
- `data/weapons/*.tres` (15 files)
- `data/WeaponPassiveBranchDefinition.gd`
- `data/weapon_passives/*.tres` (15 files)
- `data/WeaponBranchDefinition.gd`
- `data/weapon_branches/*.tres` (28 files)

Weapon runtime and classification:
- `Player/Weapons/Core/*.gd`
- `Player/Weapons/Branches/weapon_branch_behavior.gd`
- `Player/Weapons/Instances/*.gd`
- `Player/Weapons/Instances/*.tscn`
- `Player/Weapons/Modules/wmod_base.gd`
- `Player/Weapons/Modules/wmod_*.gd`
- `Player/Weapons/Modules/wmod_*.tscn` (metadata scan; 56 rewardable module scenes excluding `wmod_base.tscn`)

Rewards and economy:
- `World/rewards/reward_manager.gd`
- `World/rewards/reward_info.gd`
- `data/EconomyConfig.gd`
- `data/economy/economy_config.tres` via `DataHandler.ECONOMY_RESOURCE_PATH`
- `autoload/CellEffectRuntime.gd`
- `autoload/CellTaskModuleRuntime.gd`
- `autoload/TaskRewardManager.gd`
- `UI/scripts/reward_selection_panel.gd`

Routes and spawn:
- `data/routes/RunRouteDefinition.gd`
- `data/routes/*.tres`
- `autoload/RunRouteManager.gd`
- `data/spawns/SpawnCombatProfile.gd`
- `data/spawns/LevelCombatPlan.gd`
- `data/spawns/EnemySpawnEntry.gd`
- `data/spawns/PressurePoint.gd`
- `data/spawns/spawn_combat_profile.tres`
- `autoload/SpawnData.gd`
- `World/spawn/enemy_spawner.gd`
- `World/spawn/spawn_budget_runtime.gd`

Task modules:
- `data/task_modules/TaskModuleDefinition.gd`
- `data/task_modules/task_*.tres` (5 files)

## Current Inventory

- Weapons: 15 resources in `data/weapons/*.tres`.
- Weapon passives: 15 resources in `data/weapon_passives/*.tres`.
- Weapon branches: 28 resources in `data/weapon_branches/*.tres`.
- Rewardable weapon module scenes: 56 `Player/Weapons/Modules/wmod_*.tscn` files excluding `wmod_base.tscn`.
- Task modules: 5 resources in `data/task_modules/task_*.tres`.
- Routes: `normal`, `bonus`, `difficult`.
- Spawn levels: 10 level plans in `data/spawns/spawn_combat_profile.tres`.

## Build Axes

### Heat

Sources:
- `Player/Weapons/Core/weapon_trait.gd` defines `HEAT`.
- `Player/Weapons/Core/weapon_heat_controller.gd` owns weapon heat and shared heat pool binding.
- `Player/Weapons/Instances/machine_gun.tscn` has `weapon_traits = 17` (`physical`, `heat`, `auto_fire`) and heat fields.
- `Player/Weapons/Instances/flamethrower.tscn` has `weapon_traits = 20` (`fire`, `heat`) and heat fields.
- `Player/Weapons/Instances/plasma_lance.tscn` has `weapon_traits = 18` (`energy`, `heat`) and heat-spend fields.
- `data/weapon_passives/machine_gun_heat_expansion.tres`, `flamethrower_heat_prepared.tres`, and `plasma_lance_heat_spend_chain_triggered.tres`.
- `data/weapon_branches/cannon_thermal.tres`, `machine_gun_twin.tres`, and `plasma_overcharge_lance.tres`.
- Heat modules: `wmod_heat_capacity_heat`, `wmod_heat_concentration_heat`, `wmod_heat_throttle`, `wmod_heat_vent_heat`, `wmod_overheat_boost_heat`.

Baseline:
- Heat exists as both a weapon trait and runtime heat system.
- Several passives trigger around reload start or heat spending.
- Some branches inject or spend heat, including Cannon Thermal and Plasma Overcharge.

Risk:
- Heat is mechanically strong but not consistently exposed as a readable build tag in reward cards or weapon descriptions.

### Mark

Sources:
- `Player/Weapons/Instances/pistol.gd` applies `PISTOL_PIERCE_MARK_ID` during the Pierce Mark window.
- `Player/Weapons/Instances/spear_launcher.gd` uses repeated hits and reload to launch a marking radial volley.
- `Player/Weapons/Branches/cannon_zero_branch.gd` has execute bursts against marked enemies.
- `Player/Weapons/Projectiles/projectile.gd` checks `has_mark`.
- `data/weapon_passives/pistol_continuous_move_triggered.tres` and `piercing_blade_dance.tres`.
- `data/weapon_branches/cannon_zero.tres`, `spear_rending.tres`, and `spear_multi_pierce.tres`.
- `wmod_ember_mark_fire` is fire trait gated and mark-themed.

Baseline:
- Mark is a real combat status used by Pistol/Spear and consumed by Cannon Zero style execution.

Risk:
- Mark is not a first-class `WeaponTrait` or `ModuleTag`; it is behavior-driven and therefore harder for UI/reward logic to infer safely.

### Freeze

Sources:
- `Player/Weapons/Core/weapon_trait.gd` defines `FREEZE`.
- `Player/Weapons/Instances/glacier_projector.tscn` has `weapon_traits = 8`.
- `Player/Weapons/Branches/dash_frost_branch.gd`, `pistol_cryo_branch.gd`, `orbit_frost_branch.gd`, and `shotgun_shatter_branch.gd`.
- `data/weapon_passives/glacier_cold_snap_triggered.tres`.
- Freeze modules include `wmod_brittle_trigger_freeze`, `wmod_chill_chain_freeze`, `wmod_cryo_infuser_freeze`, `wmod_ice_prison_freeze`, `wmod_permafrost_field_freeze`, `wmod_shatter_strike_freeze`, `wmod_subzero_extension_freeze`, and `wmod_trail_aoe_freeze`.

Baseline:
- Freeze has a formal trait, several branches, and several modules.

Risk:
- Freeze module compatibility is partly trait-gated, but reward display currently shows level/name rather than why a freeze module fits the current build.

### Reload

Sources:
- `Player/Weapons/Core/weapon_ammo_controller.gd` and `weapon_plugin_dispatcher.gd`.
- `Player/Weapons/Core/module_hook.gd` defines `RELOAD_START` and `RELOAD_DURATION`.
- Reload modules: `wmod_reload_blast_damage`, `wmod_reload_blast_knockback`, `wmod_reload_damage_boost`, `wmod_reload_move_boost`, `wmod_reload_offhand_boost`, `wmod_reload_shield_boost`, `wmod_reload_speed_link`.
- Weapon passives such as Machine Gun Heat Expansion, Flamethrower Heat Prepared, Glacier Cold Snap, Pistol Pierce Mark, Shotgun Close Hit, Rocket Cluster Kill, Laser Focus Channel, and Sniper Far Hit reference reload as trigger or refresh.

Baseline:
- Reload is a major rhythm axis. It is implemented through ammo controller events, passive refresh, and module hooks.

Risk:
- Reload is not a `WeaponTrait`; UI can infer it only from hooks/descriptions unless a dedicated taxonomy is added later.

### Close Range

Sources:
- `Player/Weapons/weapon_ranger.gd` has close-range spread parameters.
- `Player/Weapons/Instances/dash_blade.gd` and `dash_blade.tscn` use melee delivery and movement capability.
- `Player/Weapons/Instances/shotgun.gd` triggers close-hit passive.
- `Player/Weapons/Instances/chainsaw_launcher.gd` and `Player/Weapons/close_quarters_chain_rules.gd` provide slowed-target vulnerability / wall-contact behavior.
- `data/weapon_passives/shotgun_close_hit_triggered.tres`, `dash_blade_long_dash_hit_triggered.tres`, and `chainsaw_wall_contact_triggered.tres`.

Baseline:
- Close range exists through melee/contact delivery, dash targeting, shotgun distance rules, and chainsaw vulnerability.

Risk:
- Close range is not normalized as a tag; it is split across delivery type, weapon-specific logic, and prose.

### Area

Sources:
- `Player/Weapons/Core/damage_delivery_type.gd` defines `AREA`.
- Area weapons/branches: Rocket Launcher, Flamethrower, Laser Prism Splitter, Charged Blaster Prism Fan, Rocket Napalm, Rocket Salvo, Sniper Impact Burst, Fire Pulse Aura, Chainsaw Explosive.
- Area modules: `wmod_area_expander`, `wmod_diffusion_nozzle`, `wmod_firepower_diffusion`, `wmod_molten_splash_fire`, `wmod_reload_blast_damage`, `wmod_reload_blast_knockback`, `wmod_trail_aoe_freeze`.

Baseline:
- Area is formalized as a delivery type and module tag.

Risk:
- Current enemy profiles include groups and support units, but there is no explicit encounter theme matrix proving Area is tested against swarm pressure.

### On Hit

Sources:
- `Player/Weapons/Core/module_hook.gd` defines `HIT`, `DAMAGE_DEALT`, `AREA_DAMAGE`, and `BEAM_HIT`.
- `Player/Weapons/Modules/wmod_base.gd` validates required hooks against module methods.
- On-hit modules include `wmod_lifesteal_on_hit`, `wmod_lightning_chain_on_hit`, `wmod_dot_on_hit`, `wmod_stun_on_hit`, and most freeze/debuff trigger modules.

Baseline:
- On Hit exists as a hook-driven module family.

Risk:
- Hook capability is data-validatable, but not currently displayed on reward cards or module details as a player-facing build axis.

### Execute

Sources:
- `Player/Weapons/Branches/cannon_zero_branch.gd` has low-HP execute burst logic against marked enemies.
- `data/weapon_branches/cannon_zero.tres` describes low-HP execute bursts.
- `wmod_overkill_recovery` and `wmod_vampiric_surge` convert overkill damage into buffs/shields, but they are overkill payoffs rather than explicit execute triggers.

Baseline:
- Execute is present but narrow: it is mainly Cannon Zero plus overkill-adjacent modules.

Risk:
- Execute is not a formal tag or trait. Later UI/reward recommendations should avoid overstating it as a broad current system.

### Economy

Sources:
- `data/EconomyConfig.gd` defines default gold, duplicate refunds, purchase/upgrade ratios, battle drop chances, reward economy chances, and reward economy values.
- `World/rewards/reward_manager.gd` creates fallback economy rewards with EXP and gold.
- `TaskRewardManager.gd` converts invalid weapon upgrade task rewards to duplicate weapon gold.
- `CellTaskModuleRuntime.gd` uses cell effects as special-shop currency for task module offers.

Baseline:
- Economy exists in gold, EXP/chips, duplicate conversion, shop costs, battle reward fallback, and cell-effect special-shop cost.

Risk:
- Economy rewards can appear as fallback/roll results, but the current reward card does not explain the strategic role of economy options.

### Task Module

Sources:
- `data/task_modules/task_*.tres` defines Kill, Hold, Clear, Hunt, Dodge task modules.
- `autoload/CellTaskModuleRuntime.gd` owns inventory, deployment, active tasks, completion state, special shop offer, and task module rewards.
- `autoload/TaskRewardManager.gd` opens task reward selection after objectives and blocks prepare interactions while pending.
- `UI/scripts/reward_selection_panel.gd` has `KIND_TASK_MODULE` display handling.

Baseline:
- Task modules are separate from normal battle rewards. The task reward flow offers Cell Effects plus a Task Module option when an objective completes.

Risk:
- Task module rewards are mechanically separate but use the same reward panel; future reward UI changes must preserve task reward blocking and replacement behavior.

## Reward Pool Baseline

### Completed Battle Drop Rewards

Source: `World/rewards/reward_manager.gd::build_completed_battle_drop_rewards()`.

Can give:
- Weapon drops from non-hidden `DataHandler.get_weapon_ids()` where `WeaponDefinition.get_drop_weight() > 0`.
- Module drops from `Player/Weapons/Modules/*.tscn`, excluding `wmod_base.tscn`, where `Module.get_drop_weight() > 0`.
- At least one weapon or module is forced when both chance rolls fail and candidates exist.

Configuration:
- `battle_drop_weapon_chance = 0.75`.
- `battle_drop_module_chance = 0.5`.
- Route bonuses can raise item or module level through `reward_item_level_bonus` and `reward_module_level_bonus`.

Does not give:
- Task modules.
- Cell effects.
- Direct economy rewards.
- Hidden or zero-weight weapons/modules.

### Battle Reward Selection Options

Source: `World/rewards/reward_manager.gd::build_reward_selection_options()`.

Can give:
- A guaranteed weapon progress reward when an equipped weapon can level up or fuse.
- Weapon obtain rewards from available non-hidden, positive-weight weapon definitions.
- Economy fallback rewards (`reward_economy_exp = 5`, `reward_economy_gold = 7`).
- Module reward options only if `EconomyConfig.reward_module_options_enabled` is true.

Current default:
- `reward_module_options_enabled = false`, so module options are not part of standard reward selection by default.
- `reward_weapon_option_chance = 0.5`.
- `reward_economy_option_chance = 0.15`.
- The standard route target count is the route's `reward_option_count`, currently 3 for all route resources.

Filters:
- Full-fuse matching weapon IDs are filtered from weapon rewards.
- Full-level matching modules are filtered from module rewards when module reward options are enabled.
- Selected reward keys prevent duplicate options in the same selection set.

Does not give:
- Task modules.
- Cell effects.
- Module selection options by default, because the config gate is off.

### Task Reward Selection

Source: `autoload/TaskRewardManager.gd::_build_reward_options_from_current_state()`.

Can give:
- Two Cell Effect rewards from `CellEffectRuntime.build_reward_options()`.
- One Task Module reward from `CellTaskModuleRuntime.build_reward_option()`.
- More Cell Effect rewards to fill up to 3 options when needed.

Does not directly give:
- Standard weapon drops.
- Standard module drops.
- Standard economy fallback, except task-selected standard rewards are passed to `BonusManager.grant_reward_immediately()` when present.

## Route Baseline

Route definition fields:
- Combat identity: `battle_enabled`, `grants_prepare_loot`.
- Enemy modifiers: `enemy_hp_multiplier`, `enemy_damage_multiplier`, `battle_timeout_multiplier`.
- Reward modifiers: `reward_option_count`, `reward_chip_multiplier`, `reward_item_level_bonus`, `reward_module_level_bonus`, `fallback_reward_chip_value`.

Current route resources:

| Route | Battle | Prepare loot | Enemy HP | Enemy damage | Timeout | Reward option count | Item level bonus | Module level bonus | Fallback chip |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Normal | yes | yes | 1.0 | 1.0 | 1.0 | 3 | 0 | 0 | 5 |
| Difficult | yes | yes | 1.35 | 1.25 | 0.85 | 3 | 1 | 1 | 10 |
| Bonus | no | no | 1.0 | 1.0 | 1.0 | 3 | 0 | 0 | 8 |

Important runtime facts:
- `RunRouteManager.get_available_routes_for_level()` currently returns only routes with `battle_enabled == true`, so `bonus` is not returned by that function.
- `EnemySpawner.calculate_scaled_enemy_stats()` applies route HP and damage multipliers.
- `EnemySpawner.get_effective_time_out()` applies route timeout multiplier.
- `RewardManager._build_reward_from_candidate()` applies route item and module level bonuses.
- `RunRouteManager` stores route history per level and can restore it from snapshots.

Risk:
- Current Difficult identity is primarily numeric: more HP, more damage, shorter time, better item/module levels.
- Current Bonus identity is present as a resource but is not returned by the available battle-route list.
- There are no route fields for enemy theme, special enemy weights, module/economy reward weighting, or task reward chance.

## Enemy Pressure And Level Generation

Source profile:
- `data/spawns/spawn_combat_profile.tres`
- `data/spawns/SpawnCombatProfile.gd`
- `World/spawn/enemy_spawner.gd`
- `World/spawn/spawn_budget_runtime.gd`

Current framework:
- Each level has `time_out_sec`, `target_total_hp`, and weighted `EnemySpawnEntry` records.
- Enemy entries specify `enemy_scene_path`, `start_sec`, and `weight`.
- Spawn runtime builds per-level weighted state, observes per-type alive caps, ranged caps, elite caps, and batch caps.
- HP budget releases over battle time using pressure points.
- Default pressure curve is early `0.85`, mid `1.0` at `t = 0.7`, late `1.2` at `t = 1.0`.
- Spawn budget stops once spawned HP reaches `target_total_hp`, then the battle can end after enemies are cleared.
- Infinite overflow starts after level 10 with HP and damage growth.

Level plan summary:

| Level | Timeout | Target HP | Main enemy entries |
| --- | ---: | ---: | --- |
| 1 | 60 | 500 | rolling ball |
| 2 | 60 | 600 | wheel cart, rolling ball |
| 3 | 49 | 800 | rolling ball, shield core, spike turret |
| 4 | 52 | 900 | bomber, repair unit, mine crawler |
| 5 | 53 | default/unspecified | mortar turret, interceptor heavy, orbit support, mirror caster |
| 6 | 55 | 1200 | wheel cart, shield core, spike turret, orbit support |
| 7 | 60 | 1400 | bomber, mine crawler, repair unit, rolling ball elite |
| 8 | 67 | 1600 | mortar turret, interceptor heavy, orbit support, tar mine crawler, mirror caster |
| 9 | 75 | 1800 | wheel cart, shield core, spike turret, repair unit, orbit support, interceptor heavy |
| 10 | 84 | 2000 | mortar turret, bomber, shield core, rolling ball elite, repair unit, interceptor heavy, mirror caster |

Risk:
- Level 5 omits `target_total_hp` in the resource, so it inherits `LevelCombatPlan` default `1000`.
- Spawn plans contain meaningful enemy mixes, but they are not named as encounter themes.
- The runtime has caps for ranged and elite enemies, but no build-axis validation showing which builds each level tests.

## UI Baseline

Reward panel:
- Shows rarity color bar.
- Shows type label, title, and one short tag.
- Detail panel shows title, detail text, and optional outcome text.
- Handles `weapon_upgrade`, `cell_effect`, `task_module`, weapon obtain, module obtain, EXP, and gold.

Current gaps:
- Reward display does not show build tags like Heat, Mark, Freeze, Reload, Area, On Hit, Execute, or Economy.
- Module reward display uses module name and level but not compatibility reason, required traits, delivery types, or hooks.
- Weapon descriptions include several placeholder/test strings, so even if UI displays them later, readability remains inconsistent.

## Risk List For Later Phases

Documentation and text:
- Several weapon descriptions are placeholders or inconsistent casing: `machine_gun`, `shotgun`, `laser`, `chainsaw_luncher`, `charged_blaster`, `dash_blade`, `flamethrower`, `orbit`.
- Mark, Reload, Close Range, Execute, and Economy are real axes but are not normalized as concise display tags.

UI:
- Reward cards do not currently communicate build affinity.
- Task rewards share the reward panel, so UI changes must preserve task reward blocking, progress text, and outcome text.
- Module compatibility is enforced in `wmod_base.gd`, but not presented in standard reward display.

Reward pool:
- Standard battle reward selection is still mostly weapon progress plus possible economy fallback because module options are gated off by default.
- Completed battle ground drops can already include modules, which means the player can receive modules outside the draft choice flow.
- Reward pool responsibilities are split across completed battle drops, battle selection, task reward selection, and special task shop.

Routes:
- Difficult route is currently mostly numeric pressure and reward level bonus.
- Bonus route exists as a non-battle route but is not returned by `get_available_routes_for_level()`.
- No explicit route-level encounter theme or reward-pool weighting exists.

Enemy themes:
- Spawn profile has enemy mixes but no formal encounter theme taxonomy.
- Ranged/elite caps exist, but support/ranged/elite ratios are not currently verified against build axes.
- Level 5 depends on the default target HP value rather than an explicit resource value.

Tests and verification:
- Phase 0 did not add tests by instruction.
- Existing verification for this phase is syntax/resource load only through Godot check-only.
- Later phases should add focused tests for reward option generation, task reward flow, route modifiers, spawn profile validation, and UI display data contracts.

## Not Done

- Did not modify gameplay code.
- Did not modify resource values.
- Did not add tests.
- Did not normalize text/tag taxonomy; that belongs to phase 1.
- Did not enable module reward options; that belongs to phase 2.
- Did not alter route definitions or spawn profiles; those belong to phases 3 and 5.

## Commands And Results

Commands already run during audit:

```powershell
git status --short
```

Result:
- `?? docs/prompt/` was already present before this audit.
- After this audit, `docs/audits/roguelike_gameplay_baseline_audit.md` is the only intended new file from phase 0.

```powershell
Get-Content -Raw -Encoding UTF8 docs\prompt\roguelike_gameplay_optimization_sequence.md
```

Result:
- Phase 0 scope confirmed: generate `docs/audits/roguelike_gameplay_baseline_audit.md`, do not change gameplay code/resources, do not add tests.

```powershell
rg -n ...
Get-Content -Raw -Encoding UTF8 ...
Get-ChildItem ...
```

Result:
- Read and indexed the files listed above for weapon/resource/reward/route/spawn/task/UI facts.

Final validation commands:

```powershell
git diff --check
```

Result:
- PASS. No whitespace errors reported.

```powershell
rg -n "[ \t]+$" docs\audits\roguelike_gameplay_baseline_audit.md
```

Result:
- PASS. No trailing whitespace reported in the new untracked audit file.

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit
```

Result:
- PASS. Godot exited with code 0.
