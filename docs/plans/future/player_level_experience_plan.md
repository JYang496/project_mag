# Player Level and Experience Plan

Status: **Deferred — not part of the current release**  
Created: 2026-08-12

## Purpose

Define a coherent run-level progression system in which EXP has understandable sources, each level-up has an immediate gameplay effect, and the capped curve complements weapon and module growth without creating uncontrolled stat inflation.

## Current implementation baseline

- Player level is capped at 10 in `PlayerData`.
- Mecha definitions provide per-level EXP thresholds and stat arrays.
- `PlayerData.player_exp` handles overflow across multiple levels.
- Chips and some objective/economy rewards can grant EXP, while ordinary combat primarily grants gold.
- `World/player_spawner.gd` applies level-indexed mecha stats during player setup.
- Some abilities read `PlayerData.player_level` live, but changing the level does not centrally reapply all level-indexed mecha stats at runtime.
- Level, EXP, and next-level EXP participate in reward rollback/restoration and save flows.

Primary references:

- `autoload/PlayerData.gd`
- `data/MechaDefinition.gd`
- `data/mechas/`
- `World/player_spawner.gd`
- `World/rewards/reward_manager.gd`
- `Player/Mechas/scripts/player_loot_system.gd`
- `Board/Cells/Bonus/objective_reward_bonus.gd`
- `autoload/TaskRewardManager.gd`
- `autoload/SaveManager.gd`

## Decisions required before implementation

1. Is level progression confined to one run, persistent per mecha, or account-wide?
2. Is a level an automatic stat increase, a player-selected perk, or a hybrid?
3. What is the intended early and late number of battles between level-ups?
4. Should ordinary enemies grant EXP, or should EXP remain an objective-focused currency?
5. How should current health behave when maximum health changes during combat?

## Proposed direction

- Keep a hard level cap and avoid uncapped percentage growth.
- Give EXP a predictable baseline source, then add bonuses for objectives and performance.
- Target frequent early feedback, provisionally one meaningful level every one to two battles, with slower late progression.
- Centralize level-up application in one runtime service or player method.
- Emit an explicit level-up event carrying old level, new level, and the applied changes.
- Apply new stats immediately and consistently; define current-health adjustment as an explicit rule rather than a side effect.
- Show a short level-up presentation and a concise change summary without interrupting dangerous combat moments.
- If levels grant choices, keep their pool separate from normal weapon/module drafts so the economy remains legible.

## Implementation phases

1. Approve progression ownership and the function of levels.
2. Model expected EXP income per battle and revise the threshold curve.
3. Add a centralized level-change event and runtime stat refresh path.
4. Specify health, cooldown, skill, and derived-stat behavior on level change.
5. Add HUD and level-up feedback.
6. Migrate old save values safely and add focused tests.
7. Balance using time-to-level, selection concentration, and run-completion data.

## Acceptance criteria

- Gaining enough EXP updates all intended stats during the current run without requiring a reload.
- Multi-level EXP overflow produces the same result as equivalent incremental grants.
- The HUD and saved data agree on level, current EXP, and the next threshold.
- Maximum-level behavior cannot accumulate unusable EXP or repeatedly trigger level-up feedback.
- Loading a save reproduces the same effective stats as reaching that state during play.
- The level curve reaches its intended cap near the planned run stage without requiring a single mandatory reward source.
- Automated tests cover single-level gain, multi-level overflow, maximum level, save/load, rollback, and live stat refresh.

## Inflation guardrails

- Do not add endless level extension beyond the cap.
- Prefer bounded choices or additive improvements over permanent compounding multipliers.
- Budget player growth against enemy time-to-kill and incoming-damage targets at each chapter.
- Do not make EXP rewards so strong that direct build rewards become false choices.

## Out of scope for this plan

- Endless-mode enemy scaling redesign.
- Weapon and module level-cap changes.
- Account-wide prestige unless separately approved as a future system.
