# 资源管线瘦身进度

## 已完成批次

### Asset-1：只读引用与重复资源审计

- 完成 425 个 tracked asset 路径的文件类型、大小、引用、import 参数和 SHA-256 扫描。
- 完成 151 个 PNG 的解码像素哈希比较。
- 完成两个字体的内部名称、cmap 和本地化字符覆盖比较。
- 完成 `characters_move.zip` 与 42 个已解压帧的逐项哈希验证。
- 没有修改任何 `asset/**` 或 `.import`。

### Asset-2：孤儿 import sidecar 清理

- 删除审计点名的孤儿 sidecar：`asset/images/weapons/Remove_background_to_create_transparent_PNG-1777246945516.png.import`。
- 没有删除、移动、压缩或改写任何源资源、字体、ZIP、PNG 或 importer 配置。

### Asset-3：ZIP 归档候选只读复核

- 只复核 `asset/images/characters/characters_move.zip`，没有处理字体、PNG 或其他资源类别。
- 未删除、移动、压缩或改写 ZIP；本批没有资源文件变更。
- 精确路径搜索只发现文档/提示引用，没有运行时代码、场景、资源或启动 manifest 引用。
- tracked 文件只包含 `asset/images/characters/characters_move.zip` 本体；没有 `characters_move.zip.import` 或 `.uid`。
- 当前仓库没有 `export_presets.cfg`；`project.godot`、`data/startup` 和启动测试中未发现 ZIP include/exclude/export 规则。
- ZIP 当前大小 13,844,956 bytes，SHA-256 为 `4140655BBAB1EB1AF358075715DEF358B099228CA12A61CC38EFCAD75C87A10B`。
- ZIP 内 42 个 PNG 文件全部能在 `asset/images/characters/move_b` / `move_f` 找到，文件 SHA-256 42/42 匹配；目录 entry 另有 2 个。
- 恢复路径：如果未来经批准归档/移出 `res://`，需记录原路径、SHA-256 和目标归档位置；恢复时把同一 ZIP 以相同 SHA-256 放回 `asset/images/characters/characters_move.zip`，不需要 `.import` 恢复。
- 结论：仍是仓库归档候选，不是运行时替代资源；未经单独批准不删除，且不能声称冷导入收益，除非后续 benchmark 证明。

## 关键指标

| 指标 | 结果 |
| --- | ---: |
| tracked asset 路径 | 425 |
| 源文件 / `.import` | 214 / 210 |
| asset 总大小 | 82,133,790 bytes（78.33 MiB） |
| 有直接路径引用 / 无直接路径引用源 | 180 / 34 |
| 无直接引用源大小 | 34,351,759 bytes（32.76 MiB） |
| 精确重复哈希组 / 文件 | 2 / 7 |
| 理论精确重复源节省 | 2,294 bytes |
| PNG 像素重复组 | 0 |
| 孤儿 `.import` | 0 |
| ZIP 条目与仓库帧匹配 | 42 / 42 |

## 测试及结果

- 引用、UID、import、SHA-256、PNG 解码、字体 cmap 和 ZIP 扫描全部正常完成并通过数量闭合校验。
- Godot 4.6.2 check-only：PASS，退出码 0，无脚本或资源错误，约 11.0 秒。
- Asset-2 后 orphan `.import` 扫描：0。
- Asset-3 ZIP 复核：精确引用只命中文档/提示；tracked sidecar/UID 为 0；ZIP 文件哈希与 42 个已解压帧逐项匹配。
- `git diff --check`：PASS。

## 已知风险和下一推荐批次

- 无直接文本引用不能证明资源未被动态加载或导出规则使用。
- 本地 Godot 为 4.6.2，项目声明 4.7；集成时需用标准版本复跑。
- 字体内部 style 不同，禁止直接互换。
- ZIP 没有 importer，其仓库大小不能直接计作冷导入收益。
- 下一安全批次：不要继续处理字体、ZIP 或图片，除非每个类别都有单独批准、视觉/导入验证和恢复方案。ZIP 若获批准，只能作为仓库归档/移出 `res://` 处理，不能替代运行时帧。

### Asset-4: final closure report

- Final report path: `docs/reports/project_slimming_completion_report.md`.
- Actual deleted asset-pipeline item remains only `asset/images/weapons/Remove_background_to_create_transparent_PNG-1777246945516.png.import`.
- Retained items are explicit: all source assets, fonts, PNGs, importer settings, and `asset/images/characters/characters_move.zip`.
- No Stage 7 asset file change was made.
