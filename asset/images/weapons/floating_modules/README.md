# Floating weapon modules

14 authoritative single-frame sprites. Instances, weapon definitions and branch icons
share these textures at every fusion level. Old source textures remain unreferenced.

| Canvas | Weapons |
|---|---|
| 48×56 | cannon, rocket_launcher |
| 40×64 | sniper, laser, plasma_lance, spear_launcher, dash_blade |
| 40×56 | machine_gun, shotgun, flamethrower, charged_blaster, glacier_projector, chainsaw_launcher, orbit |

The canvas center is the rotation origin; forward is local −Y. Four logical pixels
are reserved around the aspect-preserved body. Nearest filtering, no mipmaps, hard
alpha. Runtime intensity is 0.80/0.84/0.88, with cyan lamps responding to fire and heat.
Shadow, recoil, muzzle flash and magnetic connection are runtime presentation.

Generated with built-in ImageGen, individually per weapon. Prompt specification:
single strict orthographic top-down upward-facing floating mech weapon; blue-black
chassis, white-gray armor, circular cyan rear magnetic connector; neutral symmetric
center-bright/edge-dark shading; transparent background; no floor, cast shadow,
perspective, labels or hands. Weapon-specific prompts describe short wide cannon,
slender sniper, twin-tank sprayers, twin-barrel shotgun, rocket pods, purple energy
chambers, spear rails, toothed chainsaw, rapier and crescent orbit emitter.

Dash blade was revised to a European rapier silhouette: narrow straight silver
thrusting blade, oval swept guard, curved knuckle bow and cyan magnetic pommel.
The broad leaf blade is removed. Built-in ImageGen produced the replacement;
the project CLI normalized its aspect-preserved body to 15×56 with center sampling,
32 colors and hard alpha, then placed it on the existing 40×64 canvas. Rotation,
fusion bindings, hitbox, attack range and combat behavior are unchanged.

Normalized with the project-owned PerfectPixel CLI using explicit fitted grids,
center sampling, hard alpha and 32-color ceiling, then padded without stretching.
All 14 normalization reports returned zero warnings and shared RGB/alpha grids.
Source images remain in the Codex generated_images directory for this task.

Validation: 35 active tests passed, check-only and startup manifest passed, zero
runtime errors or shutdown diagnostics. A removed temporary probe checked all
14 instances at eight aim directions and three fusion levels, native sizing,
nearest filtering, muzzle endpoints, independent shadows and enemy occlusion inputs.
Graphical verification completed with permission using Godot 4.7.1 Vulkan Mobile
on AMD Radeon RX 6700 XT at 1280×720. Captured all 14 runtime weapon instances
at four rotations, their own fire-feedback profiles, and forced hot/overlap states.
Verified fixed ground ellipses, character readability, neutral rotating armor,
cyan-to-orange hot lamps and purple energy. The temporary scene was removed.
Projection and asset-integrity tests passed again after the connection-coordinate fix.
