你是 Godot 4.6 / GDScript 的资深工程师。请基于我项目现有的 Board/Cell 架构新增一种“新 Cell 类型”，要求最小侵入改造、保持现有占领状态机可用，并支持数据驱动配置。

【项目现状（你必须遵守）】
1) Board 在运行时生成：
- 文件：D:/Godot Projects/project_mag/World/board_cell_generator.gd
- 逻辑：按 grid_size（默认 3x3）实例化 cell_scene，中心格挂 PlayerSpawner。

2) Cell 是战斗区块状态机：
- 文件：D:/Godot Projects/project_mag/Board/Cells/cell.gd
- 通过 Area2D 感知玩家/敌人进出，维护 state：
  IDLE / PLAYER / ENEMY / CONTESTED / LOCKED
- 维护 progress，通过定时器推进占领进度：
  玩家在格内 progress 增加；敌人在格内 progress 减少；
  超过阈值切换 cell_owner（PLAYER/ENEMY/NONE）并发出状态信号。

3) Phase 流程：
- PlayerSpawner：D:/Godot Projects/project_mag/World/player_spawner.gd
- PhaseManager（Autoload）：D:/Godot Projects/project_mag/autoload/PhaseManager.gd
- Board：进 battle 时随机把部分空闲格设为敌方占领；进 reward 时重置归属。

4) EnemySpawner：
- 文件：D:/Godot Projects/project_mag/Utility/enemy_spawner.gd
- 读取各格 state/cell_owner，选择合适格刷怪，避免在玩家当前格刷怪。

【新增 Cell 的设计要求（必须实现）】
每个 Cell 仍保留现有 state/progress/cell_owner 逻辑；新 Cell 在此基础上额外增加“三特性”：
A) 任务类型 task_type：OFFENSE 或 DEFENSE（行为导向）
B) 奖励类型 reward_type：COMBAT 或 ECONOMY（收益导向）
C) 地形类型 terrain_type：例如 CORROSION/JUNGLE 等（仅在该 Cell 内生效的增益/减益）

并新增“地形效果 Aura”（只在该 Cell 内生效）：
- CORROSION：降低玩家移动速度（move_speed_mul）
- JUNGLE：降低玩家视野（vision_mul）
- 需要可扩展更多效果
- 必须支持进入 Cell 时应用、离开时移除，避免叠加错误

并新增“本地小任务 Objective”（与占领进度逻辑并行，不取代它）：
- OFFENSE 示例：在该 Cell 内击杀 X 个敌人（KILL_X_IN_CELL）
- DEFENSE 示例：在该 Cell 内停留/占领推进累计 Y 秒或累计 progress 达到阈值（HOLD_OR_PROGRESS）
- 任务完成后给予 reward（COMBAT/Economy），奖励短期有效（本局/本阶段），并可配置

【实现约束】
1) 不要改写 board_cell_generator.gd 的生成方式；如需扩展，只能“追加最小字段/绑定”。
2) 尽量不破坏 cell.gd 的既有接口。若必须新增信号/字段，请做到默认值兼容老逻辑。
3) 新功能必须数据驱动：新 Cell 的 task_type/reward_type/terrain_type 与参数来自配置（JSON/Dictionary/Resource 任选一种，但要说明放在哪里、如何加载）。
4) enemy_spawner.gd 依赖 state/cell_owner 的逻辑不得被破坏；新 Cell 不能导致刷怪选择异常。
5) 输出必须包含：文件改动清单（路径）、关键代码（可复制）、配置示例、以及自测步骤。

【要新增的具体新 Cell（请按此规格落地）】
- new_cell_id: "corrosion_offense_cell"
- task_type: OFFENSE
- objective: KILL_X_IN_CELL
  - params: { kill_count: 10 }
- reward_type: COMBAT
  - reward params: { damage_mul: 1.10, duration_sec: 20 }  # 示例，可按你实现形式
- terrain_type: CORROSION
  - aura params: { move_speed_mul: 0.85 }

【你需要怎么做（按顺序输出）】
1) 扫描并总结 cell.gd：现有信号、state 切换点、progress 更新点、玩家/敌人进出事件点（你只需概述，不要粘贴大量原文件）
2) 设计“扩展点”：说明你将把 Aura/Objective 放在 cell.gd 内、还是拆成组件脚本（建议组件化，但需最小侵入）
3) 实现 Aura：
   - 用 Cell 的 Area2D 进入/离开作为触发源，或复用现有 enter/exit 回调
   - 对玩家应用 move_speed_mul，离开时移除
   - 给出玩家侧需要的最小接口（例如 apply_move_speed_mul/remove_move_speed_mul 或 modifier stack），若项目已有接口请复用
4) 实现 Objective：
   - 在该 Cell 内统计击杀数（你可以通过全局事件、敌人死亡信号、或 spawner 回调；选择你认为最小侵入的方式）
   - 完成后发出 objective_completed(cell_id) 信号，并触发 reward 发放
5) 添加配置示例（JSON/Dictionary/Resource）并让 Board/Cell 在实例化后能加载并启用该类型
6) 给出最小自测步骤：
   - 在 3x3 中强制生成 1 个 corrosion_offense_cell
   - 进入该格触发减速，离开恢复
   - 在该格击杀达到 10 个触发完成与奖励
7) 列出边界情况与处理：
   - 玩家快速进出导致效果重复叠加
   - objective 已完成后再次进入是否重复触发
   - Phase 从 battle->reward 时如何重置（至少不报错；最好可配置是否重置）

【输出格式要求（必须严格遵守）】
- 1) 改动文件清单（新增/修改，带完整路径）
- 2) 关键代码块（按文件分段）
- 3) 配置示例（可直接复制）
- 4) 自测步骤（编辑器内可执行）
- 5) 风险与边界情况清单 + 解决策略