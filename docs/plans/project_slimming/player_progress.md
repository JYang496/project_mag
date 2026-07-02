# Player Project Slimming Progress

## Completed batches

### Player-1: Pure movement calculation pilot

- `PlayerMovementSystem` no longer stores or reads a `Player` owner.
- `Player` remains responsible for movement flags, input/phase collection, `CharacterBody2D` velocity and position application, and auto-navigation lifecycle state.
- `MovementFrameInput` and `MovementFrameResult` are allocated once during Player assembly and reused for every physics tick.
- The movement system receives a strongly typed input and writes a strongly typed result without per-tick object or container construction.
- Public Player navigation methods remain compatible: `start_auto_nav`, `stop_auto_nav`, `is_auto_nav_active`, and `configure_auto_nav_speed_mul`.

### Player-2A/2B: active skill runtime split

- Added `player.active_skill_characterization` coverage for default skill loading, energy max/min/consume/regen behavior, player-skill request signals and activation, weapon active success/cooldown failure, manual reload Assist processing, reload-block hint throttling, and missing input action setup.
- Kept `Player.gd` public facades stable: `_try_cast_player_active_skill`, `_try_cast_main_weapon_active_skill`, `_try_reload_main_weapon`, energy accessors, weapon active cooldown accessors, and input action setup still delegate through `PlayerActiveSkillRuntime`.
- Split active-skill responsibilities behind the existing runtime facade:
  - `SkillEnergyState` owns current energy, max-energy resolution, active-skill cost lookup, consume/add, and regen.
  - `PlayerSkillController` owns default active skill scene loading and player active-skill request signal emission.
  - `WeaponActionController` owns main-weapon active requests, reload requests, Assist post-reload processing, cooldown/failure reads, and reload-block hints.
- Preserved the existing reload-hint throttle compatibility field on `PlayerActiveSkillRuntime` for current tests and debug callers.

## Metrics

| Metric | Before | After |
| --- | ---: | ---: |
| `Player.gd` lines | 1786 | 1828 |
| `Player.gd` functions | 226 | 227 |
| `Player.gd` top-level fields | 97 | 99 |
| `player_movement_system.gd` lines | 71 | 65 |
| `player_movement_system.gd` functions | 8 | 6 |
| `player_active_skill_runtime.gd` lines | 180 | 112 |
| `player_active_skill_runtime.gd` functions | 19 | 20 |
| Active-skill helper files | 0 | 3 |
| Active-skill helper lines | 0 | 199 |
| Active-skill helper functions | 0 | 22 |
| Movement system `_player` references | 46 | 0 |
| Repeated movement ticks | No dedicated gate | 100,000 |
| 100,000-tick elapsed time | Not available | 428,407 usec final run |
| ObjectDB count change during repeated tick | Not available | 0 |

The temporary `Player.gd` increase is the explicit engine-adapter code and two reusable frame fields. This batch targets dependency direction and behavior protection; the approximately 700-line Player target remains a later phase goal.

## Tests

- PASS: `res://tests/scenes/player/player_movement_system_test.tscn`
  - Table-driven acceleration, deceleration, reverse-turn penalty, and PREPARE manual-input blocking.
  - Auto-navigation acceleration, speed multiplier/reset, arrival, completion, and position snap.
  - 100,000 repeated ticks reuse the same frame objects, keep ObjectDB count stable, and remain below the 2-second guard (157,169-428,407 usec observed).
  - Source contract rejects a `_player` reference in `PlayerMovementSystem`.
- PASS: `res://tests/scenes/player/player_auto_navigation_test.tscn`
  - Real Player scene traverses, snaps to the destination, and restores Player-owned navigation state.
- PASS: `res://tests/scenes/player/player_dash_movement_integration_test.tscn`
  - Dash temporarily disables and restores Player-owned movement while preserving displacement.
- PASS: `res://tests/scenes/weapon/test_weapon_smoke.tscn`
- PASS: `res://tests/scenes/player/player_active_skill_characterization_test.tscn`
- PASS: Godot 4.7 headless `--check-only --quit`, with output checked for parse/compile/load errors.
- PASS: 13-entry Worker manifest after Player-2B integration: PASS=13, FAIL=0, ERROR=0, shutdown diagnostics=19 retained as diagnostics, runtime errors=0.
- PASS: `git diff --check`.

## Known risks

- Player scene tests and the pre-existing weapon smoke emit the existing shutdown warning about four resources still in use after their explicit PASS and exit code 0.
- Final Player-2B validation used Godot 4.7. Earlier Player-1 notes used Godot 4.6.2.
- The first Godot import rewrote four tracked localization translations as format noise. Those changes were restored immediately and are not part of this batch.

### Player-3: dead damage-reaction wrapper cleanup

- Removed dead `Player.gd` elite-hit helper wrappers after repository search showed no live caller outside `PlayerDamageReactionSystem`.
- Kept incoming damage pipeline/profile ownership unchanged because moving that state would require a dedicated damage-reaction characterization gate.
- `Player.gd`: 1828 -> 1805 lines.

## Next recommended batch

Continue reducing `Player.gd` through another behavior-protected responsibility slice. Good candidates are camera/rest-area control or incoming elemental damage reaction, but add a focused gate before moving state ownership.
