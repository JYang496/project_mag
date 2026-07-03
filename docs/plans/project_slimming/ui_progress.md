# UI 瘦身进度

## 已完成批次

### UI-1：任务模块对话框 Controller

- 新增 `TaskModuleDialogController`，以 `RefCounted` 持有任务模块对话框的六项 pending/动态按钮状态。
- Controller 仅注入现有 `ModalDialogController`，不持有或回写 `owner_ui`。
- `UI.gd` 保留 `request_task_module_unassigned_confirmation` 与 `request_task_module_replacement` 两个公开兼容门面。
- 删除 `UI.gd` 中旧六个状态字段及任务模块对话框内部辅助实现。
- 新增独立 Controller 契约测试，覆盖重复打开、确认、取消、右键、Esc、动态按钮清理和回调至多一次。

### UI-2：管理菜单样式与布局职责迁移

- 将主菜单共享布局职责从 `UI.gd` 迁入 `ManagementUiBootstrapController.style_primary_menu_controls()`。
- 将 board edit primary 本地化刷新职责迁入 `LocalizationRefreshController.refresh_board_edit_primary_texts()`。
- 将管理面板标题、面板 StyleBox 和按钮 StyleBox 静态资源缓存迁入 `ManagementUiStyleHelper`。
- 删除 `UI.gd` 中管理菜单位置常量、primary menu panel helper、management panel style/input helper、instruction/button position facade。
- 扩展 `management_ui_polish_test.tscn`，验证共享 StyleBox 资源复用和 legacy equipped shop visibility 查询。
- 新增 `management_ui_visual_baseline_test.tscn`，覆盖 1280x720/1920x1080 × 英文/简体中文四组合成视觉基线。

## 修改前后关键指标

| 指标 | 修改前 | 修改后 |
| --- | ---: | ---: |
| `UI.gd` 行数 | 1802 | 1683 |
| `UI.gd` 函数数 | 208 | 199 |
| `UI.gd` `var`/`@onready var` 字段数 | 153 | 148 |
| `UI.gd` 任务模块专用 pending/custom-button 字段 | 6 | 0 |
| 新 Controller 行数 / 函数数 / 字段数 | 0 / 0 / 0 | 183 / 15 / 7（1 个注入依赖 + 6 个自有状态） |
| 新 Controller `owner_ui`/Owner 反向引用 | 0 | 0 |

UI-2 后：

- `UI.gd`：1683 -> 1607 行。
- `UI.gd` 函数数：199 -> 193。
- 管理面板 StyleBox 构造从每次调用创建 -> helper 内缓存复用。
- 四组视觉 candidate 与 baseline SHA 完全一致：
  - `en_1280x720`: `16c7a8aa24e3dcb4bba9fb2ee25da77d9cc164ada75338b2a6e3bdd66a6ec4c6`
  - `zh_CN_1280x720`: `571162012407ec9e865e0159acc9116809efb0aa081fdba7ca0816b581f7ed29`
  - `en_1920x1080`: `8dd336c3e2b594c382aa92c4f1565e9177a9dea3637dfd9a32f679822b005a11`
  - `zh_CN_1920x1080`: `513a9a63fd3acc65a90869890340a10f265cdb88626c4aed369a50a40fe5aee9`

## 测试及结果

- 修改前新增的 Controller 契约测试按预期因目标脚本尚不存在而产生 preload 解析失败。
- `task_module_dialog_controller_contract_test.tscn`：PASS，约 12.6 秒（含进程启动）。
- `unified_modal_behavior_test.tscn`：PASS，约 12.5 秒（含进程启动）；退出时仍报告既有字体 RID/资源残留告警。
- `management_ui_polish_test.tscn`：PASS。
- `management_ui_visual_baseline_test.tscn`：PASS；非-headless Vulkan 渲染路径下 baseline/candidate 四组像素匹配。Godot 4.6.2 `--headless` 使用 dummy renderer，不能生成 SubViewport 图像。
- Worker 13 项 pilot manifest：PASS=13、FAIL=0、ERROR=0。
- Godot 4.6.2 `--headless --check-only --quit`：PASS，约 16.6 秒，无脚本或资源错误。
- `git diff --check`：PASS。

## 已知风险和下一推荐批次

- 本机可用 Godot 为 4.6.2，而 `project.godot` 声明 4.7；协调集成时应使用项目标准 Godot 版本复跑。
- UI 视觉门禁需要非-headless 渲染路径；headless dummy renderer 只适合行为测试。
### UI-3: unified modal registry

- `ModalUiController` now owns a declarative ordered modal registry for selection modals.
- The registry stores modal id, owner field, world-blocking capability, and cancel capability.
- `is_modal_open()`, `is_world_interaction_blocking_modal_open()`, and `cancel_visible_modal()` now resolve behavior through the registry instead of a hard-coded panel array.
- `UI.gd._cancel_top_level_non_battle_ui()` delegates registered selection modal cancellation to `ModalUiController`, reducing duplicated fallback cancel branches while keeping existing dialog and rest-area special cases.
- `UI.gd._exit_tree()` clears the modal registry during teardown.
- `ui.unified_modal_behavior` now asserts default registry order and capabilities.
- PASS: Godot 4.7 `--headless --path . --check-only --quit`.
- PASS: Worker single-test `ui.unified_modal_behavior` with PASS=1, FAIL=0, ERROR=0; shutdown diagnostics=3 retained.

### UI-4: HUD dirty-refresh gate registration

- Reused the existing `hud_dirty_refresh_test.tscn` gate instead of adding a second HUD refresh system.
- Registered `ui.hud_dirty_refresh` in `tests/infrastructure/test_manifest.json`.
- Also registered existing UI contract scenes for player health, skill energy, combat resource, and module-fit display.
- `UI.gd` remains at 1599 lines; this batch improves selected-test coverage, not UI ownership size.

### UI-5: HUD refresh coordination controller

- Added `UI/scripts/components/hud_refresh_controller.gd` to own HUD dirty flags, HUD refresh ordering, continuous refresh cadence, and HUD refresh debug counters.
- `UI.gd` keeps compatibility entrypoints such as `_refresh_hud_if_needed`, `_mark_all_hud_dirty`, `_mark_hud_hp_dirty`, `_mark_hud_inventory_dirty`, `_mark_hud_weapon_dirty`, `reset_ui_refresh_debug_counts`, and `get_ui_refresh_debug_counts`, but those now delegate to the controller.
- `UiDirtySignalController` no longer writes HUD dirty state directly; it calls the narrow UI mark methods.
- Updated `ui.hud_dirty_refresh` to assert the controller-owned dirty state instead of private `UI.gd` fields.
- `UI.gd`: 1599 -> 1588 lines.
- PASS: Godot `--headless --path . --check-only --quit`.
- PASS: `run_selected_tests.ps1 -ChangedPath 'UI/scripts/UI.gd' -Jobs 2`: PASS=49, FAIL=0, ERROR=0, shutdown diagnostics=74, runtime errors=0. Result root: `test-results/ui-slimming-hud-refresh`.
- PASS: `git diff --check`.
- No layout or visual output changed; non-headless visual baseline was not required.

### UI-6: final closure report

- Final report path: `docs/reports/project_slimming_completion_report.md`.
- Final `UI.gd` line-count snapshot: 1802 plan-baseline lines -> 1588 final lines; 1599 lines at Stage 7 start -> 1588 final lines.
- Final responsibility state: `UI.gd` remains the scene-level facade, while task-module dialog state, management style/layout work, selection-modal registry behavior, and HUD dirty-refresh coordination now live in extracted controllers/helpers.
- No Stage 7 UI runtime code changed.

- 下一安全批次：继续在已有行为/视觉门禁保护下迁移 localization refresh 或 pause/settings UI 职责，不为行数目标裸拆。
