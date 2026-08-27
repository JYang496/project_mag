# Weapon Trigger Contract

Last reviewed: 2026-08-17.

## Design Goal

Weapon skills use a small shared vocabulary so players can understand a new weapon from its trigger instead of memorizing a separate rule for every weapon. The system should reward rotating main weapons, exhausting useful portions of a magazine, and building short cross-weapon sequences.

Every weapon passive and branch must use at most two of the eight canonical trigger families below. A branch may change the payoff, but should not introduce a ninth trigger family.

## Canonical Trigger Families

| Trigger | Runtime event | Default rule | Intended rhythm |
| --- | --- | --- | --- |
| Weapon Entry | `weapon_entered_main` | Trigger when a selectable weapon becomes the main weapon | Switch in for an opening payoff |
| Magazine Quarters | `magazine_quarter_spent` | Emit at 25%, 50%, 75%, and 100% magazine expenditure | Reward committing ammo before rotating or reloading |
| Reload Start | `reload_started` | Reload skills trigger only when reload begins | Make reload a deliberate commitment |
| Stow Charge | `stow_charge_ready` | Ready after 5 seconds in an offhand slot | Rotate away, then return for a prepared attack |
| Crossfire | `cross_weapon_hit` | Hit a target within 2 seconds of another weapon hitting it | Build short multi-weapon combos |
| Continuous Hits | `continuous_hit_threshold` | Thresholds at 3, 6, and 10 hits; sequence breaks after 0.8 seconds | Reward sustained accuracy or rapid delivery |
| Kill Reward | `target_killed` | Trigger from a kill attributed to the weapon | Reward finishing and target selection |
| Shared Resource Release | `shared_resource_release` | Fire using the shared global weapon-energy pool | Build energy with attacks, then rotate into a release weapon |

`primary_attack_fired` is an internal accounting event used to consume limited attack charges. It is not a ninth player-facing trigger.

## Weapon Assignment

| Weapon | Canonical triggers | Current payoff |
| --- | --- | --- |
| Cannon | Stow Charge; Shared Resource Release on Zero branch | A 5-second stow primes a 1.45x Breach Shot that applies 1.2x damage taken for 4 seconds; Zero Cannon spends global energy for burst damage |
| Chainsaw Launcher | Continuous Hits | Three uninterrupted hits arm slow and vulnerability; wall bounces only extend projectile lifetime |
| Charged Blaster | Shared Resource Release; Continuous Hits inside the released beam | Full energy empowers Beam Resonance and repeated hits ramp its damage |
| Dash Blade | Continuous Hits | Three uninterrupted hits trigger its control payoff; it cannot become a selectable main weapon |
| Flamethrower | Magazine Quarters | Spending all four quarters grants Heat Prepared |
| Glacier Projector | Stow Charge | A 5-second stow primes Cold Snap for the next attack |
| Laser | Shared Resource Release | Full energy starts Focus Channel |
| Machine Gun | Magazine Quarters; Reload Start | Magazine quarters build up to 4 charges; starting reload grants +8% Machine Gun damage per charge for 8 seconds |
| Orbit | Weapon Entry; Shared Resource Release | Entry empowers the next deployment; full energy expands deployment |
| Auto Pistol | Continuous Hits; Shared Resource Release on Arc branch | Six uninterrupted hits open the mark window; it cannot become a selectable main weapon |
| Plasma Lance | Shared Resource Release | Full energy deals fixed 1.85x damage and spends up to 35 shared Heat |
| Rocket Launcher | Kill Reward | Each attributed kill releases the cluster payoff, subject to its short internal cooldown |
| Shotgun | Weapon Entry; Crossfire | Entry empowers the first volley; Crossfire triggers the breach payoff |
| Sniper | Stow Charge; Crossfire | Either trigger primes the next shot for the maximum 1.8x distance multiplier |
| Spear Launcher | Continuous Hits; Reload Start | Repeated spear damage builds charge; starting reload at 10 charge fires one fixed 8-direction volley |

## Reload Contract

- `reload_started` is the only reload timing available to weapon skills and modules.
- `reload_finished` remains an internal ammunition lifecycle event. It must not appear in `ModuleTriggerSpec`, passive conditions, branch refresh rules, or HUD trigger text.
- Reload effects scale from the ammo snapshot captured when reload starts.
- Reloaded Force primes the next attacks when reload starts: level 1 grants up to +20% for 3 attacks, level 2 up to +30% for 4 attacks, and level 3 up to +40% for 5 attacks. The bonus scales with the spent-magazine ratio.

## Shared Resources and Damage

- Global weapon energy is the resource used by Shared Resource Release. Shared Heat is a separate global modifier and is not merged into energy.
- Energy release weapons may have different gains and payoffs for delivery balance, but they share the same full-pool release interaction and HUD language.
- Heat Prepared belongs to the player, not the Flamethrower instance. Its bonus therefore applies to fire damage from any player weapon, including fire-converted branches.
- Orbit consumes all ammunition currently in its magazine in one deployment. The amount consumed determines the base satellite count before branch or energy-release additions.

## Swap and HUD Contract

- Role changes are authoritative through `weapon_entered_main` and `weapon_entered_offhand`.
- The legacy `on_main_swapped` passive broadcast is removed; it had no remaining consumer and duplicated role-change information.
- HUD trigger details must display the eight player-facing family names, not internal snake-case event keys.
- Passive descriptions state the trigger and its rearm/refresh rule. Branch descriptions may describe payoff differences but must reuse the canonical trigger vocabulary.

## Implementation Sources

- `Player/Weapons/Core/weapon_trigger_runtime.gd`: shared timing, magazine, Crossfire, and Continuous Hit state.
- `Player/Weapons/Core/weapon_event.gd`: typed event identifiers.
- `Player/Weapons/Core/weapon_ammo_controller.gd`: reload-start snapshot and ammunition lifecycle.
- `UI/scripts/components/weapon_passive_panel_view.gd`: player-facing trigger labels.
- `data/weapon_passives/`: passive metadata and descriptions.
