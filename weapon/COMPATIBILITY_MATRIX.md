# Modules/Effects Compatibility Matrix (Current)

## Modules
| Module | Ranged | Melee | Notes |
|---|---|---|---|
| `damage_up` | Yes | Yes | Uses shared damage signal |
| `faster_reload` | Yes | Yes | Uses shared cooldown signal |
| `faster_speed` | Yes | Partial | Works where weapon exposes speed signal |
| `more_hp` | Yes | No | Projectile durability concept; melee N/A |
| `bullet_size_up` | Yes | No | Projectile size concept; melee N/A |
| `stun_on_hit` | Yes | Yes | On-hit plugin path |
| `erosion` | Yes | Yes | On-hit plugin path (status apply) |
| `slow_on_hit` | Yes | Yes | On-hit plugin path + enemy slow API |
| `life_steal` | Yes | Yes | On-hit plugin path |
| `lightning_chain` | Yes | Yes | On-hit plugin path |

## Effects
| Effect | Ranged | Melee | Classification |
|---|---|---|---|
| `linear_movement` | Yes | No | Projectile-only |
| `spiral_movement` | Yes | No | Projectile-only |
| `rotate_around_player` | Yes | No | Projectile-only |
| `fall` | Yes | No | Projectile-only |
| `ricochet_effect` | Yes | No | Projectile-only |
| `return_on_timeout` | Yes | No | Projectile-only |
| `scale_up_by_time` | Yes | No | Projectile-only |
| `spin_effect` | Yes | No | Projectile-only |
| `chase_closest_enemy` | Yes | No | Projectile-only |
| `hexagon_attack` | Yes | No | Projectile-only |
| `explosion_effect` | Yes | No | Projectile-only |
| `erosion_effect` | Legacy | Legacy | Superseded by module plugin implementation |
| `knock_back_effect` | Yes | Planned | Candidate for universal on-hit conversion |
| `speed_change_on_hit` | Yes | Planned | Candidate for universal on-hit conversion |
| `dmg_up_on_enemy_death` | Yes | Planned | Candidate for universal logic source |
