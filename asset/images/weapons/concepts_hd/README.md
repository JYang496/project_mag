# High-resolution weapon concept sources

These concept sources define the approved high-tech, top-down SD-mecha weapon
silhouettes used by the production 48x64 sprites. They are project-bound
references, not runtime textures.

Each weapon was generated independently with the built-in ImageGen workflow on
a flat magenta background. Prompts locked the following shared rules:

- cool white armor, blue-gray structure, and deep navy outline;
- the functional attack component dominates the silhouette;
- secondary armor and tanks remain compact;
- one shared near-circular crystal-core motif;
- no cream or yellow armor, oversized wings, cables, shadows, or text.

`tools/pixel_art/generate_weapon_sprites.mjs` removes the connected chroma
background, fits each independently redrawn concept to the common 48x64 canvas,
maps it to the shared 12-color role palette, and stamps the exact shared core.
