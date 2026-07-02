# UI 范围 Handoff

## 1. 批次目标

完成 UI-1：把任务模块未分配确认与库存替换对话框职责从 `UI.gd` 移入独立 `TaskModuleDialogController`。结果已完成，公开行为门面保持不变。

## 2. 修改文件

- `UI/scripts/UI.gd`
- `UI/scripts/components/task_module_dialog_controller.gd`
- `UI/scripts/components/task_module_dialog_controller.gd.uid`
- `tests/headless/ui/run_task_module_dialog_controller_contract_test_headless.gd`
- `tests/headless/ui/run_task_module_dialog_controller_contract_test_headless.gd.uid`
- `tests/scenes/ui/task_module_dialog_controller_contract_test.tscn`
- `docs/plans/project_slimming/ui_progress.md`
- `docs/plans/project_slimming/handoffs/ui.md`

## 3. 公开 API 或契约变化

- `UI.request_task_module_unassigned_confirmation(unassigned_count, on_confirm, on_cancel)` 签名与返回语义不变，现为薄门面。
- `UI.request_task_module_replacement(new_module_id, on_replace)` 签名与返回语义不变，现为薄门面。
- 新内部契约：`TaskModuleDialogController.bind(modal_dialog_controller)` 只接受现有 `ModalDialogController`；Controller 不持有 `owner_ui`。
- 重复打开会丢弃已被替代的 pending 回调并立即清理旧动态按钮；确认或取消回调至多执行一次。

## 4. 需要其他范围完成的工作

- 无业务范围跨域修改。
- 测试基础设施范围合并后，需要按其清单格式登记新 UI 测试场景。

## 5. 建议的共享文件修改

- 测试清单中新增 UI 域 scene 条目：`res://tests/scenes/ui/task_module_dialog_controller_contract_test.tscn`。
- 建议依赖领域为 `ui`、`autoload`，不可与共享 `user://` 状态测试并行时采用保守配置。
- 不需要修改 `project.godot`。

## 6. 测试及结果

- Controller 契约测试：PASS；覆盖重复打开、确认、取消、右键、Esc、动态按钮清理、主按钮/自定义按钮选择和回调一次性。
- 统一模态行为测试：PASS；退出时有既有字体 RID/资源残留告警，不影响显式 PASS。
- Godot 4.6.2 `--check-only --quit`：PASS，无脚本或资源错误。
- `git diff --check`：PASS。
- 初次使用 console 包装器的修改前基线运行在 184 秒后超时且无测试输出；改用等待实际 Godot 进程并写临时日志后验证稳定完成，因此不把该超时用于性能对比。

## 7. 修改前后指标

- `UI.gd`：1802 -> 1683 行。
- `UI.gd`：208 -> 199 个函数。
- `UI.gd`：153 -> 148 个 `var`/`@onready var` 字段。
- `UI.gd` 任务模块专用 pending/custom-button 字段：6 -> 0。
- 新 Controller：183 行、15 个函数、7 个字段（1 个注入依赖 + 6 个自有状态）、0 个 Owner 反向引用。
- 契约测试约 12.6 秒；统一模态测试约 12.5 秒；check-only 约 16.6 秒。均含 Godot 进程启动时间。

## 8. 合并顺序要求

- UI-1 本身不依赖其他业务分支，可独立集成。
- 全局测试清单登记应在 UI-1 和测试基础设施分支都合并后由协调者完成。
- 若后续 UI-3 修改 `ModalDialogController`/统一模态协调，应先合并并验证 UI-1 契约测试。

## 9. 已知风险

- 本地验证使用 Godot 4.6.2，项目配置声明 4.7；需在标准版本复跑。
- 未执行 UI 四组视觉门禁；本批复用了原本的标题、正文、按钮文本、尺寸和 destructive 样式参数。
- 统一模态测试退出仍有既有字体 RID/资源残留告警。

## 10. 下一安全批次

UI-2 管理菜单样式与布局。先固定 1280x720/1920x1080、英文/简体中文四组视觉基线，再把静态样式、本地化刷新和布局职责按现有 Helper/Controller 边界迁移。

---

# UI Handoff Update: UI-2

## 1. 批次目标

完成 UI-2：在视觉不变的前提下，将管理菜单静态样式、本地化刷新和 primary menu 共享布局职责从 `UI.gd` 迁入现有 management helper/controller。

## 2. 修改文件

- `UI/scripts/UI.gd`
- `UI/scripts/management/localization_refresh_controller.gd`
- `UI/scripts/management/management_ui_bootstrap_controller.gd`
- `UI/scripts/management/management_ui_style_helper.gd`
- `tests/headless/ui/run_management_ui_polish_test_headless.gd`
- `tests/headless/ui/run_management_ui_visual_baseline_test_headless.gd`
- `tests/headless/ui/run_management_ui_visual_baseline_test_headless.gd.uid`
- `tests/scenes/ui/management_ui_visual_baseline_test.tscn`
- `docs/plans/project_slimming/ui_progress.md`
- `docs/plans/project_slimming/handoffs/ui.md`

## 3. 公开 API 或契约变化

- `UI._style_primary_menu_controls()` 保留为兼容门面，委派给 `ManagementUiBootstrapController.style_primary_menu_controls()`。
- `LocalizationRefreshController.refresh_board_edit_primary_texts()` 接管 board edit primary 文案刷新。
- `ManagementUiStyleHelper` 缓存管理面板和按钮 StyleBox，减少重复构造。

## 4. 需要其他范围完成的工作

无。

## 5. 建议的共享文件修改

无。`management_ui_visual_baseline_test.tscn` 是视觉门禁，不登记到 headless Worker manifest。

## 6. 测试及结果

- PASS：Godot 4.6.2 `--headless --path . --check-only --quit`。
- PASS：`management_ui_polish_test.tscn`。
- PASS：`management_ui_visual_baseline_test.tscn`，非-headless Vulkan 渲染路径下四组 baseline/candidate 像素完全匹配。
- PASS：Worker 13 项 pilot manifest，PASS=13、FAIL=0、ERROR=0、runtime errors=0；shutdown diagnostics=21。

## 7. 修改前后指标

- `UI.gd`：1683 -> 1607 行。
- `UI.gd` 函数数：199 -> 193。
- 管理样式 StyleBox 构造：每次 style 调用新建 -> helper 缓存复用。
- 四组视觉 PNG：1280x720/1920x1080 × 英文/简体中文，candidate 与 baseline SHA 完全一致。

## 8. 合并顺序要求

UI-2 可在 UI-1 后合并。后续 UI-3 如修改 modal/HUD，应继续复跑 UI-1 task dialog、unified modal、management polish 和视觉门禁。

## 9. 已知风险

- 视觉门禁不能用 Godot 4.6.2 `--headless` dummy renderer；必须使用可渲染 display path。行为测试仍可 headless。
- 项目声明 Godot 4.7，最终 UI 视觉门禁仍需在标准版本复验。
- 退出时仍有既有 CanvasItem/font/resource 泄漏诊断。

## 10. 下一安全批次

UI-3：统一模态/HUD 后续职责迁移。继续保持 `UI.gd` 公开门面兼容，并先补行为/视觉保护再移动职责。

## UI-3 集成更新

- `UI/scripts/management/modal_ui_controller.gd` 增加声明式有序 registry。
- 默认 registry 顺序：`branch_select`、`weapon_replacement`、`route_selection`、`reward_selection`、`module_equip_selection`。
- 每个条目包含 owner field、是否阻塞世界交互、是否可取消。
- `is_modal_open()`、`is_world_interaction_blocking_modal_open()`、`cancel_visible_modal()` 已改为从 registry 解析。
- `UI.gd._cancel_top_level_non_battle_ui()` 已把 selection modal 取消交给 `modal_ui_controller.cancel_visible_modal()`，保留 module transaction、普通 confirmation dialog、board edit、rest-area 的特殊语义。
- `UI.gd._exit_tree()` 清理 registry。
- `run_unified_modal_behavior_test_headless.gd` 现在锁定 registry 默认顺序和能力。
- 当前验证：Godot 4.7 check-only PASS；Worker 单项 `ui.unified_modal_behavior` PASS，shutdown diagnostics=3。
