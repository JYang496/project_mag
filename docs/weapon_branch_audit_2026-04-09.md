# 武器与武器分支设计逻辑审计（2026-04-09）

## 1. 审计结论摘要
- 当前仓库共 **22** 把武器（`data/weapons/*.tres`）。
- 当前仓库共 **6** 个已配置武器分支（`data/weapon_branches/*.tres`）。
- 已接入分支的武器只有 3 把：
  - `machine_gun`（2分支）
  - `flamethrower`（2分支）
  - `rocket_launcher`（2分支）
- 分支系统本质是“**同武器底座上的战术改造层**”，而不是“独立新武器”。

## 2. 武器全量清单（22）
| weapon_id | display_name | scene |
|---|---|---|
| 1 | machine gun | `res://Player/Weapons/machine_gun.tscn` |
| 2 | Charged Blaster | `res://Player/Weapons/charged_blaster.tscn` |
| 3 | Spear | `res://Player/Weapons/spear_launcher.tscn` |
| 4 | shotgun | `res://Player/Weapons/shotgun.tscn` |
| 5 | pistol | `res://Player/Weapons/pistol.tscn` |
| 7 | orbit | `res://Player/Weapons/orbit.tscn` |
| 8 | rocket luncher | `res://Player/Weapons/rocket_launcher.tscn` |
| 9 | laser | `res://Player/Weapons/laser.tscn` |
| 10 | chainsaw luncher | `res://Player/Weapons/chainsaw_launcher.tscn` |
| 11 | dash blade | `res://Player/Weapons/dash_blade.tscn` |
| 12 | hammer | `res://Player/Weapons/hammer.tscn` |
| 13 | flamethrower | `res://Player/Weapons/flamethrower.tscn` |
| 14 | Thermal Cannon | `res://Player/Weapons/thermal_cannon.tscn` |
| 16 | Heat Sink Burst | `res://Player/Weapons/heat_sink_burst.tscn` |
| 17 | Plasma Lance | `res://Player/Weapons/plasma_lance.tscn` |
| 18 | Cryo Carbine | `res://Player/Weapons/cryo_carbine.tscn` |
| 19 | Shatter Buckshot | `res://Player/Weapons/shatter_buckshot.tscn` |
| 20 | Frost Dash Blade | `res://Player/Weapons/frost_dash_blade.tscn` |
| 21 | Glacier Projector | `res://Player/Weapons/glacier_projector.tscn` |
| 22 | Pulse Sidearm | `res://Player/Weapons/pulse_sidearm.tscn` |
| 23 | Arc Coil | `res://Player/Weapons/arc_coil.tscn` |
| 24 | Zero Cannon | `res://Player/Weapons/zero_cannon.tscn` |

## 3. 武器分支矩阵（6）
| weapon_scene | branch_id | display_name | unlock_fuse | behavior_scene | 战斗定位 |
|---|---|---|---:|---|---|
| `res://Player/Weapons/machine_gun.tscn` | `shield_mg` | Shield Machine Gun | 2 | `res://Player/Weapons/Branches/machine_gun_shield_branch.tscn` | 防御控制（前方盾拦截、打断） |
| `res://Player/Weapons/machine_gun.tscn` | `twin_mg` | Gatling Thermal | 2 | `res://Player/Weapons/Branches/machine_gun_gatling_branch.tscn` | 高射速/双通道/热量联动 |
| `res://Player/Weapons/flamethrower.tscn` | `long_cone_flame` | Long Cone Flame | 2 | `res://Player/Weapons/Branches/flamethrower_long_cone_branch.tscn` | 锥形延长、中距压制 |
| `res://Player/Weapons/flamethrower.tscn` | `fire_pulse_aura` | Fire Pulse Aura | 2 | `res://Player/Weapons/Branches/flamethrower_fire_aura_branch.tscn` | 停用主火，改为周期脉冲光环 |
| `res://Player/Weapons/rocket_launcher.tscn` | `salvo_rocket` | Salvo Rocket | 2 | `res://Player/Weapons/Branches/rocket_salvo_branch.tscn` | 多发散射覆盖，单发伤害折算 |
| `res://Player/Weapons/rocket_launcher.tscn` | `napalm_rocket` | Napalm Rocket | 2 | `res://Player/Weapons/Branches/rocket_napalm_branch.tscn` | 爆炸后持续燃烧区 |

核验结果：6 个分支资源的 `weapon_scene` 与 `behavior_scene` 文件均存在。

## 4. 分支系统生效主链路（数据层 -> 触发层 -> 行为层）

### 4.1 数据层
- 武器定义：`WeaponDefinition`（`weapon_id/display_name/scene`）。
- 分支定义：`WeaponBranchDefinition`（`branch_id/unlock_fuse/weapon_scene/behavior_scene`）。
- 启动时 `DataHandler.load_weapon_branch_data()` 按 `weapon_scene` 聚合分支列表。

### 4.2 触发层
- 熔合确认（`UI/scripts/gf_confirm_btn.gd`）会生成 `fused_item`，并调用 `ui.request_weapon_branch_selection(fused_item)`。
- `request_weapon_branch_selection` 仅在以下条件成立时弹窗：
  - 武器还没有 `branch_id`
  - `weapon.get_branch_options()` 非空
  - 分支面板实例有效
- `get_branch_options()` 内部会以当前 `fuse` 过滤 `unlock_fuse`，即 `fuse >= unlock_fuse` 才可选。

### 4.3 行为层
- 选中分支后调用 `weapon.set_branch(branch_id)`。
- `set_branch` 校验 `branch_id` 与 `unlock_fuse`，再挂载 `WeaponBranchBehavior`。
- 后续武器在射击/升级阶段调用分支回调，分支可修改：
  - 冷却倍率（`get_cooldown_multiplier`）
  - 发射方向/弹量（`get_shot_directions`）
  - 伤害倍率与伤害类型（`get_projectile_damage_multiplier`/`get_damage_type_override`）
  - 额外机制（护盾、Napalm配置改写、光环脉冲等）

## 5. 三类已接入分支武器的设计逻辑

### 5.1 Machine Gun：火力分支 vs 控制分支
- `twin_mg`（实际行为为 Gatling）：
  - 大幅提升射速（冷却倍率约 0.42）
  - 双通道散射
  - 热量高时切换为火焰伤害并获得额外伤害
- `shield_mg`：
  - 武器上挂前盾实体
  - 可拦截前方攻击并打断敌人动作
- 设计意图：在同一武器上提供“输出形态强化”和“生存控制强化”二选一。

### 5.2 Flamethrower：锥形压制 vs 光环驻场
- `long_cone_flame`：
  - 扩大射程并收窄角度
  - 附带伤害/冷却参数重调
- `fire_pulse_aura`：
  - 显式禁用主火输入
  - 改为按周期在机体周围释放火脉冲 AoE
- 设计意图：同为火系近中距离武器，一个强化“指向性压制”，一个转换为“站位收益/区域拒止”。

### 5.3 Rocket Launcher：瞬时覆盖 vs 持续压场
- `salvo_rocket`：
  - 一次触发多枚散射
  - 降低单枚伤害，提升覆盖面
- `napalm_rocket`：
  - 改写爆炸配置
  - 形成持续燃烧区并周期伤害
- 设计意图：在“爆发覆盖”与“持续消耗/区域控制”之间提供策略分化。

## 6. 实现风险与一致性问题
1. 分支面板关闭默认选第一项
- `branch_select_panel.close_panel(true)` 会自动发送首个 `branch_id`。
- 风险：玩家可能在未明确确认的情况下被动选中默认分支。

2. `twin_mg` 命名与绑定实现不一致
- 资源 `machine_gun_twin.tres` 当前绑定 `machine_gun_gatling_branch.tscn`。
- 仓库中另有 `machine_gun_twin_branch.gd/.tscn`，但不在当前资源链路使用。
- 风险：策划命名、UI文案、代码行为可能出现认知偏差。

3. 分支覆盖面有限
- 22 把武器中仅 3 把有分支，系统可扩展性已具备，但内容覆盖尚低。

## 7. 测试核对项（本次审计可执行范围）
- 数据完整性（已完成）
  - `branch_id/unlock_fuse/weapon_scene/behavior_scene` 均非空且目标文件存在。
- 触发流程（代码路径已确认）
  - `fuse>=2` 才可选分支；`fuse<2` 不进入候选。
  - 选中后通过 `set_branch` 挂载 `branch_behavior`。
- 行为验证（需运行时实测）
  - Machine Gun：多方向射击、热量阈值伤害类型切换、护盾拦截。
  - Flamethrower：长锥范围变化、光环分支主火禁用。
  - Rocket：齐射散布与 Napalm 持续区域伤害。

## 8. 关键证据文件
- 数据定义
  - `data/WeaponDefinition.gd`
  - `data/WeaponBranchDefinition.gd`
  - `data/weapons/*.tres`
  - `data/weapon_branches/*.tres`
- 加载与查询
  - `autoload/DataHandler.gd`
- 分支触发与UI
  - `UI/scripts/gf_confirm_btn.gd`
  - `UI/scripts/UI.gd`
  - `UI/scripts/branch_select_panel.gd`
- 武器分支挂载核心
  - `Player/Weapons/Core/weapon.gd`
  - `Player/Weapons/Branches/weapon_branch_behavior.gd`
- 三类武器行为接入
  - `Player/Weapons/machine_gun.gd`
  - `Player/Weapons/flamethrower.gd`
  - `Player/Weapons/rocket_launcher.gd`
