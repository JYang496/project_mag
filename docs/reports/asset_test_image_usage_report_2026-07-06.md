# `asset/images/test` 图片资源使用与重制建议报告

日期：2026-07-06  
项目：MagArena（Godot 4）

## 1. 范围与结论

本报告检查 `res://asset/images/test/` 下 7 张 PNG 图片，以及运行时代码、场景和数据资源中的 14 处直接引用。历史测试归档、生成报告和 `.godot` 导入缓存不在统计范围内。

当前 7 张图片全部被引用，但它们仍是 4×32 至 32×32 的低分辨率像素占位图，与项目现有的机甲、武器和敌人美术所采用的“俯视科幻、白/深灰装甲、青蓝能量、红色敌对信号”风格不一致。

最需要优先处理的不是单纯换高清图，而是拆分一图多义：

| 当前图片 | 同时表达的内容 | 建议 |
| --- | --- | --- |
| `minigun_bullet.png` | 手枪弹、火箭弹、敌方尖刺弹 | 拆成 3 张图 |
| `sniper_bullet.png` | 狙击弹、霰弹弹丸、通用弹体默认图 | 至少拆成 2 张正式弹体图，并移除无意义默认图 |
| `spear.png` | 长矛弹体、被动技能图标 | 拆成弹体和 UI 图标 |
| `bullet.png` | 轨道弹体、爆炸范围视觉 | 拆成弹体和爆炸特效 |

## 2. 重制资源的统一规范

### 2.1 视觉方向

- 角色、武器、弹体采用俯视或轻微 3/4 俯视角，保持与现有机甲及敌人素材一致。
- 玩家及友方以白、深灰、青蓝能量为主；敌对物体使用深灰、黑、暗红和红色发光。
- 拾取物使用高亮轮廓和明确的类别颜色，在战斗背景上保持辨识度。
- 所有运行时图片使用透明背景，不把阴影烘焙到画布边缘；需要阴影时单独留柔和半透明区域。
- 弹体默认朝画布上方。相关移动脚本使用 `运动方向角度 + 90°` 旋转节点，朝上的源图能正确对齐飞行方向。

### 2.2 尺寸策略

Sprite2D 默认按图片原始像素显示。直接把 16×16 图片换成 64×64 会让世界中的物体变成四倍大。因此有两种交付方式：

1. **无代码替换**：保持原画布尺寸、中心点和透明边距，只改善轮廓与配色。
2. **正式重制**：制作更高分辨率资源，同时在对应场景调整 `scale`、UI 拉伸模式或代码中的目标像素尺寸。

本报告给出的“建议正式尺寸”是正式重制目标，不代表可以不调整节点直接覆盖原文件。

### 2.3 文件组织

正式资源不应继续放在 `images/test`：

- 弹体：`asset/images/weapons/projectiles/`
- 敌方弹体：`asset/images/enemies/projectiles/`
- 拾取物：`asset/images/items/` 或 `asset/images/loot/`
- NPC：`asset/images/npc/`
- 技能与状态图标：`asset/images/ui/icons/`
- 特效：`asset/images/effects/`

## 3. 单张图片分析

### 3.1 `bullet.png`

**当前规格**：32×32。红色不规则实心圆，表达的是最基础的圆形弹丸或爆炸占位块。

**引用位置**

- `Player/Weapons/Instances/orbit.gd:6`：轨道武器的弹体。
- `Player/Weapons/Effects/explosion_effect.gd:14`：爆炸/区域效果的默认视觉。

**实际表达**

- 在 `orbit.gd` 中，它是围绕玩家运动的实体弹体，应表达持续存在、可碰撞的轨道武器。
- 在 `explosion_effect.gd` 中，它会被橙色半透明调制并旋转，应表达爆炸范围或爆炸能量，而不是实体子弹。

**重制建议**

- 拆成 `orbit_projectile.png`：32×32 或 48×48，圆形机械浮游刃/能量球，深灰外壳、青蓝核心，轮廓清晰，旋转时仍能看出方向或机械结构。
- 拆成 `explosion_core.png` 或动画帧：64×64 至 128×128，中心白热、外圈橙黄、边缘红色烟火或冲击波；保持柔和透明边缘。
- 爆炸如果继续旋转，图案应有放射状或螺旋细节；更理想的是使用 6–10 帧爆炸动画，而不是旋转静态圆点。

### 3.2 `chip.png`

**当前规格**：16×16。绿色方形线框，近似微型芯片或电路板。

**引用位置**

- `Objects/loots/chip.tscn:4`：可收集的芯片物体。

**实际表达**

这是战场拾取物，应该传达“科技零件/芯片资源”，并与金币、武器掉落物明显区分。

**重制建议**

- 建议 24×24 或 32×32；若升级尺寸，同步缩放 `Sprite2D`。
- 造型为斜放或正面的微型六边形芯片：深色基板、四周金属触点、绿色或青绿色发光核心。
- 增加一圈轻微绿色辉光，使其在深色地面和战斗特效中可见。
- 保持轮廓紧凑，不使用复杂文字或微小电路线，避免缩小后产生噪点。

### 3.3 `empty_wp.png`

**当前规格**：16×16。白色细线“X”。

**引用位置**

- `UI/scripts/weapon_selector.gd:57`：武器节点没有有效 Sprite 纹理时的回退图。

**实际表达**

它不是正常的空武器槽背景；正常无武器时图标会被隐藏。它只在武器存在但无法取得图标时显示，因此更接近“武器图标缺失”提示。

**重制建议**

- 建议改名为 `missing_weapon_icon.png`，放入 UI 图标目录。
- 使用 32×32 或 64×64 透明画布：简化武器轮廓加问号，颜色使用中性灰和警示黄。
- 不建议继续只画一个 X；X 容易被理解为禁用、删除或无法装备。
- 如果希望对玩家隐藏资源错误，可以返回通用武器剪影；如果希望开发阶段容易发现问题，则用洋红/黄黑警示图标。

### 3.4 `minigun_bullet.png`

**当前规格**：16×16。朝上的灰色细长弹头。

**引用位置**

- `Npc/enemy/scenes/enemy_spike_projectile.tscn:4`：敌方尖刺弹。
- `Player/Weapons/Instances/pistol.gd:5`：手枪弹。
- `Player/Weapons/Instances/rocket_launcher.gd:5`：火箭弹。

**实际表达**

同一张图同时代表三种尺寸、阵营和威胁完全不同的弹体，是当前语义冲突最明显的资源之一。

**重制建议**

- `pistol_projectile.png`：12×20 或 16×24，朝上，短小金属弹头或蓝白能量弹，尾部保留 2–4 像素亮尾迹。
- `rocket_projectile.png`：24×40 或 32×48，朝上，具备弹头、弹身、尾翼和橙色尾焰；轮廓应明显大于手枪弹。
- `enemy_spike_projectile.png`：24×24 或 32×32，黑红尖刺/锥体，红色发光核心，明确表示敌对攻击。
- 三者都应保留透明背景和向上朝向，以兼容现有旋转逻辑。

### 3.5 `player.png`

**当前规格**：32×32。蓝白色小人侧身形象。

**引用位置**

- `UI/scenes/mecha_select.tscn:4`：机甲选择卡片的初始纹理。

**实际表达**

该图通常不是最终展示内容。`World/mecha_select.gd:37` 会在机甲数据加载成功后，用实际机甲场景中 `MechaSprite` 的纹理覆盖它。因此它本质上是加载前或数据异常时的回退图。

**重制建议**

- 不需要制作成某一台具体机甲，否则加载失败时会误导玩家。
- 建议使用 128×128 的中性“未知机体”全身剪影或蓝色全息投影，正面/轻微 3/4 视角。
- 可以加入扫描线、问号或未解锁轮廓，但不要使用红色错误符号破坏选择界面风格。
- 如果界面加载过程不会显示初始纹理，最简方案是移除场景中的该引用，改为空纹理；只有确实可见时才需要正式回退图。

### 3.6 `sniper_bullet.png`

**当前规格**：16×16。非常细的棕色竖线，近似弹壳或细长弹丸，辨识度低。

**引用位置**

- `Player/Weapons/Instances/sniper.gd:5`：狙击弹。
- `Player/Weapons/Instances/shotgun.gd:7`：霰弹弹丸。
- `Player/Weapons/Projectiles/projectile.tscn:4`：通用弹体场景默认纹理。
- `Player/Weapons/Projectiles/sniper_projectile.tscn:4`：狙击弹场景默认纹理。

**实际表达**

狙击弹需要体现高速、高穿透和强方向性；霰弹需要体现多发、近距和较低单发权重。两者不应共享同一视觉。

场景中的 `BulletSprite` 初始为不可见，运行时又会由武器写入 `projectile_texture`，因此两个 `.tscn` 中的默认纹理更像编辑器占位，不应被当作正式共享资源。

**重制建议**

- `sniper_projectile.png`：16×48 或 24×64，朝上，白蓝高亮弹芯、细长青色尾迹、尖锐前端；高速移动时仍应形成清楚的亮线。
- `shotgun_pellet.png`：12×16 或 16×20，短粗金属弹丸或橙白能量颗粒；多发散射时不能形成过亮大片。
- 通用 `projectile.tscn` 的默认纹理可设为空，依赖调用方显式提供；若需要编辑器预览，使用明确命名的 `debug_projectile_placeholder.png`。
- 狙击弹场景可继续使用正式 `sniper_projectile.png` 作为默认图。

### 3.7 `spear.png`

**当前规格**：4×32。极细的绿色竖条，能够表示朝上的长矛，但不适合作为 UI 图标。

**引用位置**

- `Player/Weapons/Instances/spear_launcher.gd:15`：长矛发射器弹体。
- `data/weapon_passives/piercing_blade_dance.tres:3`：`piercing_blade_dance` 被动技能图标。

**实际表达**

在武器逻辑中它是飞行长矛；在被动资源中它需要代表“穿刺剑舞/环形齐射”能力。两种使用方式需要不同构图。

**重制建议**

- `spear_projectile.png`：12×48 或 16×64，朝上，银白枪尖、深色枪身、青绿色能量纹；枪尖轮廓应占足够宽度，避免缩放后消失。
- `piercing_blade_dance_icon.png`：64×64 或 128×128，圆形构图，多支长矛从中心向外放射或环绕旋转，青蓝/绿色能量轨迹，深色背景板。
- UI 图标不能直接使用细长弹体原图，否则图标主体只占画布极小面积。

## 4. 按引用文件汇总

| 引用文件 | 当前图片 | 语义 |
| --- | --- | --- |
| `data/weapon_passives/piercing_blade_dance.tres` | `spear.png` | 穿刺剑舞被动图标 |
| `Npc/enemy/scenes/enemy_spike_projectile.tscn` | `minigun_bullet.png` | 敌方尖刺弹 |
| `Objects/loots/chip.tscn` | `chip.png` | 芯片拾取物 |
| `Player/Weapons/Effects/explosion_effect.gd` | `bullet.png` | 爆炸/区域视觉 |
| `Player/Weapons/Instances/orbit.gd` | `bullet.png` | 轨道弹体 |
| `Player/Weapons/Instances/pistol.gd` | `minigun_bullet.png` | 手枪弹 |
| `Player/Weapons/Instances/rocket_launcher.gd` | `minigun_bullet.png` | 火箭弹 |
| `Player/Weapons/Instances/shotgun.gd` | `sniper_bullet.png` | 霰弹弹丸 |
| `Player/Weapons/Instances/sniper.gd` | `sniper_bullet.png` | 狙击弹 |
| `Player/Weapons/Instances/spear_launcher.gd` | `spear.png` | 长矛弹体 |
| `Player/Weapons/Projectiles/projectile.tscn` | `sniper_bullet.png` | 通用弹体场景默认图 |
| `Player/Weapons/Projectiles/sniper_projectile.tscn` | `sniper_bullet.png` | 狙击弹场景默认图 |
| `UI/scenes/mecha_select.tscn` | `player.png` | 机甲选择回退图 |
| `UI/scripts/weapon_selector.gd` | `empty_wp.png` | 武器图标缺失回退 |

## 5. 建议制作顺序

### P0：先拆分语义冲突

1. `minigun_bullet.png`：拆分手枪、火箭、敌方尖刺弹。
2. `sniper_bullet.png`：拆分狙击弹和霰弹。
3. `spear.png`：拆分弹体与被动技能图标。
4. `bullet.png`：拆分轨道弹体与爆炸特效。

### P1：替换高频世界占位图

1. 芯片。

### P2：处理回退与 UI

1. 武器缺图和模块缺图图标。
2. 机甲选择加载/异常回退图。
3. UI 星标。

## 6. 验收标准

- `res://asset/images/test/` 不再被任何运行时文件引用。
- 每张图片只表达一个稳定概念，不再由不同阵营或不同物体类别共享。
- 所有弹体源图朝上，并在八个方向飞行时验证旋转方向。
- 新尺寸资源在 1280×720 目标视口中检查实际屏幕占比，不只检查源文件。
- 世界 Sprite 的视觉范围与碰撞范围大致一致，护盾和拾取物尤其需要校准。
- 在浅色、深色、特效密集三种背景下检查轮廓辨识度。
- 最近邻过滤只用于明确的像素画；高分辨率插画风素材应统一检查导入过滤设置。
- 替换完成后运行 Godot `--check-only`，并进入涉及的场景核对资源加载错误、缩放、旋转和透明边缘。
