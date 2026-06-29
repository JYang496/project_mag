Project: project_mag
Task: Sequential project-structure cleanup prompt pack.

Use these prompts in order. They are written for the current local environment:

- Project root: `D:\Godot Projects\project_mag`
- Shell: PowerShell on Windows
- Godot validation executable: `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- The worktree is expected to be dirty. Do not revert or overwrite unrelated changes.
- Godot MCP can be used for inspection when useful, but shell validation with the executable above is the baseline.

Execution order:

1. `project_structure_sequence_01_docs_report_paths.txt`
2. `project_structure_sequence_02_ui_autoload_path_settle.txt`
3. `project_structure_sequence_03_deprecated_weapon_cleanup.txt`
4. `project_structure_sequence_04_utility_boundary_audit.txt`
5. `project_structure_sequence_05_world_test_reorg_next_step.txt`
6. `project_structure_sequence_06_final_validation.txt`

Current known state when this pack was written:

- `docs/README.md`, `docs/audits/`, `docs/design/`, and `docs/reports/` already exist.
- `docs/reports/dps/` already contains moved DPS report HTML snapshots.
- Some benchmark configs and scripts still point at `res://docs/dps_reports`.
- `UI/scenes/components/enemy_hp_bar.tscn` exists and `Npc/components/npc_damage_feedback_controller.gd` points to it.
- `project.godot` points `DisplaySettings` at `res://autoload/DisplaySettings.gd`.
- `Player/Weapons/Deprecated/` appears empty in the current file inventory, but deleted deprecated scenes are still visible in `git status`.
- `legacy test folder ` is still intentionally unmoved. Use the existing plan at `docs/audits/world_test_reorganization_plan.md`.

General rules for every phase:

- Start with `git status --short`.
- Treat pre-existing dirty files as user or previous-worker changes unless they are directly in the phase scope.
- Keep each phase narrow. Do not opportunistically reorganize adjacent systems.
- Prefer `rg` for searches.
- Use `apply_patch` or normal editor operations for text edits; do not use destructive git commands.
- When a phase touches `.gd`, `.tscn`, `.tres`, `.uid`, or `project.godot`, run:
  `& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit`

Final reporting requirement for every phase:

- List files changed.
- List old-path references that remain, if any, and explain why.
- Report validation commands and results.
- Call out unrelated dirty files instead of modifying them.
