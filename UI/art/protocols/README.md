# Protocol UI image assets

This is the first scoped image-driven UI migration. Runtime text and contract
rules are not baked into any image. `UI/AGENTS.md` records the direction for future
UI work. Other screens are intentionally outside this migration.

## Runtime binding

`data/battle_contracts/<id>.tres` → selection panel → card `setup(definition)` →
`UI/resources/protocols/catalog.tres` → illustration, symbol, frame, tint and focal
point. These presentation resources are explicitly loaded by the UI and are not a
new startup-manifest gameplay catalog. No gameplay definitions are modified.

| ID | Illustration / symbol subject | Runtime files in `textures/` |
|---|---|---|
| elimination | Targeted damaged combat drone / skull crosshair | `elimination_normalized.png`, `elimination_symbol_normalized.png` |
| survival | Shielded fortress / shield | `survival_normalized.png`, `survival_symbol_normalized.png` |
| reward | Salvage cache / chest | `reward_normalized.png`, `reward_symbol_normalized.png` |
| operation | Communications uplink / antenna | `operation_normalized.png`, `operation_symbol_normalized.png` |
| containment | Locked blast gate / barred gate | `containment_normalized.png`, `containment_symbol_normalized.png` |
| extraction | Evacuation dropship / ship and exit arrow | `extraction_normalized.png`, `extraction_symbol_normalized.png` |
| rest | Mech repair gantry / service tools | `rest_normalized.png`, `rest_symbol_normalized.png` |
| finale | Crown-shaped reactor / mechanical crown | `finale_normalized.png`, `finale_symbol_normalized.png` |

Shared art: `frame_normalized.png`, `selected_normalized.png`,
`button_normalized.png`; selected, enhanced, rare, disabled, focus and hover badge
PNGs; `fallback_icon_normalized.png`. `elimination_icon_normalized.png` preserves
the first prototype's icon; the final catalog uses the matching eight-icon set.

## Logical geometry and safe zones

The source of truth is `Visual/pixel_art_policy.gd`:

- Illustrations: 240×80, displayed at native logical size. Focal-point positioning
  moves the illustration within its own banner with integer coordinates, without
  stretching the art or putting text over it.
- Panel and state frame: 128×128, 24-pixel nine-slice corners. Normal panel fills
  the center; overlays omit the center. Selection, focus, enhancement and rarity
  have separate nodes and distinct persistent image badges.
- Icons: 32×32; status strip reserves 48 pixels beneath the body. Selection also
  retains localized text, so it is not conveyed solely by color or animation.
- Button: 192×64, 16-pixel slices. Shared by confirmation, enhancement, keyboard
  prompt and enemy portrait bases. Dynamic captions remain Godot controls.
- Card content uses 24-pixel horizontal / 18-pixel top safe margins. Long body copy
  and briefing copy scroll. Card Page Up / Page Down supports keyboard inspection.
  Full protocol titles also have tooltips.

Nearest filtering and rounded panel/banner positions preserve integer logical
geometry. Opening/selection/enhancement use fades, not card scaling. The HUD
handoff retains its existing movement; its settled geometry remains integral.

## Generation and normalization

Artwork was made with the built-in ImageGen tool, not geometry screenshots or an
external API wrapper. Original generated PNGs live in `source/` (Godot ignores
that directory). `prepare_sources.py` composites the panel onto an opaque dark
backing and crops transparent icon atlases; it draws no replacement artwork.

Prompt set: production dark science-fiction terminal pixel art; navy/charcoal
base; restrained per-protocol accents; chunky readable silhouettes at the logical
grids above; no baked text, UI screenshot, photorealism, gradients or bright glare.
Each illustration was requested separately as a wide 3:1 image using the subjects
in the table. The eight protocol symbols were requested as a transparent 4×2
atlas. The state emblems were requested as a transparent row of eight cells:
prototype skull, selected check-shield, enhanced chevrons/lightning, rare star,
disabled lock, focus reticle, hover pointer, fallback question-mark hexagon.
The normal panel prompt specifies flat dark center, straight stretchable edges,
stepped corners and restrained teal metal plates. The selection overlay specifies
transparent center, corner clamps, edge rails and a persistent bottom chevron.
The button prompt specifies a calm navy center and cyan metal end caps.

All final grids were processed directly with the project-owned CLI:

```powershell
& tools/perfect_pixel_normalizer/.venv/Scripts/python.exe tools/perfect_pixel_normalizer/cli.py normalize <source> --preset custom --grid <policy-grid> --palette-limit <limit> --output-dir UI/art/protocols/textures --protection error --report <report-path> --json
```

Palette limits: illustrations 48, frames 32, symbols/badges/button 24. Frames,
button and symbols use hard alpha. Each channel shares one grid. The six source
quality reports record zero warnings, successful output sizes, grid coordinates
and protection results; these are independent images, not animation sequences.
No digest metadata or cryptographic hashes are added by this workflow.

## Fallback and scope

Missing textures return null safely. Missing illustration/symbol retains dynamic
name, objective, rules and selection controls with an explicit art-offline label.
Missing frame gets an emergency StyleBoxFlat; missing overlay cannot remove the
selected text. This fallback is intentional, not the normal visual path.

Remaining procedural visuals elsewhere include the battle HUD itself, shared
legacy contract icon/frame components used by other screens, and unrelated UI.
The modal shade remains a functional alpha dimmer. Native scrollbars and font
rendering remain Godot controls. Long translations may require scrolling; the
illustrations intentionally trade fine detail for readability at 240×80.

Manual review: open the `协议图像` page in
`res://tests/showcases/ui/ui_gallery_showcase.tscn`.
