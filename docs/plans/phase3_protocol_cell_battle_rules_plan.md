# Phase 3: Protocol and Cell Battle-Rule Plan

## Status

- Document type: implementation archive
- Scope: Phase 3 only
- Depends on: Phase 1 unified build tags and synergy evaluation
- Intentionally not implemented by this document

## Objective

Make protocols and board cells change how a battle is played, rather than only
changing rewards, descriptions, or flat numeric values. Protocols and cells
must share a typed rule-modifier contract, expose their build relationships
through the Phase 1 tag vocabulary, clean up symmetrically at every lifecycle
boundary, and remain measurable in deterministic performance scenarios.

## Product Requirements

Every Phase 3 vertical slice must satisfy all of the following:

1. A player must make at least one decision that is absent from an ordinary
   battle.
2. The protocol must remain completable without a recommended build, while a
   matching build changes the viable strategy rather than merely adding a flat
   reward multiplier.
3. At least one cell changes state during combat and communicates that state in
   the world and HUD.
4. The selection card must state the changed rule, primary risk, potential
   benefit, relevant build tags, and special cell behavior.
5. Death, rollback, battle completion, scene exit, and a second battle must not
   retain modifiers, callbacks, timers, collision changes, or UI state.
6. The same seeded workload must be runnable with the protocol enabled and
   disabled for performance comparison.

## Architecture

### Typed battle-rule modifiers

Introduce a typed modifier contract instead of adding further unvalidated keys
to `BattleContractDefinition.parameters`.

Suggested API:

```gdscript
class_name BattleRuleModifier
extends Resource

func install(context: BattleRuleContext) -> void:
    pass

func uninstall(context: BattleRuleContext) -> void:
    pass

func describe(snapshot: Dictionary) -> Dictionary:
    return {}

func get_synergy_tags() -> Array[StringName]:
    return []
```

`install()` and `uninstall()` must be idempotent. Setup and teardown must be
symmetrical. A modifier must not search globally for arbitrary UI or runtime
nodes when the required dependency can be supplied through the context.

### Battle rule context

`BattleRuleContext` is the narrow dependency boundary for modifiers. It should
provide explicit ports for:

- spawn planning and spawn-budget adjustments;
- enemy stat and behavior overlays;
- player heat, movement, weapon, and damage overlays;
- board-cell activation and ownership;
- reward and economy adjustments;
- objective progress and completion;
- presentation events;
- counters required by deterministic tests and benchmarks.

Do not make it a second `GlobalVariables`. Each port should expose only the
operations needed by rule modifiers, and modifier removal must use a stable
source ID so that only its own overlays are removed.

### Rule scopes

Use one modifier interface with explicit scopes:

| Source | Scope | Lifetime |
|---|---|---|
| Protocol | Whole battle | battle start to settlement/death/exit |
| Cell effect | cell area or linked cells | activation to loss/expiry/exit |
| Cell objective | objective participants | objective start to completion/failure |
| Protocol-cell interaction | named source pair | while both source conditions hold |

### State ownership

- `BattleContractManager` owns the selected definition, not the detailed combat
  mutation state.
- Contract runtime owns modifier installation and removal for the current
  battle.
- Each cell owns its local activation/ownership state.
- A battle-rule coordinator owns active source IDs and guarantees teardown.
- HUD presenters consume immutable presentation snapshots or events; they do
  not decide gameplay state.

## Cell State Model

Every interactive Phase 3 cell uses the following semantic states:

```text
INACTIVE -> AVAILABLE -> PLAYER_CONTROLLED
                 |              |
                 v              v
             CONTESTED <----- DISRUPTED
                 |
                 v
              EXPIRED
```

Not every cell must use every transition, but each visible state must have one
meaning and one authoritative owner. Readiness, progress, warning, selection,
and decoration may not reuse the same visual cue.

Required presentation channels:

- ground shape or boundary: area and ownership;
- fill/progress: capture, charge, or remaining duration;
- icon: rule category;
- color plus shape/text: friendly, contested, disrupted, expired;
- compact HUD entry: current obligation and consequence;
- transition animation: explain state change without delaying control.

## Vertical Slice A: Thermal Lockdown

### Changed rules

- Enemy density or reinforcement rate increases.
- Passive heat dissipation is reduced during combat.
- Weapons receive a damage or effect bonus above a configured heat threshold.
- Cooling cells appear and provide accelerated dissipation while controlled.
- Selected enemies may disrupt cooling cells, creating an explicit target
  priority.

### Player decisions

- Remain at high heat for damage or rotate to a cooling cell before lockout.
- Defend a cooling cell or abandon it to maintain damage uptime elsewhere.
- Choose between a heat-synergy reward and a neutral safety option.

### Tags

`heat`, `on_overheat`, `area`, `objective`, `defense`

### Required tests

- threshold bonus begins and ends at exact boundary values;
- cooling applies only in the valid cell state and area;
- disrupted cell removes cooling immediately;
- death, settlement, rollback, and second battle restore heat behavior;
- player without heat-tagged equipment can still finish the objective;
- seeded 80/160/240-enemy benchmarks with protocol on and off.

## Vertical Slice B: Migrating Cryo Zone

### Changed rules

- A safe combat zone migrates between selected cells on a deterministic timer.
- Outside the zone, movement or weapon recovery is penalized.
- Freeze-compatible effects extend a zone window, slow migration pressure, or
  reduce the external penalty.
- Enemy composition or approach vectors change when the zone moves.

### Player decisions

- Move before the zone transition or remain temporarily to finish a priority
  target.
- Spend freeze effects on crowd control or on maintaining positional safety.
- Choose a route that balances cell ownership and enemy concentration.

### Tags

`freeze`, `movement`, `terrain`, `area`, `control`

### Required tests

- deterministic zone sequence for a fixed seed;
- boundary and transition-frame behavior;
- outside penalty never stacks through duplicate callbacks;
- freeze interaction has a configured cap;
- scene exit and second battle clear all zone state and HUD;
- benchmarks compare stationary and migrating high-density workloads.

## Vertical Slice C: Fire-Supply Chain

### Changed rules

- A portion of kill rewards becomes supply objects or objective credit.
- Credit is secured only near a controlled supply cell or through a delivery
  action.
- Special enemies can disrupt the supply cell.
- Economy, summon, area, or defense builds receive distinct ways to protect or
  deliver supplies without making any one tag mandatory.

### Player decisions

- Clear enemies, defend the supply cell, or collect/deliver unsecured value.
- Risk staying near a dense objective or accept lower secured rewards.
- Kill a disruptive special enemy or finish a nearly complete delivery.

### Tags

`economy`, `on_kill`, `objective`, `defense`, `area`

### Required tests

- kill budget and secured value conserve total configured reward;
- credit is granted only under valid ownership/delivery conditions;
- disruption pauses or changes securing without duplicating rewards;
- unclaimed objects clean up at all battle exits;
- rollback restores the correct pre-battle economy state;
- bulk-kill benchmark records object creation, pooling, and cleanup spikes.

## Delivery Order

1. Add `BattleRuleModifier`, `BattleRuleContext`, and a coordinator with no
   gameplay changes.
2. Add lifecycle tests proving repeated install/uninstall is safe.
3. Implement Thermal Lockdown end to end.
4. Audit the abstraction after the first slice; change the contract before
   copying it.
5. Implement Migrating Cryo Zone.
6. Implement Fire-Supply Chain.
7. Convert additional existing protocols only after the three slices establish
   stable patterns.

## UI Contract

Protocol selection cards must expose structured fields rather than infer them
from prose:

- rule change: one concise sentence;
- primary risk: one concise sentence;
- potential benefit: one concise sentence;
- up to three primary build tags;
- synergy status and reason from Phase 1;
- special cell type and state summary;
- advanced detail sections for exact values and edge rules.

The combat HUD should show the current obligation and immediate consequence,
not repeat the full selection-card text.

## Performance Contract

Each slice records:

- revision and changed files;
- seed, enemy count and composition;
- density and spawn arrangement;
- active modifier and active cell states;
- warm-up and sample durations;
- average, p95, p99, and maximum frame time;
- relevant query calls, candidates, collisions, allocations, spawned VFX,
  created objectives, and freed nodes.

Compare identical enabled/disabled workloads. Compilation or a passing semantic
test is not evidence that the performance requirement is satisfied.

## Regression Matrix

Every slice covers:

| Boundary | Expected proof |
|---|---|
| First battle start | modifiers install once and first-frame behavior is valid |
| Active combat | rule and UI snapshots agree |
| Objective success | rewards commit exactly once |
| Objective failure | failure rule and cleanup execute exactly once |
| Player death | overlays, cells, UI, timers, and signals clear |
| Settlement | no battle-only rule remains |
| Rollback/load | pre-battle state is restored without duplicate sources |
| Second battle | behavior matches a clean first battle |
| Scene exit | shutdown diagnostics and transient groups are clean |

## Definition of Done

Phase 3 is complete only when all three vertical slices are implemented,
structurally tested, performance-compared at representative scales, visually
reviewed with explicit graphical permission, and verified across a second
battle. A typed modifier framework without changed player decisions does not
complete the phase.
