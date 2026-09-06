# Trail surface effects

The flamethrower moving inferno, dash blade rift and Frost Trail module use
`Combat/visual/trail_surface_visual.gd`. Their existing capsule damage records
remain authoritative. Chainsaw cage boundaries keep their dedicated renderer.

## Presentation

- Fire: charcoal footprint, animated orange embers and short upright flames.
- Rift: purple footprint, narrow irregular bright core and floating fragments.
- Frost: blue ground film, branching crystals and low-opacity cold mist.
- The flamethrower spray and its afterimages also use the combustion material.
  Glacier spray is unaffected by the opt-in `burning_style` setting.

One horizontal quad evaluates the union of an effect's capsule records, including
zero-length circular marks. Intersections do not accumulate segment opacity.
World-space texture coordinates remain stationary as the camera and emitter move.
The 2D fallback uses the same surface function with CanvasItem UV orientation.

RGB and coverage share a two-world-pixel grid. The shared 128 × 128 seamless
NoiseTexture2D uses nearest filtering and no mipmaps. This is a procedural material,
not an imported replacement for the approved flame sprite frames.

Active detail develops over 0.12 seconds and fades toward the end of each record's
lifetime. Expired geometry contributes only 0.35 seconds of dim decorative residue.
Residue is held separately and never participates in damage. Finishing Moving
Inferno still ends damage immediately; it does not extend the weapon skill.
Battle cleanup removes both active and retired records.

## Owners and limits

- `Combat/area_effect/trail_area_effect.gd`: style, active/retired lifecycle and damage.
- `Combat/visual/trail_surface_visual.gd`: capsule payload, shared textures, bounded
  decoration sampling and hybrid registration.
- `Shaders/trail_surface.gdshaderinc`: union coverage and the three ground materials.
- `Shaders/trail_motes_3d.gdshader`: flame tongues, rift fragments and cold mist.
- `Visual/Oblique/connected_effect_renderer.gd`: ground quad and MultiMesh projection.
- `Shaders/burning_spray.gdshaderinc`: combustion color, flow and organic spray edges.

Each surface accepts 64 visual records. Current weapons use at most 28 active
records and keep at most 32 retired records, fitting together without dropping
active coverage. If a future weapon increases these limits, update the shader and
payload capacity together before shipping it. Each effect has at most 96 upright
decorations, with at most 1024 candidate cells examined per geometry change.
Decorations use a fixed jittered world grid and do not add collision nodes.

## Review and validation

Use the existing actual-world laboratory:
`tests/showcases/weapon/weapon_active_skill_gameplay_lab.tscn`.
Select flamethrower or dash blade, activate the weapon skill and move/fire to inspect
generation and persistence. The Frost Trail module consumes projectile-spawn events.

The implementation was checked with the existing `weapon.runtime_chain`,
`weapon.cone_spray_trail` and `world.projection_runtime_contract` workers, the startup
manifest audit and the headless compilation gate. A removed temporary probe checked
capsule endpoints, default overlap deduplication, expiry/no-damage residue, hybrid
re-registration, cleanup, real weapon bindings, and 2D/3D screenshots. No new test
was added to the active catalog.
