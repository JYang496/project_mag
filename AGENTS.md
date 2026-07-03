# AGENTS.md

## Project Type

This is a Godot 4 project named `MagArena`.

Start from:

- `project.godot`
- `tests/README.md`
- the files directly related to the requested task

Do not scan the whole repository before identifying the task domain.

## Main Runtime Areas

Use these folders as the primary runtime/code areas:

- `autoload/`
- `World/`
- `Player/`
- `Combat/`
- `Board/`
- `Objects/`
- `UI/`
- `data/`

## Default Do-Not-Read Areas

Unless the user explicitly asks for them, avoid reading:

- `docs/prompt/**`
- `docs/reports/**`
- `docs/plans/**`
- `test-results/**`
- `.godot/**`
- `asset/**`
- generated HTML reports
- historical implementation prompts
- archived slimming handoff notes

These files are usually historical, generated, or asset-heavy and can waste context.

## Testing

Read `tests/README.md` before choosing test commands.

Prefer affected or focused tests instead of scanning or running every historical test.

Use the existing test infrastructure when possible:

```powershell
pwsh -NoProfile -File tests/infrastructure/select_affected_tests.ps1
pwsh -NoProfile -File tests/infrastructure/run_selected_tests.ps1 -BaseRef origin/master