# Project Optimization Prompt

Use this prompt when asking Codex to inspect and optimize this Godot project.

```text
你现在在 Godot 项目 `D:\Godot Projects\project_mag` 中工作。请对整体项目做一次以“可维护性 + 性能”为目标的优化检查，并按当前项目的真实配置一步步引导我，而不是给泛泛建议。

工作方式：
1. 先只读检查，不要改文件。先运行或读取：
   - `git status --short`，确认当前是否有未提交改动；如果有，后续不要覆盖用户改动。
   - `rg --files`，快速了解项目结构。
   - `godot --headless --path . --check-only --quit`，确认当前工程能否解析加载。
2. 以当前代码为准，不要依赖旧记忆或旧文档。历史文档只能作为线索，最终结论必须指向当前文件和行号。
3. 优先检查这些当前项目已知高价值区域：
   - UI 每帧刷新与 dirty flag：`UI/scripts/UI.gd`、`UI/scripts/components/hud_presenter.gd`、`UI/scripts/components/ui_dirty_signal_controller.gd`、`UI/scripts/weapon_selector.gd`
   - 旧式商店/升级卡片每帧轮询：`UI/scripts/shop_weapon_slot.gd`、`UI/scripts/shop_module_slot.gd`、`UI/scripts/margin_upgrade_card.gd`、`UI/scripts/margin_item_card.gd`
   - 玩家战斗主循环：`Player/Mechas/scripts/Player.gd` 以及已抽出的 `player_*_system.gd`
   - 武器与投射物热点：`Player/Weapons/Core/weapon.gd`、`Player/Weapons/Components/projectile_emitter.gd`、`Player/Weapons/Projectiles/projectile.gd`
   - 敌人生成与查询：`Utility/enemy_spawner.gd`、`autoload/EnemyRegistry.gd`、`Npc/enemy/components/enemy_movement_runtime.gd`
   - 掉落物和短生命周期对象：`Objects/loots/*.gd`、`Utility/area_effect/*.gd`、`autoload/ObjectPool.gd`
   - 休息区与管理 UI：`World/rest_area.gd`、`UI/scripts/management/*.gd`
4. 用这些搜索先定位热点，不要直接大改：
   - `rg -n "func _process|func _physics_process|func _input|func _unhandled_input" -g "*.gd"`
   - `rg -n "get_nodes_in_group|find_child|find_children|get_parent\\(\\)|get_node\\(" -g "*.gd"`
   - `rg -n "load\\(|ResourceLoader\\.load|instantiate\\(|queue_free\\(|ObjectPool" -g "*.gd"`
   - 统计最大脚本：列出前 20 个 `.gd` 文件行数。
5. 把发现分成三类：
   - 立即可做：低风险、局部、可用现有测试验证，例如把 UI 金币轮询改为 dirty/信号刷新。
   - 需要实测：可能有收益但必须 profiler 或基准证明，例如敌人查询改为空间网格、扩大对象池。
   - 暂缓：重构成本高或会干扰当前玩法调整，例如大规模拆 `Player.gd` / `enemy_spawner.gd`。
6. 给建议时必须包含：
   - 具体文件路径和行号。
   - 当前行为是什么。
   - 为什么它可能影响性能或维护性。
   - 建议怎么改。
   - 验证方式，优先使用项目已有 headless 测试。
7. 不要建议删除用户正在编辑的大量未提交内容。若工作区很脏，先明确“本轮只读审计”或只做用户明确同意的窄范围修改。

当前项目的优化优先级：
1. 清理旧 UI 每帧金币/可购买状态轮询，改成金币变化、面板刷新、商品刷新时更新。
2. 缩小 `Player.gd` 每个物理帧里的非必要工作，把只在装备/阶段/输入变化时才需要的逻辑改为 dirty 或事件驱动。
3. 统一战斗敌人查询入口到 `EnemyRegistry`，再用 `World/Test/run_enemy_registry_many_enemy_benchmark_headless.gd` 判断是否需要空间网格。
4. 扩展 `ObjectPool` 到高频短生命周期对象，优先考虑投射物以外的金币、芯片、常见 area effect、warning/telegraph。
5. 统一 debug 输出开关，避免 `enemy_spawner.gd`、`rest_area.gd` 等运行期默认打印影响测试和性能判断。
6. 对大脚本继续做小步责任拆分：`UI.gd` 保持 controller/presenter 迁移路线；`enemy_spawner.gd` 优先拆预算、候选选择、生成、战斗结算；`rest_area.gd` 优先拆输入、移动、菜单联动。

如果我让你执行优化：
1. 每次只做一个小阶段，先说明要改哪些文件。
2. 不要批量重构无关系统。
3. 修改后至少运行：
   - `godot --headless --path . --check-only --quit`
4. 如果改 UI dirty/刷新逻辑，优先补跑相关测试：
   - `World/Test/hud_dirty_refresh_test.tscn` 或对应 `run_*_headless.gd`
   - 管理 UI 相关改动跑 `World/Test/run_management_ui_polish_test_headless.gd`
   - 武器 HUD/被动改动跑 `World/Test/run_weapon_selector_layer_test_headless.gd` 和 `World/Test/run_weapon_passive_charge_test_headless.gd`
5. 如果改敌人查询或注册逻辑，优先跑：
   - `World/Test/run_enemy_registry_test_headless.gd`
   - `World/Test/run_enemy_registry_many_enemy_benchmark_headless.gd`
6. 如果改对象池或投射物生命周期，优先跑相关武器/投射物/伤害回归测试，并检查是否出现泄漏或节点未归还。

输出格式：
- 先给“最高优先级 3-6 项”，按收益/风险排序。
- 每项都要有文件路径、当前证据、建议动作、验证命令。
- 最后给“建议执行顺序”，每一步都应该能独立验证。
- 如果当前 `--check-only` 有警告或错误，单独列出，不要把它们当作已经修复。
```

