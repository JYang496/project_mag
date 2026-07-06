# Player Movement System Investigation

Date: 2026-07-05

## Scope

This report audits the current player movement implementation in `MagArena`, based on the live code paths under `project.godot`, `tests/README.md`, `Player/`, `World/`, `Board/`, `autoload/`, and directly related `data/` resources.

The goal is to clarify:

- how the player currently moves;
- which systems read, modify, or depend on movement;
- where the current design limits advanced play;
- how to evolve movement into a deeper gameplay system without breaking existing runtime contracts.

## Executive Summary

The player is a `CharacterBody2D` controlled by `Player/Mechas/scripts/Player.gd`, with frame movement delegated to `PlayerMovementSystem`. The core movement path is strict and centralized:

1. `Player._physics_process()` gathers combat, heat, damage, loot, and movement updates.
2. `Player._tick_movement()` builds a `MovementFrameInput`.
3. `PlayerMovementSystem.tick()` computes the next velocity.
4. `Player.gd` assigns `velocity`.
5. `move_and_slide()` resolves physics movement.

Current movement already has some game feel features: acceleration, deceleration, turn penalty, input buffering, speed modifiers, auto-navigation, and movement-linked modules. However, the system is mostly a speed pipeline. It does not yet expose a rich movement-state contract such as dash state, perfect dodge, sprint window, drift, slide, collision outcomes, stamina, or movement-trigger events.

The most important optimization direction is to keep `PlayerMovementSystem` authoritative and move direct position/tween movement into explicit movement actions. The active Dash skill currently tweens `Player.global_position` directly, which bypasses `velocity`, `move_and_slide()`, terrain bounds, movement-state reporting, and any future movement-event hooks.

## Current Movement Implementation

### Core Runtime Path

The live movement loop is in `Player/Mechas/scripts/Player.gd`.

- `Player` extends `CharacterBody2D`.
- `_physics_process(delta)` calls `_tick_movement(delta)`, then calls `move_and_slide()`.
- `_tick_movement()` packages movement state into `MovementFrameInput`.
- `PlayerMovementSystem.tick()` writes into `MovementFrameResult`.
- `Player.gd` copies `result.next_velocity` back into `velocity`.

Key code paths:

- `Player/Mechas/scripts/Player.gd:236` starts the physics loop.
- `Player/Mechas/scripts/Player.gd:248` calls `_tick_movement(delta)`.
- `Player/Mechas/scripts/Player.gd:249` calls `move_and_slide()`.
- `Player/Mechas/scripts/Player.gd:1572` builds movement input.
- `Player/Mechas/scripts/Player.gd:1588` computes effective move speed from base speed, bonus speed, and multiplicative modifiers.
- `Player/Mechas/scripts/Player.gd:1594` delegates to `PlayerMovementSystem.tick()`.
- `Player/Mechas/scripts/Player.gd:1595` assigns the resulting velocity.

### Manual Input

Manual movement reads project input actions:

- `LEFT`
- `RIGHT`
- `UP`
- `DOWN`

These are mapped in `project.godot` to WASD and arrow keys. The input resolver lives in `Player._resolve_buffered_move_input()`:

- reads action strengths;
- builds a raw 2D vector;
- stores the last non-zero normalized direction;
- keeps the previous direction for `move_input_buffer_sec`.

This means the movement has a small input buffer, so short input gaps do not immediately drop the direction.

Important paths:

- `project.godot` `[input]` section maps movement actions.
- `Player/Mechas/scripts/Player.gd:1021` resolves buffered movement input.
- `Player/Mechas/scripts/Player.gd:1026` records fresh input.
- `Player/Mechas/scripts/Player.gd:1030` reuses buffered input briefly.

### Manual Movement Feel

`PlayerMovementSystem` implements a simple top-down acceleration model:

- if movement input exists, target velocity is normalized direction times effective move speed;
- if there is no input, velocity decelerates toward zero;
- if current velocity and target velocity point against each other, acceleration is reduced by `move_turn_penalty`;
- all transitions use `Vector2.move_toward()`.

Important paths:

- `Player/Mechas/scripts/player_movement_system.gd:24` handles manual movement.
- `Player/Mechas/scripts/player_movement_system.gd:28` creates target velocity.
- `Player/Mechas/scripts/player_movement_system.gd:30` detects hard turns.
- `Player/Mechas/scripts/player_movement_system.gd:34` selects acceleration or deceleration.
- `Player/Mechas/scripts/player_movement_system.gd:37` moves velocity toward the target.

Current exported tuning on `Player.gd`:

- `move_accel = 2800.0`
- `move_decel = 3200.0`
- `move_turn_penalty = 0.15`
- `move_input_buffer_sec = 0.1`

### Phase Gating

Manual movement is disabled during `PhaseManager.PREPARE`.

In `_tick_movement()`, manual input is only allowed when:

- auto-navigation is not active;
- `movement_enabled` is true;
- current phase is not `PREPARE`.

This creates a clear distinction:

- battle: direct player movement;
- prepare/rest: movement is mainly controlled by rest-area navigation.

Important path:

- `Player/Mechas/scripts/Player.gd:1575` checks auto-nav and movement state.
- `Player/Mechas/scripts/Player.gd:1577` disables manual input in `PREPARE`.

### Speed Formula

The current effective movement speed is:

```gdscript
(PlayerData.player_speed + PlayerData.player_bonus_speed) * get_total_move_speed_mul()
```

That is a two-layer model:

- additive layer: base speed plus bonus speed;
- multiplicative layer: status/module/aura movement multipliers.

Important paths:

- `autoload/PlayerData.gd:33` stores `player_speed`.
- `autoload/PlayerData.gd:38` stores `player_bonus_speed`.
- `Player/Mechas/scripts/Player.gd:1588` computes effective movement speed.
- `Player/Mechas/scripts/player_status_modifier_system.gd:18` applies multiplicative speed modifiers.
- `Player/Mechas/scripts/player_status_modifier_system.gd:31` multiplies all movement modifiers.

### Mecha Base Movement

Base speed comes from selected mecha data during spawn:

- `World/player_spawner.gd:54` loads `GlobalVariables.mech_data.player_speed[lvl_index]` into `PlayerData.player_speed`.

Current mecha data examples:

- Heavy Assault: `95` at all listed levels.
- Ranger: starts at `115`, then gradually decreases to `108`.
- Melee: `100`.
- Collector/Tank: starts at `120`, then `100`.
- Turret: `100`.

This means movement is already part of mecha identity, but the current spread is narrow and mostly passive.

## Auto-Navigation

Auto-navigation is a second movement mode handled by the same `PlayerMovementSystem`.

Entry points:

- `Player.start_auto_nav(dest)` disables manual movement and enables `moveto_enabled`.
- `Player.stop_auto_nav()` restores movement, clears destination, zeroes velocity, and resets auto-nav speed multiplier.
- `Player.configure_auto_nav_speed_mul(speed_mul)` forwards speed tuning into `PlayerMovementSystem`.

Important paths:

- `Player/Mechas/scripts/Player.gd:925` starts auto navigation.
- `Player/Mechas/scripts/Player.gd:932` stops auto navigation.
- `Player/Mechas/scripts/Player.gd:946` configures auto-nav speed multiplier.
- `Player/Mechas/scripts/player_movement_system.gd:44` updates auto navigation.
- `Player/Mechas/scripts/player_movement_system.gd:47` computes dynamic reach distance.
- `Player/Mechas/scripts/player_movement_system.gd:52` snaps position to destination when reached.

Rest area uses this path:

- `World/rest_area_auto_navigation.gd:7` starts player navigation.
- `World/rest_area_auto_navigation.gd:55` computes zone movement speed override.
- `World/rest_area.gd:561` calls `start_player_navigation(...)`.

This is a good existing foundation for scripted movement, but it currently only supports point-to-point travel.

## Direct Position Movement

The active player Dash skill moves the player differently from the core movement system.

`Player/Skills/dash.gd`:

- picks dash direction from current `velocity`;
- falls back to current input direction;
- temporarily disables normal movement;
- tweens `_player.global_position` to a target point;
- restores `movement_enabled`.

Important paths:

- `Player/Skills/dash.gd:3` sets `dash_distance`.
- `Player/Skills/dash.gd:4` sets `dash_duration`.
- `Player/Skills/dash.gd:27` reads start position.
- `Player/Skills/dash.gd:28` computes target position.
- `Player/Skills/dash.gd:34` tweens `Player.global_position` directly.
- `Player/Skills/dash.gd:43` uses current `velocity` as the preferred dash direction.

This is currently the biggest movement-system gap. It works as a visible dash, but because it bypasses `PlayerMovementSystem`, it is hard to integrate cleanly with:

- terrain projection;
- collision response;
- movement state;
- movement-triggered modules;
- dodge windows;
- dash attack chains;
- replay/test assertions;
- future camera/motion feedback.

## Movement-Related Systems

### Status Modifier System

`PlayerStatusModifierSystem` is the central owner of multiplicative movement speed modifiers.

It stores modifiers by `source_id`, clamps each multiplier between `0.05` and `10.0`, multiplies all active values, and emits player status hints.

Important paths:

- `Player/Mechas/scripts/player_status_modifier_system.gd:6` stores `_move_speed_mul_modifiers`.
- `Player/Mechas/scripts/player_status_modifier_system.gd:18` applies a speed multiplier.
- `Player/Mechas/scripts/player_status_modifier_system.gd:25` removes a speed multiplier.
- `Player/Mechas/scripts/player_status_modifier_system.gd:31` computes the total multiplier.
- `Player/Mechas/scripts/Player.gd:670` exposes `apply_move_speed_mul`.
- `Player/Mechas/scripts/Player.gd:676` exposes `remove_move_speed_mul`.

This is a strong contract and should remain the single public API for multiplicative speed effects.

### Board Cell Auras

Board cell modules already modify movement:

- speed boost aura applies a multiplier, default `1.2`;
- corrosion aura applies a multiplier, default `0.7`.

Important paths:

- `Board/Cells/Modules/cell_aura_speed_boost.gd:4` defines speed multiplier.
- `Board/Cells/Modules/cell_aura_speed_boost.gd:13` applies speed boost.
- `Board/Cells/Modules/cell_aura_speed_boost.gd:18` removes speed boost.
- `Board/Cells/Modules/cell_aura_corrosion.gd:4` defines corrosion slow.
- `Board/Cells/Modules/cell_aura_corrosion.gd:13` applies slow.
- `Board/Cells/Modules/cell_aura_corrosion.gd:18` removes slow.

These are the clearest existing hooks for movement-as-positioning gameplay.

### Objective Reward Bonus

`Board/Cells/Bonus/objective_reward_bonus.gd` can add temporary speed through `PlayerData.player_bonus_speed`.

Important paths:

- `Board/Cells/Bonus/objective_reward_bonus.gd:130` adds combat bonus speed.
- `Board/Cells/Bonus/objective_reward_bonus.gd:228` removes combat bonus speed.

This uses the additive layer, not the multiplier API. That is fine for a flat reward, but future effects should be explicit about additive versus multiplicative speed.

### Rest Area Navigation

Rest area uses auto-navigation plus speed override:

- target zone determines auto-nav destination;
- `zone_move_speed` is converted to an auto-nav speed multiplier;
- zone 4 hold can apply a temporary move-speed multiplier.

Important paths:

- `World/rest_area_auto_navigation.gd:11` configures zone speed before moving.
- `World/rest_area_auto_navigation.gd:36` applies zone 4 hold boost.
- `World/rest_area_auto_navigation.gd:44` clears zone 4 hold boost.
- `World/rest_area_auto_navigation.gd:64` applies auto-nav multiplier.

This path should be preserved as non-combat movement. It should not be mixed with combat dash semantics unless a future design explicitly wants rest-area traversal mechanics.

### Camera System

Movement and camera are adjacent but currently not strongly coupled.

`PlayerCameraSystem` handles:

- zoom context;
- prepare/rest camera ownership;
- rest-area camera movement;
- shake;
- offset reset.

The old movement lookahead is no longer active:

- `Player/Mechas/scripts/player_camera_system.gd:216` comments that camera no longer uses movement-based lookahead/inertia offset.

Important paths:

- `Player/Mechas/scripts/Player.gd:956` forwards rest-area camera move requests.
- `Player/Mechas/scripts/player_camera_system.gd:117` moves rest-area camera target.
- `Player/Mechas/scripts/player_camera_system.gd:253` moves camera toward rest-area target.

For advanced movement, camera feedback should be added deliberately: dash shake, dodge zoom pulse, landing impulse, or high-speed streaks should be driven by movement events instead of ad hoc camera calls.

### Damage Reactions and Elemental Effects

Incoming attacks can affect movement:

- elite/boss hits briefly slow the player;
- frost stacks apply a movement slow.

Important paths:

- `Player/Mechas/scripts/player_damage_reaction_system.gd:116` applies elite hit slow.
- `Player/Mechas/scripts/player_damage_reaction_system.gd:125` removes elite hit slow.
- `Player/Mechas/scripts/player_elemental_effect_system.gd:187` applies incoming frost slow from profile callback.
- `Player/Mechas/scripts/player_elemental_effect_system.gd:198` refreshes frost slow by stack count.
- `Player/Mechas/scripts/player_elemental_effect_system.gd:202` removes frost slow.

This is already compatible with the multiplier system and should remain there.

### Active Skills

Active skills interact with movement in three ways:

1. Direct position dash:
   - `Player/Skills/dash.gd` tweens `global_position`.

2. Bullet Time:
   - `Player/Skills/bullet_time.gd` changes `Engine.time_scale`;
   - adds `PlayerData.player_speed * speed_bonus_multiplier` to `PlayerData.player_bonus_speed`.

3. Heavy Assault Heat Lock:
   - `Player/Skills/heavy_assault_heat_lock.gd` locks shared heat;
   - passively applies a movement speed multiplier based on heat ratio proximity.

Important paths:

- `Player/Skills/skills.gd:44` handles active skill request.
- `Player/Skills/skills.gd:48` checks `can_activate()`.
- `Player/Skills/skills.gd:50` pays energy.
- `Player/Skills/skills.gd:51` activates skill.
- `Player/Skills/bullet_time.gd:26` adds speed bonus.
- `Player/Skills/heavy_assault_heat_lock.gd:42` applies heat-ratio movement multiplier.

### Weapon Modules

Several modules depend on movement or modify movement:

- `wmod_reload_move_boost.gd`: reload grants temporary movement speed.
- `wmod_momentum_haste.gd`: hits grant stacking movement speed and attack speed.
- `wmod_inertial_aim.gd`: reads player `velocity` to distinguish moving versus stationary.

Important paths:

- `Player/Weapons/Modules/wmod_reload_move_boost.gd:82` applies reload movement speed.
- `Player/Weapons/Modules/wmod_reload_move_boost.gd:89` removes reload movement speed.
- `Player/Weapons/Modules/wmod_momentum_haste.gd:46` applies stacking movement speed.
- `Player/Weapons/Modules/wmod_momentum_haste.gd:55` removes stacking movement speed.
- `Player/Weapons/Modules/wmod_inertial_aim.gd:25` reads `Player.velocity` and compares to `moving_threshold`.

The `Inertial Aim` module is important for future design: it already treats movement state as combat-relevant, but only through raw velocity length.

### Dash Blade Is Not Player Movement

`Dash Blade` has dash terminology, but it moves the weapon blade node, not the player.

Important paths:

- `Player/Weapons/Instances/dash_blade.gd:189` moves `blade_anchor.global_position` toward the enemy.
- `Player/Weapons/Instances/dash_blade.gd:233` records dash start distance.
- `Player/Weapons/Instances/dash_blade.gd:294` emits `dash_blade_long_dash_hit_triggered`.

This weapon is still movement-adjacent because it creates a "long dash hit" gameplay condition and supports close-quarters chains, but it should not be described as a player movement mode.

## Current Strengths

- Movement is mostly centralized through `PlayerMovementSystem`.
- The player uses `CharacterBody2D` and `move_and_slide()`, which is appropriate for controllable top-down movement.
- Speed modifiers have a clean source-id contract.
- Auto-navigation shares the same movement system instead of duplicating movement math.
- Movement is already tied to board terrain, modules, damage reactions, active skills, and mecha identity.
- Strict missing-system guards exist, which matches the project preference for single-path behavior over silent fallbacks.

## Current Weaknesses

### 1. Dash Bypasses the Movement System

The active dash skill tweens `global_position` directly. That makes dash visually simple, but mechanically disconnected.

Risks:

- no `move_and_slide()` collision resolution during dash;
- possible terrain/bounds bypass;
- modules reading `velocity` may not recognize dash movement correctly;
- no shared movement event such as `dash_started`, `dash_hit`, `dash_ended`;
- hard to build perfect dodge or collision-triggered effects.

### 2. Movement State Is Implicit

The code mostly exposes raw `velocity` and booleans such as `movement_enabled` and `moveto_enabled`.

Missing concepts:

- idle;
- accelerating;
- braking;
- turning;
- sprinting;
- dashing;
- slowed;
- immobilized;
- auto-moving;
- dodge window;
- post-dash recovery.

Without explicit states, advanced gameplay has to infer behavior from velocity and timers.

### 3. Movement Has No Event Bus

There is no obvious movement event contract for:

- movement started;
- movement stopped;
- hard turn;
- dash started;
- dash ended;
- dash passed near enemy;
- collision during dash;
- perfect dodge;
- terrain entered/exited.

Existing systems work by polling or directly applying modifiers. This is okay now, but movement-heavy gameplay will become fragile if every module polls `Player.velocity`.

### 4. Additive and Multiplicative Speed Are Mixed

The current formula supports both:

- `PlayerData.player_bonus_speed`;
- `PlayerStatusModifierSystem` multipliers.

The separation is useful, but not fully documented in code. For future mechanics, unclear use of additive versus multiplicative speed can create balance spikes.

### 5. Terrain Bounds Are Not Integrated Into Every Movement Mode

`Board/board_cell_generator.gd` has `project_point_to_player_traversable_area()`, and existing units can be clamped by board enforcement. However, the direct dash tween does not visibly call that projection each frame.

If advanced movement adds longer dashes, slides, pulls, or knockbacks, all forced movement should go through a shared path that can clamp or reject invalid destinations.

### 6. Camera Feedback Is Decoupled From Movement Events

Camera shake exists, but movement does not produce structured feedback events. This limits how polished advanced movement can feel.

## Optimization Plan

### Phase 1: Make Movement State Explicit

Add a small typed movement state model owned by `PlayerMovementSystem` or a sibling movement runtime.

Recommended states:

- `IDLE`
- `MANUAL_MOVE`
- `BRAKE`
- `TURN`
- `AUTO_NAV`
- `DASH`
- `FORCED_MOVE`
- `IMMOBILIZED`

Expose a read-only status dictionary or typed object through `Player`, for example:

```gdscript
func get_movement_status() -> Dictionary:
    return _movement_system.get_status()
```

Keep compatibility with existing fields:

- `velocity`
- `movement_enabled`
- `moveto_enabled`
- `start_auto_nav()`
- `stop_auto_nav()`

This allows existing code to keep working while new modules can use stable movement semantics.

### Phase 2: Move Dash Into the Movement System

Replace direct `global_position` tweening in `Player/Skills/dash.gd` with a movement action request:

```gdscript
player.request_dash(direction, distance, duration, source_id)
```

The movement system should then:

- set dash state;
- compute dash velocity or fixed displacement;
- call movement through the normal frame result;
- clamp to traversable board area;
- emit start/end events;
- optionally expose invulnerability or dodge windows.

This is the highest-priority implementation step if the target is advanced movement gameplay.

### Phase 3: Add Movement Events

Add signals on `Player` or a dedicated movement signal relay:

- `movement_state_changed(previous, current)`
- `movement_action_started(action_id, data)`
- `movement_action_finished(action_id, data)`
- `movement_hard_turn(direction, speed_ratio)`
- `dash_started(direction, distance, duration)`
- `dash_finished(start_position, end_position, interrupted)`
- `perfect_dodge_triggered(source_attack)`

Consumers:

- camera feedback;
- modules;
- weapon passives;
- UI status hints;
- enemy AI reactions;
- future achievements/tasks.

This avoids future modules polling `velocity` every physics frame.

### Phase 4: Create Advanced Movement Mechanics

Recommended direction: build advanced movement around deliberate risk/reward, not just faster speed.

#### Option A: Tactical Dash

Core rules:

- dash has energy/cooldown cost;
- dash has a short startup and recovery;
- dash grants a very short dodge window;
- dashing through enemy threat zones can trigger "perfect dodge";
- perfect dodge rewards energy, reload acceleration, or temporary fire-rate boost.

Why it fits current code:

- active skills already use energy and cooldown;
- damage pipeline already knows incoming attacks;
- speed modifiers and module hooks already exist;
- close-quarters builds already care about movement.

#### Option B: Momentum Meter

Core rules:

- continuous movement builds momentum;
- sharp turns or stopping spends/breaks momentum;
- high momentum grants small move speed, reload speed, or dodge distance;
- some weapons/modules consume momentum for stronger effects.

Why it fits current code:

- `PlayerMovementSystem` already detects hard turns.
- `wmod_momentum_haste` already has a movement fantasy but is hit-driven.
- `wmod_inertial_aim` already distinguishes moving and stationary.

#### Option C: Terrain Mastery

Core rules:

- speed cells, corrosion cells, and future terrain zones affect more than speed;
- entering/leaving terrain can trigger movement choices;
- examples: slide on speed cells, dash cooldown refund on corrosion escape, shield while standing still on defense cells.

Why it fits current code:

- board cell aura modules already apply movement multipliers.
- rest area and board systems already know player cell position.

#### Option D: Close-Quarters Movement Loop

Core rules:

- player dash and Dash Blade long-hit become separate but synergistic mechanics;
- player dash marks a "commitment window";
- Dash Blade or Chainsaw hits during that window trigger close-chain bonuses;
- missed dash creates recovery risk.

Why it fits current code:

- `Dash Blade` already has long-distance hit semantics.
- `close_quarters_chain_rules.gd` already handles close-combat slow/vulnerability/final damage.

## Recommended Implementation Order

1. Add movement status reporting without changing behavior.
   - Keep it read-only and testable.
   - Report current mode, speed ratio, input direction, and action state.

2. Refactor player Dash skill to request a dash action from the movement system.
   - Preserve current visible defaults: distance `220`, duration `0.12`, cooldown from `PlayerData.dash_cooldown`.
   - Maintain energy/cooldown behavior in `Skills.gd`.

3. Add board projection for dash end position.
   - Use `Board.project_point_to_player_traversable_area()` when available.
   - Decide whether dash should stop at walls or slide along bounds.

4. Add movement events.
   - Start with dash start/end and hard-turn events.
   - Avoid broad event spam; emit only semantically useful transitions.

5. Convert `wmod_inertial_aim` to use movement status instead of raw velocity.
   - This creates the first consumer and validates the API.

6. Add one advanced movement mechanic.
   - Recommended first mechanic: perfect dodge during dash.
   - It is easy to understand, creates skill expression, and connects movement to survival/combat.

7. Add focused tests.
   - Current `tests/README.md` says there are no active registered scene tests.
   - For implementation, add a scene-backed movement test under `tests/scenes/player/` and a runner under `tests/headless/player/` only when making behavior permanent.

## Test and Verification Strategy

For this report-only change:

- use Godot `--check-only` as a syntax/resource gate if desired;
- no runtime behavior changed;
- no scene-backed movement test exists yet.

For future implementation:

1. Unit-like headless scene for `PlayerMovementSystem`.
   - manual acceleration;
   - deceleration;
   - hard-turn penalty;
   - auto-nav completion;
   - dash action completion.

2. Runtime player scene test.
   - instantiate a player;
   - simulate movement input or call movement API;
   - assert status transitions and final position.

3. Integration test for movement consumers.
   - verify `wmod_inertial_aim` sees moving/stationary through the new status API;
   - verify speed multipliers stack and clear by source id.

4. Board-boundary test for forced movement.
   - dash toward invalid area;
   - assert final position is projected or interrupted according to the chosen rule.

## Concrete Design Recommendation

The best direction is to turn player movement into a "movement action system" rather than only a speed calculator.

Keep the current movement foundation:

- `PlayerMovementSystem` remains authoritative;
- `Player.gd` remains the coordinator;
- `PlayerStatusModifierSystem` remains the speed modifier API;
- existing public methods remain compatible.

Add the new layer:

- explicit movement states;
- action requests such as dash/forced move;
- movement events;
- terrain-aware endpoint handling;
- optional advanced mechanics such as perfect dodge or momentum.

This route uses the codebase's existing architecture instead of replacing it. It also gives designers more knobs: distance, duration, startup, recovery, invulnerability window, terrain interactions, momentum gain/loss, and module triggers.

## Suggested First Playable Advanced Mechanic

Implement "Perfect Dash" as the first advanced movement feature.

Draft rule:

- Press active skill to dash in movement direction.
- During the first part of the dash, the player has a short perfect-dodge window.
- If an enemy attack would hit during that window, the player avoids it and triggers a reward:
  - small energy refund;
  - brief move-speed or attack-speed buff;
  - optional camera pulse.
- If no dodge occurs, dash is still useful for repositioning but has recovery.

Why this should be first:

- it makes movement skill-based;
- it does not require redesigning all weapons;
- it works with existing active skill energy/cooldown;
- it gives future modules a clean hook;
- it can be tested with deterministic movement/damage probes.

## Files Most Relevant For Future Work

- `Player/Mechas/scripts/Player.gd`
- `Player/Mechas/scripts/player_movement_system.gd`
- `Player/Mechas/scripts/movement_frame_input.gd`
- `Player/Mechas/scripts/movement_frame_result.gd`
- `Player/Mechas/scripts/player_status_modifier_system.gd`
- `Player/Skills/dash.gd`
- `Player/Skills/skills.gd`
- `Player/Mechas/scripts/skill_energy_state.gd`
- `World/rest_area_auto_navigation.gd`
- `World/rest_area.gd`
- `World/board_cell_generator.gd`
- `Board/Cells/Modules/cell_aura_speed_boost.gd`
- `Board/Cells/Modules/cell_aura_corrosion.gd`
- `Player/Weapons/Modules/wmod_inertial_aim.gd`
- `Player/Weapons/Modules/wmod_momentum_haste.gd`
- `Player/Weapons/Modules/wmod_reload_move_boost.gd`
- `Player/Weapons/Instances/dash_blade.gd`
- `Player/Weapons/close_quarters_chain_rules.gd`
