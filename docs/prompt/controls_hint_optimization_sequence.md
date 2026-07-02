# Controls Hint Optimization Sequential Prompt Pack

工作目录：`D:\Godot Projects\project_mag`

目标：按审计中观察到的现象逐一优化控制提示面板，让 F1、持久设置、菜单上下文教学、战斗自适应折叠的语义更清晰且更少打扰。

通用约束：

- 开始前必须执行 `git status --short`，记录与本任务相关的既有改动。
- 不要回滚、覆盖或格式化无关文件；如果目标文件已有他人改动，先读懂并在其基础上追加最小改动。
- 每个阶段只做该阶段范围内的工作。不要提前实现后续阶段。
- 代码优先保持现有 `ControlsHintView`、`PlayerAssistSettings`、`PauseUiController`、本地化和测试风格。
- 验证优先使用：
  - `godot --headless --path . --check-only --quit`
  - `godot --headless --path . --scene res://tests/scenes/ui/controls_hint_view_test.tscn`
  - `godot --headless --path . --scene res://tests/scenes/world/secondary_menu_world_blocking_contract_test.tscn`
- 如果当前 shell 中 `godot` 不在 PATH，可用已验证路径：
  - `D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- 最终汇报必须包含：改动文件、行为变化、兼容字段/旧行为处理方式、验证命令和结果、是否仍有既有 RID/resource leak warning。

## 阶段 1：统一 F1 语义为“展开/折叠”

### Prompt

你在 `D:\Godot Projects\project_mag` 工作。请只执行“控制提示 F1 文案语义统一”这一阶段。

先读：

- `docs/audits/text_only_ui_player_experience_audit.md`
- `project.godot`
- `UI/scripts/components/controls_hint_view.gd`
- `UI/scripts/management/pause_ui_controller.gd`
- 本地化文本文件中包含 `ui.controls.expand`、`ui.controls.collapse`、`ui.settings.controls_hint` 的条目
- `tests/scenes/ui/controls_hint_view_test.gd`

允许修改：

- `UI/scripts/components/controls_hint_view.gd`
- pause/settings 相关本地化文本资源
- `tests/scenes/ui/controls_hint_view_test.gd`
- 必要时可更新 `docs/audits/text_only_ui_player_experience_audit.md` 的验证记录

禁止修改：

- `Player/`、`World/`、`data/`、武器/模块资源
- `UI/scripts/UI.gd`
- 与控制提示无关的 HUD、奖励、路线、商店 UI

目标：

1. 确认 F1 仍然只做临时 `EXPANDED` / `COMPACT` 切换，不把普通折叠写入 `PlayerAssistSettings.controls_hint_mode`。
2. 所有玩家可见文案避免把 F1 描述成 Hide/Show。统一使用 Expand/Collapse，中文统一使用 展开/折叠 或 展开/收起。
3. 暂停菜单的三档持久设置继续保持 `Adaptive` / `Always Expanded` / `Hidden`，但说明文字要避免让玩家误以为 F1 会修改持久隐藏模式。
4. 测试要明确覆盖：F1 折叠后 `controls_hint_mode` 仍为 `Adaptive`。

验证：

```powershell
godot --headless --path . --check-only --quit
godot --headless --path . --scene res://tests/scenes/ui/controls_hint_view_test.tscn
```

最终汇报：

- 列出改动文件。
- 说明 F1 当前语义。
- 说明持久 Hidden 与临时 Compact 的边界。
- 贴出验证结果。

## 阶段 2：非战斗文本上下文按 context 记住折叠

### Prompt

你在 `D:\Godot Projects\project_mag` 工作。请只执行“非战斗文本上下文 per-context 折叠记忆”这一阶段。

先读：

- `UI/scripts/components/controls_hint_view.gd`
- `UI/scripts/management/rest_area_ui_controller.gd`
- `tests/scenes/ui/controls_hint_view_test.gd`
- `tests/headless/world/run_secondary_menu_world_blocking_contract_test_headless.gd`
- `tests/scenes/world/secondary_menu_world_blocking_contract_test.tscn`

允许修改：

- `UI/scripts/components/controls_hint_view.gd`
- `tests/scenes/ui/controls_hint_view_test.gd`
- 必要时可修改 `tests/headless/world/run_secondary_menu_world_blocking_contract_test_headless.gd`

禁止修改：

- `UI/scripts/management/rest_area_ui_controller.gd`，除非你发现 context 输出本身是错误根因；如果必须改，先在最终报告中说明原因。
- `UI/scripts/UI.gd`
- 暂停菜单持久设置语义
- 任何战斗平衡、资源、武器、模块文件

目标：

1. 保留当前设计：新文本上下文第一次出现时可以展开教学。
2. 将 `_manual_text_context_collapsed` 从单一当前状态扩展为按上下文身份记录。可使用类似：

```gdscript
var _collapsed_text_contexts: Dictionary = {}
```

3. 建议 context key 使用 `_text_context_identity()` 或等价稳定身份，而不是完整文本内容；同类二级菜单如 `warehouse`、`upgrade`、`task_management` 应能跨刷新保持折叠。
4. 行为目标：
   - 第一次进入 `warehouse`：展开。
   - 在 `warehouse` 按 F1：折叠到 compact。
   - 刷新同一个 `warehouse`：保持 compact。
   - 切到 `upgrade`：第一次展开。
   - 在 `upgrade` 折叠后，再回到 `warehouse`：如果之前已折叠过，保持 compact。
5. `Always Expanded` 必须覆盖 per-context 折叠记忆。
6. `Hidden` 必须仍由 `PlayerAssistSettings.controls_hint_mode` 控制。
7. 战斗 Adaptive 自动折叠逻辑不要改。

测试要求：

- 在 `controls_hint_view_test.gd` 增加上述 warehouse/upgrade/task 或等价上下文切换断言。
- 确认 F1 临时展开仍不修改 `Adaptive`。
- 确认 `Always Expanded` 不被 per-context compact 记忆压住。

验证：

```powershell
godot --headless --path . --check-only --quit
godot --headless --path . --scene res://tests/scenes/ui/controls_hint_view_test.tscn
godot --headless --path . --scene res://tests/scenes/world/secondary_menu_world_blocking_contract_test.tscn
```

最终汇报：

- 列出改动文件。
- 说明 context key 的选择。
- 说明 `Adaptive` / `Always Expanded` / `Hidden` 三档如何与 per-context 记忆交互。
- 贴出验证结果和任何既有 warning。

## 阶段 3：优化 compact 状态的可恢复提示

### Prompt

你在 `D:\Godot Projects\project_mag` 工作。请只执行“compact 状态可恢复提示优化”这一阶段。

先读：

- `UI/scripts/components/controls_hint_view.gd`
- 本地化文本中 `ui.controls.expand`、`ui.tutorial.state.secondary.*`、`ui.tutorial.panel.secondary.*` 相关条目
- `tests/scenes/ui/controls_hint_view_test.gd`

允许修改：

- `UI/scripts/components/controls_hint_view.gd`
- 控制提示相关本地化文本资源
- `tests/scenes/ui/controls_hint_view_test.gd`

禁止修改：

- `UI/scripts/UI.gd`
- 休息区控制器、世界交互、战斗逻辑
- 与控制提示无关的 UI 文案

目标：

1. compact 状态只承担“这里有帮助，可以展开”的职责，不塞完整教学。
2. 非战斗文本上下文 compact 文案建议形态：

```text
Warehouse controls · F1 Expand
```

中文可用：

```text
仓库操作 · F1 展开
```

3. 保留当前上下文标题，让玩家知道 compact 提示属于哪个菜单。
4. 确保长文本不会撑宽面板或导致 label 溢出。
5. 点击 compact 区域仍应展开。

测试要求：

- 更新或新增 compact 文案断言。
- 保留现有 label bounds 检查。
- 覆盖中文 locale 下的 compact 文案不溢出。

验证：

```powershell
godot --headless --path . --check-only --quit
godot --headless --path . --scene res://tests/scenes/ui/controls_hint_view_test.tscn
```

最终汇报：

- 列出改动文件。
- 给出英文/中文 compact 示例。
- 说明点击和 F1 展开是否保持一致。
- 贴出验证结果。

## 阶段 4：整理设置菜单说明并保存行为说明

### Prompt

你在 `D:\Godot Projects\project_mag` 工作。请只执行“设置菜单三档说明和文档同步”这一阶段。

先读：

- `UI/scripts/management/pause_ui_controller.gd`
- `UI/scripts/components/controls_hint_view.gd`
- `docs/audits/text_only_ui_player_experience_audit.md`
- 相关本地化文本资源
- `tests/scenes/ui/controls_hint_view_test.gd`

允许修改：

- `UI/scripts/management/pause_ui_controller.gd`
- 控制提示设置相关本地化文本资源
- `tests/scenes/ui/controls_hint_view_test.gd`
- `docs/audits/text_only_ui_player_experience_audit.md`

禁止修改：

- `PlayerAssistSettings` 的存储格式，除非当前设置无法表达三档语义。
- `UI/scripts/UI.gd`
- 与控制提示无关的设置项

目标：

1. 设置菜单三档语义清楚：
   - `Adaptive`：新提示会展开，用过后可折叠。
   - `Always Expanded`：始终展开提示。
   - `Hidden`：隐藏提示面板。
2. 如果当前 UI 只有 OptionButton 文本，没有说明位，不要大改暂停菜单布局；优先使用更准确的选项标签和 tooltip/辅助文本，如果现有组件支持。
3. 文档同步记录最终行为：
   - F1 是临时展开/折叠。
   - Hidden 是持久设置。
   - 非战斗上下文采用 per-context 折叠记忆。
   - 战斗 Adaptive 仍按时间/玩家动作自动折叠。
4. 不要改变存档兼容性。

测试要求：

- 继续确认暂停菜单有三档选项。
- 如果改了本地化 key，测试要覆盖英文和中文主要标签。

验证：

```powershell
godot --headless --path . --check-only --quit
godot --headless --path . --scene res://tests/scenes/ui/controls_hint_view_test.tscn
godot --headless --path . --scene res://tests/scenes/world/secondary_menu_world_blocking_contract_test.tscn
```

最终汇报：

- 列出改动文件。
- 说明是否修改了存储格式；如果没有，明确写“未修改 PlayerAssistSettings 存储格式”。
- 说明最终四类行为：F1、Adaptive、Always Expanded、Hidden。
- 贴出验证结果。

