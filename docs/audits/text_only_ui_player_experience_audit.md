# 纯文字 UI 玩家体验审计报告

日期：2026-07-01

范围：当前游戏中仍然主要依赖文字表达的玩家可见 UI，以及这些界面对 roguelike 构筑决策、战斗读秒和休息区操作体验的影响。

本报告只记录现状和优化建议，没有修改游戏脚本、场景、资源或数值。

## 检查范围

重点检查的玩家可见路径：

- 奖励选择：`UI/scripts/reward_selection_panel.gd`、`UI/scenes/reward_selection_panel.tscn`
- 路线选择：`UI/scripts/route_selection_panel.gd`、`data/routes/*.tres`
- 主 HUD：`UI/scripts/components/hud_presenter.gd`、`UI/scripts/components/skill_energy_meter.gd`、`UI/scripts/weapon_selector.gd`
- 任务 HUD：`UI/scripts/components/task_objective_hud_presenter.gd`
- 休息区入口提示：`World/rest_area_hint_presenter.gd`、`World/rest_area.tscn`
- 控制提示面板：`project.godot`、`UI/scripts/components/controls_hint_view.gd`、`UI/scripts/management/pause_ui_controller.gd`、`UI/scripts/management/rest_area_ui_controller.gd`
- 模块仓库和模块详情：`UI/scripts/management/module_management_card_factory.gd`、`UI/scripts/management/module_management_detail_presenter.gd`、`UI/scripts/module_fit_formatter.gd`
- 商店卡片：`UI/scripts/shop_weapon_slot.gd`、`UI/scripts/shop_module_slot.gd`
- 当前 baseline 文档：`docs/audits/roguelike_gameplay_baseline_audit.md`

## 总体结论

当前游戏已经不再是完全纯文字 UI。武器栏、模块仓库、技能能量、任务 HUD 已经有不同程度的视觉表达：武器图标、冷却环、被动 charge 点、模块图标、稀有度颜色、拖拽兼容高亮、技能能量格和任务进度条都已经存在。

但关键决策界面仍然偏文字，尤其是奖励选择、路线选择、主 HUD 的 Heat/Ammo/WeaponState、休息区入口提示。这些界面承担的是 roguelike 游戏最重要的即时判断：我要选哪个奖励、这条路线风险和收益是什么、当前武器/技能/热量状态是否可用、休息区下一步该做什么。当前 UI 把很多判断压在名称、描述、短标签和说明文本里，玩家需要阅读而不是扫读。

## 控制提示行为校正

当前控制提示面板不是简单的“显示/隐藏”开关。`project.godot` 将 `TOGGLE_CONTROLS` 绑定到 F1；F1、Header 收起按钮和 compact 展开按钮都先进入 `ControlsHintView._request_display_state()` / `_request_toggle_display()`，再由统一规则决定是否允许切换。面板已展开时，Header 按钮请求折叠并把当前显示状态切到 `COMPACT`，不会切到 `HIDDEN`；面板处于 compact 时，compact 区域的专用按钮请求 `EXPANDED`。面板本体和内容区域不是点击热区，避免“点击提示栏任意位置”与按钮语义冲突。真正的隐藏来自暂停菜单里的持久设置：`PlayerAssistSettings.controls_hint_mode` 可选 `Adaptive`、`Always Expanded`、`Hidden`，由 `PauseUiController` 的 controls hint 选项写入。

需要区分两层状态：

- `PlayerAssistSettings.controls_hint_mode` 是持久设置：`Adaptive` / `Always Expanded` / `Hidden`。
- `ControlsHintView.display_state` 是当前临时显示状态：`EXPANDED` / `COMPACT` / `HIDDEN` / `CONTEXT_REMINDER`。

F1 操作在 Adaptive 模式下刻意不改持久模式，只做临时展开/折叠；现有测试覆盖“F1 临时展开/折叠仍保持 Adaptive”，也覆盖 Hidden / Always Expanded 不把 F1 当作有效 toggle 消费。在非战斗文本上下文中，F1 折叠会按 `_text_context_identity()` 记录到 per-context compact 记忆，因此同一个 `warehouse` / `upgrade` / `task_management` 等上下文刷新时会保持 compact；切到尚未折叠过的新文本上下文时，`_render_text_context()` 会展开，让新菜单上下文第一次出现时先教玩家操作。compact 状态只显示当前上下文摘要和 `F1 Expand`，不再放入完整教学行。

战斗和非战斗提示也不是同一套展示规则。战斗中 Adaptive 默认展开，然后会按时间或玩家已移动/攻击自动折叠；非战斗文本上下文没有这个自动折叠，只靠 F1 折叠、F1 展开或首次进入新上下文展开。因此“战斗里自己收起来”和“菜单里切换后又展开”是两套逻辑共同造成的当前行为，不应描述成同一个隐藏/显示循环。暂停菜单的三档持久设置语义为：Adaptive 会展开新提示且允许用 F1 临时折叠；Always Expanded 始终展开提示、覆盖 per-context compact 记忆，并禁用折叠按钮避免假承诺；Hidden 持久隐藏控制提示面板。

二级菜单当前也不再是“打开时提示隐藏”。实际路径是 `RestAreaUiController.get_secondary_menu_context()` 返回 `purchase`、`upgrade`、`warehouse`、`grid_management`、`task_management` 等上下文，再由 `ControlsHintView` 渲染对应文本。旧结论如果仍写成“二级菜单打开时提示隐藏”，已经不符合当前代码。

## 当前已有的视觉化基础

### 武器栏

`UI/scripts/weapon_selector.gd` 已经提供较成熟的战斗读数基础：

- 武器图标来自 weapon 节点 Sprite。
- 主手/副手使用不同背景。
- 冷却使用 diamond progress。
- 被动状态有独立进度环、闪光和 charge beans。

这部分方向是正确的，应该成为后续 HUD 视觉化的参考：状态信息贴近图标，进度用环/点/高亮表达，文字只保留必要状态。

### 技能能量

`UI/scripts/components/skill_energy_meter.gd` 已经把技能能量从普通文本改为核心格：

- 当前能量用填充表达。
- 技能消耗用下划线表达。
- 能量不足用红色缺口表达。
- 冷却用遮罩表达。

这比 `Resource: value` 文本更接近动作 roguelite 的即时反馈需求。

### 模块仓库

`UI/scripts/management/module_management_card_factory.gd` 已经为模块仓库卡片提供：

- 模块图标。
- 稀有度颜色。
- 等级和稀有度。
- 安装目标文本。
- effect tags 文本。
- 拖拽时兼容/不兼容边框高亮。

这里的问题不是缺少数据，而是标签和兼容结果仍主要以文字呈现。下一步应把 effect tags 和 fit status 变成统一视觉 chip / icon 状态。

### 任务 HUD

`UI/scripts/components/task_objective_hud_presenter.gd` 已经使用：

- 小色块 marker。
- 状态颜色。
- 数值文本。
- 指令文本。
- 进度条。

任务 HUD 已经比纯文字强，但 marker 目前是 hash 色块，不是稳定语义图标。玩家看到颜色不一定能理解是 Kill、Hold、Clear、Hunt 还是 Dodge。

## 仍然偏纯文字的主要问题

### P0：奖励选择面板仍然不够适合构筑决策

现状：

- `reward_selection_panel.gd::_build_reward_card_button()` 构建的卡片主要包含稀有度色条、type label、title、short tag。
- 模块奖励的短标签来自 `ModuleFitFormatter`，但最终仍是 `"Fits current / Tag / Tag"` 这样的文字串。
- detail panel 仍是 title、detail text、outcome text 三段文字。
- 奖励卡没有直接显示 weapon icon / module icon / task icon。
- 构筑轴 Heat、Mark、Freeze、Reload、Area、On Hit、Execute、Economy 没有形成第一眼可扫读的视觉 chip。

体验影响：

- 玩家在奖励选择时需要读文本判断构筑价值。
- 模块选项开启后，标准奖励流会更频繁出现模块；如果模块适配只靠短文本，选择成本会显著上升。
- 稀有度色条可以表达稀有度，但不能表达“为什么适合当前构筑”。

建议：

1. 奖励卡增加左侧 icon 区：武器使用 `WeaponDefinition.icon`，模块使用模块 Sprite，任务模块/Cell Effect 使用对应定义图标，经济奖励使用固定资源图标。
2. 把 `ModuleFitFormatter.build_display_data()` 的 `fit_status` 做成状态徽章：Fits、Blocked、No current weapon。
3. 把 effect tags 渲染为 chip，而不是拼接成一行文字。优先 chip：Heat、Mark、Freeze、Reload、Area、On Hit、Execute、Economy。
4. detail panel 保留解释文本，但第一层卡片只显示图标、名称、等级/稀有度、2-4 个 chip、兼容状态。
5. 保留 task reward 当前的 blocking / next-step 文案，不要为了视觉化破坏任务奖励流程。

### P0：路线选择是纯文字按钮

现状：

- `RouteSelectionPanel.open_for_routes()` 为每条路线创建一个 `Button`。
- 按钮文本是路线名加路线描述。
- `data/routes/*.tres` 已经包含 HP、damage、timeout、reward option count、item/module level bonus、fallback chip 等字段，但 UI 没有视觉比较这些字段。

体验影响：

- Difficult 的身份主要是更高 HP、更高伤害、更短时间、更好奖励，但玩家需要读描述猜具体差异。
- Bonus 资源存在，但如果未来进入选择列表，纯文本也不能清楚表达“无战斗，拿奖励，推进层数”。
- 路线选择应是风险收益比较，而不是普通菜单。

建议：

1. 把路线按钮改为路线卡：左侧 route icon / difficulty icon，右侧指标行。
2. 指标行显示：Enemy HP、Enemy Damage、Time、Reward Level、Fallback Chip。
3. 数值相对默认路线做颜色提示：风险上升用红/橙，收益上升用蓝/绿。
4. 增加一句短 identity tag，例如 `Standard`、`High Risk`、`No Combat`，避免只读长描述。

### P1：主 HUD 的 Heat / Ammo / WeaponState 仍然以文字为主

现状：

- `HudPresenter._update_heat_label_text()` 输出 `"Heat: value/max (percent)"` 和 overheat 文本。
- `HudPresenter._update_ammo_label_text()` 输出 `"Ammo: current/max (Reloading x.xs)"`。
- `HudPresenter._update_weapon_state_label_text()` 输出 `"Main:... Offhand:... Swap:... PS:..."`。
- 技能能量已经视觉化，但 Heat、Ammo、Reload、WeaponState 还没有同级别视觉化。

体验影响：

- 战斗中玩家没有时间阅读长 HUD 文本。
- Heat 和 Ammo 都是节奏资源，应该通过条、环、格、颜色和闪烁反馈表达。
- WeaponState 文本混合主手、副手数量、swap 状态、player skill cooldown、fail reason，信息层级过密。

建议：

1. Heat 改为热量条或围绕当前热武器的 ring；overheat 用红色临界区、脉冲或锁定 icon 表示。
2. Ammo 改为弹匣格或短 bar；reload 使用倒计时遮罩，不把秒数作为唯一提示。
3. WeaponState 拆分：主手状态并入武器栏，PS cooldown 并入技能图标或 energy meter，失败原因只做短 toast。
4. Gold 和 Time 可以继续文本，但建议配固定 icon，减少 Label 漂浮感。

### P1：休息区入口提示仍是标题加状态文本

现状：

- `World/rest_area_hint_presenter.gd` 为 Purchase、Upgrade、Warehouse、Board、Battle Center 生成文字提示。
- hover/selected 有样式变化，但语义仍主要靠文本。
- 状态如 upgrades available、stored modules、board action 仍是第二行文本。

体验影响：

- 新玩家需要读每块入口文字，而不是通过图标和 badge 形成空间记忆。
- 休息区本质是回合间操作 hub，应让玩家快速看到哪里有待处理事项。

建议：

1. 每个入口绑定固定图标：Purchase、Upgrade、Warehouse、Board、Start Battle。
2. 状态用 badge 表示：可升级数量、临时模块数量、待安装 cell effect、待部署 task module、pending task reward。
3. hover 时 HUD hint 可以保留详细文字，但场景内标签应减少长句。
4. Start Battle 保留 hold progress ring，并加更明显的 center action icon。

### P1：任务 HUD marker 缺少稳定语义

现状：

- `TaskObjectiveHudPresenter` 使用 `ColorRect` marker。
- marker 颜色由 icon_key hash 生成。
- 进度条和状态颜色已经存在。

体验影响：

- hash 色块不能让玩家建立任务类型记忆。
- 多任务并行时，颜色随机感会降低可读性。

建议：

1. 用固定 task icon 替换 hash 色块：Kill、Hold、Clear、Hunt、Dodge。
2. 保留进度条，完成/等待/阻塞状态继续用现有颜色。
3. 任务卡中只保留短 label 和 value；instruction 应尽量短，并在详情/hover 中解释。

### P2：商店卡片有图标，但说明仍偏文本

现状：

- `ShopWeaponSlot` 已有武器 icon、稀有度颜色、价格颜色。
- `ShopModuleSlot` 已有模块 icon、价格、效果描述、适配需求。
- 模块需求目前会显示原始 trait / delivery / capability 字符串。

体验影响：

- 商店比奖励选择压力低，但仍会影响玩家对构筑轴的理解。
- 原始 requirement 字符串不如统一 chip 清晰。

建议：

1. 商店沿用奖励卡 chip 系统，避免一套 UI 一套说法。
2. 价格旁加 gold icon；买不起时用禁用 overlay，而不仅仅价格变红。
3. 模块适配需求用 chip 显示，具体原因放 tooltip 或详情区。

## 推荐实施顺序

### 第 1 步：建立统一构筑 chip / icon 词表

目标：

- 给 Heat、Mark、Freeze、Reload、Area、On Hit、Execute、Economy、Projectile、Beam、Defense 等标签建立统一显示规格。
- 输出应包含 label、color、icon_key、排序权重。

建议落点：

- 复用或扩展 `UI/scripts/module_fit_formatter.gd` 的标签格式化能力。
- 如果需要更通用，可新增 `UI/scripts/build_tag_display.gd`，由 reward panel、module detail、shop slot 共用。

### 第 2 步：重做奖励选择卡片

目标：

- 奖励卡第一眼能看出：类型、稀有度、图标、等级、构筑标签、当前适配状态。
- detail panel 只作为解释层。

这是最高优先级，因为奖励选择是构筑方向的核心决策点。

### 第 3 步：重做路线选择卡片

目标：

- 路线选择从读描述变成风险收益比较。
- 每条路线至少显示 HP、Damage、Time、Reward bonus 的视觉指标。

### 第 4 步：主 HUD 资源视觉化

目标：

- Heat、Ammo、Reload、PS cooldown 不再依赖长文本。
- 保留文字作为 fallback 或 tooltip，但战斗时主要看图形状态。

### 第 5 步：休息区入口 badge 化

目标：

- 玩家进入休息区后，第一眼知道哪里有可操作事项。
- 状态从长句转为图标 + 数字 badge + hover 详情。

### 第 6 步：任务 HUD 图标化

目标：

- 把任务类型从 hash 色块改为固定图标。
- 强化任务类型记忆和多任务扫读能力。

## 验证记录

已执行：

```powershell
git status --short
```

结果：

- 当前工作区已有大量未提交和未跟踪改动。
- 本报告新增前未修改这些既有改动。

已执行：

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit
```

结果：

- Godot check-only 退出码为 0。
- 当前 shell 中 `godot` 不在 PATH，因此使用已验证的 Steam 安装路径执行。

已执行：

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/scenes/ui/controls_hint_view_test.tscn
```

结果：

- 退出码为 0。覆盖 F1 临时展开/折叠、Adaptive 持久模式保持、Hidden 不被 F1 改写、per-context compact 记忆、Always Expanded 覆盖、英文/中文 compact 文案和暂停菜单三档标签。
- 当前 shell 未显示测试脚本的 PASS 文本，但失败路径会 `push_error()` 并以非 0 退出。
- 仍输出既有 `CanvasItem` RID leak 和 `ObjectDB` leak warning。

已执行：

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/scenes/world/secondary_menu_world_blocking_contract_test.tscn
```

结果：

- 退出码为 0。覆盖二级菜单 world blocking 合约，并确认二级菜单上下文路径仍可通过测试场景验证。
- 当前 shell 未显示测试脚本的 PASS 文本，但失败路径会 `push_error()` 并以非 0 退出。
- Godot 退出时仍可能输出既有 RID/resource leak warning；本次报告只记录行为，不处理资源释放警告。

已执行：

```text
MCP Godot run_project: res://World/world.tscn
```

结果：

- 主场景可启动。
- MCP stop 输出的 `finalErrors` 为空，没有启动级 fatal error。

## 本轮未涉及范围

- 没有修改 Player、World、data/weapon、data/module 或战斗数值资源。
- 没有修改 `UI/scripts/UI.gd`。
- 没有修改暂停菜单布局或 `PlayerAssistSettings` 存储格式。
- 没有覆盖 `docs/audits/roguelike_gameplay_baseline_audit.md`。
