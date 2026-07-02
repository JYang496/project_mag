# Roguelike Gameplay Optimization Sequence Prompt

用途：用于今后按顺序优化 `project_mag` 的 roguelike 玩法、奖励选择、构筑可读性、路线压力和验证体系。每一阶段都应先读当前代码和资源，再做小范围修改；不要凭旧记忆或旧文档直接改。

当前基线快照，来自 2026-06-30 的仓库检查：

- 武器资源：`data/weapons/*.tres`，15 把。
- 武器被动：`data/weapon_passives/*.tres`，15 个。
- 武器分支：`data/weapon_branches/*.tres`，28 个。
- 武器模组场景：`Player/Weapons/Modules/wmod_*.tscn`，排除 `wmod_base.tscn` 后 56 个。
- 任务模块：`data/task_modules/task_*.tres`，5 个。
- 路线：`data/routes/normal_route.tres`、`data/routes/difficult_route.tres`、`data/routes/bonus_route.tres`。
- 当前普通战斗奖励配置里 `data/EconomyConfig.gd` 和 `data/economy/economy_config.tres` 的 `reward_module_options_enabled` 为 `true`，任务模块奖励开启。
- 当前推荐验证路径：
  - 新功能、行为、UI、奖励、战斗、路线、生成压力测试优先使用 Godot MCP：`get_project_info` -> `run_project(scene="res://tests/scenes/<domain>/<test>.tscn")` -> `get_debug_output` -> `stop_project`。
  - MCP `run_project(scene=...)` 优先指向 scene-backed test，也就是 `res://tests/scenes/<domain>/*.tscn`；`res://tests/headless/<domain>/*.gd` 是 runner script，不要直接当作 MCP scene 参数，除非已经确认该入口可由项目运行器加载。
  - 必须检查 MCP debug output 中是否出现 `PASS`、`FAIL`、`ERROR` 或关键断言日志；不能只看运行是否启动成功。
  - Shell Godot `--check-only` 作为全仓语法/资源 gate，或 MCP 无法覆盖、需要 import/class discovery 时的补充验证。
  - 当前 shell gate 命令：`& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit`

## 总控提示词

```text
你在 Windows 本地仓库 D:\Godot Projects\project_mag 工作。目标是按顺序优化这个动作 roguelike / roguelite 项目的玩法深度、奖励选择、构筑可读性和路线压力。

先执行 `git status --short`，不要回滚或覆盖其他人的改动。每个阶段开始前必须重新读取当前相关代码和资源，不能依赖旧文档直接修改。优先保持现有架构：WeaponDefinition / WeaponPassiveBranchDefinition / RewardInfo / RewardSelectionPanel / RunRouteDefinition / SpawnCombatProfile / CellTaskModuleRuntime / InventoryData / PlayerData 等既有路径。

按阶段推进，不要跨阶段大改：
0. 建立当前玩法基线和风险清单。
1. 修复武器、被动、分支、模组的构筑文案和标签可读性。
2. 让战斗后奖励更像 roguelike draft，重点评估并逐步开放模组奖励选项。
3. 强化路线差异，让 Normal / Difficult / Bonus 不只是奖励数值差异。
4. 在奖励和管理 UI 中显示“与当前构筑的关系”，减少玩家猜测。
5. 强化敌人遭遇主题，让不同构筑面对不同战斗题型。
6. 建立构筑验证矩阵和回归测试，证明优化没有破坏核心循环。

每阶段都要输出：
- 实际读取过的文件。
- 修改过的文件。
- 关键设计决策。
- 未做事项和原因。
- 验证命令和结果。

每阶段最低验证：
- 如果阶段涉及新功能、行为、UI、奖励、HUD、分支、武器、任务模块、路线或生成压力，优先通过 Godot MCP 运行对应 focused scene/test，并读取 `get_debug_output` 判断结果。
- MCP 优先运行 `res://tests/scenes/<domain>/*.tscn`；如果当前只有 `tests/headless/<domain>/*.gd` runner，应优先寻找或补建对应 scene-backed test，或明确说明为什么改用 shell `--script`。
- 同时运行 shell Godot `--check-only` 作为全仓语法/资源 gate：`& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit`
- 只有在 MCP 工具不可用、目标验证不是 scene/project 运行、或需要 import/class discovery 时，才把 shell headless 命令作为主要运行验证。
- 不要只用源代码检查或 `--check-only` 替代新功能的运行验证。
```

## 阶段 0：玩法基线审计

```text
阶段目标：不改代码，生成当前玩法基线报告，为后续阶段锁定事实来源。

读取范围：
- data/weapons/*.tres
- data/weapon_passives/*.tres
- data/weapon_branches/*.tres
- Player/Weapons/Core/*.gd
- Player/Weapons/Modules/wmod_base.gd
- Player/Weapons/Modules/wmod_*.gd
- World/rewards/reward_manager.gd
- World/rewards/reward_info.gd
- data/EconomyConfig.gd
- data/routes/*.tres
- data/spawns/spawn_combat_profile.tres
- data/spawns/*.gd
- autoload/CellTaskModuleRuntime.gd
- autoload/TaskRewardManager.gd
- UI/scripts/reward_selection_panel.gd

输出文件：
- docs/audits/roguelike_gameplay_baseline_audit.md

报告必须包含：
- 当前主要构筑轴：Heat、Mark、Freeze、Reload、Close Range、Area、On Hit、Execute、Economy、Task Module。
- 每个构筑轴的真实代码或资源来源。
- 当前奖励池实际会给什么，不会给什么。
- 当前路线差异。
- 当前敌人压力和关卡生成框架。
- 文案、UI、奖励池、路线、敌人题型、测试覆盖的风险清单。

禁止事项：
- 不修改 gameplay 代码。
- 不修改资源数值。
- 不新增测试。

验证：
- 运行 shell Godot `--check-only` 作为只读基线 gate。
- 报告中列出所有命令和结果。
```

## 阶段 1：构筑文案和标签统一

```text
阶段目标：先让玩家能读懂构筑。修复武器、被动、分支、模组显示文案中的 test 文案、大小写混乱、缺少构筑关键词等问题。

优先读取：
- data/weapons/*.tres
- data/weapon_passives/*.tres
- data/weapon_branches/*.tres
- Player/Weapons/Modules/wmod_base.gd
- Player/Weapons/Modules/wmod_*.gd
- autoload/LocalizationManager.gd
- data/localization/*.csv
- UI/scripts/reward_selection_panel.gd
- UI/scripts/management/module_management_detail_presenter.gd
- UI/scripts/weapon_obtain_preview_formatter.gd

建议写入范围：
- data/weapons/*.tres
- data/weapon_passives/*.tres
- data/weapon_branches/*.tres
- Player/Weapons/Modules/wmod_*.gd 的 `ITEM_NAME` 和效果描述方法
- data/localization/*.csv，如果当前 UI 走本地化键
- 可新增 docs/design/build_tag_taxonomy.md

硬性要求：
- 不改变数值、触发条件、掉落权重、分支解锁等级。
- 每个武器说明必须回答：战斗距离、核心触发、适配构筑轴。
- 每个分支说明必须回答：它把武器推向什么玩法，牺牲什么。
- 每个模组说明必须回答：适合哪些武器/标签，触发时机是什么。
- 标签命名统一为短词：Heat、Mark、Freeze、Reload、Close、Area、Beam、Projectile、Melee、On Hit、Execute、Defense、Economy。

推荐顺序：
1. 建立 `docs/design/build_tag_taxonomy.md`，定义标签和展示语法。
2. 修复明显占位文案：shotgun、laser、machine gun、chainsaw launcher 等。
3. 给被动描述补上触发和刷新方式，但不要制造不存在的效果。
4. 给模组描述补上适用范围，尤其是 Heat、Reload、Freeze、On Hit 类。
5. 检查奖励卡和管理面板是否能显示这些描述。

验证：
- 优先用 Godot MCP 运行涉及 reward/module detail 的 UI focused scene/test，并读取 debug output。
- 运行 shell Godot `--check-only`。
- 如果改了 CSV，增加或运行已有 CSV parse 检查。
- 没有现成 UI 测试时，至少新增一个轻量测试验证关键文本字段能被读取，并优先通过 MCP 跑该测试。

最终汇报：
- 列出改了哪些文案类别。
- 列出未改的文案和原因。
- 明确说明没有改变机制或数值。
```

## 阶段 2：战斗后奖励 draft 深化

```text
阶段目标：让每场战斗后的奖励选择更像 roguelike draft，而不是只偏武器升级。当前模组奖励开关已经开启，重点验证模组奖励进入普通奖励池后的权重、去重、满级过滤、保底进度和任务奖励隔离。

优先读取：
- data/EconomyConfig.gd
- World/rewards/reward_manager.gd
- World/rewards/reward_info.gd
- UI/scripts/reward_selection_panel.gd
- autoload/InventoryData.gd
- autoload/TaskRewardManager.gd
- autoload/CellTaskModuleRuntime.gd
- tests/headless 与 reward/task/module 相关测试

建议写入范围：
- data/EconomyConfig.gd
- World/rewards/reward_manager.gd
- World/rewards/reward_info.gd
- UI/scripts/reward_selection_panel.gd
- tests/headless/reward 或 tests/headless/ui 下新增 focused tests
- docs/design/reward_draft_rules.md

硬性要求：
- 不一次性重写奖励系统。
- 保留至少一个武器进度保底，避免玩家 build 卡死。
- 模组奖励开放要有开关或配置，不要硬编码散落在 UI。
- 不让已满级模组、满 fuse 武器继续污染奖励池。
- 奖励卡必须显示：类型、稀有度，以及可由当前数据结构生成的短标签。模组奖励的构筑关系必须来自 `MODULE_FIT_FORMATTER.build_display_data()` 返回的 `fit_status`、`fit_label`、`effect_tags`、`fit_warnings`，不要另造平行字段。非模组奖励只展示已有奖励类型/效果标签，不强行生成武器适配判断。

推荐顺序：
1. 写 `docs/design/reward_draft_rules.md`，明确普通奖励、困难路线奖励、Bonus 路线奖励、任务奖励的分工。
2. 重新读取 `data/EconomyConfig.gd` 和 `data/economy/economy_config.tres`，确认 `reward_module_options_enabled` 当前值；不要按旧文档假设它仍为 `false`。
3. 在 `RewardManager.build_reward_selection_options()` 中验证每组奖励至少包含一个进度项，同时允许模块/经济项竞争。
4. 在 `RewardSelectionPanel` 中显示模组适配标签和当前构筑关联；实现时复用 `UI/scripts/module_fit_formatter.gd`，不要在面板里重复推断 required traits / delivery types。
5. 新增测试：奖励池去重、满级过滤、保底武器进度、模组奖励开关、任务奖励不被普通奖励破坏。

验证：
- 优先用 Godot MCP 运行或新增 reward selection focused test，并读取 debug output。
- 优先用 Godot MCP 运行 task reward flow 相关测试，确保任务模块奖励仍然阻塞且可领取。
- 运行 shell Godot `--check-only`。

最终汇报：
- 奖励池现在会出现哪些类型。
- 哪些类型仍然不会出现，以及原因。
- 概率/权重如何配置。
- 哪些测试覆盖了奖励去重和保底。
```

## 阶段 3：路线差异和风险回报

```text
阶段目标：让 Normal / Difficult / Bonus 成为 run 决策，而不是只改变奖励等级。

优先读取：
- data/routes/*.tres
- data/routes/RunRouteDefinition.gd
- autoload/RunRouteManager.gd
- World/rest_area_route_flow.gd
- World/rewards/reward_manager.gd
- data/spawns/spawn_combat_profile.tres
- World/spawn/enemy_spawner.gd
- World/spawn/spawn_budget_runtime.gd

建议写入范围：
- data/routes/RunRouteDefinition.gd
- data/routes/*.tres
- World/rest_area_route_flow.gd
- World/spawn/enemy_spawner.gd 或 spawn runtime，仅在确实需要 route modifier 时改
- docs/design/route_risk_reward_design.md
- tests/headless/spawn 或 tests/scenes/spawn 下新增 focused tests；当前没有 `tests/headless/route` 目录，只有确需独立 route domain 时才新增 route 测试目录。

硬性要求：
- 不把路线差异只做成 UI 文案。
- 不让 Difficult 变成单纯 HP 膨胀。
- Bonus Route 必须保持无战斗奖励路线的清晰身份，除非用户另行确认。
- 路线修饰必须能序列化保存或从 route history 恢复；优先使用 `RunRouteManager.get_route_history_snapshot()` 和 `RunRouteManager.restore_route_history()`，不要另建平行历史结构。

推荐顺序：
1. 给路线定义补充可扩展字段：敌人压力倍率、特殊敌人权重、奖励池权重、任务奖励机会等。
2. Normal 保持标准体验。
3. Difficult 增加明确战斗题型，例如更多支援敌/远程压力/精英压力，而不是只提高奖励等级。
4. Bonus 保持无战斗，但奖励应偏构筑修补或经济修补，不要比 Difficult 更强。
5. 在路线选择 UI 中展示清楚：风险、敌人主题、奖励增益。

验证：
- 优先用 Godot MCP 运行路线资源 sanitize、Spawn profile 或 route selection 相关测试，并读取 debug output。
- 手动或通过 MCP/headless 验证 Difficult 的 route modifier 实际影响 spawn/reward，而不是只存在资源字段。
- 运行 shell Godot `--check-only`。

最终汇报：
- 每条路线的真实规则。
- 规则在哪些文件实现。
- 哪些测试证明 route history 和 reward/spawn 修改生效。
```

## 阶段 4：奖励与管理 UI 的模组适配提示

```text
阶段目标：玩家看到模组相关奖励或管理界面时，能知道该模组是否适配当前武器，以及它通过短标签强化哪一方面的效果。

优先读取：
- UI/scripts/reward_selection_panel.gd
- UI/scenes/reward_selection_panel.tscn
- UI/scripts/management/module_management_detail_presenter.gd
- UI/scripts/management/module_management_card_factory.gd
- UI/scripts/weapon_obtain_preview_formatter.gd
- autoload/InventoryData.gd
- autoload/PlayerData.gd
- Player/Weapons/Core/weapon.gd
- Player/Weapons/Modules/wmod_base.gd

建议写入范围：
- UI/scripts/reward_selection_panel.gd
- UI/scripts/weapon_obtain_preview_formatter.gd
- UI/scripts/management/module_management_detail_presenter.gd
- UI/scripts/module_fit_formatter.gd，仅在现有字段不足时扩展
- tests/scenes/ui 和 tests/headless/ui 下新增 UI data-contract tests；MCP 优先运行 scene-backed test

硬性要求：
- 不在 UI 里重新实现 gameplay 规则。
- UI 只能消费 weapon/module/status 数据和 helper 输出。
- 不强调“最佳适配”，不生成带主观排序意味的推荐理由。
- 不让奖励卡变成长段说明；卡片只显示适配状态和 1-3 个效果短标签。
- 模组适配显示必须复用 `UI/scripts/module_fit_formatter.gd` 的 `build_display_data(module_instance, target_weapon)`，并只消费 `fit_status`、`fit_label`、`effect_tags`、`fit_warnings`。如果需要更多字段，先扩展 helper 和测试，不要在 `RewardSelectionPanel` 或管理面板里复制判断逻辑。
- “当前构筑”在本阶段只指 `MODULE_FIT_FORMATTER.get_current_weapon()` 能拿到的当前武器及其 trait / delivery type 适配关系；不要引入全局 build score、最佳推荐排序或隐藏权重。
- 兼容普通奖励、任务奖励、武器升级、武器获得、模组获得、经济奖励；非模组奖励可只显示已有奖励类型/效果标签，不强行生成武器适配判断。

推荐顺序：
1. 先读取 `UI/scripts/module_fit_formatter.gd`，沿用现有展示数据结构：`effect_tags`、`fit_status`、`fit_label`、`fit_warnings`。
2. 在 helper 中从武器 trait、模组 required traits、delivery type、module tags 生成展示数据；如果 helper 已覆盖需求，只改调用方和测试。
3. Reward card 只展示 `fit_label` 和 1-3 个 `effect_tags`，例如 Damage、Reload、On Hit、Heat、Freeze、Area、Defense、Economy。
4. Detail panel 只补充 `fit_warnings` 或必要适配事实，例如“当前武器满足需求”或“当前武器缺少 required trait / delivery type”，不展开“为什么最佳”。
5. 对不适配当前武器的模组给出清晰警告，但不要阻止玩家选择，除非现有规则本来阻止。

验证：
- 优先用 Godot MCP 运行 UI focused test：不同 reward kind 都能生成 display data。
- 优先用 Godot MCP 运行模组兼容性 test：required traits / delivery types 不被 UI 错读。
- 运行 shell Godot `--check-only`。

最终汇报：
- UI 现在显示哪些模组适配状态和效果短标签。
- 数据来自哪里。
- 哪些奖励类型已覆盖。
- 哪些复杂推荐或最佳适配判断明确未做。
```

## 阶段 5：敌人遭遇主题强化

```text
阶段目标：让不同构筑面对不同战斗题型，避免所有强构筑只是在同一个刷怪场景里比 DPS。

优先读取：
- data/spawns/spawn_combat_profile.tres
- data/spawns/*.gd
- World/spawn/enemy_spawner.gd
- World/spawn/spawn_budget_runtime.gd
- Npc/enemy/scripts/*.gd
- Npc/enemy/scenes/*.tscn
- tests/headless/spawn/*.gd
- tests/headless/enemy/*.gd

建议写入范围：
- data/spawns/spawn_combat_profile.tres
- data/spawns/*.gd
- World/spawn/*.gd
- Npc/enemy/scripts/*.gd，仅限明确敌人行为问题
- tests/headless/spawn/*.gd
- docs/design/encounter_theme_matrix.md

硬性要求：
- 不先调玩家武器来解决敌人题型不足。
- 不用单纯提高 HP/伤害替代敌人主题。
- 每个新增或强化的遭遇主题必须对应至少一种构筑优势和一种构筑弱点。
- 保持 spawn budget 的目标总 HP、压力曲线、上限控制可验证。

推荐遭遇主题：
- Swarm：考验 Area、Chain、Pierce。
- Elite Hunt：考验 Mark、Execute、Single Target。
- Support Nest：考验目标优先级、穿透、爆发。
- Ranged Siege：考验机动、防御、打断。
- Close Pressure：考验近战风险管理、控制和吸血。
- Hazard Field：考验移动、路线选择、持续输出窗口。

推荐顺序：
1. 写 `docs/design/encounter_theme_matrix.md`，列出构筑轴和遭遇题型的克制关系。
2. 给现有 10 个 level plan 标注主题，不急于新增敌人。
3. 调整 spawn weights / caps，让主题实际出现。
4. 如果主题缺少行为，再小范围改敌人脚本。
5. 新增 spawn validation：远程上限、精英上限、支援敌比例、目标 HP 释放仍然正确。

验证：
- 优先用 Godot MCP 运行 spawn combat profile validation。
- 优先用 Godot MCP 运行 enemy support behavior tests。
- 至少一条 MCP/headless 检查证明每个主题能在对应关卡生成目标敌人组合。
- 运行 shell Godot `--check-only`。

最终汇报：
- 每个关卡或路线的遭遇主题。
- 每个主题鼓励/压制哪些构筑。
- 哪些敌人权重或行为被改动。
- 验证结果。
```

## 阶段 6：构筑验证矩阵和平衡回归

```text
阶段目标：建立可重复的构筑验证，不只看单武器 DPS。验证不同构筑在清群、单体、支援敌、远程压制、近战压力等题型里的表现。

优先读取：
- tests/headless/weapon/*.gd
- tests/headless/combat/*.gd
- tests/headless/spawn/*.gd
- data/test/*.tres
- docs/reports/dps/*.html
- tools/generate_weapon_module_report.gd
- Player/Weapons/close_quarters_chain_rules.gd
- autoload/DamageManager.gd
- Utility/damage/*.gd

建议写入范围：
- tests/headless/combat/*.gd
- tests/headless/weapon/*.gd
- data/test/*.tres
- tools/*.gd
- docs/reports 或 docs/audits 下新增报告

硬性要求：
- 不只用 `--check-only` 代表平衡验证完成。
- 不只跑单武器 DPS。
- 每个测试构筑必须写清楚武器、分支、模组、目标遭遇题型。
- 允许先做 smoke/contract test，再逐步做数值报告。

推荐构筑验证组：
- Heat Loop：Machine Gun + Flamethrower + Plasma Lance + 任意补位。
- Mark Execute：Auto Pistol + Spear + Sniper + Cannon。
- Freeze Control：Glacier Projector + Shotgun + Dash Blade + Orbit/Pistol。
- Close Risk：Dash Blade + Chainsaw Launcher + Shotgun + Flamethrower/Orbit。
- Area Control：Rocket + Laser + Flamethrower + Orbit。
- Reload Rhythm：任意大弹匣武器组 + Reload Link/Relay/Burst/Barrier 模组。

推荐测试题型：
- 60 秒 Swarm 清群。
- 单体高 HP 精英。
- 支援敌 + 护盾核心。
- 远程炮台/迫击压力。
- 近战突进压力。
- 任务目标同时存在的战斗。

验证：
- 优先用 Godot MCP 运行对应 focused headless scenes/tests，并读取 debug output。
- 运行 shell Godot `--check-only`。
- 如生成报告，保存到 docs/reports 或 docs/audits，并说明报告生成命令。

最终汇报：
- 每个构筑在哪些题型表现强/弱。
- 是否发现单一构筑覆盖所有题型。
- 是否有奖励池或路线导致某构筑过早成型。
- 下一轮应该调敌人、奖励权重、文案还是武器数值。
```

## 收尾检查清单

每个阶段结束前，执行以下检查：

```text
1. `git status --short`，确认只改了本阶段允许范围。
2. `git diff --check`，确认没有空白错误。
3. 优先用 Godot MCP 运行本阶段 focused scenes/tests，并读取 debug output。
4. 运行 shell Godot `--check-only` 作为全仓语法/资源 gate。
5. 最终汇报包含文件、行为、验证、剩余风险。
6. 不把旧 docs 或记忆里的结论当成当前事实；所有 gameplay 结论都必须能指向当前文件。
```
