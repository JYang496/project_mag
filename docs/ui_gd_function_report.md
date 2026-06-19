# UI.gd 功能归类报告

源文件：`UI/scripts/UI.gd`

当前定位：`UI.gd` 是顶层 `CanvasLayer` UI 协调器。它仍保留场景根节点引用、旧测试可见字段、兼容桥接方法和跨系统弹窗调度入口；具体界面逻辑已逐步下沉到 controller、presenter 和 view。

## 1. 生命周期与启动装配

代码范围：`_ready()`、`_exit_tree()`、`_init_*_controller()`、`_restore_pending_equipment_transactions()`。

职责：
- 注册和清理 `GlobalVariables.ui`。
- 设置全局 UI theme。
- 创建并绑定 UI controller、presenter、view。
- 恢复未完成的武器替换、模块装配事务。
- 连接阶段、本地化、玩家和背包 dirty 信号。

主要委托文件：
- `UI/scripts/management/ui_bootstrap_controller.gd`
- `UI/scripts/management/modal_ui_controller.gd`
- `UI/scripts/components/ui_dirty_signal_controller.gd`

## 2. HUD 与刷新调度

代码范围：`_physics_process()`、`_refresh_hud_if_needed()`、`_mark_*_dirty()`。

当前状态：
- HUD 静态、HP、库存、武器状态仍由 `UI.gd` 调度 dirty flag。
- HUD 文本和 HP 动画由 `UI/scripts/components/hud_presenter.gd` 执行。
- HUD 布局已迁到 `HudPresenter.layout_hud()`；`UI.gd._layout_hud()` 只保留兼容委托。
- HUD 连续刷新计时已迁到 `HudPresenter.refresh_continuous()`；`UI.gd` 只记录测试可见刷新计数。
- 商店、升级、仓库动作按钮刷新已从每帧轮询改为 `_schedule_management_action_refresh()` 的 deferred 合并刷新。

后续建议：
- 将 HUD 连续刷新计时器继续迁入 `HudPresenter`，让 `UI.gd` 不再承担 HUD 帧调度。
- 保留 `reset_ui_refresh_debug_counts()` / `get_ui_refresh_debug_counts()`，直到相关测试迁到 presenter 层。

## 3. 弹窗与阻塞选择流程

代码范围：武器替换、模块确认、武器分支、模块装配、路线选择、奖励选择。

职责：
- 作为跨系统阻塞 UI 的统一入口。
- 保持旧字段同步，供测试和现有场景读取。
- 将具体弹窗创建和行为下沉到 modal/controller/view。

主要委托文件：
- `UI/scripts/management/modal_ui_controller.gd`
- `UI/scripts/components/equipment_pickup_flow_controller.gd`
- `UI/scripts/components/weapon_branch_selection_controller.gd`
- `UI/scripts/components/module_transaction_dialog_controller.gd`

## 4. 休息区管理 UI

代码范围：购买、升级、仓库一级菜单和二级面板入口。

当前状态：
- `RestAreaUiController` 是购买、升级、仓库菜单流的主要 owner。
- `RestAreaUiController` 已直接持有 `UiLayoutController`，主路径不再通过 `owner_ui._show_primary_menu()` / `_hide_primary_menu()` / `_stop_primary_menu_tween()` 反向调用 `UI.gd`。
- `UI.gd` 中购买、升级、仓库函数仍作为兼容入口保留。
- 确认无外部调用的购买/仓库/升级纯转发包装已删除；仍被旧脚本使用的 `upgrade_panel_out()` 保留。
- 模块管理可用性判断已迁到 `RestAreaUiController.is_module_management_available()`；`UI.gd.is_rest_area_module_management_available()` 只保留委托。

主要委托文件：
- `UI/scripts/management/rest_area_ui_controller.gd`
- `UI/scripts/management/rest_area_management_shell.gd`
- `UI/scripts/management/purchase_management_controller.gd`
- `UI/scripts/management/upgrade_management_controller.gd`
- `UI/scripts/management/module_warehouse_controller.gd`
- `UI/scripts/management/module_management_card_factory.gd`
- `UI/scripts/management/warehouse_drag_controls.gd`
- `UI/scripts/management/upgrade_detail_presenter.gd`

后续建议：
- 迁移外部调用方到 `rest_area_ui_controller` 直接 API 后，再删除 `UI.gd` 中纯转发包装。
- 继续减少 `RestAreaUiController` 对 `owner_ui` 字段的直接读写，改为显式绑定 root/view 引用。

## 5. 布局、菜单动画与样式

当前状态：
- 响应式布局、居中面板、左侧一级菜单和菜单 tween 由 `UI/scripts/management/ui_layout_controller.gd` 管理。
- 管理面板和按钮样式由 `UI/scripts/management/management_ui_style_helper.gd` 管理。
- `UI.gd` 仍保留 `_show_primary_menu()`、`_hide_primary_menu()`、`_fit_*()` 等兼容桥接。

后续建议：
- 当 `RestAreaUiController` 和测试都不再调用 `UI.gd` 布局桥接后，删除这些纯转发方法。
- 将共享 primary-menu 样式刷新继续保留在本地化刷新链路中，避免语言切换后布局漂移。

## 6. 提示、光标与 Game Over

当前状态：
- 任务提示、休息区 hover hint、zone hint 由 `UI/scripts/components/hint_presenter.gd` 执行。
- 战斗硬件光标和 spread overlay 由 `UI/scripts/components/battle_cursor_presenter.gd` 执行。
- Game Over 视图由 `UI/scenes/components/game_over_view.tscn` 和 `game_over_view.gd` 执行。
- `UI.gd` 仍保留对外方法，例如 `set_quest_hint()`、`set_rest_area_hover_hint()`、`debug_get_game_over_stat_texts()`。

后续建议：
- 对外调用点迁移后，删除提示和光标相关纯转发包装。
- 光标体验改动仍需手动实机感受；headless 只能证明解析和状态路径。

## 推荐下一步

1. 把 `RestAreaUiController` 中对 `owner_ui` 的 root 字段访问改为显式 `bind_roots()`。
2. 继续拆分 `module_management_view.gd` 的拖拽规则执行逻辑和 `upgrade_management_view.gd` 的 item 数据构建逻辑。
3. 迁移测试和场景调用到 controller/presenter 直接 API。
4. 每轮继续使用 `godot --headless --path . --check-only --quit` 加聚焦 UI 测试验证。
