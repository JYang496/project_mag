# Art-unification showcases

These scenes are manual, 1280 x 720 review surfaces for the current MagArena
art-unification milestones. They are intentionally separate from the active
regression manifest so a reviewer can open only the area they want to inspect.

## Unified UI gallery

- Scene: `res://tests/showcases/ui/ui_gallery_showcase.tscn`
- A persistent manual-review hub for production UI and HUD components. It includes
  state switching, Chinese/English refresh, background contrast modes, safe-area
  guides, a searchable inventory of every production UI scene, and every focused
  UI showcase as an internal page. The UI review flow never leaves the gallery.
- Controls: `Q`/`E` pages, `A`/`D` states, `L` language, `B` background,
  `G` guides, `F` focus mode, and `R` reset.
- The gallery uses representative sample data and does not validate gameplay data
  flow. Embedded pages isolate their 1280 x 720 presentation in a SubViewport;
  the production game remains authoritative for complete runtime interactions.
- Internal pages include reward draft, reward-card gallery, weapon-core card,
  module equip selection, trigger-module cards, contract selection,
  protocol imagery, gold-supply HUD, passive-action badges, and heat accessibility.
- On embedded pages, `Q`/`E` remain gallery navigation; all other keys are owned
  by the current page and its on-screen instructions.

Use the local Godot console executable from the repository root:

```powershell
& 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe' `
  --path . res://tests/showcases/<domain>/<scene>.tscn
```

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

## Arena environment

- Scene: `res://tests/showcases/presentation/arena_environment_variants_showcase.tscn`
- Shows the four deterministic, decorative-only industrial ground themes using
  the production battlefield shader.

The weapon HUD, player health bar, and heat meter are deliberately absent from
these review scenes because those approved components are outside this change.

## Weapon active-skill lab

- Scene: `res://tests/showcases/weapon/weapon_active_skill_lab.tscn`
- Use the 15 buttons or `Q`/`E` to select every production weapon in sequence.
- Press `C` to force-ready and cast the selected weapon skill, left-click to fire,
  and `R` to restore the twelve fixed one-million-HP target dummies.
- `追踪能量弹` is marked as a basic-attack-only entry: use left-click to review
  its level-scaled fan and homing behavior; `C` intentionally has no effect.
- For `迫击炮`, aim along a row of targets and verify that its four Walking
  Barrage impacts advance from near to far with alternating lateral offsets.
- Pass `-- --validate-weapon-skill-lab` for the headless scene contract check.
- Pass `-- --capture-weapon-skill-lab` to save a deterministic visual review image
  under `output/showcases/weapon/` and exit.

## Player dash curve lab

- Scene: `res://tests/showcases/player/jet_dash_showcase.tscn`
- Uses the production HeavyAssault player and active skill in an isolated arena.
- Keeps the camera fixed at the center of the review arena while the player moves.
- Adjust duration, distance, curve endpoints, peak time, and peak speed live; the
  plotted curve and subsequent automatic or manual dashes update immediately.
- Press `TAB` for automatic eight-direction playback, or use `WASD + Space`.

## Production-world weapon active-skill lab

- Scene: `res://tests/showcases/weapon/weapon_active_skill_gameplay_lab.tscn`
- Inherits the production `World/world.tscn`, including the real board, hybrid
  ground, player/mecha spawn path, camera projection, battle HUD, and registries.
- It suppresses only the normal world-entry coordinator and enemy waves, then
  overlays the 15-weapon selector and twelve fixed one-million-HP targets.
- The selector includes `追踪能量弹` as a basic-attack-only review entry.
- The `迫击炮` entry includes an in-panel check for the four-step Walking Barrage
  footprint and impact order.
- The main menu exposes this scene as `Weapon Skill Test Lab`; entering it does
  not clear, create, or commit a save.
- The production-world lab now includes `快速`, `压力`, and `全武器` performance
  suites. They drive the production player input path, collect frame percentiles,
  hitch counts, entity peaks, central simulation timing, pool activity, and save
  schema-v2 JSON reports under `user://performance/weapon_lab/`.
- Click `性能测试` in the same lab for a 120-real-enemy stress sequence across
  every weapon. The simulated player moves, attacks, and uses available skills;
  JSON and a readable summary are saved under `docs/performance/weapon_lab/`.
  This is a synthetic extreme workload, not a reproduction of first-level rules.
  The report does not claim precise rendering or physics percentages.
- Launch with `-- --run-weapon-performance=quick` (or `stress` / `all_weapons`)
  to run a graphical suite automatically and exit after printing
  `WEAPON_PERFORMANCE_REPORT=<absolute path>`.
- Performance thresholds are deliberately not active test assertions: compare
  runs on the same machine with the in-lab baseline action. The active contract
  test only validates scenario determinism, statistics, and report structure.

## Production-world enemy generator performance lab

- From the main menu, click `全敌人生成器性能测试`, or open
  `res://tests/showcases/enemy/enemy_performance_lab.tscn` manually.
- Choose one enemy type and click `测试所选敌人`, or click `测试全部敌人`.
  The list comes from the active combat spawn profile. Each type is sampled at
  10, 40, and 120 live enemies after an empty-world baseline. The fixed player
  does not attack, and enemy contact damage is disabled for repeatable sampling.
- The panel shows progress and the JSON report path under
  `user://performance/enemy_lab/`. Compare frame percentiles, enemy simulation
  timing, entity peaks, and setup time for each type and count. Click `停止测试`
  to cancel, or `返回主菜单` to leave. This is an isolated synthetic workload;
  enemy waves and weapon use are excluded.
