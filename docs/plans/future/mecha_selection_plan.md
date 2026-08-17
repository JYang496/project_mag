# Mecha Selection Plan

Status: **Deferred — not part of the current release**  
Created: 2026-08-12

## Purpose

Restore mecha choice as a clear player-facing start-of-run decision, with reliable previews and save semantics for every supported mecha.

## Current implementation baseline

- Multiple mecha definitions exist under `data/mechas/`.
- `PlayerData.select_mecha_id` stores the active selection and currently defaults to ID `1`.
- `World/mecha_select.gd` and `World/mecha_container.gd` contain legacy or disconnected selection presentation logic.
- The current start menu does not expose a supported mecha-selection step.
- New-game initialization preserves the existing selected ID, and save data stores the selected mecha.
- `World/player_spawner.gd` loads the selected mecha definition and its autosave data.

Primary references:

- `data/mechas/`
- `data/MechaDefinition.gd`
- `autoload/PlayerData.gd`
- `autoload/SaveManager.gd`
- `World/start_menu.gd`
- `World/new_game_btn.gd`
- `World/mecha_select.gd`
- `World/mecha_container.gd`
- `World/player_spawner.gd`

## Decisions required before implementation

1. Is mecha choice made for each new run, or is it an account-level last-used preference?
2. Does each mecha keep separate level/loadout progress, or does a run share progression across mechas?
3. Are all mechas available immediately, or are some unlocked through bounded milestones?
4. Which differences are core identity: base attributes, starting weapon, skill, heat behavior, or all of them?
5. What happens when loading older saves with an invalid or removed mecha ID?

## Proposed direction

- Add a dedicated selection step after choosing New Game and before run state is reset.
- Require explicit confirmation rather than silently retaining a previous selection.
- Show role, core ability, starting weapon, meaningful strengths, and one clear weakness for every mecha.
- Keep numerical comparisons compact; highlight playstyle rather than exposing every internal field.
- Validate the selected definition before saving or spawning, with a deterministic supported fallback.
- Treat Continue as loading the run's saved mecha without presenting a new choice.
- If unlocks are used, make locked mechas visible with clear requirements and no permanent percentage-stat purchases.

## Implementation phases

1. Approve selection timing, unlock policy, and progression ownership.
2. Define a stable mecha ID contract and save migration fallback.
3. Rebuild or reconnect the selection UI to the current start-menu flow.
4. Add preview data and localization for all supported mechas.
5. Validate spawning, starting weapons, skills, stats, and save/load for each mecha.
6. Add controller/keyboard/mouse navigation and focused automated tests.

## Acceptance criteria

- New Game cannot silently start with an unexplained stale selection.
- Continue restores the mecha associated with that saved run.
- Every selectable mecha has a truthful role and ability preview.
- Invalid legacy IDs fall back safely and are repaired on the next save.
- Selection is fully usable without a mouse.
- Each supported mecha passes spawn, default weapon, ability, death/restart, and save/load tests.

## Out of scope for this plan

- Creating additional mechas.
- Full character customization or cosmetics.
- Player level and EXP redesign, except for deciding whether progression is shared or per-mecha.
