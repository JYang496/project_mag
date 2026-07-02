# 资源管线范围 Handoff

## 1. 批次目标

完成第一批只读引用与重复资源审计。已交付文件/大小分布、引用和依赖、import 差异、哈希重复、制作源分类、重点候选风险和恢复建议；未修改资源。

## 2. 修改文件

- `docs/plans/project_slimming/asset_pipeline_audit.md`
- `docs/plans/project_slimming/asset_pipeline_progress.md`
- `docs/plans/project_slimming/handoffs/asset_pipeline.md`

没有修改、删除或移动任何 `asset/**`、`.import`、业务代码或共享文件。

## 3. 公开 API 或契约变化

- 无。
- 资源路径、UID、import 设置和玩家可见内容均未改变。

## 4. 需要其他范围完成的工作

- Startup 范围可在其冷导入基线中分别记录 OTF、Cell PNG 和 ZIP 对扫描/导入阶段的实际影响。
- UI/协调者在任何字体处理前需执行 1280x720、1920x1080 的英文与简体中文视觉门禁。
- Player/协调者在 ZIP 归档前需确认 `mecha_move_frames.tres` 的 42 个已解压帧保持原路径；不要以 ZIP 替换运行时帧。

## 5. 建议的共享文件修改

- 当前不建议修改 `project.godot`。
- 若未来将制作源移出 `res://`，目录和导出策略由协调者批准后另立批次；本批不建议直接增加全局忽略规则。

## 6. 测试及结果

- 425 个 tracked 路径与 worktree 文件数一致。
- 数量闭合：214 源 + 211 import = 425；180 有引用 + 34 无引用 = 214；210 个可导入源 + 1 个孤儿 sidecar = 211。
- 214 个源 SHA-256 扫描完成。
- 151 个 PNG 全部解码，未发现像素完全相同的 PNG。
- ZIP 42/42 条目与已解压帧 SHA-256 一致。
- Godot 4.6.2 check-only：PASS，退出码 0，无脚本或资源错误。
- `git diff --check`：PASS。

## 7. 修改前后指标

- 本批是只读审计，资源文件数、源体积、import 配置和导入缓存均无修改前后变化。
- 当前基线：425 个 asset 路径，82,133,790 bytes。
- 34 个无直接引用源合计 34,351,759 bytes；其中 32 个现存可导入源约 19.55 MiB。
- 2 组精确 SVG 重复仅理论节省 2,294 bytes，且 7 个路径均被 Player 场景引用。
- 当前主工作区导入缓存中，无直接引用的现存可导入源约占 17,212,707 bytes；此数值不是冷导入收益结论。

## 8. 合并顺序要求

- 本批只有文档，可独立合并。
- 后续任何资源改动必须等待协调者明确批准，并一次只处理一个资源类别。
- 字体处理必须在 UI 视觉门禁准备后；ZIP 处理必须在 Player 帧引用确认后。

## 9. 已知风险

- `NotoSansSC-Regular.ttf` 内部 style 是 Thin，未引用 OTF 是 Regular；两者不能直接互换。
- OTF 虽无 tracked 路径/UID 引用，但仍需排除导出或非文本动态依赖。
- `characters_move.zip` 是 42 个运行时帧的完整副本，但无 importer，删除主要是仓库瘦身，不应伪报冷导入收益。
- `dirt1.png`、`fact2.png` 无直接引用但与当前使用图片内容不同，必须视觉确认。
- 孤儿 `.import` 的源已缺失、UID/路径无引用，是最低风险候选，但本批未删除。
- 本地验证版本为 Godot 4.6.2，项目配置声明 4.7。

## 10. 下一安全批次

在协调者批准后，仅处理
`asset/images/weapons/Remove_background_to_create_transparent_PNG-1777246945516.png.import`：

- 再次确认源不存在、UID/path 无引用。
- 记录 sidecar SHA-256 和处理前提交以便恢复。
- 只删除该孤儿 sidecar，不顺带处理 OTF、ZIP 或 PNG。
- 运行 check-only、启动/相关资源加载、冷导入对照和 `git diff --check`。

Follow-up status: completed in Asset-2. The orphan sidecar was deleted alone; fonts, ZIPs, source images, and importer settings were not changed.
