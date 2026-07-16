# 提示词 04：拆分 UI Bootstrap 阶段

请将当前 UI 的一次性重型初始化拆成核心战斗、暂停、休整区和管理功能四个阶段，使 World 首帧只承担即时战斗所需 UI，同时保持现有外部 API 和功能行为。

## 开始前

阅读 `UI/scripts/management/ui_bootstrap_controller.gd`、`UI/scripts/UI.gd`、主 UI 场景及 bootstrap 直接调用方。列出当前每个初始化步骤、依赖、信号和首次使用场景，先形成职责映射再改代码。

## 实施要求

- 提供幂等的 `bootstrap_core()`、`bootstrap_pause()`、`bootstrap_rest_area()`、`bootstrap_management()`。
- `bootstrap_core()` 仅保留：HUD Presenter；HP、Ammo、Heat、Resource、Gold、Time；Weapon Selector/Passive；Battle Cursor/Spread Cursor；Hint Presenter；Task Objective HUD；Battle Contract HUD；UI dirty signals；响应式布局；Game Over 必要入口。
- 首帧移除 Purchase、Upgrade、Module Warehouse 控制器，Management UI Bootstrap、Rest Area Management Shell、管理列表 `ensure_view()` 和非首帧 Modal 的初始化。
- 明确阶段依赖；后续阶段被先调用时，应安全补齐必要前置或返回可诊断错误。
- 所有阶段重复调用不得重复连接信号、重复创建节点或覆盖有效引用。
- World 的 ready 条件只等待 `bootstrap_core()`，不得等待休整区或管理阶段。
- 暂停和语言切换仍在首次需要前完成；本地化刷新必须覆盖之后延迟创建的 UI。

## 验收与验证

- World 首帧战斗 HUD、光标、任务、合约、Game Over 和响应式布局完整可用。
- 未进入休整区时，商店、升级、仓库、棋盘管理和非必要 Modal 未初始化，并提供可观察证据。
- 验证暂停、语言切换、战斗结束、进入休整区的兼容性。
- 运行 Godot `--check-only` 和聚焦运行验证，记录 `world_ready` 前后初始化项目。

完成后给出 bootstrap 职责映射、首帧移除项、兼容措施和性能变化。

