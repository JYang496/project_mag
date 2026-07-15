# 游戏加载与 UI 拆分优化计划

## 目标

1. 将 World 所需的同步数据准备提前到开始菜单空闲期。
2. 避免每局重复加载不变的只读资源定义。
3. 缩短点击“新游戏/继续”到进入 World 的等待时间。
4. 将过重的 `UI.tscn` 拆为即时战斗 UI 和按需加载的管理 UI。
5. 保持现有战斗、休整区、暂停、奖励及本地化功能不变。

## 执行前基线

先记录以下时间点，分别在 Debug 和导出版本测量：

- `start_menu_ready`
- `prewarm_started`
- `prewarm_finished`
- `start_button_pressed`
- `threaded_load_started`
- `threaded_load_finished`
- `world_scene_changed`
- `world_ready`
- `first_stable_frame`

同时记录点击开始后连续超过 33 ms 的帧，以及第二次返回标题再进入 World 时是否重复扫描资源目录。

## 阶段一：保留只读资源缓存

### 修改范围

- `autoload/GlobalVariables.gd`
- 新游戏及继续游戏的状态重置调用方

### 步骤

1. 将当前 `reset_runtime_state()` 拆分为：
   - `reset_run_state()`：清理玩家、敌人、UI 引用、战斗计数和本局临时状态。
   - `clear_resource_cache()`：显式清理只读资源目录。
2. 普通新游戏和继续游戏只调用 `reset_run_state()`。
3. 以下只读缓存保留到应用退出：
   - `weapon_list`
   - `mecha_list`
   - `economy_data`
   - `weapon_branch_list`
   - `weapon_passive_branch_list`
4. 仅开发热重载、Mod 内容变化或显式刷新时调用 `clear_resource_cache()`。

### 验收

- 新游戏仍能完全清空本局状态。
- 第二次进入 World 不重新扫描武器、机甲和经济配置目录。
- Cell Effect 与 Task Module 的运行时库存被重置，但定义缓存保留。

## 阶段二：开始菜单预热同步数据

### 修改范围

- `World/start_menu.gd`
- `World/world_entry_prepare_gate.gd`
- `autoload/SpawnData.gd`

### 步骤

1. 开始菜单完成首帧显示后，通过 `call_deferred()` 启动预热。
2. 依次执行：
   - `WorldEntryPrepareGate.prepare_world_entry()`
   - `SpawnData.ensure_loaded()`
3. 保存预热状态与错误结果，避免重复启动。
4. “新游戏/继续”按钮仍调用准备入口作为安全校验，但正常情况下必须直接命中缓存。
5. 如果菜单预热仍产生明显卡帧，将数据、Cell Effect、Task Module 和 Spawn Data 分散到不同帧；第一版不引入 WorkerThread。

### 验收

- 开始菜单先正常显示，再进行预热。
- 点击开始到 threaded load 启动低于 50 ms。
- 预热失败时能显示明确错误，按钮不会永久禁用。

## 阶段三：合并 World 多线程加载代码

### 修改范围

- `World/continue.gd`
- `World/new_game_btn.gd`
- 新增 `World/world_scene_loader.gd`

### 步骤

1. 将 `ResourceLoader.load_threaded_request()`、进度轮询和错误处理提取到共享加载器。
2. 加载器只负责加载 World 并报告进度，不负责新游戏/继续游戏的状态差异。
3. 两个按钮继续负责自身状态准备、按钮文案及最终场景切换。
4. 将进度拆为：
   - 0%–10%：准备运行状态
   - 10%–80%：加载 World 资源
   - 80%–100%：构建战场

### 验收

- 新游戏和继续游戏走同一个加载实现。
- 失败、取消和重复点击均不会留下禁用按钮或半初始化状态。

## 阶段四：拆分 UI Bootstrap

### 修改范围

- `UI/scripts/management/ui_bootstrap_controller.gd`
- `UI/scripts/UI.gd`

### 步骤

将当前 `bootstrap()` 拆为：

- `bootstrap_core()`：战斗首帧必需内容。
- `bootstrap_pause()`：暂停与语言控制。
- `bootstrap_rest_area()`：休整区服务入口。
- `bootstrap_management()`：购买、升级、仓库和棋盘管理。

`bootstrap_core()` 仅保留：

- HUD Presenter
- HP、Ammo、Heat、Resource、Gold、Time
- Weapon Selector 和 Weapon Passive
- Battle Cursor 与 Spread Cursor
- Hint Presenter
- Task Objective HUD
- Battle Contract HUD
- UI dirty signals
- 响应式布局
- Game Over 必要入口

从首帧移除：

- Purchase Management Controller
- Upgrade Management Controller
- Module Warehouse Controller
- Management UI Bootstrap
- Rest Area Management Shell
- 管理列表 `ensure_view()`
- 非首帧使用的 Modal

### 验收

- World 启动时战斗 HUD 完整可用。
- 未进入休整区时，不初始化商店、升级、仓库和棋盘管理控制器。

## 阶段五：提取 Battle HUD

### 新结构

新增：

- `UI/scenes/runtime/battle_hud.tscn`
- 对应 `BattleHudView` 脚本

迁移内容：

- WeaponSelector
- HpLabel
- Gold
- Time
- Resource
- 战斗状态标签
- 任务 HUD Host
- 提示 Host

### 步骤

1. `BattleHudView` 使用唯一节点名暴露稳定引用。
2. `UI.gd` 从长 `$GUI/...` 路径改为访问 `battle_hud` 的字段。
3. 保持 `UI.gd` 作为外部调用门面，避免一次性改动所有业务调用方。

### 验收

- 所有战斗 HUD、响应式布局和本地化正常。
- 移动节点不再要求修改 `UI.gd` 中大量硬编码路径。

## 阶段六：延迟加载休整区入口菜单

### 新结构

新增：

- `UI/scenes/runtime/rest_area_primary_menus.tscn`

迁移：

- Purchase Primary Menu
- Upgrade Primary Menu
- Warehouse Primary Menu
- Board Edit Primary Menu
- Battle Start Primary Menu

### 步骤

1. 首次进入休整区时调用 `ensure_rest_area_ui()`。
2. 实例化后统一绑定现有 Controller。
3. 第二次进入休整区复用已有实例。

### 验收

- World 首帧不创建五套休整区入口菜单。
- 所有入口、返回按钮和语言刷新正常。

## 阶段七：延迟加载 Management Shell

### 新结构

新增：

- `UI/scenes/runtime/management_shell.tscn`

迁移：

- ShoppingRootv2
- UpgradeRootv2
- ModuleManagementRoot
- Warehouse Weapon Panel
- 棋盘与任务管理面板
- 奖励、模块选择和武器替换 Modal

### 步骤

1. `UI.gd` 中管理节点的 `@onready` 硬路径改为普通引用。
2. Management Shell 实例化后通过 `_bind_management_view()` 一次性赋值。
3. 各入口改为 `ensure_purchase_management()`、`ensure_upgrade_management()` 等按需初始化。
4. 第一版只延迟加载，不主动卸载，避免重复实例化和信号生命周期复杂化。

### 验收

- 首次打开管理 UI 时才实例化对应内容。
- 第二次打开复用同一实例。
- 不出现重复信号连接、重复面板或过期引用。

## World Ready 定义

World 可淡入并允许交互的条件：

- 棋盘初始化完成。
- 玩家已进入场景树。
- Camera 首次同步完成。
- Battle HUD 初始化完成。
- 当前可见的第一批 3D 地面完成构建。

休整区管理 UI、仓库、升级和未请求的 Modal 不纳入 `world_ready`。

## 建议提交边界

1. `preserve-runtime-resource-caches`
2. `prewarm-world-data-from-start-menu`
3. `share-world-threaded-loader`
4. `split-ui-bootstrap-phases`
5. `extract-battle-hud-scene`
6. `lazy-load-rest-area-menus`
7. `lazy-load-management-shell`
8. `remove-legacy-ui-node-paths`

每个提交都应独立通过 Godot `--check-only`，并验证新游戏、继续游戏、战斗 HUD、暂停、休整区入口、管理面板、返回流程和语言切换。

## 推荐开始点

优先实施前三项：

1. 保留只读缓存。
2. 开始菜单预热。
3. 拆分 UI bootstrap 阶段。

这三项不要求立即搬动大量场景节点，风险较低，也能先获得并验证主要加载收益。
