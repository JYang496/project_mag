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

Use the project baseline Godot executable:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit
```

Run a specific scene-backed test with:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/scenes/weapon/weapon_numeric_module_test.tscn
```
