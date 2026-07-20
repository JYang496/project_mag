# Player Status HUD Assets

All runtime textures are RGBA PNG files with transparent corners and 8 px clear padding.

- `ui_frame.png`: static frame/background. Render behind all dynamic controls.
- `ui_frame_rim_only.png`: outer metallic rim and left emblem only; the full interior is transparent so every dynamic control can be positioned freely.
- `ui_frame_clean_panel.png`: outer rim, left emblem, and one continuous opaque dark honeycomb backing panel; contains no preset resource slots or internal frames.
- `hp_fill.png`: horizontally clip or resize from the left using `current_hp / max_hp`.
- `shield_fill.png`: place directly below HP; clip using `current_shield / max_shield`.
- `energy_125_fill.png`: exact cell widths are `618 / 618 / 309` px with 16 px gaps, representing `50 / 50 / 25` energy. Use cell visibility or left-to-right clipping for the current value.
- `ammo_icon.png`: static ammo icon only. Render current and maximum ammo with a separate Label using `"%02d / %02d"`.

Recommended Godot setup: use clipped child `TextureRect` controls for HP and shield, discrete child controls for energy cells, and a Label for ammo values. Keep numeric state out of the textures.

`process_hud_assets.py` documents the deterministic trim and exact energy-cell correction applied after image generation.
