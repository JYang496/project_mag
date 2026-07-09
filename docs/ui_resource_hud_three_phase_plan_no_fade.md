# UI Resource HUD Optimization Plan — Three Implementation Phases

## Purpose

The current lower-left HUD permanently displays a Heat resource meter, but Heat is only relevant to some weapons. This is not ideal because:

1. It occupies HUD space even when the active weapon does not use Heat.
2. It makes Heat look like a global player resource, while it is actually weapon-mechanic-specific.
3. Future weapons may have similar resource meters, but not all of them should be treated as Heat.

Examples of future resource types may include:

- Heat
- Charge
- Energy
- Battery
- Pressure
- Focus
- Ammo-related special state
- Weapon-specific cooldown / lock state

The long-term design should change the lower-left HUD from a permanent `Heat HUD` into a generic:

> Primary Weapon Resource HUD

This file summarizes the implementation in three phases.

Important constraint for this version:

> Do not implement fade-in / fade-out animation yet. Use immediate show / hide behavior for now.

---

# Phase 1 — Low-Risk UI Cleanup

## Goal

Stop showing the Heat meter permanently. The lower-left resource slot should only appear when the currently active weapon actually has a relevant resource to show.

This phase should avoid large architecture changes.

## Main Changes

### 1. Hide Heat meter when the active weapon does not use Heat

Current behavior:

- Heat meter can be visible as a persistent HUD element.
- The UI may treat Heat as a global player resource.

Target behavior:

- If the active weapon uses Heat, show the Heat meter.
- If the active weapon does not use Heat, hide the Heat meter immediately.
- Do not show empty placeholder text such as `Heat: --`.

Suggested rule:

```gdscript
if active_weapon_has_heat_resource:
    show_heat_meter()
else:
    hide_heat_meter()
```

Do not use `get_total_heat_max()` as the main UI visibility condition. That checks whether the player has Heat-capable systems somewhere, but the HUD should care about the active weapon's current resource relevance.

---

### 2. Keep the current Heat display implementation temporarily

In this phase, do not fully refactor Heat into a generic resource system yet.

Keep the existing `CombatResourceMeter` behavior for Heat, including:

- Resource bar drawing
- Ratio display
- Warning state
- Locked / overheated state
- Short text
- Tooltip

The main change is visibility logic only.

---

### 3. Remove or disable empty fallback labels

If old fallback labels still exist, such as:

```text
Heat: --
Ammo: --
```

They should not appear when no valid resource exists.

Target behavior:

- No valid resource: hide the whole resource slot.
- Valid resource: show the visual meter.
- Empty placeholder text should not be visible in normal gameplay.

---

### 4. Do not show non-active weapon Heat in the lower-left slot

If a non-active weapon is overheated, cooling down, or locked, do not keep the lower-left Heat meter permanently visible for that weapon.

For Phase 1:

- Lower-left resource meter only reflects the active weapon.
- Non-active weapon status can be ignored temporarily, or shown only in the weapon selector if that support already exists.

Full non-active weapon indicators are handled in Phase 3.

---

## Suggested Files to Inspect / Modify

Likely files:

```text
UI/scripts/components/hud_presenter.gd
UI/scripts/components/combat_resource_meter.gd
```

Potential related files:

```text
UI scenes containing HeatMeter / resource slot nodes
Weapon scripts that expose Heat state
Player weapon management scripts
```

---

## Acceptance Criteria

Phase 1 is complete when:

1. Starting with a non-Heat weapon does not show a Heat meter.
2. Switching to a Heat weapon shows the Heat meter.
3. Switching back to a non-Heat weapon hides the Heat meter immediately.
4. No `Heat: --` placeholder is visible during normal gameplay.
5. Existing Heat warning / locked behavior still works for Heat weapons.
6. No fade-in or fade-out animation is introduced.

---

# Phase 2 — Generic Primary Weapon Resource System

## Goal

Refactor the HUD so the lower-left resource slot is no longer Heat-specific. It should support any active weapon resource type through a shared interface.

This phase prepares the game for future weapons with resources similar to Heat but mechanically different from Heat.

---

## Main Changes

### 1. Introduce a generic weapon resource interface

Each weapon that has a special resource should be able to expose that resource to the HUD.

Suggested method:

```gdscript
func get_combat_resource_slots() -> Array[Dictionary]:
    return []
```

A weapon with no special resource returns an empty array.

A Heat weapon may return:

```gdscript
return [
    {
        "id": "flamethrower_heat",
        "type": "heat",
        "display_name": "Heat",
        "current": current_heat,
        "max": max_heat,
        "ratio": current_heat / max_heat,
        "state": &"normal",
        "short_text": "",
        "tooltip": "Heat: 72/100",
        "priority": 40,
        "visibility": "active_weapon"
    }
]
```

A future Charge weapon may return:

```gdscript
return [
    {
        "id": "railgun_charge",
        "type": "charge",
        "display_name": "Charge",
        "current": current_charge,
        "max": max_charge,
        "ratio": current_charge / max_charge,
        "state": &"charging",
        "short_text": "CHG",
        "tooltip": "Charge: 64%",
        "priority": 40,
        "visibility": "active_weapon"
    }
]
```

---

### 2. Rename Heat-specific HUD variables

Current Heat-specific naming should be replaced with generic naming where possible.

Recommended rename direction:

```text
heat_meter              -> primary_resource_meter
heat_resource_row       -> primary_resource_row
heat_resource_bar       -> primary_resource_bar
sync_heat_resource_slot -> sync_primary_resource_slot
hide_heat_resource_slot -> hide_primary_resource_slot
build_heat_resource_slot -> build_primary_resource_slot
```

The goal is to prevent future code from adding separate systems like:

```text
sync_charge_resource_slot()
sync_energy_resource_slot()
sync_pressure_resource_slot()
```

Instead, the HUD should sync one generic resource slot based on resource data.

---

### 3. Refactor HudPresenter resource collection

The HUD should collect resources from the active weapon, not from a hardcoded Heat system.

Suggested logic:

```gdscript
func _collect_primary_weapon_resource_slots() -> Array[Dictionary]:
    var slots: Array[Dictionary] = []
    var active_weapon = _get_active_weapon()

    if active_weapon == null:
        return slots

    if active_weapon.has_method("get_combat_resource_slots"):
        slots = active_weapon.call("get_combat_resource_slots")

    return slots
```

Then select the most relevant resource by priority:

```gdscript
func _select_primary_resource_slot(slots: Array[Dictionary]) -> Dictionary:
    if slots.is_empty():
        return {}

    slots.sort_custom(func(a, b):
        return int(a.get("priority", 0)) > int(b.get("priority", 0))
    )

    return slots[0]
```

---

### 4. Extend CombatResourceMeter beyond Heat and Ammo

Current `CombatResourceMeter` may contain Heat / Ammo-specific modes.

Target behavior:

- `CombatResourceMeter` accepts a generic `resource_type`.
- The meter chooses icon, label, color theme, and state display based on `resource_type` and `state`.

Suggested supported types:

```gdscript
const RESOURCE_AMMO := &"ammo"
const RESOURCE_HEAT := &"heat"
const RESOURCE_CHARGE := &"charge"
const RESOURCE_ENERGY := &"energy"
const RESOURCE_BATTERY := &"battery"
const RESOURCE_PRESSURE := &"pressure"
```

Do not hardcode all future resource behavior inside `HudPresenter`. `HudPresenter` should only pass data to the meter.

---

### 5. Implement immediate show / hide only

Since fade animation is intentionally excluded, visibility should remain simple:

```gdscript
if selected_slot.is_empty():
    primary_resource_meter.visible = false
else:
    primary_resource_meter.visible = true
    primary_resource_meter.set_resource(...)
```

Do not add Tween, `modulate.a`, fade delay, or animation state in this phase.

---

## Suggested Files to Inspect / Modify

Likely files:

```text
UI/scripts/components/hud_presenter.gd
UI/scripts/components/combat_resource_meter.gd
```

Likely weapon-side files:

```text
Player/Weapons/
Player/Weapons/Modules/
data/weapons/
```

Specific Heat weapon scripts should expose `get_combat_resource_slots()`.

---

## Acceptance Criteria

Phase 2 is complete when:

1. The lower-left resource meter is no longer named or structured as Heat-only.
2. Heat weapons still display Heat correctly.
3. Non-Heat weapons do not display Heat.
4. A test resource type such as `charge` can be displayed without creating a separate Charge HUD system.
5. `HudPresenter` does not need separate sync methods for each resource type.
6. Visibility is still immediate show / hide, with no fade animation.

---

# Phase 3 — Complete HUD Experience for Multi-Weapon Resource States

## Goal

Improve the full combat HUD so it can communicate both:

1. The active weapon's primary resource in the lower-left HUD.
2. Important non-active weapon states in the weapon selector.

This phase improves usability after the generic resource system exists.

---

## Main Changes

### 1. Keep lower-left HUD focused on the active weapon

The lower-left resource slot should remain dedicated to the active weapon's most important resource.

Examples:

| Active Weapon Type | Lower-Left Resource Slot |
|---|---|
| Normal weapon with no resource | Hidden |
| Flamethrower | Heat |
| Railgun | Charge |
| Battery weapon | Battery / Energy |
| Pressure weapon | Pressure |
| Ammo-heavy weapon | Ammo or reload state, if relevant |

Do not use the lower-left HUD to show every weapon's resource state at once.

---

### 2. Add mini indicators to the weapon selector

Non-active weapon states should appear near the corresponding weapon icon, not in the lower-left primary resource slot.

Recommended weapon selector indicators:

| State | Indicator Suggestion |
|---|---|
| Overheated | Red warning dot / flame icon |
| Cooling | Small progress ring or mini bar |
| Reloading | Reload ring |
| Charge full | Glow border or READY marker |
| Low ammo | Yellow dot |
| Locked / jammed | Lock icon |

This gives the player awareness of all weapons without making the main HUD noisy.

---

### 3. Add resource priority rules

If a weapon exposes multiple resource slots, the HUD should choose the most important one.

Suggested priority scale:

| Priority | Meaning |
|---:|---|
| 100 | Locked / overheated / jammed |
| 80 | Warning state, such as high Heat or low Ammo |
| 60 | Reloading / charging / cooling |
| 40 | Normal active resource |
| 10 | Idle or low-value resource state |

Example:

```gdscript
var priority := 40

if state == &"locked":
    priority = 100
elif state == &"warning":
    priority = 80
elif state == &"reloading" or state == &"charging" or state == &"cooling":
    priority = 60
```

---

### 4. Add resource themes

Different resources should be visually distinguishable.

Suggested theme mapping:

| Resource Type | Visual Direction |
|---|---|
| Heat | Flame / orange-red / overheat warning |
| Charge | Electric / blue-white / ready pulse |
| Energy | Plasma / cyan-purple |
| Battery | Segmented battery icon |
| Pressure | Gauge / compression icon |
| Ammo | Magazine / bullet icon |

Exact colors and icons can follow the existing game art style.

Important: theme mapping should live inside the resource meter or a resource theme helper, not inside every weapon script.

---

### 5. Add tooltip and localization-ready fields

Resource data should include display-friendly fields:

```gdscript
{
    "display_name": "Heat",
    "short_text": "HOT",
    "tooltip": "Heat: 86/100",
    "state": &"warning"
}
```

Future localization can replace `display_name`, `short_text`, and `tooltip` with translation keys if needed.

---

### 6. Keep animation out of this phase unless explicitly requested later

This phase should still avoid fade-in / fade-out animation.

Allowed:

- Immediate show / hide
- Existing warning pulse already implemented inside the meter
- Static icon changes
- Static warning markers

Not included:

- Fade-in
- Fade-out
- Crossfade
- Delayed hiding
- Tween-based visibility transitions

These can be implemented later as a separate visual polish task.

---

## Suggested Files to Inspect / Modify

Likely files:

```text
UI/scripts/components/hud_presenter.gd
UI/scripts/components/combat_resource_meter.gd
UI weapon selector scripts / scenes
Weapon slot UI scripts
Weapon scripts exposing resource states
```

---

## Acceptance Criteria

Phase 3 is complete when:

1. The lower-left HUD only shows the active weapon's primary resource.
2. Non-active weapon warnings appear on the weapon selector, not in the main lower-left resource slot.
3. The HUD can display at least two different resource types, such as Heat and Charge.
4. Resource priority determines which active weapon resource is shown when multiple resources exist.
5. Different resource types have distinct visual themes.
6. No fade-in / fade-out animation is implemented.

---

# Recommended Development Order

## Step 1

Implement Phase 1 first to remove the immediate UX problem:

- Heat should not be permanently visible.
- Heat should only show when the active weapon uses it.

## Step 2

Implement Phase 2 to prevent future technical debt:

- Replace Heat-specific HUD logic with a generic primary resource slot.
- Add `get_combat_resource_slots()` to weapons that need resource display.

## Step 3

Implement Phase 3 when the weapon selector needs more advanced state feedback:

- Add mini indicators for non-active weapons.
- Add resource priority and visual theme mapping.

---

# Summary for Codex

Implement the lower-left HUD resource system in three phases. First, stop showing the Heat meter permanently and only show it when the active weapon uses Heat. Second, refactor the Heat-specific HUD into a generic Primary Weapon Resource HUD using a weapon-provided `get_combat_resource_slots()` interface. Third, move non-active weapon resource warnings into the weapon selector and add priority/theme support for multiple resource types. Do not implement fade-in or fade-out animation in this task; visibility should use immediate show/hide behavior only.
