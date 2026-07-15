# Documentation Index

Last reviewed: 2026-07-15.

## Current sources of truth

- [`../Overview.md`](../Overview.md): current gameplay and runtime overview.
- [`design/`](design/): durable design contracts.
- [`plans/battle_contract_combat_port.md`](plans/battle_contract_combat_port.md): stable battle-contract integration boundary.
- [`plans/hybrid_2d_3d_2_5d_architecture.md`](plans/hybrid_2d_3d_2_5d_architecture.md): current 2D-authoritative/3D-ground architecture reference.
- [`../tests/README.md`](../tests/README.md): current test layout and validation commands.

## Historical and snapshot material

- `plans/battle_contract_codex_prompts/`: completed implementation prompts; preserve for traceability, not as outstanding work.
- `reports/`: dated or generated snapshots, not live specifications.
- `player_movement_system_report.md`: dated investigation and recommendations.
- `module prompt.txt`: reusable operational template; generated HTML is not a source-of-truth document.
- `design/cell_task_combat_hud_solution.md` and `design/cell_task_module_design.md`: legacy files containing invalid UTF-8 bytes. Do not use them as current contracts; consult `TaskObjectiveHudPresenter`, `CellTaskModuleRuntime`, `TaskRewardManager`, and `Board/Cells/Modules/` instead.

## Placement rules

- Put durable behavior and architecture contracts in `design/` or `plans/`.
- Put dated investigations and generated artifacts in `reports/`.
- Do not reference nonexistent `audits/`, `prompt/`, or `reports/dps/` directories unless deliberately created.
- When implementation supersedes a plan, add a status banner or keep it in a clearly marked historical collection.
