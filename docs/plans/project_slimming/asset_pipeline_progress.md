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
- `git diff --check`：PASS。

## 已知风险和下一推荐批次

- 无直接文本引用不能证明资源未被动态加载或导出规则使用。
- 本地 Godot 为 4.6.2，项目声明 4.7；集成时需用标准版本复跑。
- 字体内部 style 不同，禁止直接互换。
- ZIP 没有 importer，其仓库大小不能直接计作冷导入收益。
- 下一安全批次：不要继续处理字体、ZIP 或图片，除非每个类别都有单独批准、视觉/导入验证和恢复方案。
