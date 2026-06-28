# 玩家操作引导审查与改进建议

## 审查结论

当前游戏内置提示已经覆盖了基础输入，但还不足以独立引导不熟悉操作的新玩家完成全部游戏流程。

基础战斗和休息区入口层面的提示相对完整；问题主要集中在三类位置：

1. 提示文案和真实输入行为存在不一致。
2. 玩家进入二级菜单后，全局操作提示会消失，复杂面板只能依赖局部文字。
3. 新增的格子任务、任务模组、战斗任务 HUD 还缺少“从获得到部署再到完成和领奖”的连续引导链。

这份建议按“先修误导，再补断点，最后做体系化新手引导”的顺序组织。

## 当前已有提示覆盖

### 输入映射

`project.godot` 当前定义了这些主要输入：

- `UP/DOWN/LEFT/RIGHT`：WASD 和方向键移动。
- `ATTACK`：鼠标左键攻击。
- `CLICK`：鼠标左键点击 UI 或世界交互。
- `INTERACT`：F。
- `CANCEL`：鼠标右键。
- `ESC`：暂停。
- `SWITCH_LEFT / SWITCH_RIGHT`：Q / E 切换武器。
- `SKILL_PLAYER`：Space。
- `SKILL_WEAPON`：R。

基础输入本身没有明显缺项。

### 全局操作提示

`UI/scripts/components/controls_hint_view.gd` 会按状态显示右上角操作提示：

- 休息区：左键点击菜单和区域，左键长按中心开始战斗，Esc 暂停。
- 一级菜单：左键点击按钮，右键退出当前菜单。
- 战斗：WASD 移动，左键攻击，Space 角色技能，R 武器技能，Q/E 切换武器，Esc 暂停。

但这个控件在二级菜单打开时会隐藏，因此玩家进入购买、升级、仓库、格子管理、任务管理等具体面板后，统一提示链会中断。

### 休息区区域提示

`World/rest_area_hint_presenter.gd` 会在休息区区域悬停时显示：

- 购买：购买武器与模组。
- 升级：升级武器与模组，并显示可升级数量。
- 仓库：打开武器或模组仓库。
- 格子面板：安装格子效果，并提示选择格子效果后点击或拖到 active cell。
- 中心：按住中心开始战斗。

休息区的“在哪里点”基本可被发现。

### 战斗任务 HUD

`UI/scripts/components/task_objective_hud_presenter.gd` 会在战斗中显示最多两个任务卡、状态值和进度条。它适合做战斗中的持续状态反馈，但现在更像“进度仪表”，不是完整教学。

## 明确问题

### 1. R 键提示与真实行为不一致

当前本地化文本把 R 写成：

- `[R] Weapon Skill`
- `[R] 武器技能`

但 `Player/Mechas/scripts/player_active_skill_runtime.gd` 中 `process_input_event()` 对 `SKILL_WEAPON` 的处理是：

```gdscript
if event.is_action_pressed("SKILL_WEAPON"):
    try_reload_main_weapon()
```

也就是说，R 当前实际是“装填主武器”，不是“释放武器技能”。同一文件里确实存在 `try_cast_main_weapon_active_skill()`，但没有由当前输入路径触发。

这会直接误导新玩家。玩家按 R 期待技能，看到的却是换弹行为；同时 HUD 里仍有 `WS` 字段，会进一步强化误解。

建议二选一：

- 如果设计目标是 R 装填：把教程和 HUD 文案改为 `Reload / 装填`，避免写武器技能。
- 如果设计目标是 R 武器技能：把输入逻辑接回 `try_cast_main_weapon_active_skill()`，并为手动装填另设键位或保留自动换弹。

优先级：P0。

### 2. 二级菜单缺少持续操作提示

`ControlsHintView.refresh_for_phase()` 当前在 `secondary_menu_open` 时直接隐藏提示。这样玩家从一级菜单进入具体面板后，会失去“右键返回、点击选择、拖拽可用、Esc 暂停/取消”的统一提示。

受影响的面板包括：

- 购买。
- 升级。
- 仓库。
- 格子面板。
- 任务管理。

这些面板内有局部说明，但不是统一、持续、状态化提示。新玩家在复杂面板中最容易不知道：

- 右键是否还能返回。
- 当前应该先选左边还是右边。
- 是否支持拖拽。
- 操作会立即生效、待提交，还是开战时才消耗。

建议改成：二级菜单不隐藏提示，而是切换为“当前面板操作提示”。例如：

- 购买：`左键选择商品 / 点击购买 / 右键返回`
- 升级：`选择武器或模组 / 查看花费 / 点击升级 / 右键返回`
- 仓库：`拖拽交换武器或模组 / 右键返回`
- 格子面板：`选择格子效果 / 点击或拖拽到 active cell / 开战时消耗 / 右键返回`
- 任务管理：`选择任务模组 / 点击或拖拽到 active cell / 开战时消耗 / 未部署会丢弃`

优先级：P0。

### 3. 任务管理页只说明“先选再点”，但没有完整交互规则

`UI/scripts/cell_management_panel.gd` 任务管理页当前有标题和副标题：

`Select a task module, then choose an active cell. Battle start consumes deployed modules and discards unassigned modules.`

选中任务模组后也会显示：

`Selected: ... Choose an active cell on the grid to deploy it.`

这能告诉玩家最小路径，但不足以覆盖实际操作：

- 卡片支持点击选择，也支持拖拽。
- 目标 cell 必须是 active cell。
- 已部署任务 cell 可以 hover 查看详情。
- 点击已部署任务 cell 会锁定详情窗口。
- 替换已有任务会弹确认，旧任务会被丢弃。
- 已部署任务开战后消耗。
- 未部署任务开战会被丢弃。
- 单场最多激活 2 个任务。

建议把任务管理页拆成三层提示：

1. 顶部短说明：只保留当前主要动作。
2. 侧边状态提示：显示 `Ready To Install` 数量、已部署数量、上限。
3. 空状态/选中状态提示：针对当前状态显示具体下一步。

推荐文案：

- 未选中时：`Select or drag a task module to an active cell. Up to 2 tasks can be deployed for the next battle.`
- 选中后：`Click a highlighted active cell to deploy. Right click to cancel selection.`
- 已有部署时：`Hover a deployed task cell to preview details. Click to pin the detail window.`
- 有未部署任务准备开战时：`Unassigned task modules will be discarded when battle starts.`

优先级：P1。

### 4. 格子面板和任务管理入口容易混淆

休息区区域提示里 `Board Edit / 格子面板` 的说明主要是格子效果：

`Select a cell effect, then click or drag it onto an active cell.`

但现在格子面板下还有 `Grid Management` 和 `Task Management` 两个入口。对于新玩家来说，“格子面板”可能被理解为只管理格子效果，不一定知道任务模组部署也在这里。

建议在休息区区域提示中把格子区域描述改成双入口：

- 标题：`Board`
- 状态：`Install cell effects or deploy task modules`
- 操作：`Open Grid Management or Task Management`

中文：

- 标题：`格子`
- 状态：`安装格子效果或部署任务模组`
- 操作：`进入格子管理或任务管理`

优先级：P1。

### 5. 战斗任务 HUD 反馈有进度，但目标解释不足

`TaskObjectiveHudPresenter` 显示任务标签、数值和进度条。它适合告诉玩家“进度是多少”，但未必能解释“我现在应该怎么做”。

不同任务类型需要不同的短提示：

- 击杀：`Kill enemies`
- 守点：`Stay inside the marked cell`
- 清场：`Clear enemies near this cell`
- 猎杀精英：`Defeat the marked elite`
- 闪避生存：`Avoid damage until timer ends`

建议 `CellTaskModuleRuntime.get_active_task_statuses()` 或各任务模块输出一个 `instruction` 字段，让 HUD 卡片在空间允许时显示一行短目标。HUD 不要显示长句，只显示行动动词。

优先级：P1。

### 6. 任务奖励与下一步部署之间缺少闭环提示

任务完成后已有奖励提示：

- `Objective complete. Reward choice unlocked for the Rest Area.`
- 奖励面板：`Choose one reward for completing an objective this battle.`

如果奖励选择的是任务模组，它会进入 `Ready To Install`。但新玩家可能不知道下一步应回到任务管理部署。

建议在任务模组奖励详情里追加结果提示：

- 英文：`Added to Ready To Install. Deploy it from Board > Task Management before the next battle.`
- 中文：`已加入待部署任务模组。请在下一场战斗前进入 格子 > 任务管理 进行部署。`

优先级：P1。

### 7. 右键取消规则需要更一致地显式化

当前代码里右键取消被广泛使用：

- 非战斗状态下 `UI.gd` 会通过 `handle_non_battle_right_cancel()` 处理右键。
- 多个弹窗也支持 `CANCEL` 或右键。
- 一级菜单提示写了 `[RMB] Exit current menu`。

但二级面板中提示隐藏，玩家不一定知道右键仍然是主要返回路径。

建议统一加在所有管理面板的页脚或右上提示：

- `RMB: Back`
- `Esc: Pause`

如果某些弹窗支持 Esc/右键取消，也应在按钮区旁边保留短提示。

优先级：P1。

### 8. 空状态提示需要从“事实描述”改成“下一步动作”

目前部分空状态是事实描述，例如：

- `No task modules. Complete cell objectives to earn more.`
- `No cell effects yet. Complete objectives to earn them.`

这类提示是正确的，但还可以更行动化：

- `No task modules. Complete cell objectives in battle, then choose task module rewards.`
- `No cell effects yet. Complete cell objectives and choose cell effect rewards.`

中文：

- `暂无任务模组。战斗中完成格子任务后，可在奖励中选择新的任务模组。`
- `暂无格子效果。战斗中完成格子任务后，可在奖励中选择格子效果。`

优先级：P2。

## 推荐实施顺序

### 第一阶段：修正误导和断点

目标是让现有提示不再说错，并让玩家进入二级菜单后仍有操作指导。

建议改动：

1. 修正 R 键文案或输入行为。
2. 扩展 `ControlsHintView`，支持二级菜单上下文。
3. 在 `RestAreaUiController` 或 `UI.gd` 中提供当前二级菜单类型给 `ControlsHintView`。
4. 所有二级面板至少显示 `左键操作 / 右键返回`。

验收标准：

- 战斗提示里的 R 键行为与真实代码一致。
- 打开购买、升级、仓库、格子管理、任务管理时，右上角或面板内仍显示当前操作提示。
- 右键返回路径被明确提示。

### 第二阶段：补齐任务模组闭环

目标是让玩家知道任务模组从哪里来、怎么部署、什么时候消耗。

建议改动：

1. 更新任务管理页顶部说明。
2. 增加已部署数量和最多部署数量提示。
3. 增加 hover/click 详情提示。
4. 任务模组奖励详情提示下一步去 `Board > Task Management`。
5. 未部署任务开战确认弹窗继续保留，并强化“会丢弃”的文案。

验收标准：

- 玩家拿到任务模组奖励后，能从奖励面板知道下一步去哪里。
- 任务管理页能直接说明点击和拖拽两种部署方式。
- 玩家能知道 active cell 限制和部署上限。

### 第三阶段：战斗任务目标短提示

目标是让任务 HUD 不只显示进度，还告诉玩家行动目标。

建议改动：

1. 为每种任务状态增加短行动提示。
2. HUD 卡片显示 `任务名 + 行动提示 + 进度`。
3. 完成时保留短反馈，不使用长句持续占位。

验收标准：

- 五类基础任务都有不超过一行的操作目标。
- 战斗中不需要打开说明文档也能理解当前任务该做什么。

## 建议文案清单

### 战斗提示

如果 R 保持为装填：

- `[R] Reload`
- `[R] 装填`

如果 R 改回武器技能：

- `[R] Weapon Skill`
- `[R] 武器技能`

不要在行为未统一前继续使用“武器技能”描述 R。

### 二级菜单提示

购买：

- `Click an item to preview. Confirm to buy. RMB: Back.`
- `点击物品查看，确认后购买。右键返回。`

升级：

- `Select a weapon or module, review cost, then upgrade. RMB: Back.`
- `选择武器或模组，确认花费后升级。右键返回。`

仓库：

- `Drag or click weapons and modules to manage storage. RMB: Back.`
- `拖拽或点击武器与模组管理仓库。右键返回。`

格子管理：

- `Select a cell effect, then click or drag it to an active cell. Battle start consumes pending edits.`
- `选择格子效果，点击或拖到已激活格子。开战时消耗待提交调整。`

任务管理：

- `Select or drag a task module to an active cell. Deployed tasks are consumed when battle starts.`
- `选择或拖拽任务模组到已激活格子。已部署任务会在开战时消耗。`

### 战斗任务 HUD

击杀：

- `Kill enemies`
- `击杀敌人`

守点：

- `Stay inside the marked cell`
- `停留在标记格子内`

清场：

- `Clear enemies near this cell`
- `清理该格附近敌人`

猎杀精英：

- `Defeat the marked elite`
- `击败标记精英`

闪避生存：

- `Avoid damage until timer ends`
- `在倒计时结束前避免受伤`

## 风险与注意事项

1. 不建议把所有说明都塞进一个新手弹窗。当前系统是状态驱动的，最好在玩家实际进入对应状态时给短提示。
2. 不建议用长句覆盖战斗 HUD。战斗中只需要行动动词、目标和进度。
3. 不建议让 `ControlsHintView` 继续只知道 `primary_menu_open / secondary_menu_open` 两个布尔值；它需要知道具体二级面板类型。
4. 如果 R 键最终是装填，HUD 中 `WS` 字段也要一起审查，避免同一界面中同时出现“R 装填”和“WS 武器技能”。
5. 任务模组和格子效果都放在格子入口下时，入口命名要避免只强调 `Board Edit`，否则玩家会找不到任务部署。

## 最小可行改动方案

如果只做一轮小改，建议范围如下：

1. 修改 `data/localization/ui_texts.csv` 中 R 键教程文本，使其匹配真实行为。
2. 修改 `UI/scripts/components/controls_hint_view.gd`，新增二级菜单提示模式。
3. 从 `RestAreaUiController` 或 `UI.gd` 传入当前二级菜单类型。
4. 修改 `UI/scripts/cell_management_panel.gd` 的任务管理页文案，明确点击、拖拽、active cell、开战消耗。
5. 修改任务奖励详情文案，任务模组奖励说明下一步去任务管理部署。

这能用较小代码量覆盖最大的新手迷路风险。
