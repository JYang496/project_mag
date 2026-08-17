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

## Cryptographic Hash Policy

- Do not add cryptographic hashing, digest fields, checksums based on cryptographic
  hashes, HMACs, or hash-based encryption to runtime code, tools, reports, tests,
  manifests, or generated artifacts.
- Do not use external asset-processing wrappers that inject cryptographic digest
  metadata into project reports; invoke the project-owned tool directly instead.
- Use direct byte comparison when a test only needs to prove that two files are
  byte-identical.
- Deterministic non-cryptographic hashes used for spatial indexing or procedural
  visual distribution are allowed and must not be presented as security features.

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

### Active Test Addition Policy

- Do not add a new test to the active test catalog unless the task develops a
  genuinely new product feature.
- Bug fixes, refactors, balancing, visual changes, maintenance, and investigation
  work must not introduce new persistent active tests.
- This restriction does not prohibit validation. Temporary tests or probes may be
  created when needed to verify the current task, but they must be deleted after
  validation completes.
- Do not register temporary validation in `tests/infrastructure/test_manifest.json`,
  archive it for later reuse, or leave any test scene, runner, fixture, probe, or
  generated test artifact that would be run again in future work.
- Reuse existing active tests when they already cover the affected behavior. A
  request to add durable regression coverage does not override this policy unless
  the work is for a genuinely new feature or the user explicitly changes this rule.

### Windowless Godot Validation

Default to non-interactive, windowless CLI validation for all Codex tasks in
this repository.

- Do not call Godot MCP `run_project` or `launch_editor` by default.
- Use the Godot console executable with `--headless` and the existing test
  infrastructure for compilation, resource import, and automated tests.
- Read-only Godot MCP operations that do not open a window are allowed.
- If visual verification genuinely requires graphical rendering, tell the user
  first and wait for explicit permission before briefly launching a Godot
  window.

Use the existing test infrastructure when possible:

```powershell
pwsh -NoProfile -File tests/infrastructure/select_affected_tests.ps1
pwsh -NoProfile -File tests/infrastructure/run_selected_tests.ps1 -BaseRef origin/master
```

The local Godot 4.7.1 console executable is:

```text
E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe
```

Use it for the project-wide script and resource compilation gate:

```powershell
& 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --check-only --quit
```
