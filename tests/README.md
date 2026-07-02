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

## Affected-test selection

The pilot manifest at `tests/infrastructure/test_manifest.json` defines the registration contract for active tests. Each entry must provide:

- a stable `id`;
- `entry_type` (`scene` or `script`) and a `res://` entry path;
- an owning `domain` and explicit `dependency_domains`;
- `parallel_safe` and `writes_user_data` flags;
- a positive `timeout_seconds`.

The current catalog deliberately contains representative gates only and has `catalog_status: "pilot"`. It does not replace existing manual full-suite gates. Register the remaining active tests before treating manifest `full` mode as the repository's complete test suite.

Use the selector from the repository root. Without `-ChangedPath`, it reads unstaged, staged, untracked, and optional base-ref changes:

```powershell
pwsh -NoProfile -File tests/infrastructure/select_affected_tests.ps1
pwsh -NoProfile -File tests/infrastructure/select_affected_tests.ps1 -BaseRef origin/master -Json
```

For diagnostics or automation, paths and explicit test additions can be supplied directly:

```powershell
pwsh -NoProfile -File tests/infrastructure/select_affected_tests.ps1 `
  -ChangedPath 'UI/scripts/controllers/example.gd','Player/Weapons/example.gd' `
  -IncludeTest 'world.threaded_world_load'
```

Every result includes a selection mode and reasons. Known source domains select tests owned by or depending on those domains. The selector fails closed to all registered tests for:

- `project.godot`, Autoload, core facade, manifest, mapping, or selector changes;
- uncertain dependency mappings such as broad `data/`, `asset/`, `Shaders/`, or `Objects/` changes;
- unmapped production or test paths;
- wildcard test dependencies or mapped domains with no registered coverage.

A genuinely empty or documentation-only change set returns `none` with an explicit reason. Unknown explicit test IDs are errors.

Run the selector contract tests with:

```powershell
pwsh -NoProfile -File tests/infrastructure/tests/test_selection_test.ps1
```

When adding a test, add one manifest entry and update `source_domain_map.json` only when a new source location has a defensible domain mapping. If ownership or dependencies are unclear, retain a full fallback instead of guessing.

## Limited-parallel Worker

Run registered tests with independent Godot processes:

```powershell
pwsh -NoProfile -File tests/infrastructure/run_test_workers.ps1 `
  -TestId 'cell.effect_runtime','weapon.numeric_module'
```

Omit `-TestId` to run every entry in the selected manifest. The default concurrency is two; use `-Jobs` to override it deliberately. `-GodotPath` overrides executable discovery, and `GODOT_PATH` is used when the parameter is omitted.

Select and run affected tests in one command:

```powershell
pwsh -NoProfile -File tests/infrastructure/run_selected_tests.ps1 `
  -ChangedPath UI/scripts/UI.gd `
  -GodotPath 'C:\Program Files (x86)\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64_console.exe'
```

The wrapper runs Godot `--check-only` first, scans the output for runtime/script errors, then invokes isolated Workers for the selected manifest entries. Use `-BaseRef` for Git comparison, `-IncludeTest` to append explicit ids, `-OutputRoot` to retain artifacts in a stable directory, and `-Json` for machine-readable output.

The Worker applies the manifest contract conservatively:

- only entries with `parallel_safe: true` and `writes_user_data: false` can overlap;
- entries that are not parallel-safe or write `user://` run exclusively;
- every process receives unique `GODOT_USER_HOME`, `APPDATA`, and `LOCALAPPDATA` roots;
- `timeout_seconds` is enforced per process by terminating its process tree;
- explicit runtime error output or a timeout is `ERROR`, a failure marker or nonzero exit is `FAIL`, and exit zero still requires an explicit `PASS` marker;
- known Godot shutdown leak diagnostics after an explicit `PASS` are retained as diagnostics instead of being promoted to runtime `ERROR`;
- the CLI exits `0` when all tests pass, `1` for test failures, and `2` for infrastructure/error outcomes.

Each run retains `stdout.log`, `stderr.log`, `result.json`, and a top-level `summary.json` under the printed temporary run directory. Failed and errored entries print captured output and an exact PowerShell reproduction command. Use `-OutputRoot` when a stable artifact location is required and `-Json` for machine-readable output.

Validate the parser, real-process outcomes, timeout termination, scheduling, retained logs, and Windows `user://` isolation with:

```powershell
pwsh -NoProfile -File tests/infrastructure/tests/test_worker_test.ps1
pwsh -NoProfile -File tests/infrastructure/tests/test_selected_runner_test.ps1
```

The intentional failure and timeout fixtures are infrastructure self-test inputs only; they are not registered in the active pilot manifest.
