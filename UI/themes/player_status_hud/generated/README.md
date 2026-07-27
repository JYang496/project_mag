# Legacy Player Status HUD Raster Assets

These files are retained as source-history artifacts and are not used by the
runtime HUD. `res://UI/scripts/components/player_status_hud.gd` now renders HP,
shield, and energy with antialiased modern geometry so the meters remain sharp
at different UI scales without adopting a pixel-art appearance.

Do not add new runtime references to `hp_fill.png`, `shield_fill.png`,
`energy_125_fill.png`, or the old frame variants. New raster combat HUD assets
belong under `res://UI/themes/modern/` and should be authored at 2x display
resolution with mipmaps and linear filtering.

`process_hud_assets.py` is preserved only to document how the archived files
were produced.
