# Player Handoff

## 1. 批次目标

完成 Player-1 移动系统纯计算试点。结果：移动系统不再持有 Player；Player 收集引擎/输入状态并应用强类型结果；帧输入与结果只在装配时分配一次并循环复用；移动、PREPARE、自动导航和 Dash 行为由新增门禁锁定。

## 2. 修改文件

- `Player/Mechas/scripts/Player.gd`
- `Player/Mechas/scripts/player_movement_system.gd`
- `Player/Mechas/scripts/movement_frame_input.gd`
- `Player/Mechas/scripts/movement_frame_input.gd.uid`
- `Player/Mechas/scripts/movement_frame_result.gd`
- `Player/Mechas/scripts/movement_frame_result.gd.uid`
- `tests/headless/player/run_player_movement_system_test_headless.gd`
- `tests/headless/player/run_player_movement_system_test_headless.gd.uid`
- `tests/headless/player/run_player_auto_navigation_test_headless.gd`
- `tests/headless/player/run_player_auto_navigation_test_headless.gd.uid`
- `tests/headless/player/run_player_dash_movement_integration_test_headless.gd`
- `tests/headless/player/run_player_dash_movement_integration_test_headless.gd.uid`
- `tests/scenes/player/player_movement_system_test.tscn`
- `tests/scenes/player/player_auto_navigation_test.tscn`
- `tests/scenes/player/player_dash_movement_integration_test.tscn`
- `docs/plans/project_slimming/player_progress.md`
- `docs/plans/project_slimming/handoffs/player.md`

## 3. 公开 API 或契约变化

- Player 公开导航门面保持不变：`start_auto_nav(dest)`、`stop_auto_nav()`、`is_auto_nav_active()`、`configure_auto_nav_speed_mul(speed_mul)`。
- Player 继续拥有 `movement_enabled`、`moveto_enabled`、`moveto_dest` 以及 CharacterBody2D 位置/速度应用。
- 新内部强类型契约：
  - `MovementFrameInput`：delta、当前位置/速度、移动和导航状态、手动方向、速度/加减速/转向配置。
  - `MovementFrameResult`：下一速度、到达状态、可选吸附位置、导航完成状态。
  - `PlayerMovementSystem.tick(frame_input, frame_result)` 只计算并写入既有结果实例。
- 移除仅由 Player 调用的旧内部方法：`setup(player)`、`start_auto_nav(dest)`、`stop_auto_nav()`、`is_auto_navigating()`。仓库搜索未发现其他直接调用者。

## 4. 需要其他范围完成的工作

- 测试基础设施范围在本分支合并后，把三个新 Player scene 入口加入声明式测试清单，并映射到 Player 域。
- 不需要 UI、Startup、Asset Pipeline 或 Autoload 改动。

## 5. 建议的共享文件修改

- 仅建议协调者/测试基础设施登记以下 scene：
  - `res://tests/scenes/player/player_movement_system_test.tscn`
  - `res://tests/scenes/player/player_auto_navigation_test.tscn`
  - `res://tests/scenes/player/player_dash_movement_integration_test.tscn`
- 不建议修改 `project.godot`。

## 6. 测试及结果

- PASS：Player movement system 表驱动测试。
- PASS：PREPARE 禁止手动输入。
- PASS：自动导航推进、速度倍率/复位、到达、完成和位置吸附。
- PASS：100,000 次 Tick 复用同一 input/result，ObjectDB 数量变化 0；最终一次 428,407 usec，观测范围 157,169-428,407 usec，门限 2,000,000 usec。
- PASS：Player 自动导航场景，实际 physics frame 完成移动和精确吸附。
- PASS：Player Dash 场景，移动禁用/恢复和位移保持。
- PASS：既有 `test_weapon_smoke.tscn`。
- PASS：Godot 4.6.2 `--headless --check-only --quit`，无 parse/compile/load error。
- PASS：`git diff --check`。
- Player 场景与既有 weapon smoke 在显式 PASS、退出码 0 后仍输出项目既有的“四个资源仍占用”退出警告。

## 7. 修改前后指标

- `Player.gd`：1786 -> 1828 行；226 -> 227 函数；97 -> 99 顶层字段。
- `player_movement_system.gd`：71 -> 65 行；8 -> 6 函数。
- 移动系统 `_player` 引用：46 -> 0。
- 新帧契约：input 15 行/12 字段；result 15 行/5 字段/1 reset 函数。
- 旧代码没有独立重复 Tick 基线；新增门禁最终一次 100,000 Tick 为 428,407 usec（观测范围 157,169-428,407 usec），ObjectDB 数量无变化。

## 8. 合并顺序要求

1. 同一 Player 分支内先具备 `MovementFrameInput`、`MovementFrameResult` 和新 `PlayerMovementSystem` 契约，再应用 `Player.gd` 调用方。
2. Player 实现和 Player 域测试作为同一原子批次合并。
3. 合并后再由测试基础设施/协调者登记全局测试清单。
4. 本批次不依赖其他第一轮范围，可按协调者的低层契约优先策略集成。

## 9. 已知风险

- `Player.gd` 在试点中增加 42 行适配/应用代码和两个长生命周期帧对象；约 700 行目标需由后续职责拆分继续推进。
- 项目声明 Godot 4.7 feature，但当前可用验证引擎为 4.6.2；建议协调者使用项目标准版本复验。
- 首次 Godot 导入曾自动重写四个 `data/localization/*.translation`；已恢复到 HEAD，最终变更清单不包含这些越权文件。
- 场景测试退出资源警告尚未在本批次跨域追查，因为显式结果和退出码均成功，且既有 weapon smoke 同样出现。

## 10. 下一安全批次

Player-2 主动技能运行时：先补能量边界/恢复消耗、默认技能、玩家技能、主武器主动与换弹、信号次数、Assist、提示节流和缺失 InputMap 的特征测试，再拆分 `SkillEnergyState`、`PlayerSkillController` 与 `WeaponActionController`。跨域输入接线只写 handoff，待 UI 分支合并后由协调者处理。

## 11. Player-2A/2B 集成更新

- 已加入并登记 `res://tests/scenes/player/player_active_skill_characterization_test.tscn`，manifest id 为 `player.active_skill_characterization`。
- `PlayerActiveSkillRuntime` 保持既有门面，内部改为协调 `SkillEnergyState`、`PlayerSkillController`、`WeaponActionController`。
- `SkillEnergyState`：当前能量、最大能量、主动技能能量成本查询、消耗、恢复和每帧 regen。
- `PlayerSkillController`：默认主动技能 scene 加载、玩家主动技能请求信号。
- `WeaponActionController`：主武器主动、换弹请求、Assist post-reload、失败原因/CD 读取、换弹中提示节流。
- `Player.gd` 对外/测试调用点保持不变；本批次没有新增 Autoload、没有改 `project.godot`，也没有跨 UI/Startup 修改。
- 兼容说明：`PlayerActiveSkillRuntime._reload_block_hint_ready_at_msec` 仍保留，并在调用武器控制器前后同步，避免破坏当前测试和调试入口。

## 12. Player-2 验收结果

- PASS：Godot 4.7 `--headless --path . --check-only --quit`。
- PASS：`player_active_skill_characterization_test.tscn`。
- PASS：`player_movement_system_test.tscn`，100,000 tick 为 376,451 usec。
- PASS：`player_auto_navigation_test.tscn`。
- PASS：`player_dash_movement_integration_test.tscn`。
- PASS：`test_weapon_smoke.tscn`。
- PASS：完整 13-entry Worker manifest：PASS=13，FAIL=0，ERROR=0，shutdown diagnostics=19，runtime errors=0，结果目录 `test-results/worker-13-manifest-player2b`。
