# 提示词 00：建立加载性能基线

请为 MagArena 的“开始菜单到 World 可交互”流程建立低侵入、可开关的性能观测基线。本任务只添加测量能力和记录现状，不实施缓存、预热或 UI 延迟加载优化。

## 开始前

阅读 `project.godot`、`tests/README.md`、`docs/plans/loading_and_ui_split_optimization_plan.md`，然后只检查开始菜单、新游戏、继续游戏、World 入口/ready、现有加载界面及 UI bootstrap 的直接相关文件。先搜索项目是否已有性能标记或日志工具，优先复用。

## 实施要求

- 记录以下统一命名的时间点：`start_menu_ready`、`prewarm_started`、`prewarm_finished`、`start_button_pressed`、`threaded_load_started`、`threaded_load_finished`、`world_scene_changed`、`world_ready`、`first_stable_frame`。
- 当前尚无预热时，也要让预热时间点接口可供下一任务接入；不要伪造预热耗时。
- 记录点击开始后连续超过 33 ms 的帧或等价卡顿证据，避免每帧刷屏。
- 能区分首次启动、返回标题后第二次进入、新游戏和继续游戏。
- 明确定义并集中实现 `world_ready` 判定：棋盘初始化、玩家入树、相机首次同步、Battle HUD 初始化、首批可见 3D 地面完成；不要等待未请求的管理 UI。
- 埋点应仅在调试/显式启用时输出，不污染正常发布日志，不改变场景切换时序。
- 输出一次进入流程的汇总，包含阶段耗时和超长帧统计；若某标记缺失，明确标为缺失。

## 验收与验证

- 对新游戏、继续游戏、第二次进入分别说明如何采集数据。
- 确认标记顺序合理，重复进入不会沿用上一次时间戳。
- 运行 Godot `--check-only`，并执行当前条件下可行的聚焦启动验证。
- 给出 Debug 与导出版本的人工测量步骤和基线结果表模板；没有实际数据就留空，不填估算值。

完成后总结修改文件、埋点启用方式、实测结果、无法自动验证的项目和下一任务可复用的接口。

