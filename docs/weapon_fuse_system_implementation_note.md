# Weapon Fuse System Implementation Note

## Obtain Sources

- Reward selection and route reward grants: auto-fuse enabled through `Player.try_auto_fuse_weapon_obtain()` before normal weapon creation.
- Loot drops: auto-fuse enabled when interacting with a dropped duplicate weapon.
- Shop purchases: auto-fuse enabled after payment and before normal weapon creation.
- Initial loadouts: auto-fuse disabled; mecha setup still calls `Player.create_weapon()` directly.
- Inventory equip and equipment swap: auto-fuse disabled; inventory weapons remain normal inventory/equip flow.
- Test setup and benchmark scripts: auto-fuse disabled unless the test explicitly calls the auto-fuse helper.

## Runtime Rules

- Only equipped weapons can be automatic fuse subjects.
- Inventory-only duplicate weapons return `not_applicable` from prediction and follow normal obtain flow.
- A successful duplicate increases fuse only; it does not alter weapon level.
- Max-fuse duplicates convert to gold using weapon base price with a minimum value.
- Every fuse increase queues a branch choice with weapon reference, weapon id, and target fuse.
- Branch options are recalculated when the branch panel opens.
- Branch selection is deferred during battle and blocks reward, shop, and upgrade interactions until resolved.

## Persistence Hooks

- `DataHandler.build_weapon_save_payload()` records weapon id, level, fuse, branch ids, and equipped modules.
- `DataHandler.instantiate_weapon_from_save_payload()` restores in order: weapon, fuse, level, branch ids, modules, status recalculation.
- `Weapon.restore_branch_ids()` skips missing, incompatible, locked, or excess saved branches with warnings.
