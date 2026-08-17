# Future Development Plans

Status: **Deferred — not part of the current release**  
Created: 2026-08-12

This directory preserves scoped plans that should remain discoverable without being treated as current-version commitments. Do not include these items in the current release gate unless their status is explicitly changed by a later planning decision.

## Parked plans

| System | Plan | Resume when |
| --- | --- | --- |
| Task modules | [Task Module Progression Plan](task_module_progression_plan.md) | The core battle and settlement loop is stable and task-economy work is scheduled. |
| Mecha selection | [Mecha Selection Plan](mecha_selection_plan.md) | Multiple mechas are ready to be presented as supported player choices. |
| Player level and EXP | [Player Level and Experience Plan](player_level_experience_plan.md) | The intended role of run-level progression has been approved. |

## Reopening procedure

Before implementing one of these plans:

1. Re-audit the referenced runtime files because their interfaces may have changed.
2. Convert the selected plan into a version-scoped implementation issue or milestone.
3. Confirm save-data compatibility and define focused automated coverage.
4. Remove the `Deferred` status only after the feature enters an approved release scope.

These plans are independent. Reopening one does not automatically bring the other two into scope.
