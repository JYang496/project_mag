# MagArena Presentation Standard

This document describes the split presentation contract enforced by
`Visual/pixel_art_policy.gd` and `presentation.pixel_art_policy`: gameplay
sprites may retain pixel-art rendering, while UI uses a modern antialiased
sci-fi language.

## Rendering contract

- The logical canvas is 1280x720.
- Window stretch scaling is integer-only.
- Canvas textures inherit nearest-neighbour filtering by default.
- Mipmapped pixel textures select the nearest mip level.
- Pixel-art gameplay textures must not opt into linear filtering.
- Fractional `Node2D.scale` is allowed only to normalize a source canvas to an
  integer final target size or for a temporary gameplay animation.
- Stable world placement should use whole logical pixels. Use
  `PixelArtPolicy.snap_logical_position()` when a persistent visual anchor is
  computed from fractional values.
- UI controls override the world default with linear or linear-mipmapped
  filtering and may use subpixel placement for smooth layout and animation.

## Density tiers

| Asset role | Authored or final logical size |
| --- | --- |
| Player animation frame | 128x128 |
| Player support unit / drone | 64x64 |
| Standard enemy source frame | 32x32 |
| Large enemy source frame | 48x48 |
| Large loot | 64x64 |
| Equipped weapon | 48x64 authored canvas and 64 px final height |
| Standard projectile | 10x10 final size |
| Cannon projectile | 12x12 final size |
| Large projectile | 32x32 final size |
| Board cell | 256x256 |
| Large scene prop | 256x256 |
| Small combat effect | 32x32 |
| Medium combat effect / explosion | 64x64 |
| Large combat effect | 128x128 |
| Flame spray frame | 256x80 |
| Glacier spray frame | 256x90 |
| Common module icon | 32x32 |

Transparent padding is part of the frame size. Directional or elongated assets
may use a different aspect ratio, but their final displayed width and height
must still be positive whole logical pixels.

## Enemy silhouette and HurtBox alignment

Enemy billboard scale is authored per scene from the non-transparent texture
bounds, not from the padded source-frame size. The adjusted silhouette should
approximately cover its HurtBox; narrow decorative tips may extend past it.

| Enemy | HurtBox | Adjusted visible silhouette | Billboard scale |
| --- | ---: | ---: | ---: |
| Bomber | 24x22 | 24x24 | 1.5 |
| Interceptor | 42x42 | 43x38 | 1.125 |
| Mine crawler | 18x18 | 18x18 | 0.875 |
| Mirror caster | 24x24 | 25x25 | 1.25 |
| Mirror clone | 16x16 | 15x16 | 0.75 |
| Mortar turret | 26x26 | 28x26 | 1.75 |
| Orbit support | 20x20 | 20x18 | 1.0 |
| Repair unit | 24x24 | 25x25 | 1.125 |
| Rolling ball | 20x20 | 20x18 | 1.0 |
| Rolling ball elite | 20x20 | 23x23 | 0.75 |
| Shield core | 27x27 | 27x29 | 1.5 |
| Spike turret | 24x24 | 20x28 | 1.0 |
| Tar mine crawler | 18x18 | 20x17 | 1.0 |
| Wheel cart | 30x25 | 28x28 | 1.75 |
| Reward enemy | 30x36 | 32x34 | 2.0 |

Enemy HP bars use a 40x6 logical frame, a -30 px vertical screen offset, and
an absolute foreground z-layer so billboard bodies cannot cover them.

## Asset workflow

1. Choose the closest density tier before drawing or generating the asset.
2. Keep hard alpha edges and a limited palette.
3. Import with inherited filtering unless the scene explicitly needs
   `TEXTURE_FILTER_NEAREST`; never select linear filtering for pixel art.
4. Author equipped weapons on a 48x64 transparent canvas instead of shrinking
   oversized sources at runtime. Narrow silhouettes use transparent horizontal
   padding so the production weapon family keeps a uniform source resolution.
5. Author board cells and large rest-area props at 256x256. Do not add 1K
   runtime sources for these roles.
6. Use 32/64/128px effect tiers. Directional spray frames use 256px authored
   length; gameplay range remains independent and scales the visual from that
   base length.
7. Normalize runtime display dimensions through `PixelArtPolicy` constants.
8. Extend `presentation.pixel_art_policy` when adding a new stable asset family
   or density tier.

## Archived sources and deterministic migration

Oversized originals and unused legacy character/enemy sources replaced on
2026-07-24 are preserved under `archive/deprecated_pixel_sources_20260724/`. Its
`.gdignore` prevents archived art from being imported as runtime resources.
The archive manifest records original and result checksums.

Run `tools/migrate_pixel_art_assets.py` with the bundled Python runtime to
reproduce the replacements. The script uses Pillow nearest-neighbour scaling
only; it does not use Godot rendering or redraw the artwork.

## Modern UI and font contract

- `UI/themes/pixel/` is a legacy experiment directory. Runtime scenes and
  scripts must not reference it.
- Modern combat HUD textures live under `UI/themes/modern/`, are authored at 2x
  their logical display size, generate mipmaps, and use linear filtering.
- The visual language uses a dark blue-black base, cyan-blue information
  accents, orange action/energy accents, restrained glow, and chamfered edges.
- Main weapon slots display at 96x72 from a 192x144 source. Offhand slots
  display at 72x72 from 144x144 sources. The heat gauge displays at 152x152
  from a 304x304 source.
- Player HP, shield, and energy meters are antialiased code-drawn controls.
  They must retain distinct health, shield, and energy channels and may use
  subpixel geometry.
- Menu panels and buttons use readable dark backings, cyan-blue borders,
  modern spacing, and smooth interaction states through
  `UI/themes/global_ui_theme.tres`.
- The Simplified Chinese font keeps full Chinese coverage and uses raster
  rendering with grayscale antialiasing, light hinting, and automatic subpixel
  positioning. Do not enable MSDF for this font: its CJK outlines produce
  visible fragments and internal seams at large title sizes.
- Runtime module icons use generated 32x32 PNG sources under
  `asset/images/modules/pixel/`. SVG files remain editable source artwork only
  and must not be referenced by module scenes.

Run the combined gameplay-pixel/modern-UI regression with:

```powershell
pwsh -NoProfile -File tests/infrastructure/run_test_workers.ps1 `
  -TestId 'presentation.pixel_art_policy' `
  -GodotPath 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe'
```

Regenerate all module pixel icons from their SVG source artwork with:

```powershell
& 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . --script res://tools/build_pixel_module_icons.gd
```
