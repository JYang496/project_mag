# Documentation Audit — 2026-07-15

## Scope

Reviewed human-authored Markdown and text files in the repository. Generated HTML, imported assets, `.godot/`, `test-results/`, and historical test assets were excluded.

## Findings and actions

| Document | Finding | Action |
| --- | --- | --- |
| `docs/README.md` | Referenced nonexistent `audits/`, `prompt/`, and `reports/dps/` directories | Replaced with an index matching the current tree and explicit source-of-truth rules |
| `Overview.md` | Described the retired NPC/Space start flow, old `SpawnInfo` model, and incomplete save status; omitted battle contracts and hybrid ground | Rewritten as a current high-level overview |
| `docs/plans/battle_contract_choice_design.md` | Still required a three-second pre-battle countdown | Updated to immediate start after snapshot creation and marked as implemented product intent |
| `docs/plans/battle_contract_codex_prompts/` | Completed prompts appeared to be outstanding implementation work | Directory README now marks stages 1–8 as historical implementation records |
| `docs/plans/hybrid_2d_3d_2_5d_architecture.md` | Claimed development should continue on the old `2.5d-test` branch | Reframed as the current architecture reference with code taking precedence |
| `docs/module prompt.txt` | Could imply the generated audit HTML must already exist | Marked as an operational template and its HTML as generated output |
| `docs/player_movement_system_report.md` | Dated recommendations could be mistaken for current backlog | Marked explicitly as an investigation snapshot |
| Two cell-task design documents | Contain invalid UTF-8 bytes and predate current runtime | Preserved without destructive transcoding; documentation index points maintainers to current runtime sources |

## Documents retained as snapshots

- `docs/reports/asset_test_image_usage_report_2026-07-06.md` is already dated and scoped.
- `docs/player_movement_system_report.md` remains useful for historical reasoning after adding its snapshot banner.
- Battle-contract stage prompts and resolved error notes remain useful for traceability.

## Follow-up rule

Do not attempt automated character replacement in the two damaged cell-task files. Recover them from an original clean source or replace them with a newly written current contract after checking the live runtime.
