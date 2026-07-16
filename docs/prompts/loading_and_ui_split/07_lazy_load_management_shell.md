# 提示词 07：延迟加载 Management Shell

请新增 `UI/scenes/runtime/management_shell.tscn`，将商店、升级、仓库、棋盘/任务管理及相关 Modal 从 World 首帧移除，并在对应功能首次打开时按需初始化和复用。

## 开始前

检查 `UI.gd`、Management UI bootstrap、Purchase/Upgrade/Warehouse/Board/Task 控制器和相关 Modal。建立管理节点引用、创建顺序、信号、返回路径、数据刷新和本地化依赖清单。

## 实施要求

- 迁移 ShoppingRootv2、UpgradeRootv2、ModuleManagementRoot、Warehouse Weapon Panel、棋盘与任务管理面板，以及奖励、模块选择、武器替换 Modal。
- 将 `UI.gd` 中指向这些节点的 `@onready` 硬路径改为可空普通引用；Shell 实例化后由 `_bind_management_view()` 集中、原子地赋值。
- 提供幂等的 `ensure_purchase_management()`、`ensure_upgrade_management()`、`ensure_warehouse_management()` 及其他实际需要的入口。
- 只在首次打开相应功能时实例化/初始化；第二次打开复用。若采用一个整体 Shell，也不得在创建时无条件执行全部管理列表的重型 `ensure_view()`。
- 第一版不卸载 Shell，避免重复实例化和复杂信号生命周期。
- 防止重复连接、重复面板、过期引用、半初始化绑定和入口并发调用。
- Modal 必须在其首次真正需要时可用，并保持奖励等流程的阻塞/回调语义。
- 延迟创建后同步当前语言、主题、布局和最新数据状态。

## 验收与验证

- 证明 World 首帧未实例化 Management Shell 内容，首次打开才创建，第二次复用。
- 逐一验证购买、升级、仓库、棋盘、任务、奖励、模块选择、武器替换及全部返回路径。
- 验证跨语言切换、连续开关、多入口切换、战斗/休整区状态变化后数据刷新。
- 搜索重复信号风险和遗留硬路径；运行 Godot `--check-only` 及聚焦运行验证。

完成后列出按需入口、绑定引用、每个子系统的首次初始化时机、兼容风险和验证结果。

