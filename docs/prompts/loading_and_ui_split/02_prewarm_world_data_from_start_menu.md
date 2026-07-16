# 提示词 02：在开始菜单预热 World 数据

请把 World 入口所需的同步数据准备移动到开始菜单首帧显示后的空闲期，使点击“新游戏/继续”时通常直接命中缓存，并保持按钮入口的安全校验。

## 开始前

检查 `World/start_menu.gd`、`World/world_entry_prepare_gate.gd`、`autoload/SpawnData.gd` 及新游戏/继续游戏按钮调用链。复用提示词 00 的性能标记接口和提示词 01 的缓存生命周期。

## 实施要求

- 开始菜单先完成首帧显示，再通过 `call_deferred()` 启动预热。
- 按顺序执行 `WorldEntryPrepareGate.prepare_world_entry()` 和 `SpawnData.ensure_loaded()`。
- 使用明确状态表示未开始、进行中、成功、失败；保存错误详情并防止重复启动。
- 新游戏与继续游戏按钮仍调用同一准备入口做幂等安全校验；预热进行中时应等待同一任务/状态，不得重复加载。
- 处理菜单退出、快速点击、重复点击和预热失败。失败时恢复可操作状态并显示明确错误，不得永久禁用按钮。
- 接入 `prewarm_started`、`prewarm_finished` 标记并报告点击后准备阶段耗时。
- 首版不引入 `WorkerThread`。若同步步骤造成明显卡帧，则将数据、Cell Effect、Task Module、Spawn Data 分散到不同帧，同时保持依赖顺序。

## 验收与验证

- 菜单必须先可见，再开始预热。
- 正常预热成功后，点击开始到 `threaded_load_started` 的目标低于 50 ms；报告真实测量值。
- 验证预热未完成时点击、预热失败后重试、新游戏、继续游戏和第二次进入。
- 确认没有重复扫描只读资源目录。
- 运行 Godot `--check-only` 并给出聚焦运行验证结果。

完成后说明状态机、错误恢复方式、性能前后对比和未达到 50 ms 时的具体瓶颈。

