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

## Attack warnings

- Scene: `res://tests/showcases/vfx/attack_warning_gallery_showcase.tscn`
- Shows the complete active enemy attack-warning vocabulary: bomber and mortar
  circular AOE timing without numeric countdowns, spike-turret line lock, and
  rolling-elite dash corridor.
- Pass `--capture-attack-warning-showcase` to capture the gallery at 72% warning
  progress under `output/showcases/vfx/` and exit.

## Enemy auras

- Scene: `res://tests/showcases/vfx/enemy_aura_gallery_showcase.tscn`
- Shows every production enemy support aura together: speed, repair, and shield.
- Each panel preserves the production ownership ring and functional-color detail;
  repair and shield also show their active source-to-target links.

## Reward draft

- Scene: `res://tests/showcases/ui/reward_draft_unification_showcase.tscn`
- Controls: `L` language, `F` focus, `H` hold progress, `R` reset.
- Shows three self-contained cards without a duplicate detail row, long bilingual copy, focus, selection, and
  quick-confirm states.

## Contract difficulty

- Scene: `res://tests/showcases/ui/contract_difficulty_comparison_showcase.tscn`
- Shows the same Operation contract as a standard card and as an enhanced-risk
  card, with separate objective, risk, and bonus-reward hierarchy. Shared base
  rewards are intentionally omitted until contracts have distinct base rewards.

## Expanded contract selection

- Scene: `res://tests/showcases/ui/battle_contract_selection_expanded_showcase.tscn`
- Shows the production protocol selector with its transparent outer layout,
  near-full-screen safe area, and responsive two-card or three-card density.
- Pass `-- --capture-contract-selection-showcase` to save both production layouts
  plus the reserved enhanced-card interface state
  under `output/showcases/ui/` and exit.

## Arena environment

- Scene: `res://tests/showcases/presentation/arena_environment_variants_showcase.tscn`
- Shows the four deterministic, decorative-only industrial ground themes using
  the production battlefield shader.

The weapon HUD, player health bar, and heat meter are deliberately absent from
these review scenes because those approved components are outside this change.
