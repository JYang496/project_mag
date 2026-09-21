# UI asset direction

New or substantially reworked UI should use image assets for its primary visual
identity: PNG illustrations/icons, nine-slice frames, StyleBoxTexture and texture
buttons. Godot controls retain all localized text, data, layout and interaction.
Do not bake protocol names, rules, enemy information or shortcuts into artwork.

Migrate only the components explicitly in scope. Preserve existing runtime rules
and input behavior. Keep visible selection, focus and enhanced state distinct;
selection must remain recognizable without color or animation. Missing artwork
must retain readable text and usable controls; a simple emergency style is allowed.

Use `Visual/pixel_art_policy.gd` for logical grids and the project-owned pixel
normalizer for generated pixel art. Use nearest filtering, integer geometry and
fixed nine-slice corners. Keep per-protocol paths and art direction in independent
presentation resources (`UI/resources/protocols/catalog.tres` is the first example).
Follow root AGENTS.md for checks, tests and graphical preview permissions.
