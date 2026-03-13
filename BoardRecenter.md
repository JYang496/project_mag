# Board Recenter 功能说明

## 目标
- 在 `BATTLE` 阶段结束时，自动将 3x3 Cell Board 重新对齐。
- 对齐标准：玩家位置对齐到第 5 个 Cell（中心 Cell）的几何中心。
- 同时让场景中的 NPC 与 StartBattleButton 同步位移，保持相对布局不变。

## 触发时机
- 文件：`res://World/board_cell_generator.gd`
- 在 `_on_phase_changed(new_phase)` 中：
  - 当阶段从 `BATTLE` 切换到非 `BATTLE` 时，调用 `recenter_board_around_player()`。

## 核心逻辑
`recenter_board_around_player()` 的关键步骤：

1. 获取玩家全局坐标 `player_position`。
2. 获取中心 Cell 的全局中心点 `center_cell_position`。
3. 计算位移：
   - `recenter_offset = player_position - center_cell_position`
4. 对 Board 应用位移：
   - `global_position += recenter_offset`
5. 对场景中的 NPC 与 StartBattleButton 应用相同位移。

说明：
- 使用的是全局坐标（`global_position`），避免父节点层级导致的局部坐标误差。
- 中心 Cell 中心优先使用 `CapturePolygon` 质心；无多边形时回退到 `cell.global_position`。

## 同步对象
- NPC：通过 group `npc` 统一收集并平移。
- StartBattleButton：递归查找 `StartBattleButton` 实例并平移。
- 对已在 Board 子树内的节点会跳过，避免重复偏移。

## Debug 模式
- 开关：`debug_recenter_logs`（`BoardCellGenerator` 导出变量，默认 `false`）。
- 开启后，每次 recenter 会输出：
  - `board_before`
  - `board_after`
  - `player_before`
  - `player_after`
  - `offset`
  - `center_player_distance`

日志示例：
`[BoardRecenter] ... center_player_distance=0.0000`

验收标准：
- `center_player_distance` 接近 `0.0000`（或非常小的浮点误差）。

## 相关文件
- `res://World/board_cell_generator.gd`
- `res://World/player_spawner.gd`
- `res://World/start_battle_button.gd`
