# MagArena 全项目 Code Review（2026-08-08）

> 修复状态（2026-08-08）：P1 与 P2 已通过统一的 `progression_state` 存档 schema 修复，并加入最终通关、无尽入口及旧存档兼容的保存往返测试；全量 65 项测试通过。P3 仍为后续事项。

## 结论摘要

本次审查以当前工作区（包含未提交改动）为基线，覆盖项目入口、autoload 生命周期、战斗协议、敌人生成、世界/休整区流程、UI、奖励、存档、数据资源与自动化测试基础设施。

共确认 3 项需要处理的问题：

- P1：1 项——最终关通关状态无法跨存档恢复，继续游戏可绕过通关结算状态。
- P2：1 项——进入无尽模式后的首次完整休整资格无法跨存档恢复。
- P3：1 项——章节资源公开的 `rest_after_completion` 配置未被运行时消费。

项目当前可以编译，启动资源清单一致，65 个注册测试全部通过；这说明现有主路径稳定，但测试尚未覆盖上述“保存→重置→恢复”的状态边界。

## 审查基线与验证

- 分支：`master`
- 工作区：95 个已跟踪文件发生变化，另有未跟踪的新进度资源、遥测 autoload 与测试资源；审查未修改任何运行时代码。
- Godot：4.7.1 stable，使用无窗口 console。
- `--headless --check-only --quit`：PASS。
- `tools/update_startup_manifest.ps1 -Check`：PASS；weapons 15、mechas 5、economy 1、cell effects 21、task modules 5、weapon branches 28、weapon passives 18。
- 受影响测试选择：因 `project.godot`、核心 autoload、跨域数据及未映射路径变化，选择器按设计回退到 full。
- Worker：PASS=65、FAIL=0、ERROR=0、SHUTDOWN_DIAGNOSTICS=0、RUNTIME_ERRORS=0。
- 测试产物：`test-results/code-review-20260808/`。
- `git diff --check`：未发现空白符错误。

## Findings

### [P1] 最终通关状态没有写入存档，继续游戏会回到普通 REST 流程

证据：

- `autoload/PhaseManager.gd:66-71` 在最终战胜利后先把 `current_level` 从 9 增至 10，再以普通 `STATE_REST_AREA` 调用 `SaveManager.commit_battle_success()`。
- `autoload/PhaseManager.gd:246-251` 只有仍处于 `SETTLEMENT` 时，结算完成检查才调用 `enter_run_complete()`。
- `autoload/SaveManager.gd:118-138` 只保存等级与 `endless_mode`，不保存 phase、`RUN_COMPLETE` 或“主流程已完成”等价状态。
- `World/continue.gd:23-31` 在恢复前把 `PhaseManager` 重置为默认 REST；`autoload/SaveManager.gd:92-104` 恢复时也没有重建 `RUN_COMPLETE`。
- `World/world_ready_coordinator.gd:3-34` 世界就绪后不会根据 `current_level > final_level_index` 重新进入通关结算。

影响：玩家完成最终关后退出，在主菜单选择继续，将以 `current_level == 10`、`endless_mode == false`、phase 为 REST 的状态进入世界，而不是重新看到通关总结/无尽模式选择。随后休整区路线会走普通协议分支，使玩家在没有明确选择无尽模式的情况下继续第 11 场战斗，破坏主流程完成语义，也可能覆盖这个异常状态下的新存档。

建议：为存档增加明确的运行阶段/完成状态（例如 `run_complete_pending`，不要仅从瞬时 phase 推断），在 world 前恢复或 world ready 时重建 `RUN_COMPLETE`。最终战的原子保存应发生在该状态确定之后。增加“最终战完成→保存→reset_runtime_state→restore→仍显示通关总结”的往返测试。

### [P2] 无尽模式入口的首次完整休整资格只存在于内存中

证据：

- `autoload/PhaseManager.gd:192-199` 在选择无尽模式时设置 `endless_mode = true` 与私有标志 `_endless_entry_rest_available = true`。
- `UI/scripts/UI.gd:1550-1555` 随后立即保存 `endless_started`。
- `autoload/SaveManager.gd:127-137` 只持久化 `endless_mode`，没有持久化 `_endless_entry_rest_available` 或等价状态。
- `autoload/PhaseManager.gd:277-285` 重置时清除该标志；`autoload/SaveManager.gd:92-104` 恢复时不重建它。
- `autoload/PhaseManager.gd:133-138` 完整商店及休整协议资格依赖此标志，或 `run_completed_levels % 3 == 0`。主流程完成时通常为 10，后者为 false。

影响：玩家在通关总结中选择进入无尽模式后，如果在开始下一战前退出，继续游戏会保留 `endless_mode`，却失去设计上承诺的首次完整休整/商店资格。该资格在同一进程内存在，跨存档则消失，行为不一致。

建议：持久化一个语义明确且可消费的入口资格（例如 `endless_entry_rest_pending`），或从持久化的模式转换状态可靠重建；在真正进入战斗时再清除。增加“选择无尽→保存→重置→恢复→完整商店仍开放→开战后资格清除”的测试。

### [P3] `rest_after_completion` 是无效的数据配置

证据：

- `data/progression/RunChapterDefinition.gd:13` 暴露 `@export var rest_after_completion := true`。
- `data/progression/run_progression_profile.tres:53` 为最终章节显式设置 `rest_after_completion = false`。
- 项目运行时代码没有读取该字段；`RunProgressionProfile.get_settlement_type_for_completed_level()` 仅按 `is_final_level()` / `is_chapter_end()` 决定结算类型，`PhaseManager._try_complete_settlement()` 也仅按结算类型进入章节休整。

影响：当前最终章节因 `final` 分支优先而碰巧符合预期，但任何未来章节把此字段设为 false 都仍会进入章节休整。资源向设计者提供了一个看似有效、实际上被静默忽略的控制项，容易造成内容配置与运行时行为漂移。

建议：要么让进度策略在决定 settlement 时读取此字段，要么删除该导出字段和 `.tres` 配置，保持单一事实来源。为 true/false 各加一条资源驱动测试。

## 架构与质量观察

### 做得较好的部分

- `EnemySpawner` 将出生点、HP 预算与击杀金币预算拆分成独立 runtime，对高复杂度战斗逻辑形成了可测试边界。
- 战斗协议经 `BattleContractCombatPort` / bridge 隔离，合同 runtime 不直接依赖世界节点；新增 finale 复用了 elimination runtime，没有复制一套生命周期。
- registry 使用事件驱动注册和 tree-exiting 清理；本轮相关测试和 shutdown diagnostics 均为 0。
- 存档采用临时文件校验、主文件/备份替换与 checkpoint 回滚，基础原子写入策略清晰。
- 测试基础设施会隔离 `user://`、限制并发、要求显式 PASS，并把运行时错误与退出泄漏纳入结果；本轮 full 结果无失败或泄漏。
- 启动资源清单具备目录覆盖、排序、类型与 ID 校验，当前数据绑定没有发现缺失或孤儿项。

### 主要风险集中区

- 新增的章节/最终关/无尽模式引入了“phase、level、settlement type、endless mode、入口资格”多个相关状态，但存档只持久化其中一部分。今后应以显式、可序列化的 run state machine 取代依赖私有瞬时标志的推断。
- `PhaseManager` 同时承担阶段切换、战后统计、奖励阻塞、休整策略、运行完成和存档触发，已经成为跨域状态汇合点。继续扩展前可把“进度策略”和“可持久化运行状态”抽成独立对象，由 PhaseManager 负责执行转换。
- 当前测试对同一进程内的 finale 与 endless 转换覆盖良好，但 persistence suite 没有覆盖这些新增字段和跨进程语义，导致 65 个测试全绿仍遗漏关键恢复缺陷。

## 建议修复顺序

1. 先定义并持久化明确的运行完成/无尽入口状态，修复 P1 与 P2；两项应在同一个存档 schema 变更中处理。
2. 添加最终通关与无尽入口的完整保存往返测试，并验证旧存档缺字段时的兼容默认值。
3. 决定 `rest_after_completion` 的唯一事实来源，修复或删除无效配置。
4. 重新运行 persistence、world、UI、combat/reward 聚焦测试，再运行 full Worker 和 startup manifest audit。

## 审查限制

- 按项目约束未启动图形窗口，因此没有进行人工视觉验收；UI 结论来自场景/脚本审查及 headless 测试。
- 本报告针对 2026-08-08 当前未提交工作区快照；后续改动可能改变行号或消除/引入问题。
- 二进制图片与 translation 资源通过导入/清单/测试门禁验证，没有进行逐像素美术质量评审。
