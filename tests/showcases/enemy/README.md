# Wheel-cart crowd baseline

Run the deterministic second-stage crowd workload with:

```powershell
& 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/showcases/enemy/wheel_cart_shared_separation_showcase.tscn
```

The showcase runs five compact formations using the production rolling-ball and
wheel-cart scenes: 80+20, 120+60, and 120 heavy enemies in active, slowdown,
and stunned states. Each `BASELINE` line reports the
average, p95, and maximum physics-frame interval, slide contacts, heavy-enemy
collision-mask observations, spatial-query candidate checks, sweep query counts,
and crowd push/blocker checks.

Frame timings are machine-dependent and are comparison data, not a pass threshold.
`PASS` means all scenarios retained their expected enemy count, kept enemy body
mask 3 disabled, produced no enemy body slide contacts, and kept spatial-query
work bounded by local candidates. Compare the three emitted scenarios against the
stage-0 capture: `80_normal_20_heavy`, `120_normal_60_heavy`, and
`0_normal_120_heavy`. A run is not acceptable if either heavy scenario shows a
multi-second frame-time plateau, sweep queries exceed one per moving heavy per
physics frame, or candidate checks scale with total enemy pairs.
