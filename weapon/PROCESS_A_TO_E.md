# Weapon Effects Migration Process

## Goal
Make weapon modules/effects compatible across melee and ranged systems while preserving projectile-specific behavior.

## Phase A (Core Infrastructure)
- Add unified weapon on-hit plugin pipeline:
  - `Weapon.register_on_hit_plugin(plugin)`
  - `Weapon.unregister_on_hit_plugin(plugin)`
  - `Weapon.on_hit_target(target)`
- Ensure hit events route through this pipeline from:
  - melee hitboxes
  - ranged bullets/beam emitters via source weapon forwarding
- Remove module reliance on legacy ranged-only fields where possible.

## Phase B (On-Hit Modules)
- Convert all on-hit style modules to plugin model with `apply_on_hit(source_weapon, target)`:
  - `stun_on_hit`
  - `erosion`
  - `slow_on_hit`
  - `life_steal`
  - `lightning_chain`
- Add/standardize enemy helper methods needed by modules:
  - `apply_stun`
  - `apply_slow`
  - `is_stunned`
  - `get_current_movement_speed`

## Phase C (Shared Stat Contract)
- Define common stat signals for all weapon archetypes.
- Keep optional hooks for archetype-specific stats.
- Ensure all modules use capability checks instead of concrete weapon class assumptions.

## Phase D (Effects Compatibility)
- Classify effects into:
  - universal
  - melee-specific
  - projectile-only
- Keep projectile motion effects projectile-only.
- Provide melee analogs for universal combat intent effects where needed.

## Phase E (Validation)
- Add compatibility matrix and runtime checklist.
- Verify no missing property/signal errors when module is mounted on melee or ranged weapon.
- Verify combat balance and proc frequency after migration.
