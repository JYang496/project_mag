# Reward Draft Rules

Phase 2 makes post-battle choices behave more like a roguelike draft while preserving existing progression guarantees.

## Reward Sources

| Source | Can Offer | Must Not Offer |
| --- | --- | --- |
| Standard battle reward selection | Weapon progress, weapon obtain, module obtain, economy fallback | Task modules, cell effects |
| Completed battle ground drops | Weapon drops, module drops | Economy rewards, task modules, cell effects |
| Task objective reward selection | Cell effects, one task module option when available | Standard battle weapon/module draft pollution |
| Special task shop | Task modules paid with cell effects | Standard battle reward options |

## Standard Battle Draft

- A battle reward selection keeps one weapon-progress slot when an equipped weapon can level up or fuse.
- Module options are enabled by `EconomyConfig.reward_module_options_enabled`.
- Weapon-vs-module preference is controlled by `EconomyConfig.reward_weapon_option_chance`; the phase-2 resource value is `0.6`, so module options can appear without pushing weapon growth out of the draft.
- Economy rewards are still possible through `reward_economy_option_chance`, but only one economy option is allowed in a selection set.
- Duplicate option keys are rejected inside one draft.

## Filtering

- Hidden or zero-weight weapons are not offered.
- A weapon already at final fuse is not offered as a weapon obtain reward.
- A module already owned at max level, whether temporary or equipped, is not offered as a module reward.
- Task modules stay in `TaskRewardManager` and `CellTaskModuleRuntime`; standard battle reward generation does not add them.

## Display Contract

- Reward cards show type, rarity, name, and a short build-facing tag when available.
- Reward details show the landing result: weapon obtained/fused/converted, module stored/equippable, economy resources added, task module deployment path, or cell-effect inventory.
- Module details reuse `Module.get_effect_descriptions()` so compatibility tags, target constraints, and trigger timing come from existing module data rather than UI-side rule copies.

## Current Limits

- This phase does not add current-build affinity scoring or conflict warnings; that belongs to phase 4.
- This phase does not change route-specific reward identity; that belongs to phase 3.
- This phase does not alter task reward blocking, replacement, or rollback behavior.
