# Perfect Pixel / MagArena 图片规范化工具

一个离线 Windows 桌面和命令行工具，用来把 AI 生成的“像素风”图片恢复为
规则网格，并按 MagArena 的游戏资产标准输出。

## 已实现能力

- 成品资产保护：防止把已有的 32×32、48×48、40px 高武器等再次降采样
- MagArena 资产预设：角色、敌人、武器、投射物、特效、喷射帧、模块和地图格
- 现代 UI 隔离：拒绝规范化应保留抗锯齿的现代 UI
- RGB/Alpha 共用校正后的网格坐标
- 硬边、五级 Alpha 和保留 Alpha 三种策略
- 动画序列锁定：所有帧复用参考帧的网格、画布和处理参数
- 质量报告：尺寸、颜色、Alpha、包围盒、警告和网格坐标
- GUI 预览、批量导出和独立 CLI

## 直接运行

解压发布包后：

```text
PerfectPixelNormalizer.exe  # 桌面界面
PerfectPixelCLI.exe         # 命令行
```

目标机器不需要安装 Python。GUI 的 `_internal` 目录必须与 EXE 保持在同一目录。

## 成品资产保护

保护默认开启。满足选定预设尺寸的图片不会再次采样；自定义模式下，小于等于
256px 且 Alpha 已离散的图片也会被视为疑似成品。

CLI 可选择：

- `--protection error`：停止并返回退出码 3，默认
- `--protection copy`：不采样，原样复制
- `--protection allow`：明确绕过保护，并在报告中记录警告

## MagArena 预设

| ID | 目标 |
| --- | --- |
| `player` | 128×128，硬 Alpha |
| `player_support` | 64×64，硬 Alpha |
| `enemy_standard` | 32×32，硬 Alpha |
| `enemy_large` | 48×48，硬 Alpha |
| `weapon` | 保持宽高比，固定高 40px |
| `projectile_standard` | 10×10 |
| `projectile_cannon` | 12×12 |
| `projectile_large` | 32×32 |
| `effect_small` | 32×32，分级 Alpha |
| `effect_medium` | 64×64，分级 Alpha |
| `effect_large` | 128×128，分级 Alpha |
| `effect_flame_spray` | 256×80，分级 Alpha |
| `effect_glacier_spray` | 256×90，分级 Alpha |
| `module` | 32×32，硬 Alpha |
| `board_cell` | 256×256，保留颜色与 Alpha |
| `scene_prop_large` | 256×256 |
| `modern_ui` | 禁止处理 |

`--preset auto` 会根据 MagArena 项目内的输入路径自动选择预设。

## CLI

处理单张图片：

```powershell
.\PerfectPixelCLI.exe normalize generated_enemy.png `
  --output-dir normalized `
  --preset enemy_standard `
  --report normalized\enemy_report.json
```

处理整个目录：

```powershell
.\PerfectPixelCLI.exe normalize generated_weapons `
  --output-dir normalized `
  --preset weapon
```

锁定动画序列：

```powershell
.\PerfectPixelCLI.exe sequence generated_explosion `
  --output-dir normalized_explosion `
  --preset effect_medium `
  --reference-index 3
```

常用参数：

```text
--sampling median|center|majority
--grid 32x32
--scale 1
--refine 0.25
--alpha-mode hard|stepped|preserve
--alpha-steps 5
--palette-limit 64
--protection error|copy|allow
--json
```

退出码：

| 退出码 | 含义 |
| ---: | --- |
| 0 | 成功 |
| 2 | 命令行参数错误 |
| 3 | 成品资产保护阻止处理 |
| 4 | 禁止的资产类型，例如现代 UI |
| 5 | 网格、文件或处理错误 |

## 质量报告

默认写入输出目录的 `quality_report.json`，包括：

- 完整处理参数与解析后的资产预设
- 输入、逻辑输出和导出图片指标
- 请求网格、校正后网格及完整 X/Y 网格坐标
- `channels_share_grid: true` 共享网格契约
- 颜色数、Alpha 等级、半透明像素和可见包围盒
- 序列锁定状态和参考帧索引
- 逐文件警告和汇总

## 构建

需要 Windows 和 Python 3.10+：

```powershell
pwsh -NoProfile -File build.ps1 -PythonPath "C:\path\to\python.exe"
```

构建脚本会创建隔离虚拟环境、安装固定版本依赖、运行测试，然后生成 GUI、
CLI 和 `PerfectPixelNormalizer-windows-x64.zip`。

## 已知边界

- 输入应已经具有明显的像素块结构；本工具不是通用照片转像素画算法。
- 动画序列锁定要求所有源帧尺寸一致。
- 对透视或旋转严重的网格，仍建议手动指定预设/网格并检查预览。
- 第三方来源与许可说明见 `THIRD_PARTY_NOTICES.md`。
