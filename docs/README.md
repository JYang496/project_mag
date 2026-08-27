# Documentation Index

Last reviewed: 2026-08-17.

## Current sources of truth

- [`../Overview.md`](../Overview.md): current gameplay and runtime overview.
- [`design/`](design/): durable design contracts.
- [`design/weapon_trigger_contract.md`](design/weapon_trigger_contract.md): canonical eight-trigger weapon-skill contract and current weapon assignments.
- [`plans/battle_contract_combat_port.md`](plans/battle_contract_combat_port.md): stable battle-contract integration boundary.
- [`plans/hybrid_2d_3d_2_5d_architecture.md`](plans/hybrid_2d_3d_2_5d_architecture.md): current 2D-authoritative/3D-ground architecture reference.
- [`../tests/README.md`](../tests/README.md): current test layout and validation commands.

## Historical and snapshot material

- `plans/battle_contract_codex_prompts/`: completed implementation prompts; preserve for traceability, not as outstanding work.
- `reports/`: dated or generated snapshots, not live specifications.
- `player_movement_system_report.md`: dated investigation and recommendations.
- `module prompt.txt`: reusable operational template; generated HTML is not a source-of-truth document.
- `design/cell_task_combat_hud_solution.md` and `design/cell_task_module_design.md`: legacy files containing invalid UTF-8 bytes. Do not use them as current contracts; consult `TaskObjectiveHudPresenter`, `CellTaskModuleRuntime`, `TaskRewardManager`, and `Board/Cells/Modules/` instead.

## Deferred future plans

- [`plans/future/`](plans/future/): features deliberately excluded from the current release scope and preserved for later development.
- [`plans/future/task_module_progression_plan.md`](plans/future/task_module_progression_plan.md): task-module economy, deployment, and reward-loop revision.
- [`plans/future/mecha_selection_plan.md`](plans/future/mecha_selection_plan.md): player-facing mecha selection and per-mecha persistence.
- [`plans/future/player_level_experience_plan.md`](plans/future/player_level_experience_plan.md): player level, experience income, runtime stat application, and feedback.

## Placement rules

- Put durable behavior and architecture contracts in `design/` or `plans/`.
- Put dated investigations and generated artifacts in `reports/`.
- Do not reference nonexistent `audits/`, `prompt/`, or `reports/dps/` directories unless deliberately created.
- When implementation supersedes a plan, add a status banner or keep it in a clearly marked historical collection.
