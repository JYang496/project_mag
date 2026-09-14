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

### Project-wide Test Execution Policy

- This policy applies to every future task in this project, across conversations.
- Do not automatically run tests after modifications. Bug fixes, refactors,
  balancing, visual changes, maintenance, and investigations run tests only when
  the player explicitly requests them.
- After modifying runtime scripts, scenes, resources, or project configuration,
  run the smallest windowless Godot check needed to catch parsing, compilation,
  resource-loading, and startup errors. Inspect the output as well as the exit
  code; an exit code of zero alone does not prove that no errors occurred.
  Fix errors introduced by the task and repeat only the necessary check until
  they are cleared. Report unrelated errors and the limits of the check plainly.
  This minimal Godot check is required and does not need player permission.
- A separate default exception is genuinely new product feature development: one
  focused validation run is allowed for the completed feature. Do not repeat it
  after subsequent edits or run additional validation without a player request.
- Tests, temporary probes, and broader validation/audit commands remain subject
  to the opt-in requirement. The minimal Godot error check above does not
  authorize automated gameplay tests, full audits, or graphical windows.
- Reading code, reviewing diffs, and making required implementation changes are
  allowed without running tests. Report unexecuted gameplay validation plainly; do not ask
  for test permission routinely after every modification.
- When the player requests tests, use the requested scope and prefer affected or
  focused tests over the entire historical suite.

### Active Test Addition Policy

- Do not add a new test to the active test catalog unless the task develops a
  genuinely new product feature.
- Bug fixes, refactors, balancing, visual changes, maintenance, and investigation
  work must not introduce new persistent active tests.
- Temporary tests or probes may be created only for validation allowed by the
  execution policy above, and must be deleted after validation completes, except
  for retained manual visual showcases described below.
- Tests developed for a genuinely new feature may be saved and registered for
  future player-requested runs. Saving tests does not authorize automatic reruns.
- Do not register temporary validation in `tests/infrastructure/test_manifest.json`,
  archive it for later reuse, or leave any test scene, runner, fixture, probe, or
  generated test artifact that would be run again in future work. Manual visual
  showcases meeting the policy below are exempt from this retention restriction.
- Reuse existing active tests when they already cover the affected behavior. A
  request to add durable regression coverage does not override this policy unless
  the work is for a genuinely new feature or the user explicitly changes this rule.

### Manual Visual Showcase Policy

- Visual content that needs repeated player review, such as UI, HUD, layouts,
  animation, and combat presentation, may retain a runnable manual showcase even
  when the task is a visual change or maintenance rather than a new feature.
- Store these scenes under `tests/showcases/<domain>/`. Their supporting scripts,
  local fixtures, and matching UID sidecars may also be retained there.
- Reuse the affected runtime UI scenes and components where practical. If an
  isolated preview or sample data is necessary, document that limitation and do
  not present it as validation of the actual gameplay flow.
- Include concise launch instructions and the visual states the player should
  inspect. Keep showcases available for repeated review rather than automatically
  exiting after a short timer.
- Showcases are manual review tools, not persistent active tests. Do not register
  them in `tests/infrastructure/test_manifest.json`, affected-test selection, or
  automated test runners. This exception does not permit retaining unrelated
  temporary tests, probes, or generated validation artifacts.
- Retention does not authorize execution: automatic tests and validation still
  follow the execution policy above, and opening a graphical Godot window still
  requires explicit player permission. Honor permission already given for the
  current task without asking again.

### Windowless Godot Validation

When validation is authorized by the execution policy above, default to
non-interactive, windowless CLI validation.

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

For the minimal script/resource error check, use the headless editor so Godot
loads and scans project scripts, including scripts outside the main scene:

```powershell
& 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit
```

Use a brief headless startup only when the affected loading path requires it;
do not expand this into gameplay testing. `--check-only --quit` alone may leave
scripts outside the loaded scene unchecked. For a brief project startup check:

```powershell
& 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit-after 3
```

Do not use `--script --check-only` for runtime scripts that depend on autoload
singletons: that standalone mode can report missing singleton identifiers even
when the project loads correctly. Check them in the project loading context.
