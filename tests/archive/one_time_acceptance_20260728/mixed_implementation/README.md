# Retired implementation-bound assertions

This folder preserves complete release-specific renderer and probe scripts that
were separated from the active regression suite on 2026-07-28.

The active replacements validate stable runtime behavior:

- projection round trips and camera reconfiguration;
- weapon and projectile scene contracts;
- enemy scene loading and damage-warning feedback;
- wheel-cart contact configuration.

The following release-specific checks were removed from otherwise durable active
tests rather than kept as executable archive scripts:

- exact damage-number atlas geometry, magnitude tiers, and colors;
- exact weapon-selector slot geometry, icon rotation, and crop bounds;
- tactical-beacon palette, mesh, layer, and arrow-edge layout;
- legacy player-facing placeholder string searches.

Git history remains the source for those removed partial assertions. Recreate a
new acceptance scene if a future visual design needs an equivalent release gate.
