# Test Infrastructure Handoff

## 1. 批次目标

建立可独立验证的声明式测试清单契约、保守受影响测试选择器、隔离 Worker，以及 selector-to-Worker 一体化执行入口。

## 2. 修改文件

- `tests/infrastructure/test_manifest.json`
- `tests/infrastructure/source_domain_map.json`
- `tests/infrastructure/TestSelection.psm1`
- `tests/infrastructure/select_affected_tests.ps1`
- `tests/infrastructure/tests/test_selection_test.ps1`
- `tests/README.md`
- `docs/plans/project_slimming/test_infrastructure_progress.md`
- `docs/plans/project_slimming/handoffs/test_infrastructure.md`

## 3. 公开 API 或契约变化

- 清单 schema version 1 要求每项包含 `id`、`entry_type`、`path`、`domain`、`dependency_domains`、`parallel_safe`、`writes_user_data`、`timeout_seconds`。
- 选择器 CLI 支持自动 Git 改动发现、`-BaseRef`、`-ChangedPath`、`-IncludeTest` 和 `-Json`。
- 选择结果包含 `mode`、`catalog_status`、改动路径、领域、显式测试、未知路径、原因和完整测试条目。
- `catalog_status` 当前为 `pilot`；不得把其 `full` 解释为历史测试全集。

## 4. 需要其他范围完成的工作

- UI、Player、Startup 范围在各自 handoff 中提供新测试的最终 ID、入口类型、路径、领域、依赖、并行安全、`user://` 写入和超时建议。
- 并行分支未合并前，本范围不猜测或登记其最终路径。
- Player 当前基线没有 `tests/headless/player/**` 或 `tests/scenes/player/**` 条目；Player 范围合并后再登记。

## 5. 建议的共享文件修改

本批次不需要修改 `project.godot` 或其他协调者独占文件。协调者合并各业务分支后，可在确认最终测试路径后统一扩充清单；清单改动会自动触发保守全量回退。

## 6. 测试及结果

- 选择器自测：PASS，覆盖 schema、空改动、单域、多域、核心、清单自身、依赖不确定、未知生产文件、纯文档和显式追加。
- CLI 单域验证：PASS，UI helper 改动选择 `ui.unified_modal_behavior` 并输出原因。
- CLI 核心验证：PASS，`project.godot` 返回 `full` 和全部 5 个已登记条目。
- Godot 4.7 独立 worktree 导入：PASS；只生成该 worktree 内被忽略的 `.godot` 缓存。
- Godot 4.7 `--headless --path . --check-only --quit`：PASS。
- `git diff --check`：PASS。
- 首次导入自动改写了 `data/localization/rest_area_shop_update.en.translation` 与 `data/localization/rest_area_shop_update.zh_CN.translation`；两项超范围改动已恢复，不包含在交付中。

## 7. 修改前后指标

- 测试基础设施文件：0 -> 5（含 1 个自测）。
- 清单条目：0 -> 5 个代表性 gate。
- 显式源码域规则：0 -> 32。
- 自动选择器场景：0 -> 10。
- 原有测试库存不变：64 个 headless `.gd`、47 个 scene `.tscn`。

## 8. 合并顺序要求

本批次是低层契约，可先于业务范围合并。业务范围测试路径稳定并合并后，再由测试基础设施后续批次或协调者登记新条目。有限并行 Worker 必须建立在本清单契约之后。

## 9. 已知风险

- pilot 清单尚未登记所有历史活跃测试；在扩充完成前不能替代现有全量门禁。
- `data/`、`asset/`、`Shaders/`、`Objects/` 及未知生产路径因依赖不确定而全量回退，反馈提速有限但不会静默漏测。
- 尚未实现 Worker，当前只输出选择结果。
- 现有测试对 `user://` 的实际写入行为尚未逐项审计；pilot 条目采取保守标记。

## 10. 下一安全批次

实现有限并行 Worker：每个进程使用独立用户数据目录，默认并行度保守，捕获退出码、PASS/FAIL/ERROR、超时和日志，并输出可单独复现命令。先用专用基础设施夹具覆盖成功、失败、超时和隔离，再扩充清单登记。

## 11. Batch 3 集成更新

- 已新增 `tests/infrastructure/run_selected_tests.ps1`，把 changed-path selector、Godot check-only、隔离 Worker 串成单命令。
- 默认先运行 Godot `--check-only`，并复用 Worker 诊断分类扫描输出，避免 Godot 退出码为 0 但含 `SCRIPT ERROR` 时误放行。
- 支持 `-ChangedPath`、`-BaseRef`、`-IncludeTest`、`-ManifestPath`、`-SourceMapPath`、`-GodotPath`、`-Jobs`、`-OutputRoot`、`-SkipCheckOnly`、`-Json`。
- docs-only/空选择默认只跑 check-only，不启动 Worker。
- 已新增 `tests/infrastructure/tests/test_selected_runner_test.ps1`，用临时 manifest 验证 `ChangedPath -> Select-AffectedTests -> Invoke-TestWorkers` 的真实执行链。
- 当前验证：PowerShell parser PASS；`test_selection_test.ps1` PASS；`test_selected_runner_test.ps1` PASS。
