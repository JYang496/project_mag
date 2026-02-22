# Phase A+B Implementation Log

## Completed in A
- Unified module base helper in `Player/Weapons/Modules/module.gd`:
  - `can_apply_to_weapon(...)`
  - `register_as_on_hit_plugin()`
  - `unregister_as_on_hit_plugin()`
  - support flags: `supports_melee`, `supports_ranged`
- Replaced erosion legacy ranged-only attachment logic with on-hit plugin flow.

## Completed in B
- Converted on-hit modules to universal plugin flow:
  - `Player/Weapons/Modules/stun_on_hit.gd`
  - `Player/Weapons/Modules/erosion.gd`
  - `Player/Weapons/Modules/slow_on_hit.gd`
  - `Player/Weapons/Modules/life_steal.gd`
  - `Player/Weapons/Modules/lightning_chain.gd`

## Enemy Runtime Support Added
- `Npc/enemy/scripts/BaseEnemy.gd`
  - slow state runtime
  - `apply_slow(multiplier, duration)`
  - `is_slowed()`
  - `get_current_movement_speed()`

## Enemy Movement Updated to Consume Slow
- `Npc/enemy/scripts/enemy_rolling_ball.gd`
- `Npc/enemy/scripts/enemy_wheel_cart.gd`
- `Npc/enemy/scripts/enemy_orbit_support.gd`
- `Npc/enemy/scripts/enemy_rolling_ball_elite.gd`

## Notes
- These changes keep projectile-only movement effects untouched.
- On-hit modules now apply to both melee and ranged as long as hit events are routed to weapon plugins.
