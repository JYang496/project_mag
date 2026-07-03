# Startup Project Slimming Progress

## 已完成批次

### Startup-1：可重复启动基线与静态目录清单设计

- 扩展 `tools/benchmark_startup_loading.ps1`：
  - 冷导入使用系统临时目录中的项目副本，明确排除 `.git` 和 `.godot`。
  - 每个 Godot 进程使用独立 `GODOT_USER_HOME`。
  - 热启动和代表性定向测试默认各运行 5 次并报告中位数、最小值、最大值。
  - 记录加载资源分类、退出码、运行错误、退出泄漏诊断、警告、编辑器阶段和探针阶段。
  - 输出可复现 JSON，并在退出码、运行期错误或定向测试缺少 PASS 时失败。
- 新增菜单到世界的启动基线探针，记录 Start scene 加载、实例化、世界请求、世界进入和 Player runtime ready。
- 新增仅供设计和审计的静态资源 manifest；本批次没有运行时代码读取它。
- 新增 manifest 一致性审计，检查目录完整性、路径重复、资源类型、空 ID 和重复 ID。

### Startup-2A：routes、cell effects、task modules 清单消费

- `ResourceCatalog` 新增 startup manifest 路径解析入口，要求 manifest 明确声明 `runtime_consumed=true`。
- `RunRouteManager.prepare_route_definitions()`、`CellEffectRuntime.prepare_definitions()`、`CellTaskModuleRuntime.prepare_definitions()` 改为从 manifest 指定路径加载。
- 三个 prepare API 均为显式、幂等、可失败，并返回 `{ok, errors, count}`；旧 `reload_route_definitions()` / `load_definitions()` 作为强制刷新兼容入口保留。
- 资源缺失、路径重复、空 ID、重复 ID、无效类型或 manifest 契约不一致都会返回失败，不再静默跳过目录资源。
- `startup_resource_manifest.json` 状态更新为 `runtime_partial`，当前运行时消费域限定为 `routes`、`cell_effects`、`task_modules`。
- 新增 `startup_manifest_runtime_consumption_test.tscn` 覆盖三类目录的 manifest path collection、prepare 计数、幂等刷新和关键 ID 可用性。
- 本批未接入 DataHandler 的 weapons/mechas/economy/branches/passives，未修改 `World/new_game_btn.gd`、`World/continue.gd` 或世界进入门禁。

### Startup-2B：DataHandler 清单消费

- `DataHandler` 的 weapons、mechas、economy、weapon branches、weapon passives 全部迁移到 startup manifest 指定路径。
- `prepare_world_data(include_deferred_runtime_data=false)` 和 `prepare_deferred_runtime_data()` 现在返回 `{ok, errors, count}` 聚合结果；旧调用方忽略返回值时仍保持兼容。
- 新增 `prepare_weapon_data()`、`prepare_mecha_data()`、`prepare_economy_data()`、`prepare_weapon_branch_data()`、`prepare_weapon_passive_branch_data()`；旧 `load_*` 方法保留为强制刷新兼容入口。
- DataHandler 资源准备改为临时表加载，整批无错误后才替换 `GlobalVariables`，缺失、重复 ID、空 ID、无效类型或 manifest 契约不一致都会显式失败。
- `startup_resource_manifest.json` 状态更新为 `runtime_full`，8 个 catalog 均在运行时通过 manifest 消费。
- `startup_manifest_runtime_consumption_test.tscn` 扩展覆盖 DataHandler 五类 catalog 的计数、幂等准备、关键 ID 可读性、scene path 索引、branch/passive 查找和 aggregate prepare。

## 基线环境

- Commit：`51ec0972b219626780e1f31909885adad7dd120d`
- Godot：`4.6.2.stable.official.71f334935`
- 日期：2026-07-02
- 热启动场景：`res://World/Start.tscn`
- 定向测试：`res://tests/scenes/startup/startup_baseline_probe.tscn`
- 热启动退出：2 frames
- 冷导入：一次隔离项目副本
- 热启动：5 次
- 定向测试：5 次

## 基线结果

| 测量 | 原始结果 | 中位数 | 最小值 | 最大值 |
| --- | --- | ---: | ---: | ---: |
| 冷导入 | 61,379 ms | 不适用（单次） | 61,379 ms | 61,379 ms |
| 热启动 | 7,206 / 9,480 / 8,267 / 7,531 / 9,501 ms | 8,267 ms | 7,206 ms | 9,501 ms |
| 定向测试 | 12,588 / 10,837 / 14,821 / 11,777 / 12,304 ms | 12,304 ms | 10,837 ms | 14,821 ms |

资源与错误：

| 测量 | 唯一加载资源 | Data | Weapons | Enemies | UI | Assets | 运行期错误 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 冷导入 | 66 | 6 | 0 | 0 | 7 | 11 | 0 |
| 热启动中位运行 | 258 | 55 | 0 | 0 | 7 | 76 | 0 |
| 定向测试中位运行 | 353 | 72 | 24 | 0 | 26 | 87 | 0 |

- 冷导入生成 425 个 `.godot/imported` 文件。
- 冷导入观察到 `first_scan_filesystem`、`update_scripts_classes`、`reimport`、`loading_editor_layout`。
- 5 次热启动均 exit 0、0 error、0 warning。
- 5 次定向测试均显式 PASS、exit 0、0 运行期错误。
- verbose 退出清理每次产生 10 条泄漏诊断和 2 条 warning；测量器把 leak dump 区段与运行期错误分开保留。

定向探针内部阶段：

| 阶段 | 中位数 | 最小值 | 最大值 |
| --- | ---: | ---: | ---: |
| probe ready | 1.005 ms | 0.662 ms | 1.170 ms |
| Start scene loaded | 285.640 ms | 198.660 ms | 551.728 ms |
| Start scene instantiated | 998.825 ms | 830.197 ms | 1,510.535 ms |
| world request started | 1,079.485 ms | 943.517 ms | 1,601.430 ms |
| world scene entered | 3,483.447 ms | 2,795.313 ms | 4,594.224 ms |
| Player runtime ready | 3,483.546 ms | 2,795.436 ms | 4,594.342 ms |

外部定向测试中位数 12,304 ms 与探针内部 Player ready 中位数 3,483.546 ms 的差值包含 Godot 进程启动、Autoload 初始化、verbose 输出和退出清理，后续优化复测必须保持同一命令和口径。

## 静态目录审计

- 8 个 catalog、93 个资源：
  - weapons：15
  - mechas：5
  - economy：1
  - routes：3
  - cell effects：21
  - task modules：5
  - weapon branches：28
  - weapon passives：15
- Startup-2 后，routes、cell effects、task modules、weapons、mechas、economy、weapon branches 和 weapon passives 都通过 manifest 指定路径准备，共 93 个目录资源。
- `DataHandler.prepare_world_data()` 在世界进入前准备 weapons、mechas 和 economy；`include_deferred_runtime_data=true` 时同时准备 branches/passives，普通运行期需求仍会按需准备 deferred 数据。
- Spawn 使用单一显式 `spawn_combat_profile.tres`，不需要目录 manifest。

## 修改前后工具指标

- 启动基准脚本：46 行 -> 329 行。
- 修改前：3 次运行、平均值、无隔离冷导入、无中位数、无阶段数据、错误分类较窄。
- 修改后：默认 5 次、中位数、隔离冷导入、隔离 user home、JSON 原始运行数据、资源分类、阶段和错误/泄漏分类。
- Startup-1 没有启动运行时代码变化，因此没有声称性能改善；Startup-2 改变了 8 个目录 catalog 的路径发现方式，但未重复完整启动基准，性能比较仍留给 Startup-4。

## 已知风险

- 项目声明 Godot 4.7 feature，但可用验证引擎为 4.6.2；最终基线应在项目标准引擎上复验。
- 热启动与定向测试存在明显方差，优化验收应继续使用 5 次中位数，不使用单次最好结果。
- 定向测试退出存在稳定泄漏诊断；当前未证明影响运行期行为，但后续应单独定位。
- Manifest 已由 Startup-2 完整运行时消费；世界进入门禁尚未实施。

## 下一推荐批次

### Startup-3: world-entry prepare gate

- Added non-Autoload `WorldEntryPrepareGate` to aggregate world-entry preparation for DataHandler core world data, routes, cell effects, and task modules.
- The gate intentionally calls `DataHandler.prepare_world_data(false)` so weapon branch/passive deferred data is not loaded during title-to-world startup.
- `World/new_game_btn.gd` and `World/continue.gd` now consume the aggregate `{ok, errors}` result before requesting the threaded world scene.
- Prepare failures restore the button state, report the aggregated error text, and stop world entry instead of continuing with empty data.
- Added `startup.world_entry_prepare_gate` to the representative manifest.
- PASS: Godot 4.7 `--headless --path . --check-only --quit`.
- PASS: `res://tests/scenes/startup/world_entry_prepare_gate_test.tscn`.
- PASS: selected world run through `run_selected_tests.ps1`: PASS=5, FAIL=0, ERROR=0, shutdown diagnostics=11, runtime errors=0.

### Startup-3B：Autoload eager prepare 收口

- `RunRouteManager._ready()` 不再准备 route manifest；route definitions 改为由 world-entry gate 或显式测试调用准备。
- `CellTaskModuleRuntime._ready()` 不再准备 task module manifest；仅保留 phase signal 连接。
- `CellEffectRuntime._ready()` 不再准备 cell effect manifest；cell effect runtime state 改为在 `prepare_definitions()` 成功后一次性恢复，避免继续存档在定义尚未准备时被错误清空。
- `World/new_game_btn.gd` 的 starting cell/task loadout 移到 world-entry prepare 成功之后，确保定义已准备后再发放初始内容。
- `world_entry_prepare_gate_test` 增加断言，防止 routes、cell effects、task modules 在显式 world entry 前由 Autoload `_ready()` 提前准备。

验证：

- PASS：Godot 4.6.2 `--headless --path . --check-only --quit`。
- PASS：`res://tests/scenes/startup/world_entry_prepare_gate_test.tscn`。
- PASS：`res://tests/scenes/startup/startup_manifest_runtime_consumption_test.tscn`。
- PASS：`res://tests/scenes/startup/startup_resource_manifest_audit.tscn`，8 catalogs、93 resources。
- PASS：`res://tests/scenes/startup/startup_baseline_probe.tscn`。

限制：

- `LocalizationManager._ready()` 仍会调用 `DataHandler.load_weapon_data()` 构建 weapon scene 到 ID 的本地化查找表。该文件不在启动范围允许修改列表内，因此 weapons 仍可能在菜单阶段准备；已写入 handoff 交给协调者/对应范围处理。
- `DataHandler` 的部分旧 getter 仍保留兼容性 lazy prepare，以免在 UI/Player 调用方未迁移前改变行为；后续应由协调者安排调用方显式 prepare 后再收紧这些 getter。

### Startup-4：复测结果

复测环境与原基线相同：Commit `51ec0972b219626780e1f31909885adad7dd120d`，Godot `4.6.2.stable.official.71f334935`，热启动 `res://World/Start.tscn`，定向测试 `res://tests/scenes/startup/startup_baseline_probe.tscn`，热启动退出 2 frames。

首次完整复测：

| 测量 | 原基线中位数 | 复测结果 | 变化 |
| --- | ---: | ---: | ---: |
| 冷导入 | 61,379 ms | 91,606 ms | +49.2% |
| 热启动 | 8,267 ms | 10,504 ms | +27.1% |
| 定向测试 | 12,304 ms | 11,577 ms | -5.9% |

确认复测（跳过冷导入）：

| 测量 | 原基线中位数 | 确认复测中位数 | 变化 | 原始运行 |
| --- | ---: | ---: | ---: | --- |
| 热启动 | 8,267 ms | 8,663 ms | +4.8% | 9,631 / 8,663 / 8,199 / 8,671 / 7,547 ms |
| 定向测试 | 12,304 ms | 11,384 ms | -7.5% | 11,384 / 11,821 / 9,967 / 11,228 / 11,457 ms |

资源与错误：

| 测量 | 原基线资源数 | 复测资源数 | 运行期错误 |
| --- | ---: | ---: | ---: |
| 冷导入 | 66 | 66 | 0 |
| 热启动 | 258 | 215 | 0 |
| 定向测试 | 353 | 353 | 0 |

定向探针内部阶段（完整复测中位数）：

| 阶段 | 原基线中位数 | 复测中位数 |
| --- | ---: | ---: |
| probe ready | 1.005 ms | 0.976 ms |
| Start scene loaded | 285.640 ms | 422.598 ms |
| Start scene instantiated | 998.825 ms | 1,136.923 ms |
| world request started | 1,079.485 ms | 1,499.642 ms |
| world scene entered | 3,483.447 ms | 3,551.149 ms |
| Player runtime ready | 3,483.546 ms | 3,551.283 ms |

结论：

- 热启动加载资源中位数从 258 降到 215，说明延迟 routes/cell effects/task modules 有实际资源准备收益；确认复测总耗时仍比基线慢 4.8%，未超过 5% 回退阈值，但没有达到 20% 改善。
- 定向测试中位数改善 7.5%，未达到 20%。
- 冷导入单次明显回退，且 `.godot/imported` 文件从 425 增至 441；当前工作区包含其他范围大量未合并/未跟踪文件，不能把冷导入变化归因于本启动补丁，也不能声明冷导入改善。
- 未扩大到 UI、Player、`project.godot` 或 `asset/**`。

### Startup-5/6：最终启动复测

复测目的：在 Player/UI/manifest/asset 收口后，重新测量启动收益和回退风险；本批只复测和记录，不继续做无目标启动优化。

复测环境：Commit `f425b1fb2ed10da837372cd643c2f1c24e0086f2`，Godot `4.6.1.stable.steam.14d19694e`，热启动 `res://World/Start.tscn`，定向测试 `res://tests/scenes/startup/startup_baseline_probe.tscn`，热启动退出 2 frames。原始结果写入 `test-results/startup-final-benchmark-full.json`。

Benchmark 工具修复：

- `tools/benchmark_startup_loading.ps1` 默认 `ProjectPath` 改为当前工作目录，匹配文档要求的 repo-root 调用方式。
- Godot stdout/stderr 改为重定向到每次测量的临时日志文件，再流式扫描指标；这避免 verbose 输出经 PowerShell 管道触发 `NativeCommandError` 或大日志解析卡死。
- 输出 schema 和计量口径保持不变：5 次中位数、隔离 cold project、隔离 `GODOT_USER_HOME`、资源分类、运行期错误与退出诊断分离。

最终复测：

| 测量 | Startup-1 基线 | Startup-4 确认复测 | Stage 6 结果 | 相对 Startup-1 | 相对 Startup-4 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 冷导入 | 61,379 ms | 不采用首次冷导入信号 | 48,455 ms | -21.1% | 不比较 |
| 热启动中位数 | 8,267 ms | 8,663 ms | 5,056 ms | -38.8% | -41.6% |
| 定向启动中位数 | 12,304 ms | 11,384 ms | 7,090 ms | -42.4% | -37.7% |

原始运行：

| 测量 | 原始结果 | 中位数 | 最小值 | 最大值 |
| --- | --- | ---: | ---: | ---: |
| 冷导入 | 48,455 ms | 不适用（单次） | 48,455 ms | 48,455 ms |
| 热启动 | 5,054 / 5,055 / 5,057 / 5,065 / 5,056 ms | 5,056 ms | 5,054 ms | 5,065 ms |
| 定向测试 | 7,063 / 7,091 / 7,068 / 7,090 / 7,100 ms | 7,090 ms | 7,063 ms | 7,100 ms |

资源与错误：

| 测量 | 唯一加载资源 | Data | Weapons | Enemies | UI | Assets | 运行期错误 | 退出诊断 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 冷导入 | 66 | 6 | 0 | 0 | 7 | 11 | 0 | 0 error-class diagnostics；tail 中仍有 StringName 退出文本 |
| 热启动中位运行 | 215 | 26 | 0 | 0 | 7 | 69 | 0 | 0 |
| 定向测试中位运行 | 353 | 72 | 24 | 0 | 26 | 87 | 0 | 50 error-class shutdown diagnostics across 5 runs；另有 10 warnings |

- 冷导入生成 425 个 `.godot/imported` 文件。
- 5 次热启动均 exit 0、0 运行期错误、0 退出诊断。
- 5 次定向测试均显式 `StartupBaselineProbe: PASS`、exit 0、0 运行期错误。
- 定向测试退出诊断仍为既有 Godot cleanup/leak 类输出：texture/font RID leak、ObjectDB leak warning、`Cannot get path of node as it is not in a scene tree`、`resources still in use at exit`。这些继续与运行期错误分开统计。

定向探针内部阶段：

| 阶段 | Startup-1 中位数 | Stage 6 中位数 | Stage 6 原始范围 |
| --- | ---: | ---: | ---: |
| probe ready | 1.005 ms | 0.719 ms | 0.585-0.823 ms |
| Start scene loaded | 285.640 ms | 189.391 ms | 186.101-197.364 ms |
| Start scene instantiated | 998.825 ms | 863.582 ms | 821.450-880.467 ms |
| world request started | 1,079.485 ms | 1,312.246 ms | 1,271.854-1,347.620 ms |
| world scene entered | 3,483.447 ms | 2,387.414 ms | 2,334.016-2,479.338 ms |
| Player runtime ready | 3,483.546 ms | 2,390.119 ms | 2,336.761-2,482.374 ms |

验证：

- PASS：`powershell -NoProfile -ExecutionPolicy Bypass -File tools/benchmark_startup_loading.ps1 -OutputPath 'test-results\startup-final-benchmark-full.json'`。
- PASS：`git diff --check`。
- PASS：Godot `--headless --path . --check-only --quit`。
- PASS：`run_selected_tests.ps1 -ChangedPath 'data/startup/startup_resource_manifest.json' -Jobs 2 -OutputRoot 'test-results\startup-final-benchmark'`，结果 `PASS=49 FAIL=0 ERROR=0 SHUTDOWN_DIAGNOSTICS=74 RUNTIME_ERRORS=0`。

结论：

- Stage 6 在当前 Steam Godot 4.6.1 环境下，热启动和定向启动都明显快于 Startup-1 与 Startup-4 确认复测；热启动加载资源数保持 215，定向资源数保持 353。
- 由于引擎版本与 Startup-4 文档中的 Godot 4.6.2/4.7 口径不完全一致，这次结果可作为最终本机复测信号，但不能单独证明所有收益都来自代码/manifest 改动。
- 运行期错误为 0；剩余风险集中在既有 shutdown diagnostics，后续应作为 cleanup/leak 专项处理，而不是继续扩大启动优化范围。

### Startup-7: final closure report

- Final report path: `docs/reports/project_slimming_completion_report.md`.
- Final startup benchmark artifact remains `test-results/startup-final-benchmark-full.json`.
- Final benchmark summary: cold import `48,455 ms`; hot start median `5,056 ms`; directed startup median `7,090 ms`; runtime errors `0`.
- Directed startup still reports shutdown cleanup diagnostics separately from runtime errors: 50 error-class shutdown diagnostics plus 10 warnings across 5 runs.
- No Stage 7 startup runtime or benchmark-script change was made.
