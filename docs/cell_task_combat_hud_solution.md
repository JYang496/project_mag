# 格子任务战斗 HUD 解决方案

## 背景

当前格子任务已经有 5 类基础任务：`Kill`、`Hold`、`Clear`、`Hunt`、`Dodge`。任务部署和奖励闭环由 `CellTaskModuleRuntime`、`CellObjectiveModule`、`TaskRewardManager` 串联。

问题在战斗表现层：玩家在战斗中没有足够直接的任务描述和进度反馈。部分任务已有文本提示，例如 `Clear` 和 `Dodge` 会调用 `UI.set_quest_hint()`，但这些文本偏长，玩家在战斗中不适合阅读完整句子；`Kill`、`Hold`、`Hunt` 的主要进度目前更多停留在模块内部或 debug 输出上。

目标是把战斗中的任务信息改成“图标 + 短标签 + 数字进度 + 进度条”，让玩家不用读说明也能理解当前该做什么。

## 设计原则

- 战斗中只显示状态，不显示长说明。
- 任务管理页负责解释规则，战斗 HUD 负责识别、定位和进度。
- 单场最多 2 个任务，所以 HUD 可以固定显示所有 active task，不需要折叠列表。
- 每个任务模块必须提供统一状态，不允许各任务自己拼接长文本。
- 世界内格子负责空间定位，HUD 负责全局进度。
- 兼容现有 `set_quest_hint()`，但不再把它作为主要任务 HUD。

## 玩家可见形态

战斗 HUD 固定显示最多 2 张小任务卡：

```text
[icon] 击杀 3/10   ███-------
[icon] 闪避 6.2s   ██████----
```

每张卡只包含：

- 任务图标：快速识别类型。
- 短标签：2 到 4 个汉字。
- 数字进度：当前值和目标值。
- 小进度条：无需读数字也能判断完成度。
- 完成态：短暂闪光后显示 `完成`，再保持低亮或打勾状态。

不要在战斗 HUD 中显示完整描述，例如“Deploy to an active cell...”或“Quest: Clear Cell 80% remaining”。这些内容只放在任务管理详情里。

## 统一状态接口

在 `Board/Cells/Modules/cell_obj_base.gd` 增加统一接口：

```gdscript
signal task_status_changed(cell_id: int)

func get_combat_task_status() -> Dictionary:
	return {
		"cell_id": 0,
		"module_id": "",
		"type": "",
		"icon_key": "",
		"label": "",
		"progress": 0.0,
		"value_text": "",
		"state": "active",
	}
```

字段含义：

| 字段 | 含义 |
| --- | --- |
| `cell_id` | 格子 logical id，用于 HUD 与世界格子同步 |
| `module_id` | 当前任务模组 id |
| `type` | 稳定任务类型，例如 `kill`、`hold`、`clear`、`hunt`、`dodge` |
| `icon_key` | HUD 图标 key，避免 UI 反查任务类型 |
| `label` | 战斗短标签，例如 `击杀`、`守点` |
| `progress` | 0.0 到 1.0 的归一化进度 |
| `value_text` | 短数字文本，例如 `3/10`、`6.2s` |
| `state` | `waiting`、`active`、`complete`、`blocked` |

`progress` 必须始终可用。即使任务还没开始，也返回 `0.0`，不要让 HUD 自己推断。

## 5 类任务显示规则

| 任务 | HUD 标签 | value_text | progress | 状态说明 |
| --- | --- | --- | --- | --- |
| Kill | `击杀` | `3/10` | `kill_count / required_kill_count` | 玩家不在格子时仍显示，但可用低亮表现“未计数” |
| Hold | `守点` 或 `占领` | `5.1/8s` 或 `42/50` | 取当前更接近完成的条件 | 如果时间进度领先，显示守点秒数；如果格子进度领先，显示占领数值 |
| Clear | `清场` | `4/5` | `cleared_weight / required_weight` | 不显示浮点 remaining，改为清掉多少/目标多少 |
| Hunt | `精英` | `0/1` | `killed_elites / elite_count` | 任务精英保留高亮，HUD 只显示剩余目标 |
| Dodge | `闪避` | `6.2/10s` | `survival_elapsed / required_survival_seconds` | 玩家离开格子后重置为 0，并显示 waiting 或低亮 |

`Clear` 现在内部使用权重进度，HUD 可以把目标四舍五入成整数展示。重要的是玩家看到“清了几个/要清几个”，不要看到 `1.0 remaining` 这类开发视角文本。

## 世界内格子反馈

HUD 解决全局信息，但玩家还需要知道任务在哪个格子：

- 有 active task 的格子显示任务图标。
- 格子边缘或角落显示迷你进度条。
- 当前玩家所在任务格子可高亮任务图标。
- 完成时格子闪烁一次，显示短字 `完成`。
- `Clear` / `Hunt` 的任务敌人继续保留高亮，但颜色要和对应任务卡一致。

格子上不放长文字。格子只做定位和状态提醒。

## UI 架构建议

新增一个轻量 presenter：

```text
UI/scripts/components/task_objective_hud_presenter.gd
```

职责：

- 接收当前 active task status 列表。
- 创建或复用最多 2 个任务卡。
- 根据 `state`、`progress`、`value_text` 更新显示。
- 控制完成闪光、低亮、隐藏。
- 不读取具体任务模块参数，不做任务规则判断。

数据来源建议放在运行时层：

```gdscript
CellTaskModuleRuntime.get_active_task_statuses()
```

它可以遍历 active task 对应的 cell，找到 cell 上的 `CellObjectiveModule`，调用 `get_combat_task_status()`。这样 UI 不需要知道任务模块挂在哪个节点下。

## 现有提示的处理

`UI.set_quest_hint()` 保留，但降级为临时提示：

- 任务开始时短暂显示：`清场开始`、`闪避开始`。
- 任务完成时短暂显示：`任务完成`。
- 无效配置或特殊阻塞时显示短提示。

不要继续用 `set_quest_hint()` 持续显示任务进度长句。持续进度由任务卡负责。

## 实现步骤

### 阶段 1：状态契约

- 在 `CellObjectiveModule` 增加 `task_status_changed` 信号。
- 在基类增加 `get_combat_task_status()` 默认实现。
- 每个子类在进度变化、完成、重置时发出 `task_status_changed`。
- 给 5 类任务分别实现短状态字典。

### 阶段 2：运行时聚合

- 在 `CellTaskModuleRuntime` 增加 `get_active_task_statuses()`。
- 确保返回顺序稳定，例如按 `cell_id` 升序。
- 返回最多 2 条 active task status。
- 完成任务仍保留 status，直到本场战斗结束或进入准备阶段清理。

### 阶段 3：HUD 渲染

- 增加 `TaskObjectiveHudPresenter`。
- 在 `UI.gd` 或现有 `HudPresenter` 中绑定 presenter。
- 战斗中显示任务卡；非战斗隐藏。
- 支持两张卡稳定布局，不因文本长度改变大小。
- `value_text` 超长时截断或缩小，但目标是各任务都给短文本。

### 阶段 4：世界内标记

- 给有 active task 的 cell 增加任务图标和迷你进度条。
- 图标来自 `icon_key` 或任务类型映射。
- 完成时做一次短闪光。
- 格子标记不显示任务描述。

### 阶段 5：替换长文本

- `ClearCellObjectiveModule` 的持续 `"Quest: Clear Cell ..."` 文本改为状态接口。
- `DodgeSurvivalObjectiveModule` 的持续 `"Quest: Dodge ..."` 文本改为状态接口。
- 保留开始和完成时的短临时提示。

## 验收标准

- 战斗中每个 active task 都显示一张任务卡。
- 单场 2 个任务时，两张任务卡都能同时显示。
- 每张任务卡都有图标、短标签、数字进度、进度条。
- HUD 中没有超过一行的任务说明文本。
- `Kill` 能显示 `击杀 x/y`。
- `Hold` 能显示 `守点 x/y` 或 `占领 x/y`。
- `Clear` 能显示 `清场 x/y`，不显示浮点 remaining。
- `Hunt` 能显示 `精英 x/y`。
- `Dodge` 能显示 `闪避 x/y秒`，离开格子后进度重置。
- 任务完成后 HUD 和格子都有完成反馈。
- 非战斗阶段任务 HUD 隐藏。
- `godot --headless --path . --check-only --quit` 通过。

## 建议测试

- 新增或扩展 `World/Test/cell_task_module_runtime_test.tscn`：
  - 断言 5 类任务 status 都有 `type`、`label`、`progress`、`value_text`、`state`。
  - 断言 `progress` 始终在 `0.0..1.0`。
  - 断言 `value_text` 非空且不包含长句。
  - 断言 completed task 的 `state == "complete"`。

- 新增 HUD focused test：
  - 部署 2 个任务后进入战斗。
  - 断言 HUD 创建 2 张任务卡。
  - 断言每张卡有稳定尺寸，不随 `value_text` 更新改变布局。
  - 断言 `set_quest_hint()` 的旧长句不再作为持续进度显示。

## 非目标

- 不改变任务难度和完成条件。
- 不改变任务奖励结算。
- 不改变任务模组稀有度规则。
- 不把完整任务描述搬进战斗 HUD。
- 不把 UI 逻辑写进具体任务模块。
