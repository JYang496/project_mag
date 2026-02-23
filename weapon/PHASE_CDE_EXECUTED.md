# Phase C+D+E Execution Report

## Phase C Completed
- Added shared weapon capability contract:
  - `supports_projectiles()`
  - `supports_melee_contact()`
  - `get_weapon_capabilities()`
- Implemented capability overrides:
  - `Ranger.supports_projectiles() -> true`
  - `Melee.supports_melee_contact() -> true`
- Updated module gating to use capability methods (instead of hard class checks):
  - `Module.can_apply_to_weapon(...)`
- Marked projectile-only modules as not melee-capable:
  - `bullet_size_up`
  - `more_hp`
  - `faster_speed`

## Phase D Completed
- Added effect host compatibility framework in `Effect` base:
  - `supports_ranged` / `supports_melee`
  - Unsupported host auto-frees effect (graceful no-op)
- Converted selected effects to true dual-host support:
  - `knock_back_effect`: now supports melee and ranged
  - `dmg_up_on_enemy_death`: now supports melee host weapon or ranged source weapon
- Left projectile-trajectory effects as projectile-only by default.

## Phase E Completed (Static Validation)
- Validation checks run:
  - weapon capability methods present in base/melee/ranger
  - module capability and plugin hooks present
  - effect compatibility flags and lifecycle hooks present
  - no remaining legacy `bullet_effects` references in `Player/Weapons`
- Validation limitation:
  - Runtime in-editor combat test was not executed in this terminal pass.

## Ready For Runtime QA
- Test matrix should include:
  - melee weapon with `knock_back_effect` and on-hit modules
  - ranged weapon with projectile-only effects still unchanged
  - mixed module loadout on both archetypes to confirm no missing signal/property errors
