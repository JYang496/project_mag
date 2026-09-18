# Jet dash manual showcase

Launch from the project root:

```powershell
& 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe' --path . res://tests/showcases/player/jet_dash_showcase.tscn
```

The actual HeavyAssault scene and active skill run in an isolated grid arena.
Automatic mode refills energy, resets cooldown and demonstrates eight directions.
Press TAB to toggle automatic mode; WASD + Space operates the skill manually.
The showcase disables the production player-follow camera and uses a fixed camera
centered on the 1280 x 720 review arena, so player movement never pans the view.

The runtime panel adjusts dash duration, distance, start/end speed multipliers,
peak time, and peak speed. Its graph updates immediately. The movement runtime
normalizes the curve area, so curve-shape edits preserve the selected distance;
duration and distance remain independent authoritative parameters. Use the reset
button to restore the approved 0.40-second, 100-unit profile with a 40% peak.

Inspect the curved acceleration/deceleration, twin reverse-facing nozzles,
expanding air shock fronts, and exhaust fade. The actual starting weapon is
created, attached to EquippedWeapons, and updated by the extracted orbit system.
This is a manual presentation tool, not validation of full battle flow or enemy
collision. The window remains open until closed. It is not an active test.
