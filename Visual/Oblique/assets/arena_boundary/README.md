# Arena surface channels

The approved cyan/graphite concept is reconstructed as exact modular source art,
not cropped from the perspective image. Godot imports the SVGs as textures; the
camera supplies perspective once. Existing terrain, cell size and collision are
preserved.

| Source | Logical size | Use |
| --- | --- | --- |
| `groove.svg` | 64 × 8 | Repeating straight recessed metal channel, rotated through UVs for vertical edges |
| `junction.svg` | 12 × 12 | Mechanical junction body; connected arms form ends, corners, T and cross connections |

Both textures use whole-pixel shapes, nearest sampling and no mipmaps. There is
no AI raster normalization step because these are native geometric sources.
The 256 × 256 board-cell policy remains unchanged; these are narrow overlay
modules with an 8-unit world footprint and a 2-unit energy core, not replacement
cell textures. Straight segments stop 6 units before each vertex, exactly meeting
the 12-unit node. One mesh is created per unique shared edge/vertex.

`arena_boundary_renderer.gd` binds both sources to `arena_boundary.gdshader`.
State 0 retains only the metal recess, state 1 adds dark teal, and state 2 adds
cyan pulses moving in positive world X/Z at 24 logical units/second, repeated
every 128 units. No emission/bloom or additive blending is used. Each node arm
inherits its own edge state, preventing active arms from lighting disabled arms.

Enabled floor edges normally use state 1. An occupied cell raises its four edges
to state 2. During deployment, revealed but still dimmed retained floors use
state 0; incomplete floors do not support a boundary until their corners have
revealed. Adjacent owners resolve to the highest visible state. Edges with no
enabled supporting floor hide with that floor. Board visibility, recentering and
rebuild/teardown are synchronized by `BoardGroundRenderer`.

The surface sits at 0.019 world Y, below activation outlines (0.024) and danger
warnings (0.032), and uses opaque depth-tested drawing without casting shadows.
The existing outer platform support frame remains separate.
