# 武器经济重平衡（2026-04-15）

## 一、现状审计结论

### 1) 武器
- 获取花费：来自 `data/weapons/*.tres` 的 `price`，用于商店购买。
- 升级花费：来自各武器脚本 `weapon_data[level].cost`，升级界面读取“下一等级”的 `cost` 扣费。
- 突破花费（Fuse）：
  - 需要 2 把同名武器作为素材；
  - 当前不消耗金币；
  - 结果武器 `fuse + 1`（上限 3），并在达到分支需求后可选进化分支。

### 2) 武器模组
- 获取：主要来自奖励掉落（`RewardInfo.module_scene`），当前无金币购买入口。
- 升级：同名模组重复获取后自动升星（`module_level`，上限 3），当前不消耗金币。
- 突破：无独立“突破”机制。
- 重复溢出：满级重复模组会转金币，公式为 `max(10, module.cost * 10) * module_level`。
  - 目前模组场景未配置 `cost`，等效按基准 10 计算。

## 二、强度依据（用于武器定价）

使用 `docs/weapon_balance_snapshot.csv` 中武器的高等级 DPS 代理（`shot_dps_proxy + tick_dps_proxy`）作为主要强度基准：
- 最高梯队：`Pistol`、`Dash Blade`、`Sniper`
- 高梯队：`Flamethrower`、`Spear Launcher`、`Cannon`、`Glacier Projector`
- 中梯队：`Plasma Lance`、`Orbit`、`Charged Blaster`、`Shotgun`
- 低梯队：`Chainsaw Luncher`、`Rocket Luncher`、`Laser`、`Machine Gun`

## 三、新定价（已落地）

定价原则：
- 武器获取价与升级单次价格统一；
- 强势武器显著提价，弱势武器下调，拉开经济梯度。

| 武器 | 新获取价 | 新升级单次花费 |
|---|---:|---:|
| machine gun | 4 | 4 |
| laser | 5 | 5 |
| rocket luncher | 6 | 6 |
| chainsaw luncher | 6 | 6 |
| shotgun | 7 | 7 |
| orbit | 8 | 8 |
| Charged Blaster | 9 | 9 |
| Spear | 9 | 9 |
| Glacier Projector | 10 | 10 |
| flamethrower | 11 | 11 |
| Plasma Lance | 12 | 12 |
| Cannon | 13 | 13 |
| Sniper | 14 | 14 |
| dash blade | 16 | 16 |
| pistol | 17 | 17 |

## 四、代码落点

- 武器获取价：`data/weapons/*.tres`（`price` 字段）
- 武器升级花费：`Player/Weapons/*.gd`（`weapon_data` 内 `cost` 字段）
