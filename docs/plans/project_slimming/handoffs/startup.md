# Startup Handoff

## 1. 批次目标

完成 Startup-1：建立可重复的冷导入、热启动和代表性定向测试基线；设计并审计静态资源目录清单。本批次没有实施 Startup-2 运行时清单消费、分阶段准备 API 或世界进入门禁。

## 2. 修改文件

- `tools/benchmark_startup_loading.ps1`
- `data/startup/startup_resource_manifest.json`
- `tests/headless/startup/run_startup_baseline_probe_headless.gd`
- `tests/headless/startup/run_startup_baseline_probe_headless.gd.uid`
- `tests/headless/startup/run_startup_resource_manifest_audit_headless.gd`
- `tests/headless/startup/run_startup_resource_manifest_audit_headless.gd.uid`
- `tests/scenes/startup/startup_baseline_probe.tscn`
- `tests/scenes/startup/startup_resource_manifest_audit.tscn`
- `docs/plans/project_slimming/startup_progress.md`
- `docs/plans/project_slimming/handoffs/startup.md`

## 3. 公开 API 或契约变化

- 没有生产运行时 API 变化。
- 基准工具新增参数契约：`Runs`、`QuitAfterFrames`、`ProjectPath`、`GodotPath`、`HotScene`、`DirectedTestScene`、`SkipColdImport`、`OutputPath`。
- 基准 JSON schema version 1，包含 commit、Godot 版本、隔离策略、冷导入、热启动/定向测试汇总和每次原始结果。
- 静态 manifest schema version 1，当前明确标记 `status=design_only`、`runtime_consumed=false`；生产代码不得把它视为已接入。

## 4. 需要其他范围完成的工作

- 测试基础设施范围在 Startup 分支合并后登记两个 Startup scene 入口。
- 协调者在启动里程碑用项目标准 Godot 版本重复同一基准命令。
- 资源管线可参考冷导入 425 个 imported files 和 61,379 ms 基线，但本 handoff 不提出资源删除。

## 5. 建议的共享文件修改

- 不需要修改 `project.godot`。
- 建议测试清单登记：
  - `res://tests/scenes/startup/startup_baseline_probe.tscn`
  - `res://tests/scenes/startup/startup_resource_manifest_audit.tscn`
- 两项均属于 Startup 域；manifest audit 可并行且不写 `user://`，baseline probe 涉及运行时状态，应独立进程执行。

## 6. 测试及结果

- PASS：Godot 4.6.2 headless `--check-only --quit`。
- PASS：`startup_resource_manifest_audit.tscn`，8 catalogs、93 resources，路径/类型/ID 一致。
- PASS：`startup_baseline_probe.tscn`，菜单到世界和 Player runtime ready。
- 冷导入：61,379 ms，425 imported files，66 unique verbose-loaded resources，0 error/warning，exit 0。
- 热启动 5 次：7,206 / 9,480 / 8,267 / 7,531 / 9,501 ms；中位 8,267 ms；258 unique resources；全为 exit 0、0 error、0 warning。
- 定向测试 5 次：12,588 / 10,837 / 14,821 / 11,777 / 12,304 ms；中位 12,304 ms；353 unique resources；全为显式 PASS、exit 0、0 runtime error。
- 定向探针 Player runtime ready 内部中位 3,483.546 ms。
- verbose 退出清理每次记录 10 条 leak-dump error 和 2 条 warning；未混入 runtime error。
- PASS：修正 leak-dump 分类后，1-run parser check 和 5-run warm/directed benchmark 均 exit 0。
- PASS：`git diff --check`。

## 7. 修改前后指标

- 基准脚本：46 -> 329 行。
- 默认采样：3 次平均值 -> 5 次原始值和中位数。
- 冷导入隔离：无 -> 临时项目副本，排除原 `.godot`。
- 用户数据隔离：无 -> 每进程独立 `GODOT_USER_HOME`。
- 错误统计：脚本/加载错误 -> runtime error、shutdown leak、warning、exit code 和 PASS marker 分离。
- 启动性能没有“修改后”值，因为本批次未改生产启动路径；61,379 / 8,267 / 12,304 ms 分别作为后续冷导入、热启动和定向测试基线。

## 8. 合并顺序要求

1. 本 Startup-1 工具、测试和 design-only manifest 作为一个原子批次合并。
2. 合并后由测试基础设施/协调者登记全局测试清单。
3. Startup-2 必须基于此 manifest audit 通过后再接入运行时。
4. Startup-3 世界进入门禁必须在 Startup-2 准备 API 稳定后实施。

## 9. 已知风险

- 项目声明 Godot 4.7，而本机验证为 Godot 4.6.2；跨版本结果不可直接作为最终验收。
- 热启动 7,206-9,501 ms、定向测试 10,837-14,821 ms，方差明显；必须继续用相同 5-run 中位数比较。
- 定向测试显式 PASS 后仍有稳定的退出泄漏诊断：RID texture/font、14 resources 和 verbose leaked-node path 输出。当前分类为 shutdown leak，不等于运行期错误，但仍需后续单独治理。
- `CellEffectRuntime`、`CellTaskModuleRuntime` 和 `RunRouteManager` 当前在 Autoload `_ready()` 扫描 29 个目录资源，尚未改为世界阶段显式准备。
- Manifest 可能随资源新增而漂移；audit 会显式失败，不能静默回退。
- 首次完整 benchmark 的总退出码因旧分类把 leak dump 中的 `Cannot get path...` 当成 runtime error 而为 1；分类修正后 1-run 与 5-run 复验均为 0。冷导入本身在首次完整运行中为 exit 0、0 error，未重复消耗一次完整冷导入。

## 10. 下一安全批次

Startup-2 静态资源目录：先为 routes、cell effects、task modules 建立显式清单消费和一致性验证，再处理 DataHandler 的 weapons、mechas、economy、branches/passives。准备结果必须显式、幂等并能报告缺失、重复 ID 和无效类型；本批不要同时实现 `World/new_game_btn.gd` / `World/continue.gd` 门禁。

---

# Startup Handoff Update: Startup-2A

## 1. 批次目标

完成 Startup-2A：将 routes、cell effects、task modules 从运行时目录扫描切换为 `data/startup/startup_resource_manifest.json` 指定路径消费，提供显式、幂等、可失败的准备 API。本批不处理 DataHandler 目录，也不实施世界进入门禁。

## 2. 修改文件

- `autoload/ResourceCatalog.gd`
- `autoload/RunRouteManager.gd`
- `autoload/CellEffectRuntime.gd`
- `autoload/CellTaskModuleRuntime.gd`
- `data/startup/startup_resource_manifest.json`
- `tests/headless/startup/run_startup_resource_manifest_audit_headless.gd`
- `tests/headless/startup/run_startup_manifest_runtime_consumption_test_headless.gd`
- `tests/scenes/startup/startup_manifest_runtime_consumption_test.tscn`
- `tests/infrastructure/test_manifest.json`
- `docs/plans/project_slimming/startup_progress.md`
- `docs/plans/project_slimming/overall_progress.md`
- `docs/plans/project_slimming/handoffs/startup.md`

## 3. 公开 API 或契约变化

- `ResourceCatalog.collect_startup_catalog_paths(domain, expected_directory, expected_extension, manifest_path)` 返回 `{ok, paths, errors}`。
- `RunRouteManager.prepare_route_definitions(force=false)` 返回 `{ok, errors, count}`；`reload_route_definitions()` 保持为强制刷新兼容入口。
- `CellEffectRuntime.prepare_definitions(force=false)` 与 `CellTaskModuleRuntime.prepare_definitions(force=false)` 返回 `{ok, errors, count}`；`load_definitions()` 保持为强制刷新兼容入口。
- Startup manifest 状态从 `design_only/runtime_consumed=false` 改为 `runtime_partial/runtime_consumed=true`，当前 `runtime_consumed_domains` 为 `routes`、`cell_effects`、`task_modules`。

## 4. 需要其他范围完成的工作

无。UI、Player、资源管线不需要配合本批。

## 5. 建议的共享文件修改

- 已由协调者登记 `startup.manifest_runtime_consumption` 到 `tests/infrastructure/test_manifest.json`。
- 不需要修改 `project.godot`。

## 6. 测试及结果

- PASS：Godot 4.6.2 `--headless --path . --check-only --quit`。
- PASS：`startup_manifest_runtime_consumption_test.tscn`。
- PASS：`startup_resource_manifest_audit.tscn`，8 catalogs、93 resources。
- PASS：Worker 13 项 pilot manifest，PASS=13、FAIL=0、ERROR=0、runtime errors=0；shutdown diagnostics=21 保留为退出诊断。
- PASS：选择器自测、Worker 自测、`git diff --check`。

## 7. 修改前后指标

- routes/cell effects/task modules 运行时路径发现：目录扫描 -> manifest 指定路径。
- Runtime-consumed startup domains：0 -> 3。
- Pilot manifest entries：12 -> 13。
- 新增 Startup-2A 专用场景测试：0 -> 1。

## 8. 合并顺序要求

本批可在 Worker 分类修复和 12 项 manifest 复验后合并。Startup-2B 的 DataHandler 目录迁移应在本批稳定后进行；Startup-3 世界门禁必须等待 DataHandler 目录准备契约稳定。

## 9. 已知风险

- 本批只改变路径发现方式，没有重复 5-run 热启动/定向启动基准；性能改善不能声称，需 Startup-4 复测。
- Manifest 漂移会让 prepare API 显式失败；当前世界进入门禁尚未接入，因此失败上报仍依赖日志/测试，而不是用户界面阻断。
- DataHandler 仍保留原有准备方式，weapons/mechas/economy/branches/passives 不属于本批完成范围。

## 10. 下一安全批次

Startup-2B：将 DataHandler 的 weapons、mechas、economy 以及后续 branches/passives 迁移到同一 manifest prepare 契约。继续保持本批原则：不新增 Autoload，不修改世界进入门禁，不扩大到 UI 或 Player。

---

# Startup Handoff Update: Startup-2B

## 1. 批次目标

完成 Startup-2B：将 DataHandler 的 weapons、mechas、economy、weapon branches、weapon passives 迁移到同一 startup manifest prepare 契约。本批不修改世界进入门禁。

## 2. 修改文件

- `autoload/DataHandler.gd`
- `data/startup/startup_resource_manifest.json`
- `tests/headless/startup/run_startup_resource_manifest_audit_headless.gd`
- `tests/headless/startup/run_startup_manifest_runtime_consumption_test_headless.gd`
- `docs/plans/project_slimming/startup_progress.md`
- `docs/plans/project_slimming/overall_progress.md`
- `docs/plans/project_slimming/handoffs/startup.md`

## 3. 公开 API 或契约变化

- `DataHandler.prepare_world_data(include_deferred_runtime_data=false)` 和 `prepare_deferred_runtime_data()` 返回 `{ok, errors, count}` 聚合结果；旧调用方可继续忽略返回值。
- 新增 `prepare_weapon_data()`、`prepare_mecha_data()`、`prepare_economy_data()`、`prepare_weapon_branch_data()`、`prepare_weapon_passive_branch_data()`。
- 旧 `load_weapon_data()`、`load_mecha_data()`、`load_economy_data()`、`load_weapon_branch_data()`、`load_weapon_passive_branch_data()` 保留为强制刷新兼容入口。
- Startup manifest 状态从 `runtime_partial` 改为 `runtime_full`，8 个 catalog 均列入 `runtime_consumed_domains`。

## 4. 需要其他范围完成的工作

无。Startup-3 由启动范围继续接入世界进入等待与失败上报。

## 5. 建议的共享文件修改

不需要修改 `project.godot`。

## 6. 测试及结果

- PASS：Godot 4.6.2 `--headless --path . --check-only --quit`。
- PASS：`startup_manifest_runtime_consumption_test.tscn`。
- PASS：`startup_resource_manifest_audit.tscn`，8 catalogs、93 resources。
- PASS：Worker 13 项 pilot manifest after Startup-2B，PASS=13、FAIL=0、ERROR=0、runtime errors=0；shutdown diagnostics=21 保留为退出诊断。

## 7. 修改前后指标

- Runtime-consumed startup domains：3 -> 8。
- DataHandler manifest-prepared resource count：0 -> 64（weapons 15、mechas 5、economy 1、weapon branches 28、weapon passives 15）。
- Total manifest runtime-prepared resources：29 -> 93。

## 8. 合并顺序要求

Startup-2B 应跟 Startup-2A 同批或在其后合并。Startup-3 世界进入门禁必须基于本批 prepare API 的 `{ok, errors}` 结果，不应重新引入目录扫描。

## 9. 已知风险

- 本批仍未重复完整热启动/冷导入 benchmark，不能声明性能改善。
- `prepare_world_data()` 现在能返回失败结果，但当前 `World/new_game_btn.gd` 和 `World/continue.gd` 尚未消费该结果；门禁与用户可见错误留给 Startup-3。
- DataHandler 的 lazy read 方法仍会按需触发 prepare，以保持旧行为兼容。

## 10. 下一安全批次

Startup-3：在 `World/new_game_btn.gd` 和 `World/continue.gd` 等世界进入路径等待 prepare 结果；失败时阻止进入世界并报告，不以空数据继续。

## Startup-3 集成更新

- 已新增 `World/world_entry_prepare_gate.gd`，不是 Autoload。
- Gate 聚合 `DataHandler.prepare_world_data(false)`、`RunRouteManager.prepare_route_definitions()`、`CellEffectRuntime.prepare_definitions()`、`CellTaskModuleRuntime.prepare_definitions()`。
- 注意：这里刻意不准备 weapon branch/passive deferred 数据；`world.threaded_world_load` 仍锁定 title-to-world 阶段不能提前加载这些数据。
- `World/new_game_btn.gd` 和 `World/continue.gd` 在线程加载 world scene 前检查 gate 结果；失败会恢复按钮文本/disabled 状态、`push_error` 聚合错误，并停止进入世界。
- 已新增 `res://tests/scenes/startup/world_entry_prepare_gate_test.tscn`，manifest id 为 `startup.world_entry_prepare_gate`。
- 当前验证：Godot 4.7 check-only PASS；`world_entry_prepare_gate_test.tscn` PASS；`run_selected_tests.ps1 -ChangedPath World/new_game_btn.gd` PASS=5，FAIL=0，ERROR=0。

---

# Startup Handoff Update: Startup-3B / Startup-4

## 1. 批次目标

收口 Autoload 启动期 eager prepare，并复测冷导入、热启动和代表性定向测试。目标是菜单阶段不再由本范围 Autoload 准备 routes、cell effects、task modules；世界入口继续显式等待必要准备。

## 2. 修改文件

- `autoload/RunRouteManager.gd`
- `autoload/CellEffectRuntime.gd`
- `autoload/CellTaskModuleRuntime.gd`
- `World/new_game_btn.gd`
- `tests/headless/startup/run_world_entry_prepare_gate_test_headless.gd`
- `docs/plans/project_slimming/startup_progress.md`
- `docs/plans/project_slimming/handoffs/startup.md`

## 3. 公开 API 或契约变化

- 没有新增 Autoload。
- `CellEffectRuntime.prepare_definitions()` 现在在定义准备成功后一次性恢复 `user://cell_effect_runtime_state.json`，保持继续存档恢复不早于定义加载。
- `World/new_game_btn.gd` 在 world-entry prepare 成功后再调用 `CellTaskModuleRuntime.grant_starting_cell_loadout(0)`。

## 4. 需要其他范围完成的工作

- `LocalizationManager._ready()` 仍调用 `DataHandler.load_weapon_data()`，导致 weapons 可在菜单阶段被准备。`autoload/LocalizationManager.gd` 不在本范围允许修改列表内；建议协调者安排共享/本地化范围把 weapon scene 到 ID 查找改成轻量 manifest 或显式 world-entry 后构建。
- DataHandler 旧 getter 的 lazy prepare 仍为兼容保留。要彻底满足“getter 不隐式触发昂贵加载”，需要先迁移 UI/Player/World 调用方到显式 prepare 后读取。

## 5. 建议的共享文件修改

- 不需要修改 `project.godot`。
- 建议测试基础设施登记或保留 `startup.world_entry_prepare_gate`、`startup.manifest_runtime_consumption`、`startup.resource_manifest_audit`、`startup.baseline_probe`。

## 6. 测试及结果

- PASS：Godot 4.6.2 `--headless --path . --check-only --quit`。
- PASS：`res://tests/scenes/startup/world_entry_prepare_gate_test.tscn`。
- PASS：`res://tests/scenes/startup/startup_manifest_runtime_consumption_test.tscn`。
- PASS：`res://tests/scenes/startup/startup_resource_manifest_audit.tscn`，8 catalogs、93 resources。
- PASS：`res://tests/scenes/startup/startup_baseline_probe.tscn`。
- PASS：`tools/benchmark_startup_loading.ps1` 完整复测，exit 0。
- PASS：确认复测 `-SkipColdImport`，exit 0。

## 7. 修改前后指标

- 热启动唯一资源数：258 -> 215。
- 热启动中位数确认复测：8,267 ms -> 8,663 ms，回退 4.8%，未超过 5% 阈值，但未达到 20% 改善。
- 定向测试中位数确认复测：12,304 ms -> 11,384 ms，改善 7.5%，未达到 20%。
- 冷导入单次：61,379 ms -> 91,606 ms，回退 49.2%；当前工作区含其他范围大量未跟踪/修改文件，不能归因于本启动补丁，也不能声明改善。
- 冷导入 imported files：425 -> 441。
- 运行期错误：冷导入、热启动、定向测试均为 0。

## 8. 合并顺序要求

先合并 startup manifest 和 world-entry prepare gate，再由协调者处理 `LocalizationManager` 的菜单期 weapon data 读取问题。不要在本范围直接修改 UI、Player、`project.godot` 或 `asset/**`。

## 9. 已知风险

- 冷导入没有达到目标，且当前复测受脏工作区和其他范围新增文件影响。
- `LocalizationManager` 菜单期 weapon prepare 仍存在，是继续压缩热启动资源数的主要跨范围阻塞。
- `DataHandler` lazy getter 尚未完全收紧；直接收紧会影响 UI/Player/World 多个调用方，需协调迁移。
- 定向测试退出仍有既有 shutdown leak 诊断，基准脚本未计为运行期错误。

## 10. 下一安全批次

协调者处理 `LocalizationManager` 的轻量 weapon lookup 后，再复测热启动；随后在调用方显式 prepare 迁移完成后，收紧 `DataHandler` 的 lazy getter。冷导入优化应等脏工作区收敛后重新建立干净基准，不扩大到资源有损修改。
