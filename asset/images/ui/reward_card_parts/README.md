# Reward card image parts

These 11 transparent PNGs are individually generated sources for the three reward cards in the UI Gallery page 05 preview. The production `RewardCard` now uses the frame, well, badge plates, hold track, and selected strip. The gallery's page 05 also uses the divider and action plates.

| Part | Source files | Intended layer |
| --- | --- | --- |
| Card frame | `source/card_frame_cyan.png` | Outer card border, above the content well |
| Content well | `source/content_well.png` | Dark surface behind card content |
| Key badge | `source/key_badge_cyan.png`, `source/key_badge_amber.png` | Background behind the dynamic choice number |
| Type plate | `source/type_plate_cyan.png`, `source/type_plate_amber.png` | Background behind the dynamic reward type or selected label |
| Action plate | `source/action_plate_cyan.png`, `source/action_plate_amber.png` | Background behind the dynamic bottom action text |
| Divider | `source/section_divider.png` | Between title and description |
| Hold track | `source/hold_progress_track.png` | Behind the dynamic hold-progress fill |
| Selection strip | `source/selected_strip_amber.png` | Visible only for a selected card |

`parts_manifest.json` records each PNG's original dimensions, visible alpha region, and proposed logical target size. Runtime code crops the transparent margins with `AtlasTexture` and scales the visible region with nearest filtering. Color variants still differ slightly in geometry. The current pixel-art policy has no reward-card target grid. The `runtime/` directory contains a discarded normalization experiment and is not bound to production controls.

Names, descriptions, numbers, localized tags, action text, focus semantics, and progress fill remain in live UI controls. The PNGs supply appearance only. Reward detail and module card components can reuse the same parts later.
