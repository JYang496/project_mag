# Build Tag Taxonomy

Phase 1 locks the player-facing wording for build readability. These tags are display language only; they do not change weapon behavior, reward weights, branch unlocks, module compatibility, or numeric values.

## Canonical Tags

| Tag | Use For | Current Source Examples |
| --- | --- | --- |
| Heat | Heat generation, heat spending, overheat, shared heat capacity | Machine Gun, Flamethrower, Plasma Lance, Heat modules |
| Mark | Mark application, marked-target payoff, mark-assisted execution | Auto Pistol, Spear Launcher, Zero Cannon |
| Freeze | Freeze damage, frost stacks, slows, frost fields | Glacier Projector, Cryo branches, Freeze modules |
| Reload | Reload-start, reload-finished, ammo-spend, reload-duration hooks | Reload modules, Heat passives, Cold Snap |
| Close | Short-range, melee, contact, player-centered pressure | Dash Blade, Shotgun, Chainsaw Launcher, Flamethrower |
| Area | Cone, burst, splash, field, grouped enemy coverage | Rocket Launcher, Prism branches, Fire Pulse Aura |
| Beam | Beam hit or channel behavior | Laser, Charged Blaster, beam modules |
| Projectile | Projectile travel, pierce, spread, spawn behavior | Machine Gun, Spear Launcher, Sniper, projectile modules |
| Melee | Melee-contact delivery | Dash Blade and close-contact modules |
| On Hit | Hit-driven or damage-dealt module triggers | Life Steal, Lightning Chain, status/debuff trigger modules |
| Execute | Low-HP, kill, overkill, or finishing payoff | Zero Cannon, Overkill Recovery, Vampiric Surge |
| Defense | Shield, damage reaction, survival, interruption | Orbit passive, Shield Machine Gun, Reload Barrier |
| Economy | EXP, Gold, chip, duplicate conversion, shop value | Reward fallback and economy options |

## Display Rules

- Tags are short Title Case phrases: `Heat`, `Mark`, `Freeze`, `Reload`, `Close`, `Area`, `Beam`, `Projectile`, `Melee`, `On Hit`, `Execute`, `Defense`, `Economy`.
- Weapon descriptions should answer: combat range, core trigger or rhythm, and suitable build axes.
- Branch descriptions should answer: what playstyle the branch pushes toward and what it sacrifices or emphasizes.
- Passive descriptions should answer: trigger condition and refresh or recharge method.
- Module descriptions should answer: suitable weapon/tag targets and trigger timing. The shared module display appends these from existing `module_tags`, required traits, delivery types, capabilities, and hooks.

## Current Limits

- `Mark`, `Reload`, `Close`, `Execute`, `Defense`, and `Economy` are player-facing taxonomy tags, not all formal `WeaponTrait` values.
- Module compatibility remains enforced by the existing required traits, delivery types, capabilities, hooks, and property checks.
- Reward affinity and current-build recommendation scoring belong to later phases; this phase only makes existing text and tags readable.
