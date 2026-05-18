# 技能系统运行流程

本文档按当前代码的实际运行顺序梳理技能系统，供 Agent 后续查阅。这里的“技能系统”包含三条相关路径：

- 玩家主动技能 PS：`Player/Skills/*.gd`
- 武器主动技能 WS 框架：`Player/Weapons/Core/weapon.gd`
- 武器被动/副手技能 passive：各武器脚本的 `get_passive_status()`、`_on_passive_event()` 与 `emit_passive_trigger()`

## 1. 启动时加载数据

游戏启动后，`autoload/DataHandler.gd` 的 `_ready()` 会加载：

- `data/weapons/*.tres`：武器定义
- `data/weapon_branches/*.tres`：武器分支定义
- `data/weapon_passives/*.tres`：武器被动元数据
- `data/mechas/*.tres`：机甲定义
- `data/economy/economy_config.tres`：经济配置

被动元数据会注册到 `GlobalVariables.weapon_passive_branch_list`。之后 UI 可以通过 `passive_id` 查到被动的 `display_name`、`description`、`condition_type`、`refresh_type`、`ui_mode` 和 `icon`。

关键入口：

- `autoload/DataHandler.gd::_ready()`
- `autoload/DataHandler.gd::load_weapon_passive_branch_data()`
- `autoload/DataHandler.gd::read_weapon_passive_branch_definition(passive_id)`
- `data/WeaponPassiveBranchDefinition.gd`

## 2. Player 初始化玩家技能和武器

`Player/Mechas/scripts/Player.gd::_ready()` 会先把自己写入 `PlayerData.player`，再初始化默认玩家主动技能、输入、初始武器、共享热量池和玩家子系统。

默认玩家主动技能来自：

```gdscript
@export var default_active_skill_path: String = "res://Player/Skills/bullet_time"
```

`_setup_default_active_skill()` 会实例化这个 scene，并要求实例继承 `Skills`。实例会被加到 `$ActiveSkill` 节点下。

初始武器由 `custom_ready()` 创建。基类默认创建武器 `"1"`，子类机甲可以覆盖。例如 `heavy_assault.gd` 当前会额外创建 `"13"`。

关键入口：

- `Player/Mechas/scripts/Player.gd::_ready()`
- `Player/Mechas/scripts/Player.gd::_setup_default_active_skill()`
- `Player/Mechas/scripts/Player.gd::custom_ready()`
- `Player/Mechas/scripts/Player.gd::create_weapon(item_id, level)`

## 3. 玩家主动技能 PS 的运行

输入阶段，按 `SKILL_PLAYER` 或旧的 `SKILL` 会调用 `_try_cast_player_active_skill()`。当前 `_ensure_input_actions()` 默认给 `SKILL_PLAYER` 绑定 `Space`。

运行链路：

1. Player 收到输入。
2. Player 发出 `player_active_skill` 和 `active_skill` signal。
3. `Player/Skills/skills.gd` 初始化时监听 Player 的 `player_active_skill`，如果不存在则回退监听 `active_skill`。
4. `Skills._on_player_active_skill_requested()` 检查冷却和 `can_activate()`。
5. 通过后调用具体技能的 `activate_skill()`。
6. 如果 `cooldown > 0`，`Skills` 开始冷却并维护 `_cooldown_remaining`。

例子：

- `Player/Skills/bullet_time.gd`：降低 `Engine.time_scale`，给玩家加速度，Timer 结束后还原。
- `Player/Skills/heavy_assault_heat_lock.gd`：主动锁定共享热量值；同时在 `_physics_process()` 中根据热量比例提供移动速度被动。

关键入口：

- `Player/Mechas/scripts/Player.gd::_input(event)`
- `Player/Mechas/scripts/Player.gd::_try_cast_player_active_skill()`
- `Player/Skills/skills.gd::_bind_player_and_initialize()`
- `Player/Skills/skills.gd::_on_player_active_skill_requested()`

## 4. 武器创建和主副手角色分配

`Player.create_weapon()` 会从 `DataHandler` 读取武器定义，实例化武器 scene，加入 `equppied_weapons`，再放进 `PlayerData.player_weapon_list`。第一把武器会自动成为 main weapon。

之后 `_apply_weapon_roles()` 会给每把武器设置角色：

- 当前主武器：`weapon_role = "main"`
- 其他武器：`weapon_role = "offhand"`

这个角色影响三件事：

- 主武器接收普通攻击输入。
- 很多武器被动只在 main 状态下计数或触发。
- UI Presenter 会把非主武器状态覆盖为 `inactive`，并给出 `inactive_reason = "not_main_weapon"`。

关键入口：

- `Player/Mechas/scripts/Player.gd::create_weapon()`
- `Player/Mechas/scripts/Player.gd::_apply_weapon_roles()`
- `Player/Weapons/Core/weapon.gd::set_weapon_role()`
- `Player/Weapons/Core/weapon.gd::is_main_weapon()`
- `Player/Weapons/Core/weapon.gd::is_offhand_weapon()`

## 5. 每帧战斗输入驱动主武器

`Player._physics_process(delta)` 每帧调用 `_process_combat_input(delta)`。

`_process_combat_input()` 只取当前 main weapon，然后把攻击输入交给武器：

```gdscript
main_weapon.handle_primary_input(pressed, just_pressed, just_released, delta)
```

所以普通攻击不是 Player 自己发射，而是当前主武器实现自己的 `handle_primary_input()` 和 `request_primary_fire()`。武器开火后通常会调用 `notify_main_weapon_fired()`，它会广播 `on_main_weapon_fired` 给所有装备武器。

关键入口：

- `Player/Mechas/scripts/Player.gd::_physics_process(delta)`
- `Player/Mechas/scripts/Player.gd::_process_combat_input(delta)`
- `Player/Weapons/Core/weapon.gd::handle_primary_input(...)`
- 各武器脚本的 `request_primary_fire()`
- `Player/Weapons/Core/weapon.gd::notify_main_weapon_fired()`

## 6. 武器每帧维护自身状态

每把武器的 `Weapon._physics_process(delta)` 会按顺序维护：

1. `_update_reload_state(delta)`
2. `_update_heat_system(delta)`
3. `_update_weapon_active_cooldown(delta)`
4. `_update_weapon_active_hit_window()`
5. `_process_weapon_role_effects(delta)`

`_process_weapon_role_effects()` 会按角色分流：

- main weapon 调 `_process_main_weapon_effect(delta)`
- offhand weapon 调 `_process_offhand_weapon_effect(delta)`

具体武器可以重写这些函数。比如某些被动在主手计数，某些副手效果持续监听。

关键入口：

- `Player/Weapons/Core/weapon.gd::_physics_process(delta)`
- `Player/Weapons/Core/weapon.gd::_process_weapon_role_effects(delta)`

## 7. 换弹是被动系统的重要刷新点

`Weapon.request_reload()` 开始换弹时会广播 `on_reload_started`。换弹完成时 `_finish_reload()` 会：

1. 装满弹药。
2. 将 `is_reloading` 置 false。
3. 调 `_refresh_offhand_skill_on_reload()`，内部会 `refresh_passive_on_reload()`，把 `_offhand_skill_ready = true`。
4. 广播 `on_reload_finished`。
5. 发出 `weapon_reload_completed`。

目前很多武器被动的节奏是：

```text
被动触发 -> notify_offhand_skill_triggered() 让 ready=false -> 等 reload finished 刷新 ready=true
```

关键入口：

- `Player/Weapons/Core/weapon.gd::request_reload()`
- `Player/Weapons/Core/weapon.gd::_finish_reload()`
- `Player/Weapons/Core/weapon.gd::_refresh_offhand_skill_on_reload()`
- `Player/Weapons/Core/weapon.gd::refresh_passive_on_reload()`

## 8. 被动事件广播和接收

Player 里统一用 `_broadcast_weapon_passive_event(event_name, detail)` 把事件发给所有装备武器。

每把武器收到后走：

```text
dispatch_passive_event()
  -> _on_offhand_passive_event() 或 _on_main_passive_event()
  -> _on_passive_event()
```

默认 `_on_passive_event()` 会直接 `emit_passive_trigger()`。具体武器通常会重写 `_on_passive_event()`，检查事件名和 detail，再决定是否触发自己的被动。

常见事件包括：

- `on_reload_started`
- `on_reload_finished`
- `on_main_weapon_fired`
- `on_hit`
- `on_time_tick`
- `on_enemy_killed_nearby`
- `on_main_swapped`
- `on_main_active_cast_failed`

关键入口：

- `Player/Mechas/scripts/Player.gd::_broadcast_weapon_passive_event()`
- `Player/Weapons/Core/weapon.gd::dispatch_passive_event()`
- `Player/Weapons/Core/weapon.gd::_on_passive_event()`

## 9. 被动真正触发时的流程

武器满足条件后，一般会：

1. 检查 `is_offhand_skill_ready()` 或 `is_passive_ready()`。
2. 调 `notify_offhand_skill_triggered(0.0)`，把 `_offhand_skill_ready = false`。
3. 应用实际效果，比如加 buff、加共享热量、额外伤害、冷却缩减等。
4. 调 `emit_passive_trigger(event_name, detail, scope)`。

`emit_passive_trigger()` 会补齐这些字段：

- `passive_id`
- `trigger_type`
- `refresh_type`
- `state_after_trigger`
- `passive_scope`

然后发出 `passive_triggered` signal。

关键入口：

- `Player/Weapons/Core/weapon.gd::is_passive_ready()`
- `Player/Weapons/Core/weapon.gd::notify_offhand_skill_triggered()`
- `Player/Weapons/Core/weapon.gd::notify_passive_triggered()`
- `Player/Weapons/Core/weapon.gd::emit_passive_trigger()`

例子：

- `Player/Weapons/flamethrower.gd`：累计自身热量，reload started 时立刻触发 `flamethrower_heat_prepared`，给共享热量池加热并调用 Player 的 `apply_heat_prepared()`；reload finished 只恢复下一轮累计资格。
- `Player/Weapons/plasma_lance.gd`：花热量攻击累计次数，达到条件后 pending，等自身 reload finished 触发 `plasma_lance_heat_spend_chain_triggered`。

## 10. 模块也会监听被动事件

武器模块可以监听武器的 `passive_triggered` signal。例如 reload 类模块监听 `on_reload_started`，根据弹匣消耗比例给武器临时加成。

典型例子：

- `Player/Weapons/Modules/wmod_reload_damage_boost.gd`
- `Player/Weapons/Modules/wmod_reload_move_boost.gd`
- `Player/Weapons/Modules/wmod_reload_offhand_boost.gd`
- `Player/Weapons/Modules/wmod_reload_shield_boost.gd`
- `Player/Weapons/Modules/wmod_reload_blast_damage.gd`
- `Player/Weapons/Modules/wmod_reload_blast_knockback.gd`

模块通常在 `_enter_tree()` / `_ready()` 注册监听，在 `_exit_tree()` 解除监听，并在 `_physics_process()` 中处理持续时间过期。

## 11. 全局被动效果由 Player 维护

有些被动效果不是只影响当前武器，而是影响所有或多把武器，比如：

- `damage_mul`
- `damage_flat`
- `attack_speed_mul`
- `spread_mul`

这些效果通过 `Player.apply_global_weapon_passive_effect()` 注册到 `_global_weapon_passive_effects`。

Player 每帧调用 `_update_global_weapon_passives()`，同步效果到当前有效武器，过期或来源武器失效后移除。

关键入口：

- `Player/Mechas/scripts/Player.gd::apply_global_weapon_passive_effect()`
- `Player/Mechas/scripts/Player.gd::_update_global_weapon_passives()`
- `Player/Mechas/scripts/Player.gd::_apply_global_weapon_passive_to_weapon()`
- `Player/Mechas/scripts/Player.gd::clear_global_weapon_passives()`

## 12. 被动 UI 展示流程

UI 每帧调用 `_refresh_weapon_passive_panel()`。

运行链路：

1. `UI/scripts/UI.gd` 初始化 `WeaponPassivePresenter`。
2. 每帧调用 `weapon_passive_presenter.get_equipped_weapon_passive_statuses()`。
3. Presenter 遍历 `PlayerData.player_weapon_list`。
4. 对每把武器调用 `get_passive_status()`。
5. 用返回的 `id` 作为 `passive_id`，通过 `DataHandler.read_weapon_passive_branch_definition()` 查 `.tres` 元数据。
6. 合并运行时状态和元数据。
7. UI 创建或复用 row，并显示名称、状态、进度、触发提示和刷新提示。

武器脚本负责运行时状态：

- `state`
- `progress`
- `current`
- `required`
- `ready`
- `trigger_hint`
- `refresh_hint`

`.tres` 元数据负责静态展示：

- `display_name`
- `description`
- `icon`
- `condition_type`
- `refresh_type`
- `ui_mode`

关键入口：

- `UI/scripts/UI.gd::_init_weapon_passive_presenter()`
- `UI/scripts/UI.gd::_refresh_weapon_passive_panel()`
- `UI/scripts/components/weapon_passive_presenter.gd::get_equipped_weapon_passive_statuses()`
- `UI/scripts/components/weapon_passive_presenter.gd::_get_passive_meta()`
- 各武器脚本的 `get_passive_status()`

## 13. 武器主动技能 WS 的当前状态

代码里已经有武器主动技能框架：

- `Weapon.request_weapon_active()`
- `_weapon_active_cd_remaining`
- `weapon_active_cooldown_sec`
- `weapon_active_resource_type`
- `weapon_active_resource_cost`
- `_execute_weapon_active(damage_multiplier)`
- hit window bonus 相关逻辑

Player 也有 `_try_cast_main_weapon_active_skill()`，成功后会发出 `weapon_active_skill` signal。

但当前输入代码中，`SKILL_WEAPON` 调的是 `_try_reload_main_weapon()`，不是 `_try_cast_main_weapon_active_skill()`。也就是说：

- WS 框架存在。
- 当前默认输入实际把 `R` 用作换弹入口。
- 目前真正活跃的武器技能主线，是 reload 刷新的武器被动/副手技能。

关键入口：

- `Player/Mechas/scripts/Player.gd::_input(event)`
- `Player/Mechas/scripts/Player.gd::_try_reload_main_weapon()`
- `Player/Mechas/scripts/Player.gd::_try_cast_main_weapon_active_skill()`
- `Player/Weapons/Core/weapon.gd::request_weapon_active()`
- `Player/Weapons/Core/weapon.gd::_execute_weapon_active()`

## 14. 快速排查路径

如果要查某个被动为什么不触发，优先按这个顺序看：

1. 武器是否是 main：`is_main_weapon()`。
2. 被动是否 ready：`is_passive_ready()` / `_offhand_skill_ready`。
3. 事件是否真的广播：`Player._broadcast_weapon_passive_event()`。
4. 武器 `_on_passive_event()` 是否收到正确 `event_name` 和 `detail.source_weapon`。
5. 是否调用了 `notify_offhand_skill_triggered()`。
6. 是否调用了 `emit_passive_trigger()`。
7. reload finished 是否调用 `_refresh_offhand_skill_on_reload()`。
8. UI 的 `get_passive_status()` 是否反映了真实状态。
9. `.tres` 是否存在匹配的 `passive_id`。

如果要查 UI 为什么不显示，优先看：

1. 武器是否实现 `get_passive_status()`。
2. 返回的 `id` 是否和 `data/weapon_passives/*.tres` 的 `passive_id` 一致。
3. `DataHandler.read_weapon_passive_branch_definition(id)` 是否能读到资源。
4. `WeaponPassivePresenter` 是否把非主武器覆盖为 `inactive`。
5. `UI._refresh_weapon_passive_panel()` 是否拿到了非空 statuses。
