# 资源管线第一批审计

审计基线：`51ec0972b219626780e1f31909885adad7dd120d`

本批只记录证据和后续建议，没有删除、移动、压缩或改写任何 `asset/**` 文件与 `.import` 配置。

## 1. 范围与方法

- 扫描 `git ls-files asset` 中全部 425 个 tracked 路径。
- 扫描 tracked 文本中的精确 `res://asset/...` 路径、场景/资源依赖和 UID。
- 对全部源文件计算 SHA-256；对 PNG 比较解码后的 RGBA 像素哈希。
- 比较 `.import` 的 importer、目标类型和完整参数签名。
- 比较两个字体的 SFNT `cmap`、family/style 和本地化字符覆盖。
- 将 `characters_move.zip` 的全部条目与仓库已解压帧逐项比较。

“无直接文本引用”不等于可以删除；运行时拼接路径、导出规则、编辑器用途和法律文件仍需单独证明。主工作区 `.godot/imported` 仅用于描述当前缓存占用，不是可重复冷导入基准。

## 2. 文件与大小分布

425 个 tracked 路径闭合为 214 个源文件和 211 个 `.import` sidecar，总计 82,133,790 bytes（78.33 MiB）。

| 类型 | 数量 | bytes | MiB |
| --- | ---: | ---: | ---: |
| PNG | 151 | 33,820,952 | 32.25 |
| TTF | 1 | 17,772,300 | 16.95 |
| OTF | 1 | 16,437,364 | 15.68 |
| ZIP | 1 | 13,844,956 | 13.20 |
| SVG | 56 | 30,471 | 0.03 |
| MP3 | 1 | 11,701 | 0.01 |
| TRES | 2 | 2,856 | <0.01 |
| TXT | 1 | 4,388 | <0.01 |
| `.import` | 211 | 208,802 | 0.20 |

主要目录：

| 目录 | 源文件数 | bytes | MiB |
| --- | ---: | ---: | ---: |
| `asset/images/characters` | 46 | 29,147,912 | 27.80 |
| `asset/fonts` | 2 | 34,209,664 | 32.62 |
| `asset/images/cells` | 10 | 15,838,227 | 15.10 |
| `asset/images/effects` | 18 | 1,421,704 | 1.36 |
| `asset/images/weapons` | 29 | 827,649 | 0.79 |
| `asset/images/enemies` | 17 | 340,185 | 0.32 |

当前 211 个导入产物合计 50,388,841 bytes（48.05 MiB），其中 PNG 22,603,912、OTF 14,444,313、TTF 13,290,645 bytes。

## 3. 引用与依赖

- 214 个源文件中，180 个至少有一个直接 `res://asset/...` 文本引用，34 个没有直接引用。
- 175 个源文件被 `.tscn` 或 `.tres` 直接依赖，22 个被 `.gd` 直接引用；集合有重叠。
- 共 272 次直接引用：`.tres` 127、`.tscn` 113、`.gd` 32。
- 26 个资源的 UID 出现在其他 tracked 文本中，且都有路径引用；没有“仅 UID、无路径”的资源。
- 没有发现只被 `tests/**` 引用的资源。

34 个无直接文本引用的源文件合计 34,351,759 bytes（32.76 MiB）：

| 分类 | 数量 | bytes | 判断 |
| --- | ---: | ---: | --- |
| 未引用 OTF | 1 | 16,437,364 | 需字体与视觉门禁 |
| 角色 ZIP | 1 | 13,844,956 | 仓库归档候选 |
| 未引用 Cell PNG | 2 | 3,725,673 | 高视觉风险 |
| 未引用 Weapon PNG | 11 | 226,586 | 需历史与导出审计 |
| 未引用 Enemy PNG | 3 | 107,349 | 需注册表与历史审计 |
| 未引用 Test PNG | 15 | 5,443 | 名称不能证明用途 |
| `OFL.txt` | 1 | 4,388 | 法律文件，保留 |

完整列表：

```text
asset/fonts/NotoSansCJKsc-Regular.otf
asset/fonts/OFL.txt
asset/images/cells/dirt1.png
asset/images/cells/fact2.png
asset/images/characters/characters_move.zip
asset/images/enemies/b.png
asset/images/enemies/c.png
asset/images/enemies/elite.png
asset/images/test/atk_up.png
asset/images/test/chainsaw.png
asset/images/test/e2.png
asset/images/test/elevator16.png
asset/images/test/faster_reload.png
asset/images/test/hammer.png
asset/images/test/laser.png
asset/images/test/minigun.png
asset/images/test/p1.png
asset/images/test/p_gate.png
asset/images/test/rolling_ball.png
asset/images/test/short_knife.png
asset/images/test/sniper.png
asset/images/test/tornado.png
asset/images/test/wall.png
asset/images/weapons/flamethower.png
asset/images/weapons/projectiles/03(2).png
asset/images/weapons/projectiles/03(3).png
asset/images/weapons/projectiles/03(4).png
asset/images/weapons/projectiles/03(5).png
asset/images/weapons/projectiles/03(6).png
asset/images/weapons/projectiles/03(7).png
asset/images/weapons/projectiles/03(8).png
asset/images/weapons/projectiles/031.png
asset/images/weapons/prototype.png
asset/images/weapons/rifle.png
```

当前导入缓存中，32 个无直接引用但可导入的现存源约占 17,212,707 bytes；另有一个孤儿 sidecar 对应的 268,876-byte 残留缓存。该数值不是删除授权。

## 4. `.import` 设置

同类源文件的 `[params]` 签名完全一致：

| 源类型 | sidecar | 参数签名 |
| --- | ---: | ---: |
| PNG | 152 | 1 |
| SVG | 56 | 1 |
| TTF | 1 | 1 |
| OTF | 1 | 1 |
| MP3 | 1 | 1 |

没有发现同扩展名资源间的 import 参数漂移。PNG sidecar 比现存 PNG 多 1 个：

`asset/images/weapons/Remove_background_to_create_transparent_PNG-1777246945516.png.import`

其源 PNG 不存在，UID `uid://bs17c5m0bkj0w` 与源路径在其他 tracked 文本中均无引用；这是最低风险的后续独立清理候选。

## 5. 重复资源

SHA-256 发现 2 组精确重复、共 7 个已引用 SVG：

- 5 个相同的 448-byte SVG：`wmod_inertial_aim.svg`、`wmod_kill_endurance.svg`、`wmod_overkill_recovery.svg`、`wmod_rhythm_converter.svg`、`wmod_weakness_relay.svg`。
- 2 个相同的 502-byte SVG：`wmod_dash_cooler.svg`、`wmod_penetration_momentum.svg`。

理论节省仅 2,294 bytes，合并会要求跨范围路径迁移并破坏独立资源路径，建议保留。

151 个 PNG 全部成功解码，没有 SHA-256 不同但 RGBA 像素完全相同的文件。重复 basename `laser.png`、`rolling_ball.png`、`sniper.png` 的内容均不同。`flamethower.png` 与当前使用的 `flamethrower.png` 尺寸、哈希也不同，不能按重复文件删除。

## 6. 制作源与运行时分类

| 分类 | 证据 | 建议 |
| --- | --- | --- |
| 运行时直接依赖 | 180 个源有路径引用 | 保留路径和设置 |
| 未引用但会导入 | 32 个现存源，约 19.55 MiB | 分类别做 A/B |
| 制作/交付归档候选 | `characters_move.zip` 无引用、无 `.import` | 确认用途后移出 `res://` |
| 法律元数据 | `asset/fonts/OFL.txt` | 随字体保留 |
| Godot 原生资源 | 2 个 effect `.tres` 均有依赖 | 保留 |
| 孤儿导入元数据 | 1 个缺失源 PNG sidecar | 最低风险候选 |

## 7. 重点候选

### 字体

| 指标 | `NotoSansSC-Regular.ttf` | `NotoSansCJKsc-Regular.otf` |
| --- | ---: | ---: |
| 源大小 | 17,772,300 | 16,437,364 |
| 导入缓存 | 13,290,645 | 14,444,313 |
| family/style | Noto Sans SC / Thin | Noto Sans CJK SC / Regular |
| cmap | 30,890 | 44,810 |
| 路径引用 | 2 | 0 |

OTF 的 cmap 是 TTF 的严格超集；两个字体都覆盖本地化数据中的 521 个非控制字符 codepoint。但当前 UI 使用 TTF，且其内部 style 为 Thin；直接替换成 Regular OTF 会改变字重、排版或截图，禁止在无四组 UI 视觉门禁时处理。

### `characters_move.zip`

- 13,844,956 bytes，含 42 个 PNG，解压总大小 13,903,135 bytes。
- 42/42 条目逐项 SHA-256 等于 `move_b/*.png` 与 `move_f/*.png`。
- ZIP 无路径/UID 引用，也无 `.import`。
- 已解压 42 帧全部被 `Player/Mechas/animations/mecha_move_frames.tres` 引用，不能删除或用 ZIP 替代。
- ZIP 更偏仓库归档候选，不能未经冷导入实测宣称 13.2 MiB 导入收益。

### Cell 大图

10 个 Cell PNG 合计 15,838,227 bytes，当前导入缓存 10,803,648 bytes。`dirt1.png`（1,892,965）与 `fact2.png`（1,832,708）无路径/UID 引用，但与已用的 `dirt2.png`、`fact1.png` 像素不同，只能在视觉和历史审计后处理；禁止降分辨率或有损压缩。

## 8. 风险与恢复

未来任何删除/移动批次必须：

- 每次只处理一类资源，记录处理前 SHA-256、路径、源大小和导入缓存大小。
- 保留精确删除清单与处理前提交，恢复时还原原路径和配套 `.import`。
- 制作源归档保留原相对路径和 SHA-256。
- 字体同时保留许可证、family/style/cmap 报告并执行四组 UI 门禁。
- 运行时图片处理后执行 Godot check-only、启动/相关场景加载和视觉对比。

## 9. 建议顺序

1. 经协调者批准后，单独清理孤儿 PNG `.import`。
2. 对未引用 OTF 做隔离冷导入 A/B 与四组 UI 字体门禁。
3. 对 ZIP 做导出 manifest 和仓库用途确认。
4. 对 `dirt1.png`、`fact2.png` 做 Cell 视觉/历史确认。
5. 最后审计其余小型未引用 PNG，不批量删除。

## 10. 验证

- `git ls-files asset`：425，与 worktree 文件数一致。
- 214 源 + 211 sidecar = 425。
- 180 有直接引用 + 34 无直接引用 = 214。
- 210 个现存可导入源 + 1 个孤儿 sidecar = 211。
- 214 个源 SHA-256 完成。
- 151 个 PNG 全部解码，0 个像素重复组。
- ZIP 42/42 条目与已解压帧匹配。
- Godot 4.6.2 `--headless --check-only --quit`：退出码 0。
- `git diff --check`：PASS。
