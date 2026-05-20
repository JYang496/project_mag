# Weapon Fuse System Plan

## Target Rules

Fuse is a universal weapon breakthrough system. It is a gate, not a global stat multiplier. A higher fuse raises the weapon level cap and unlocks evolution branch choices; the actual power gain comes from level data, branch behavior, modules, and explicitly authored passive effects.

| Fuse | Level Cap | Branch Count |
| --- | ---: | ---: |
| 1 | 3 | 0 |
| 2 | 5 | 1 |
| 3 | 7 | 2 |

All weapons have fuse. Branches are optional content: a weapon can fuse successfully even if no branch is configured, but that should record a warning or player-facing notice instead of blocking the game.

### Automatic Fuse

Manual fuse is no longer part of the player-facing system. Duplicate weapons from rewards, shop purchases, or drops can trigger automatic fuse, but only when the player already has an equipped weapon with the same weapon ID.

Automatic fuse rules:

- The equipped weapon is always the subject that survives.
- A matching weapon in inventory is not an automatic fuse subject.
- If no matching equipped weapon exists, the new weapon follows the normal obtain flow: equip if there is room, otherwise move to inventory.
- A duplicate material only increases fuse. It does not affect the subject weapon's level.
- If the subject is already at max fuse, the duplicate converts to gold.
- Gold conversion is based on the weapon's base price and has a minimum value.
- Automatic fuse does not cost gold.
- Initial loadouts, story grants, and test setup should not trigger automatic fuse unless that source explicitly opts in.

When several duplicate materials are resolved at once, use materials to raise fuse until the cap is reached, then convert all extra duplicates to gold.

### Branch Selection

Every successful fuse increase queues exactly one mandatory branch selection.

- Fuse 1 -> 2 queues the first branch choice.
- Fuse 2 -> 3 queues the second branch choice.
- Multiple pending choices are processed in order.
- Combat should not open the branch panel. If fuse happens in combat, queue the choice and open it later in a safe UI state.
- The branch choice blocks later reward, shop, and upgrade interactions, but must not make the underlying game state unrecoverable.

The branch selection queue should store a weapon reference or stable weapon identity plus the target fuse that triggered the choice. It should not cache branch options; options must be recalculated when the panel opens.

If the queued weapon no longer exists, skip the queue item and record a warning. If there are no valid branch options, let fuse stand, skip the panel, and record or show the configuration issue.

### Branch Option Filtering

Fuse 2 and Fuse 3 use the same branch pool. `unlock_fuse` controls when a branch first appears.

Only show branches that are:

- For the current weapon.
- Unlocked by the current fuse.
- Not already selected.
- Compatible with already selected branches.

Do not show filtered-out branches in the short term. Longer term, a debug or advanced view may explain hidden incompatible options.

Branches can set `unlock_fuse = 3` to appear only for the second evolution. The system does not need prerequisite branch requirements for now. Use `incompatible_branch_ids` and `exclusive_groups` to prevent broken combinations.

### Branch Design Boundaries

Branches may form strong build combinations. The design goal is multiple clear builds per weapon, while still allowing specific weapons to use "main route plus secondary upgrade" or "two branches combine into a third play style."

Branches may significantly change weapon behavior, but should do so through `WeaponBranchBehavior`, not by replacing the whole weapon scene.

Allowed branch effects include:

- Changing attack patterns.
- Changing damage type.
- Adding or removing weapon traits through explicit runtime trait overrides.
- Adding or modifying weapon active skills or offhand passives.
- Affecting other weapons through the existing global event/passive system.

Cross-weapon effects must use the existing global event/passive system and expose their source in UI. Branch selection is not normally reversible; any future reroll or respec should be a separate system.

### UI And Feedback

Weapon detail and upgrade UI should show:

- Current fuse.
- Current level cap.
- Selected branch summary.
- Next fuse benefit.
- A clear reason when normal level upgrade is disabled by the current fuse cap.

If `level < max_level`, normal gold upgrade is available. If `level >= max_level` and `fuse < FINAL_MAX_FUSE`, normal upgrade is disabled and should tell the player that a duplicate weapon is needed to break through. If both level and fuse are capped, show the weapon as fully upgraded.

Reward/shop cards should preview the actual result:

- New weapon obtain.
- Automatic fuse to the next fuse.
- Gold conversion when max fuse is already reached.

Automatic fuse should provide immediate feedback:

- Short message.
- Equipped weapon highlight.
- Fuse star refresh.
- Lightweight upgrade sound or visual effect.
- Branch selection panel after the safe-state queue allows it.

The branch panel should show selected branch summaries for context, but selected branches cannot be chosen again.

### Persistence And Migration

Save data must persist:

- `fuse`
- `level`
- `branch_ids`
- equipped module state

Restore order should be:

1. Instantiate the base weapon.
2. Set fuse.
3. Set level.
4. Restore branch IDs and reattach branch behaviors from `DataHandler`.
5. Restore modules.
6. Recalculate weapon status.

Invalid saved branches should not break the save. Skip missing, incompatible, or invalid branch IDs and record a warning. If old save data has more than two saved branches, keep the first two legal branches in saved order and skip the rest with warnings.

## Current System Comparison

| Area | Current Behavior | Target Behavior | Change Needed |
| --- | --- | --- | --- |
| Fuse caps | `Weapon` already defines Fuse 1/2/3 level caps as 3/5/7. | Keep. | No structural change. |
| Fuse visual | `Weapon.fuse` updates `max_level` and sprite; equipment slots render stars. | Keep, add stronger feedback. | Add fuse feedback effects and richer UI text. |
| Branch count | `Weapon._can_choose_more_branches()` allows up to two branches. | Keep. | No structural change. |
| Branch filtering | Current branch options filter by weapon scene, current fuse, already selected branch, incompatibility, and exclusive groups. | Keep. | No structural change; add selected branch summary to panel. |
| Manual fuse | Gear Fuse UI exists and uses `InventoryData.ready_to_fuse_list` plus `gf_confirm_btn.gd`. | No player-facing manual fuse. | Hide/disable entry first, later remove stale UI/state. |
| Manual fuse result | First selected weapon is duplicated as subject; second contributes fuse/level and returns modules. | Not used. | Remove or leave unreachable during transition. |
| Duplicate string ID obtain | `Player.create_weapon("id")` searches equipped and inventory weapons. It upgrades fuse first, then level, then gold. | Auto fuse only matching equipped weapons; no level gain; inventory match does not auto fuse. | Change duplicate handling path outside or before `create_weapon()`, or narrow current duplicate logic. |
| Duplicate instance obtain | `Player.create_weapon(weapon_instance)` can merge into existing equipped or inventory weapon and return duplicate modules. | Auto fuse subject must be equipped; material level ignored; max fuse converts to gold. | Adjust duplicate instance path if used by reward/shop obtain. |
| Max-fuse duplicate | Current max-fuse duplicate can increase level if below max level. | Max-fuse duplicate converts to gold. | Remove duplicate-to-level behavior for target auto-fuse sources. |
| Branch prompt timing | Duplicate fuse calls `request_weapon_branch_selection()` immediately. UI queue stores weak weapon refs only. | Safe-state queue; combat should defer. Queue stores weapon ref/identity plus target fuse. | Add safe-state gating and richer queue entries. |
| Missing branch options | `request_weapon_branch_selection()` returns false if no options. | Fuse succeeds, warning/notice is recorded. | Add explicit warning/notice at fuse call site. |
| Branch panel close behavior | Some UI paths call `close_panel(true)`, which can choose the default branch if pending. | Mandatory player choice; no skip/default choice for fuse evolution. | Remove default auto-choice behavior from blocked/close paths or guard it. |
| Reward/shop preview | Existing reward/shop cards do not consistently preview auto fuse or conversion outcome. | Preview new weapon, fuse, or gold conversion before selection. | Add prediction helper and card text. |
| Upgrade cap UI | `upgrade_preview.gd` hides upgrade info when `level >= max_level`. | Disabled upgrade with reason: duplicate weapon needed, or fully upgraded. | Add cap reason display. |
| Save persistence | Not verified in this pass. Runtime has `fuse`, `level`, `branch_ids`, modules. | Persist and restore all four with migration tolerance. | Audit save/load and add branch migration if missing. |
| Initial/story grants | Current `create_weapon()` cannot distinguish source. | Initial/story grants default no auto fuse. | Keep `create_weapon()` as baseline creation path; put auto-fuse decisions in reward/shop/drop sources before calling it. |

## Execution Plan Template

Use this section as the working checklist. Each phase should be implemented, tested, and reviewed before moving to the next one unless the work naturally shares files and is safer to batch.

Status values:

- `[ ]` Not started
- `[-]` In progress
- `[x]` Complete
- `[!]` Blocked or needs decision

### Phase 0: Baseline Audit

Status: `[ ]`

Goal: confirm the exact current behavior and identify all entry points before changing runtime logic.

Primary files:

- `Player/Mechas/scripts/Player.gd`
- `autoload/InventoryData.gd`
- `UI/scripts/UI.gd`
- `UI/scripts/shop_weapon_slot.gd`
- reward selection scripts and route reward builders
- save/load scripts once identified

Tasks:

- `[ ]` Find every weapon obtain path: reward, shop, drop, initial loadout, test setup, inventory equip.
- `[ ]` List every call site of `Player.create_weapon()`.
- `[ ]` Identify reward card UI code that displays weapon rewards.
- `[ ]` Identify shop card UI code that displays weapon purchases.
- `[ ]` Identify save/load code for equipped weapons, inventory weapons, modules, and branch IDs.
- `[ ]` Decide which sources opt into auto-fuse in the first implementation pass.

Acceptance:

- `[ ]` There is a short implementation note listing obtain sources and whether each one should auto-fuse.
- `[ ]` No gameplay behavior has changed in this phase.

Risks:

- Existing `create_weapon()` combines creation, duplicate handling, equip, and inventory fallback. Missing one call site can make duplicate behavior inconsistent.

### Phase 1: Disable Player-Facing Manual Fuse

Status: `[ ]`

Goal: remove manual fuse from the player flow without deleting scene nodes that may still be referenced.

Primary files:

- `UI/scripts/UI.gd`
- `UI/scripts/to_lb.gd`
- `UI/scripts/to_upgrade.gd`
- `autoload/InventoryData.gd`
- `UI/scenes/UI.tscn`

Tasks:

- `[ ]` Hide or remove the "To Gear Fuse" entry from Smith/rest UI.
- `[ ]` Prevent player interactions from adding weapons to `InventoryData.ready_to_fuse_list`.
- `[ ]` Keep Gear Fuse scene nodes temporarily if `UI.gd` still expects them.
- `[ ]` Ensure opening upgrade/shop/rest panels does not call `gf_panel_in()`.
- `[ ]` Keep old scripts reachable only as dead/legacy code until scene references are cleaned.

Acceptance:

- `[ ]` The player cannot enter the manual Gear Fuse panel through normal UI.
- `[ ]` Clicking equipped or inventory weapons no longer fills manual fuse slots.
- `[ ]` Existing upgrade, inventory, shop, and module UI still opens without missing-node errors.

Tests:

- `[ ]` Open rest/smith UI.
- `[ ]` Try selecting equipped and inventory weapons.
- `[ ]` Verify no manual fuse panel appears.

Risks:

- `UI.gd` currently references Gear Fuse nodes directly, so deleting scene nodes too early can break unrelated UI refresh code.

### Phase 2: Auto-Fuse Helper And Result Model

Status: `[ ]`

Goal: add source-driven automatic fuse resolution without renaming `create_weapon()` or changing its signature.

Primary files:

- `Player/Mechas/scripts/Player.gd`
- likely reward/shop/drop source scripts from Phase 0
- `autoload/DataHandler.gd`

Tasks:

- `[ ]` Add a helper for obtain sources, for example `try_auto_fuse_weapon_reward(weapon_id)` or an equivalent local helper.
- `[ ]` The helper checks only `PlayerData.player_weapon_list` for a matching equipped weapon ID.
- `[ ]` Return a structured outcome: `not_applicable`, `fused`, or `converted_to_gold`.
- `[ ]` On fuse success, increment `weapon.fuse` by one.
- `[ ]` Reapply current level immediately with `set_level(clampi(level, 1, max_level))`.
- `[ ]` Do not change subject weapon level from material level.
- `[ ]` If max fuse, convert duplicate to gold using base price plus minimum.
- `[ ]` Do not consume gold for fuse.
- `[ ]` Do not auto-fuse against inventory-only duplicates.
- `[ ]` Do not change `Player.create_weapon()` signature.

Acceptance:

- `[ ]` Duplicate reward/shop/drop for equipped same-ID weapon raises fuse if below max.
- `[ ]` Duplicate reward/shop/drop for max-fuse equipped same-ID weapon converts to gold.
- `[ ]` Duplicate same-ID weapon only in inventory does not auto-fuse.
- `[ ]` Initial loadout and direct `create_weapon()` calls keep their existing baseline behavior unless explicitly routed through the helper.

Tests:

- `[ ]` Equipped Fuse 1 weapon receives duplicate: becomes Fuse 2, level unchanged.
- `[ ]` Equipped Fuse 3 weapon receives duplicate: gold increases, level unchanged.
- `[ ]` Inventory-only duplicate receives new copy: follows normal obtain/equip/inventory behavior.
- `[ ]` Non-duplicate weapon obtain still follows current equip/inventory flow.

Risks:

- Current `Player.create_weapon()` still has duplicate behavior that can fuse, level, or convert duplicates. Reward/shop/drop code must avoid sending auto-fuse-eligible duplicates directly into that old path, or the old path must be narrowed carefully.

### Phase 3: Branch Selection Queue

Status: `[ ]`

Goal: make branch selection mandatory, queued, safe-state aware, and resilient.

Primary files:

- `UI/scripts/UI.gd`
- `UI/scripts/branch_select_panel.gd`
- `Player/Weapons/Core/weapon.gd`
- Phase 2 auto-fuse helper

Tasks:

- `[ ]` Replace weak-ref-only queue entries with entries containing weapon reference or stable identity plus target fuse.
- `[ ]` Queue one branch selection for every successful fuse increase.
- `[ ]` Recalculate `weapon.get_branch_options()` only when opening the panel.
- `[ ]` Skip invalid/missing weapons with warning.
- `[ ]` If no valid options exist, skip panel and warn/notify without reverting fuse.
- `[ ]` Defer panel opening during combat.
- `[ ]` Process queued branch choices once the game is in a safe UI state.
- `[ ]` Block reward/shop/upgrade interactions while a branch choice is pending or visible.
- `[ ]` Remove or guard `close_panel(true)` paths that auto-pick a default branch.

Acceptance:

- `[ ]` Fuse 1 -> 2 queues one branch choice.
- `[ ]` Fuse 1 -> 3 through two duplicates queues two branch choices.
- `[ ]` The second choice recalculates options after the first branch is selected.
- `[ ]` Branch panel cannot be bypassed into a default selection during normal fuse evolution.
- `[ ]` Combat-time fuse does not open the panel until safe state.

Tests:

- `[ ]` Trigger one auto-fuse outside combat.
- `[ ]` Trigger two auto-fuses before opening branch panel.
- `[ ]` Trigger auto-fuse during combat, then transition to rest/reward state.
- `[ ]` Delete or invalidate a queued weapon in a test path and verify queue continues.

Risks:

- Blocking UI interactions too broadly can prevent recovery. Blocking should apply to reward/shop/upgrade interactions, not to low-level game state cleanup.

### Phase 4: Reward, Shop, Upgrade, And Branch UI

Status: `[ ]`

Goal: make fuse outcomes visible before and after they happen.

Primary files:

- reward card scripts from Phase 0
- `UI/scripts/shop_weapon_slot.gd`
- `UI/scripts/upgrade_preview.gd`
- `UI/scripts/branch_select_panel.gd`
- `UI/scripts/equipment_slot.gd`
- localization CSV files

Tasks:

- `[ ]` Add prediction helper for UI cards: obtain, fuse to target fuse, or gold conversion.
- `[ ]` Show prediction text on reward weapon cards.
- `[ ]` Show prediction text on shop weapon cards.
- `[ ]` Show current fuse and level cap in upgrade/details UI.
- `[ ]` When level is capped by fuse, disable normal upgrade and show duplicate-weapon breakthrough hint.
- `[ ]` When fully capped, show fully upgraded state.
- `[ ]` Add selected branch summary to `BranchSelectPanel`.
- `[ ]` Keep already selected branches unselectable and hidden from options.
- `[ ]` Add or reserve hooks for fuse sound/highlight/star-refresh feedback.

Acceptance:

- `[ ]` Before choosing a weapon reward, the card tells whether it will be a new weapon, fuse, or gold.
- `[ ]` Shop purchase preview matches actual result.
- `[ ]` Upgrade panel explains why a capped weapon cannot be upgraded.
- `[ ]` Branch panel shows already selected branches as context on the second choice.

Tests:

- `[ ]` Reward card with no equipped duplicate.
- `[ ]` Reward card with equipped duplicate below max fuse.
- `[ ]` Reward card with equipped duplicate at max fuse.
- `[ ]` Upgrade panel at Fuse 1 Lv.3, Fuse 2 Lv.5, and Fuse 3 Lv.7.

Risks:

- UI prediction must use the same logic as actual auto-fuse, or players will see one result and receive another.

### Phase 5: Persistence And Migration

Status: `[ ]`

Goal: ensure fuse, branches, and modules survive save/load and tolerate content changes.

Primary files:

- save/load scripts identified in Phase 0
- `Player/Weapons/Core/weapon.gd`
- `autoload/DataHandler.gd`

Tasks:

- `[ ]` Verify equipped weapons save `fuse`, `level`, `branch_ids`, and modules.
- `[ ]` Verify inventory weapons save the same data where relevant.
- `[ ]` Restore by weapon ID or scene, then fuse, then level, then branch IDs, then modules.
- `[ ]` Reattach branch behavior from `DataHandler`, not saved behavior nodes.
- `[ ]` Skip missing branch IDs with warning.
- `[ ]` Skip incompatible branch IDs with warning.
- `[ ]` Keep only the first two valid branches in saved order.
- `[ ]` Recalculate status after branch and module restore.

Acceptance:

- `[ ]` Save/load preserves fuse and branch behavior.
- `[ ]` Save/load preserves equipped modules.
- `[ ]` Invalid branch IDs do not break save loading.
- `[ ]` Old save with more than two branches keeps the first two legal branches only.

Tests:

- `[ ]` Save and load Fuse 2 with one branch.
- `[ ]` Save and load Fuse 3 with two branches and modules.
- `[ ]` Load a modified test save with a missing branch ID.
- `[ ]` Load a modified test save with more than two branch IDs.

Risks:

- If branch behavior has runtime state that is not derivable from branch ID, that state needs explicit save fields or should be treated as transient.

### Phase 6: Cleanup Legacy Manual Fuse

Status: `[ ]`

Goal: remove obsolete manual fuse code after automatic fuse is stable.

Primary files:

- `UI/scripts/gf_confirm_btn.gd`
- `UI/scripts/gf_item.gd`
- `UI/scripts/UI.gd`
- `autoload/InventoryData.gd`
- `UI/scenes/UI.tscn`
- `UI/scenes/gf_item.tscn`

Tasks:

- `[ ]` Remove unused Gear Fuse scene nodes.
- `[ ]` Remove `ready_to_fuse_list`.
- `[ ]` Remove `on_select_eqp_gf` and `on_select_slot_gf`.
- `[ ]` Remove `add_fuse_item()` and `remove_fuse_item()`.
- `[ ]` Remove `gf_panel_in()`, `gf_panel_out()`, and `update_gf()` if no longer referenced.
- `[ ]` Delete legacy Gear Fuse scripts/scenes once references are gone.
- `[ ]` Remove localization keys used only by deleted manual fuse UI.

Acceptance:

- `[ ]` `rg "ready_to_fuse_list|gf_panel|GearFuse|gf_item|gf_confirm"` finds no live runtime references except intentionally retained migration notes or docs.
- `[ ]` Inventory, upgrade, shop, reward, and branch UI still function.

Tests:

- `[ ]` Run Godot scene load smoke test.
- `[ ]` Navigate core UI panels.
- `[ ]` Trigger auto-fuse and branch selection after cleanup.

Risks:

- Godot scenes may hold script or node references that plain text search misses. Prefer cleanup after manual fuse has been unreachable for at least one working pass.

## Open Implementation Notes

- The target rules avoid changing `create_weapon()` name or signature. That means auto-fuse should be source-driven: rewards, shop, and drops opt into auto-fuse before normal weapon creation.
- Existing duplicate handling inside `Player.create_weapon()` conflicts with the target for some paths because it can merge inventory weapons and convert duplicates into level gains. Either those paths must stop feeding duplicate rewards directly into `create_weapon()`, or the internal duplicate logic must be narrowed carefully without breaking initial loadout and inventory equip behavior.
- `BranchSelectPanel.close_panel(true)` currently has a default-choice escape hatch. That is incompatible with mandatory player branch selection unless reserved for non-fuse debug/test flows.
