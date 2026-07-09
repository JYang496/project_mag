# Codex Implementation Brief: Reward Panel UI Redesign

## Purpose

Redesign the current reward selection panel so it feels like a focused game reward decision screen instead of a loose text-heavy selection list.

The current screen shows three reward cards and a confirm button, but the selected reward is only indicated by a border highlight. The top text is too long, the reward cards feel sparse, and the detail text is visually disconnected from the card selection area.

This implementation should improve clarity, visual hierarchy, selected-state feedback, and information density without changing the underlying reward generation or gameplay logic.

---

## High-Level Goals

1. Make it immediately clear that the player must choose exactly one reward.
2. Make the selected reward visually obvious without relying only on a thin border.
3. Reduce top instructional text and move non-essential rule explanations into a compact hint or tooltip.
4. Reorganize each reward card into a clearer comparison unit.
5. Convert the bottom description area into a proper selected-reward detail panel.
6. Keep the confirm action visually connected to the selected reward.

---

## Scope

### In Scope

- Reward selection panel layout cleanup.
- Top title and subtitle simplification.
- Reward card visual hierarchy improvement.
- Strong selected-card state.
- Bottom selected-reward detail panel.
- Confirm button placement and state cleanup.
- Text fallback handling for rewards that lack short descriptions or tags.

### Out of Scope

- Do not change reward generation logic.
- Do not change reward rarity, drop rates, upgrade rules, or weapon/module data.
- Do not change actual reward effects.
- Do not add complex animations in this pass.
- Do not redesign unrelated HUD panels.
- Do not introduce a full new UI framework.

---

## Locate the Relevant Files

Codex should first search the project for the current reward panel implementation.

Recommended search terms:

```text
Choose Reward
Confirm Reward
Normal Route - pick one reward
Newly obtained weapons trigger
Reward
reward_card
reward_slot
```

Likely targets may include one or more of the following:

```text
UI/
UI/scripts/
UI/scenes/
RewardPanel
RewardCard
RewardSlot
RewardSelection
```

Do not assume exact file names before searching. Update the existing scene/script instead of creating a parallel unused implementation.

---

## Current UI Problems to Fix

### 1. Selected State Is Too Weak

Current selected feedback relies mostly on a highlighted border. This is not enough during active gameplay because all cards remain visually similar.

The selected card should use multiple simultaneous indicators:

- Stronger border.
- Brighter or more saturated background.
- `SELECTED` or `CURRENT CHOICE` badge.
- Slightly stronger card shadow/glow if available.
- Optional static scale increase or vertical lift if the existing layout supports it safely.

Do not require animation for this implementation.

---

### 2. Top Text Is Too Verbose

Current top area contains too much explanatory text:

```text
Choose Reward
Normal Route - pick one reward.
Newly obtained weapons trigger the current weapon's evolution effects.
```

This takes attention away from the player's immediate action.

Replace it with:

```text
Choose Reward
Pick 1 option
```

If the evolution rule must remain visible, move it to a compact low-emphasis hint:

```text
New weapons may trigger evolution effects.
```

Preferred placement for the hint:

- Small text near the top-right or below the subtitle.
- Lower opacity than the title/subtitle.
- Or behind a small `?` / `Rules` button if the project already has tooltip support.

Do not let the rule text dominate the screen.

---

### 3. Reward Cards Are Too Loose

Each card should be structured like a comparison card, not a loose text container.

Recommended card structure:

```text
┌────────────────────────────┐
│ TYPE BADGE        SELECTED │
│                            │
│ [Icon]  Reward Name        │
│         Lv.1 / Lv.1 → Lv.2 │
│                            │
│ One-line reward summary    │
│                            │
│ [Tag] [Tag] [Tag]          │
└────────────────────────────┘
```

Minimum required fields per card:

- Reward type badge.
- Icon.
- Reward name.
- Level or level change.
- One-line summary.
- 2–3 compact tags where available.

---

## Target Layout

Recommended final screen structure:

```text
[ Choose Reward ]
[ Pick 1 option ]                                      [?]

┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ NEW WEAPON      │ │ NEW WEAPON      │ │ UPGRADE SELECTED│
│ [icon] Name     │ │ [icon] Name     │ │ [icon] Name     │
│ Lv.1            │ │ Lv.1            │ │ Lv.1 → Lv.2     │
│ short summary   │ │ short summary   │ │ short summary   │
│ [tag][tag]      │ │ [tag][tag]      │ │ [tag][tag]      │
└─────────────────┘ └─────────────────┘ └─────────────────┘

┌────────────────────────────────────────────────────────────┐
│ Machine Gun                                                │
│ Weapon Upgrade · Lv.1 → Lv.2                               │
│ Sustained mid-range automatic fire.                        │
│ • Improves sustained DPS                                   │
│ • Enhances heat/magazine synergy                           │
│ • Good for core weapon builds                              │
│                                             [Confirm Reward]│
└────────────────────────────────────────────────────────────┘
```

---

## Detailed Implementation Requirements

## Phase 1 — Top Area Cleanup

### Required Changes

1. Replace long top text with a compact title block.
2. Use only two primary lines:

```text
Choose Reward
Pick 1 option
```

3. Move the evolution explanation to an optional low-emphasis hint:

```text
New weapons may trigger evolution effects.
```

4. The hint should be visually smaller and lower priority than the reward cards.

### Acceptance Criteria

- The top area no longer contains three large lines of text.
- The reward cards become the visual focus of the screen.
- The player can understand the task without reading a paragraph.

---

## Phase 2 — Reward Card Redesign

### Required Card Fields

Each reward card should display:

| Field | Required | Notes |
|---|---:|---|
| Type badge | Yes | `NEW WEAPON`, `UPGRADE`, `MODULE`, etc. |
| Icon | Yes | Use existing reward/weapon/module icon. |
| Name | Yes | Primary text. |
| Level text | Yes | Example: `Lv.1` or `Lv.1 → Lv.2`. |
| Short summary | Yes | One short line. Use fallback if missing. |
| Tags | Preferred | 2–3 chips, fallback generated from reward data. |
| Selected badge | Yes when selected | Example: `SELECTED`. |

### Type Badge Examples

Use uppercase labels for fast recognition:

```text
NEW WEAPON
WEAPON UPGRADE
MODULE
MODULE UPGRADE
PASSIVE
```

If existing reward type values are different, map them into user-facing labels.

### Card Summary Rules

Prefer existing short description if available.

Fallback order:

1. `short_description`
2. First sentence of `description`
3. Generated fallback based on reward type
4. Empty string only as a last resort

Generated fallback examples:

```text
New weapon added to your loadout.
Upgrade equipped weapon level.
Gain a new weapon module.
Upgrade an existing module.
```

### Tag Rules

Use existing weapon/module metadata if available. Otherwise infer basic tags from known data fields.

Suggested tag sources:

- Weapon delivery type: `Projectile`, `Area`, `Beam`, `Melee`.
- Weapon resource type: `Heat`, `Ammo`, `Charge`, `Energy`.
- Damage/status type: `Freeze`, `Fire`, `Physical`, `DoT`.
- Role: `DPS`, `Crowd Control`, `AoE`, `Single Target`, `Reload`, `Core`.

Limit to 2–3 tags per card. Do not overcrowd the card.

### Card Visual State

Cards should have at least three states:

```text
normal
hover/focus
selected
```

If controller/keyboard navigation exists, `focus` and `selected` must be visually distinct.

### Selected State Requirements

When a card is selected:

- Border should be thicker/brighter than normal.
- Background should be more visible than unselected cards.
- Add `SELECTED` badge.
- The card should visually dominate the other two options.
- The selected state should remain obvious even if the player is not hovering it.

Suggested selected card styling:

```text
border width: 2–3 px
background alpha: stronger than normal
selected badge: top-right
selected text: high contrast
```

Optional non-animated layout enhancement:

- Selected card may be slightly larger, or shifted upward by 4–8 px.
- Only do this if it does not break card alignment or controller focus behavior.

### Acceptance Criteria

- Looking at the panel for one second, it is obvious which card is selected.
- Each card can be compared without reading the bottom description.
- Card content feels structured and consistent.
- Missing metadata does not break the card layout.

---

## Phase 3 — Bottom Selected Reward Detail Panel

### Required Changes

Replace the loose bottom text area with a selected-reward detail panel.

The panel should display:

1. Selected reward name.
2. Reward type and level text.
3. Main description.
4. 2–4 effect bullets if available or generated.
5. Confirm button on the right side or bottom-right inside the panel.

Recommended structure:

```text
Machine Gun
Weapon Upgrade · Lv.1 → Lv.2
Sustained mid-range automatic fire.
• Improves sustained DPS
• Enhances heat/magazine synergy
• Good for core weapon builds

[Confirm Reward]
```

### Detail Description Rules

Use existing detailed description where available.

If the existing description is too long, show:

- First sentence as the summary.
- Remaining important effects as bullets if they can be extracted safely.

If bullet extraction is not reliable, use generic bullets based on reward type.

Fallback bullet examples:

#### New Weapon

```text
• Adds a new weapon to your loadout
• Expands build options
• May trigger evolution effects
```

#### Weapon Upgrade

```text
• Increases weapon level
• Improves the equipped weapon's performance
• Strengthens the current build direction
```

#### Module

```text
• Adds a weapon modifier
• Changes or improves weapon behavior
• Can create build synergy
```

#### Module Upgrade

```text
• Increases module level
• Improves the module's effect strength
• Enhances current weapon synergy
```

### Confirm Button Rules

- The confirm button should be visually attached to the detail panel.
- If no reward is selected, the button should be disabled or display `Select a reward`.
- Once a reward is selected, button text should be `Confirm Reward`.
- The selected reward should still be clearly visible when the button is focused.

### Acceptance Criteria

- The bottom section clearly describes only the currently selected reward.
- The confirm action feels connected to the selected reward.
- There is no large disconnected block of loose text.

---

## Phase 4 — Visual Polish and Consistency

This phase should remain lightweight. Avoid large redesigns beyond the reward panel.

### Recommended Polish

1. Use consistent card padding.
2. Use consistent type badge size.
3. Use consistent icon area dimensions.
4. Use consistent tag chip style.
5. Use lower opacity for secondary text.
6. Avoid multiline overflow inside cards.
7. Use ellipsis or wrapping rules consistently.

### Suggested Text Hierarchy

| Element | Visual Priority |
|---|---:|
| Reward name | Highest inside card |
| Selected badge | High |
| Type badge | Medium-high |
| Level text | Medium |
| Summary | Medium-low |
| Tags | Medium-low |
| Rule hint | Low |

---

## Behavior Requirements

### Mouse

- Hovering a card should show hover/focus styling.
- Clicking a card selects it.
- Selected card remains selected after mouse leaves.
- Confirm button confirms the selected reward.

### Keyboard / Controller

If the current panel supports keyboard/controller input, preserve it.

- Focused card should be visible.
- Selected card should be visible.
- Focus and selected should not be confused.
- Confirm input should confirm the selected reward.

Suggested distinction:

```text
focus = thin outline or subtle glow
selected = strong border + selected badge + stronger background
```

---

## Data Handling Requirements

The UI should not require every reward to have perfect metadata.

Implement safe formatting helpers, for example:

```gdscript
func _get_reward_display_name(reward: Dictionary) -> String:
	# Prefer explicit display name; fallback to item/weapon/module name.

func _get_reward_type_label(reward: Dictionary) -> String:
	# Map internal reward type to user-facing label.

func _get_reward_level_text(reward: Dictionary) -> String:
	# Examples: "Lv.1", "Lv.1 → Lv.2".

func _get_reward_summary(reward: Dictionary) -> String:
	# Prefer short description, then first sentence of description, then generated fallback.

func _get_reward_tags(reward: Dictionary) -> PackedStringArray:
	# Use metadata or infer from weapon/module fields. Limit to 2–3 tags.

func _get_reward_detail_bullets(reward: Dictionary) -> PackedStringArray:
	# Use effect data if available, otherwise generated fallback bullets.
```

Use the project's actual reward data type. The above functions are conceptual names; adapt them to the existing script style.

---

## Styling Notes

Do not hard-code excessive one-off visual rules if the project already uses shared colors/constants.

Recommended approach:

- Add small helper constants for selected/normal/hover state colors if needed.
- Reuse existing theme colors where possible.
- Keep type colors consistent across cards and detail panel.

Suggested type color mapping:

| Reward Type | Suggested Color Direction |
|---|---|
| New Weapon | Green / mint |
| Weapon Upgrade | Blue |
| Module | Purple |
| Module Upgrade | Cyan / violet |
| Rare / special reward | Gold |

Exact colors should match the existing game theme.

---

## Do Not Do

- Do not keep the original long top instructions as large primary text.
- Do not rely only on border color for selected state.
- Do not fill reward cards with long descriptions.
- Do not make the bottom panel repeat all card content without adding detail.
- Do not change reward mechanics.
- Do not break existing confirm/cancel flow.
- Do not introduce heavy animation in this pass.

---

## Final Acceptance Checklist

The implementation is complete when all of the following are true:

- [ ] Top text is reduced to `Choose Reward` + `Pick 1 option` or equivalent.
- [ ] Optional rule explanation is visually low-priority or hidden behind a hint/tooltip.
- [ ] Each reward card has a clear type badge.
- [ ] Each reward card has name, icon, level text, summary, and optional tags.
- [ ] Selected card has strong visual treatment beyond a thin border.
- [ ] Selected card shows a `SELECTED` or equivalent badge.
- [ ] Bottom area is a selected-reward detail panel.
- [ ] Confirm button is visually connected to the selected reward detail panel.
- [ ] Missing metadata falls back safely.
- [ ] Mouse selection still works.
- [ ] Keyboard/controller selection still works if previously supported.
- [ ] Reward generation and reward effects are unchanged.

---

## Suggested Commit Message

```text
Improve reward selection panel UI hierarchy and selected state
```

---

## Summary for Codex

Refactor the reward selection screen into a cleaner three-part layout: compact title area, structured reward cards, and a selected-reward detail panel. Make selected cards visually obvious using strong border/background treatment and a selected badge. Remove or de-emphasize verbose rule text. Keep all reward mechanics unchanged.
