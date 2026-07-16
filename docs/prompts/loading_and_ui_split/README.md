# 游戏加载与 UI 拆分实施提示词

本目录把 `docs/plans/loading_and_ui_split_optimization_plan.md` 拆成可独立执行、按顺序衔接的编码提示词。

## 使用顺序

1. `00_loading_performance_baseline.md`
2. `01_preserve_runtime_resource_caches.md`
3. `02_prewarm_world_data_from_start_menu.md`
4. `03_share_world_threaded_loader.md`
5. `04_split_ui_bootstrap_phases.md`
6. `05_extract_battle_hud_scene.md`
7. `06_lazy_load_rest_area_menus.md`
8. `07_lazy_load_management_shell.md`
9. `08_remove_legacy_paths_and_final_validation.md`

每次只执行一个提示词。开始前检查工作树，保留用户已有改动；完成后报告修改文件、验证命令、验证结果、遗留风险和实测性能数据。后续提示词应以之前步骤已经完成为前提；若实际代码与此前结果不同，应先检查现状再做最小兼容调整。

## 通用约束

- 遵守仓库根目录 `AGENTS.md`，先读 `project.godot`、`tests/README.md` 和任务直接相关文件。
- 使用 Godot 4.7 / GDScript，不改变战斗、继续游戏、休整区、暂停、奖励和本地化的可见行为。
- 不扫描历史报告、历史提示词、归档测试和素材目录。
- 不顺手重构无关代码；保持 `UI.gd` 为现有业务调用方的兼容门面。
- 新增或移动场景节点时保留 owner、唯一节点名、脚本绑定、信号、主题、布局和本地化行为。
- 每步至少运行 Godot `--check-only`；当前没有已注册的活动测试，按 `tests/README.md` 进行聚焦验证，并明确区分自动验证与人工验证。
- 不伪造性能结果。无法自动测量时，保留埋点并给出明确的人工复测步骤。

