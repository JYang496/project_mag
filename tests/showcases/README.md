# Art-unification showcases

These scenes are manual, 1280 x 720 review surfaces for the current MagArena
art-unification milestones. They are intentionally separate from the active
regression manifest so a reviewer can open only the area they want to inspect.

Use the local Godot console executable from the repository root:

```powershell
& 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe' `
  --path . res://tests/showcases/<domain>/<scene>.tscn
```

## Character pixels

- Scene: `res://tests/showcases/character/ranger_pixel_unification_showcase.tscn`
- Shows Ranger front/back idle, front/back 8-frame hover movement, real display
  footprint, and the four unchanged shared-mecha resources.

## Combat readability

- Scene: `res://tests/showcases/vfx/combat_readability_showcase.tscn`
- Shows single target, group hit, merged sustained damage, and high-density flame
  readability without changing weapon range or damage.
- Pass `--capture-showcase-vfx` to save its deterministic review capture under
  `output/showcases/vfx/` and exit.

## Reward draft

- Scene: `res://tests/showcases/ui/reward_draft_unification_showcase.tscn`
- Controls: `L` language, `F` focus, `H` hold progress, `R` reset.
- Shows three self-contained cards without a duplicate detail row, long bilingual copy, focus, selection, and
  quick-confirm states.

## Arena environment

- Scene: `res://tests/showcases/presentation/arena_environment_variants_showcase.tscn`
- Shows the four deterministic, decorative-only industrial ground themes using
  the production battlefield shader.

The weapon HUD, player health bar, and heat meter are deliberately absent from
these review scenes because those approved components are outside this change.
