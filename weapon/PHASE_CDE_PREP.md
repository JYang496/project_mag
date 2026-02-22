# Phase C+D+E Preparation

## C: Shared Stats Contract (Planned)
- Add capability methods on weapons:
  - `supports_projectiles()`
  - `supports_melee_contact()`
- Standardize optional signals:
  - `calculate_weapon_damage`
  - `calculate_attack_cooldown`
  - `calculate_weapon_speed` (optional by archetype)
  - `calculate_weapon_bullet_hits` (projectile archetypes only)
- Migrate modules to capability checks only; avoid direct class assumptions.

## D: Effects Classification Draft
- Universal combat intent:
  - `knock_back_effect` (refactor toward hit-context target application)
  - `speed_change_on_hit` (split projectile travel vs on-hit variant)
  - `dmg_up_on_enemy_death` (review for non-bullet attachment)
- Projectile-only:
  - `linear_movement`
  - `spiral_movement`
  - `rotate_around_player`
  - `fall`
  - `ricochet_effect`
  - `return_on_timeout`
  - `scale_up_by_time`
  - `spin_effect`
  - `chase_closest_enemy`
  - `hexagon_attack`
  - `explosion_effect`
  - `erosion_effect` (superseded by module plugin path for status application)

## E: Validation Checklist
- Module mount tests on melee and ranged:
  - no missing-signal errors
  - no missing-property errors
- Proc correctness tests:
  - stun/slow/erosion duration and chance
  - elite/boss reductions
  - fuse scaling correctness
- Performance sanity:
  - lightning chain target search cost in high enemy density
- Regression checks:
  - pre-existing ranged weapons behavior unchanged
