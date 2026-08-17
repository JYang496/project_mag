# Task Module Progression Plan

Status: **Deferred — not part of the current release**  
Created: 2026-08-12

## Purpose

Revisit task modules as an optional risk-versus-reward layer. Deploying a task should create a meaningful strategic commitment, not become a mandatory self-replicating reward engine.

## Current implementation baseline

- `CellTaskModuleRuntime` owns inventory, deployment, the two-task active limit, persistence, and battle commitment.
- Modules are assigned to active board cells before battle.
- Starting a battle can discard unassigned temporary modules; replacing a deployed module also has an explicit loss path.
- Completing a task currently builds a guaranteed task-module reward plus a secondary task-module or cell-effect reward.
- Task presentation spans cell management, combat objective HUD, task completion feedback, and settlement reward summary.

Primary references:

- `autoload/CellTaskModuleRuntime.gd`
- `autoload/TaskRewardManager.gd`
- `data/task_modules/`
- `World/rest_area_route_flow.gd`
- `UI/scripts/cell_management_panel.gd`
- `UI/scripts/components/task_module_dialog_controller.gd`
- `Board/Cells/Modules/`

## Problems to solve later

1. One consumed task can currently return two durable resources, allowing the inventory to reproduce faster than it is consumed.
2. If task completion is sufficiently reliable, deploying the maximum number of tasks becomes the dominant answer rather than a contextual choice.
3. Task types become available with limited pacing, increasing the amount of information presented early in a run.
4. Task rewards and the normal post-battle draft are split across multiple settlement steps.
5. Replacement and discard rules are functional but can feel punitive unless expected value and risk are clearly communicated.

## Proposed direction

### Economy

- Use a neutral default loop: consuming one task returns one task-equivalent reward on successful completion.
- Put surplus value behind risk, rarity, optional performance conditions, or a player choice.
- Preferred reward model: choose one of two outcomes, such as a replacement task module or a cell effect/economy reward.
- Avoid guaranteed task-module replacement plus a guaranteed secondary durable reward.
- Define reward budgets per task rarity instead of balancing each task ad hoc.

### Progression and choice

- Stage task families by chapter or progression milestone.
- Keep the active limit at two unless telemetry demonstrates that an additional slot improves decisions rather than workload.
- Give each task a clear preview of objective, expected duration, failure condition, and reward class before deployment.
- Ensure some encounters legitimately favor zero or one deployed task.

### Presentation

- Present active tasks and their opportunity cost in the cell-management screen.
- Combine the task-result summary with the normal reward settlement where practical.
- Distinguish task completion, failure, replacement, and discard with unambiguous language.

## Implementation phases

1. Instrument acquisition, deployment, completion, failure, replacement, and discard rates.
2. Approve a task reward budget and inventory equilibrium target.
3. Change reward generation and save migration together.
4. Add chapter unlock rules and update the deployment UI.
5. Consolidate settlement presentation.
6. Add focused tests for inventory conservation, reward bounds, active limits, save/load, and battle transitions.

## Acceptance criteria

- Deploying two tasks is not the universal optimal choice.
- A normal completed task does not guarantee net inventory growth without an explicit bonus condition.
- Every task preview communicates risk and reward before commitment.
- Inventory, deployments, and active objectives survive save/load and scene transitions correctly.
- Task completion cannot duplicate rewards after repeated signals or settlement restoration.
- Automated tests cover replacement, discard, completion, failure, and capped-inventory behavior.

## Out of scope for this plan

- New combat contracts unrelated to task modules.
- General cell-effect redesign.
- Player level or mecha selection changes.
