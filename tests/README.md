# Test Directory

This folder is the canonical home for project test, probe, benchmark, fixture, and showcase resources.

## Layout

```text
tests/
  fixtures/      Shared test-only scenes and scripts.
  scenes/        Scene-backed regression tests grouped by domain.
  headless/      Headless runner scripts grouped by domain.
  benchmarks/    Measurement and balance tooling.
  probes/        Focused probes and smoke checks.
  showcases/     Manual or visual review scenes.
  archive/       Preserved legacy tools pending deletion review.
```

## Conventions

- Put new automated regression scenes under `tests/scenes/<domain>/`.
- Put their runner scripts under `tests/headless/<domain>/` unless the scene script is intentionally self-contained.
- Put shared dummy resources under `tests/fixtures/<domain>/`.
- Put one-off probes under `tests/probes/<domain>/` and promote them to `tests/scenes/<domain>/` if they become permanent regression gates.
- Put manual review scenes under `tests/showcases/<domain>/`.
- Keep `.gd.uid` sidecars with their matching `.gd` files.
- Use `res://tests/...` paths for test-only resources.

## Validation

Prefer Godot MCP for feature, behavior, UI, reward, combat, route, and spawn tests:

```text
get_project_info(projectPath="D:\Godot Projects\project_mag")
run_project(projectPath="D:\Godot Projects\project_mag", scene="res://tests/scenes/weapon/weapon_numeric_module_test.tscn")
get_debug_output()
stop_project()
```

Read the debug output before calling a run successful. Check for explicit `PASS`, `FAIL`, `ERROR`, or assertion logs; do not trust startup alone.

Use scene-backed tests as the MCP entrypoint:

```text
res://tests/scenes/<domain>/<test>.tscn
```

`tests/headless/<domain>/*.gd` files are runner scripts. Prefer an existing `tests/scenes/<domain>/*.tscn` scene for MCP runs, add a scene-backed test when the behavior should become a permanent regression gate, or use shell `--script` only when a runner script is the intentional entrypoint.

Use the shell Godot command as the repo-wide syntax/resource gate, or when MCP cannot cover a runner-script validation:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit
```

Run an intentional headless runner script with shell only when needed:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/headless/weapon/run_weapon_numeric_module_test_headless.gd
```
