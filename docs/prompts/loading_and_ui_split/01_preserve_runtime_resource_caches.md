# 提示词 01：保留只读资源缓存

请重构 MagArena 的运行状态重置逻辑，使普通新游戏和继续游戏只清理本局状态，而武器、机甲和经济配置等不变的只读资源定义在进程生命周期内复用。

## 开始前

阅读 `autoload/GlobalVariables.gd`，搜索 `reset_runtime_state()` 的定义和全部调用方，并检查 Cell Effect、Task Module 运行时库存与定义缓存的直接相关代码。确认每个字段的所有权和生命周期后再修改。

## 实施要求

- 将现有重置职责拆成语义清晰的 `reset_run_state()` 与 `clear_resource_cache()`；如需兼容旧入口，可保留薄包装并明确迁移策略。
- `reset_run_state()` 清理玩家、敌人、UI 引用、战斗计数和本局临时状态，但不得清除只读定义缓存。
- `clear_resource_cache()` 显式清理 `weapon_list`、`mecha_list`、`economy_data`、`weapon_branch_list`、`weapon_passive_branch_list` 及代码中确认属于同一生命周期的定义缓存。
- 普通新游戏和继续游戏调用方只使用 `reset_run_state()`。
- Cell Effect 与 Task Module 的运行时库存必须重置，定义缓存必须保留。
- 仅为开发热重载、Mod 内容变化或显式刷新保留调用 `clear_resource_cache()` 的能力；不要让常规流程隐式触发。
- 检查缓存对象是否会被本局逻辑原地修改；若会，修正所有权或复制边界，避免跨局污染。

## 验收与验证

- 验证新游戏仍完全清空本局状态，继续游戏仍能正确恢复。
- 用可观察证据确认第二次进入 World 不重新扫描武器、机甲和经济配置目录。
- 验证连续新游戏、返回标题再进入、继续游戏，以及显式清缓存后的重新加载。
- 运行 Godot `--check-only` 和受影响测试选择流程；没有活动测试时提供聚焦人工验证清单。

完成后列出被归为“本局状态”和“进程级缓存”的字段、修改过的调用方、验证结果及潜在可变资源风险。

