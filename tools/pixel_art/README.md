# Pixel-art tool pipeline

`pipeline_manifest.json` classifies every current pixel-art generator as active,
experimental, archived, or a one-time migration. Runtime dimensions remain
defined by `res://Visual/pixel_art_policy.gd`.

Validate and inspect the tool contract without generating files:

```powershell
pwsh -NoProfile -File tools/run_pixel_art_pipeline.ps1 -Check
pwsh -NoProfile -File tools/run_pixel_art_pipeline.ps1 -List
```

Run all active generators, or one selected task:

```powershell
pwsh -NoProfile -File tools/run_pixel_art_pipeline.ps1
pwsh -NoProfile -File tools/run_pixel_art_pipeline.ps1 -Task damage_digit_atlas
```

Experimental generators write only to `tmp/`. Archived tasks are documentation
and reproducibility aids. One-time migration tasks require `-AllowMigration`.
