# MagArena 混合 2.5D 架构方案

## 文档用途

本文供后续 Agent 在 `2.5d-test` 分支继续开发时参考。目标是在不迁移现有玩法逻辑到 3D 的前提下，实现：

- 2D 逻辑作为唯一权威；
- 透视 Camera3D 显示地面；
- 2D Billboard 显示角色、敌人、武器和掉落物；
- CanvasLayer 显示 HUD 与屏幕提示。

开始工作前必须阅读：

- `AGENTS.md`
- `tests/README.md`
- `Visual/Oblique/hybrid_ground_view_3d.gd`
- `Visual/Oblique/billboard_visual_2d.gd`
- 本次任务直接涉及的逻辑脚本和场景

不要为了视觉效果改写碰撞、AI、伤害、武器世界接口或存档格式。

## 核心架构

```text
2D Logic World（权威）
├── CharacterBody2D / Area2D
├── AI、导航和击退
├── Weapon、Muzzle 和 HitBox
├── Projectile 运动和命中
└── 掉落、吸附和拾取

3D Ground Visual（非权威）
├── Camera3D
├── Cell QuadMesh
├── RestArea 地面
├── 地面范围和警告贴片
└── 地面阴影

2D Billboard Visual（非权威）
├── 玩家和敌人 Body
├── 武器和 Projectile 图像
├── NPC、金币和掉落物
└── 立式场景物件

CanvasLayer
├── HUD
├── EnemyHpBar / HitLabel
├── 世界提示
└── 菜单和操作提示
```

数据必须单向流动：

```text
2D 逻辑位置
→ 映射到 3D 地面
→ Camera3D 投影到屏幕
→ 写入视觉节点
```

禁止将投影后的视觉位置写回 2D 逻辑节点。

## 坐标服务

`HybridGroundView3D` 是混合模式唯一的坐标转换入口。应保持并扩展以下接口：

```gdscript
world_2d_to_3d(point: Vector2) -> Vector3
project_world_to_screen(point: Vector2) -> Vector2
project_world_to_canvas(point: Vector2, viewport: Viewport) -> Vector2
screen_to_world_2d(screen_position: Vector2) -> Vector2
world_vector_to_screen(vector: Vector2, origin: Vector2) -> Vector2
screen_vector_to_world(vector: Vector2) -> Vector2
```

所有新系统必须调用这些接口，不得复制投影数学。

安全要求：

- Camera3D 初始化前安全回退；
- 防止投影分母为零；
- 检查相机后方点；
- 射线与地面平行时安全返回；
- 对已释放对象先使用 `is_instance_valid()`，再进行类型转换；
- Camera 参数变化后清理并重建 Mesh 缓存；
- Viewport 尺寸变化后重新计算屏幕锚点。

## Ground Plane 迁移规则

以下内容应迁移到 3D 地面：

- Board Cell；
- RestArea 地面；
- Cell 激活状态；
- 区域选择框；
- AreaEffect；
- 警告圈；
- 火焰区、冰面和减速区；
- 地雷范围；
- 烧痕；
- 任务区域；
- 地面阴影。

迁移规则：

- 原始 2D 节点继续负责碰撞和生命周期；
- 3D Mesh 只负责显示；
- 使用轻微 Y 偏移防止 Z-fighting；
- 透明 Material 必须考虑排序；
- 动态效果优先使用对象池；
- 不逐格使用算法缩放模拟透视；
- 不单独缩放 Cell 根节点或 CollisionShape。

后续应为圆形、矩形、扇形、线段和动画纹理建立统一 3D Ground Visual 接口。

## Upright Billboard 规则

适用对象：

- 玩家和敌人身体；
- NPC；
- 金币和掉落物；
- RestArea 设施；
- 立式场景装饰；
- 图标型世界对象。

必须遵守：

- Billboard 只修改视觉节点；
- 父级逻辑位置保持不变；
- 基础逻辑脚点与投影结果分离；
- 投影位置不能成为下一帧基础位置；
- 运行时 Sprite 缩放和动画切换必须保留；
- 屏幕偏移使用像素，不使用世界单位；
- UPRIGHT 模式保持屏幕正向；
- 可选实现轻微远近缩放，但不得影响碰撞。

推荐接口：

```gdscript
set_logical_local_position(position: Vector2)
set_screen_offset(offset: Vector2)
```

## Directional Billboard 规则

适用对象：

- 武器；
- 普通 Projectile；
- 火箭、飞刀和长条能量弹；
- 方向性机械装置；
- Muzzle Flash。

视觉角度必须从投影后的世界方向计算：

```gdscript
var screen_direction := hybrid_view.world_vector_to_screen(
    world_direction,
    logical_origin
)
```

逻辑位置、逻辑角度、Muzzle 和 HitBox 不得使用投影后的 Transform。

方向性贴图必须声明自己的美术前向轴。`BillboardVisual2D.directional_forward_degrees`
默认 `0` 表示贴图局部向右；基础 Projectile 沿用旧资产规范，贴图局部向上，因此
`Bullet` 统一设置为 `-90`。Projectile 飞行期间必须通过
`set_world_direction(base_displacement)` 显式传入权威速度方向，禁止从已经接受
Billboard 投影的父 Transform 反推飞行方向。

## Weapon 结构

建议职责结构：

```text
Weapon Logic Root
├── Muzzle
├── HitBox / Modules
├── Orbit state
└── Sprite（Directional Billboard）
```

必须保持：

- `get_muzzle_global_position()` 返回 2D 逻辑世界坐标；
- `get_fire_feedback_direction()` 返回逻辑世界方向；
- 子弹生成点和命中计算继续使用 2D；
- 视觉 Sprite 使用 Camera3D 投影；
- Muzzle Flash 在生成后投影到屏幕位置。

后坐力不得 Tween Billboard 的逻辑 `position/rotation`。使用：

- `screen_feedback_offset`
- `screen_feedback_rotation`

后坐力方向先投影为屏幕方向，再沿屏幕枪口反方向位移。

## Projectile 结构

基础 Projectile 应保持：

```text
Projectile（2D 逻辑根）
├── HitboxAnchor（2D 逻辑）
│   └── HitBox
├── Bullet（Directional Billboard）
│   ├── BulletSprite
│   └── BulletAnimation
└── ExpireTimer
```

规则：

- `base_displacement` 移动逻辑根；
- `projectile_displacement` 同步到 HitboxAnchor 和 Bullet 的逻辑视觉偏移；
- Bullet 投影到屏幕；
- HitBox 不得成为 Billboard 子节点；
- 对象池回收时重置逻辑偏移、屏幕反馈、Sprite 和动画状态。

需要重点回归追踪弹、分裂弹、弹跳弹、穿透弹、回旋弹和大小动态变化。

## Beam 和连接型效果

Beam、Laser、电弧、闪电链和喷火锥不能套用普通 Billboard。

必须分别投影起点和终点：

```gdscript
var screen_start := project_world_to_screen(start_world)
var screen_end := project_world_to_screen(end_world)
var screen_delta := screen_end - screen_start
```

根据 `screen_delta` 计算显示角度、长度、宽度和 UV。碰撞射线仍在 2D。

## 鼠标输入与瞄准

混合模式下禁止直接将 `get_global_mouse_position()` 用作地面目标。

正确流程：

```text
Viewport mouse position
→ Camera3D ray
→ 与 y=0 地面求交
→ 除以 world_scale
→ 2D 世界坐标
```

必须覆盖：

- 玩家朝向；
- 手动武器瞄准；
- 地面技能放置；
- RestArea 点击和悬停；
- Debug 世界位置选择。

自动瞄准、敌人 AI 和已有世界坐标 API 不做二次转换。

## UI 规则

普通 HUD 留在 CanvasLayer：

- 玩家生命、能量；
- 金币总数；
- 菜单；
- 操作提示；
- 暂停和奖励界面。

世界 UI 使用投影锚点和屏幕像素偏移：

- EnemyHpBar；
- HitLabel；
- InteractHint；
- 世界任务标记；
- RestArea 服务提示。

例如：

```gdscript
var screen_anchor := project_world_to_screen(enemy_position)
screen_anchor += Vector2(0.0, -30.0)
```

不得将 `-30` 当成透视地面世界单位。

## RestArea 规则

RestArea 必须拆分为：

```text
3D Ground
├── 地面
├── 服务区域标记
└── 选择/悬停贴片

2D Billboard
├── 商店
├── 升级台
├── 仓库
└── 战术控制台

CanvasLayer
├── 服务提示
├── 操作提示
└── 管理菜单
```

鼠标区域判断必须通过 Camera3D 地面射线反算回 2D。RestArea 的碰撞、区域编号、自动导航和菜单逻辑继续使用原 2D 坐标。

RestArea 服务设备默认关闭透视缩放，所有设备保持固定 Billboard 尺寸，不影响逻辑
脚点、交互区域或碰撞。该行为由 `BillboardVisual2D.perspective_scale_amount = 0.0`
控制；`perspective_min_scale` 和 `perspective_max_scale` 仅保留为可选开发参数。

RestArea 的 2D `Texture/Sprite2D` 在混合模式下只作为纹理、尺寸和逻辑锚点来源。
隐藏它之前必须创建 `RestAreaGround` QuadMesh，并在 RestArea 因关卡结算移动时持续同步
其全局中心、可见性和淡入淡出透明度。只创建服务区圆形标记而没有基础地面会导致休息区
直接显示世界清屏色。

服务设备的生成必须幂等：同一个 `zone_id` 只能存在一个 `HybridProp`。3D 地面重建、
活动 Cell 刷新或 Debug 参数变化都不得重复追加设施 Sprite。设施默认占对应区域短边的
`0.60`，默认不再叠加远近透视缩放。

服务区域标记使用 `RestAreaZoneGroundShader` 驱动的径向 UV QuadMesh，而不是 2D
`draw_circle`/`draw_arc`。单个贴片同时绘制半透明底色、向外流动的扫描纹、内圆环、
发光外边框以及中心区域的按住进度环。`hover_zone_id`、`selected_zone_id`、RestArea
淡入淡出透明度和 `_zone4_hold_elapsed` 每个 Late Sync 同步到 Shader 参数；交互判定仍
完全由 2D RestArea 负责。

战斗 Board 隐藏时必须同时隐藏 Cell 贴图、ActivationVisual 和四条 3D 边线。
不能只隐藏 Cell QuadMesh，否则休息区会残留上一战斗场地的空白梯形轮廓。

## HybridGroundView3D 渲染职责拆分

`HybridGroundView3D` 是相机与投影门面，不再直接负责每类视觉的扫描和 Late Sync
调度。运行时由以下五个组件协作：

- `GroundMeshRegistry`：按 SceneTree group 发现视觉源，路由注册请求并统一安排 Late Sync；
- `BoardGroundRenderer`：Board Cell、边界、ActivationVisual、RestArea 地面与区域贴片；
- `ConnectedEffectRenderer`：Beam、Laser、电弧、连线与喷火锥；
- `AuraRenderer`：敌人光环及敌人之间的支持连线；
- `AreaEffectRenderer`：阴影、AreaEffect、警告圈与冲刺提示器。

外部脚本继续通过 `HybridGroundView3D.register_*()` 门面注册，避免武器、敌人和场景
依赖具体 Renderer。Renderer 共享门面的 `world_2d_to_3d()` 投影，不保存第二份相机参数。

`ConnectedEffectRenderer` 同时负责几何资源复用：Beam 共享一个单位 QuadMesh，Arc 和
Link 共享一个单位 BoxMesh，长度与宽度通过 `MeshInstance3D.scale` 表达。共享 Shader
Material 使用 instance uniform 接收颜色和透明度，避免实例间串色。喷火锥以半角为缓存
键共享单位 ArrayMesh，射程只改变实例缩放，不允许每帧重建 ArrayMesh。

地面视觉采用严格的主动生命周期：视觉源在 `_ready()` 完成后调用对应 `register_*()`，
并在 `_exit_tree()` 调用 `unregister_ground_visual()`。Registry 不允许在 `_process()` 中使用
`get_nodes_in_group()` 扫描；group 只保留分类和调试用途。注销必须立即移除缓存并释放对应
MeshInstance，Renderer 的 Late Sync 弱引用检查仅作为异常安全网。

若视觉源早于 `HybridGroundView3D` 进入 SceneTree，`HybridGroundRegistration` 使用 WeakRef
挂起注册请求；View 完成 Renderer 初始化后一次性 `flush_pending()`。源在等待期间退出会
主动删除挂起项，因此不需要恢复周期扫描，也不会持有已释放节点。

高频连接视觉使用 `GroundMeshInstancePool`。Beam、Arc、Link 和 Cone 注销后隐藏并归还按
类型分组的池，下一次注册复用同一个 MeshInstance；共享 Mesh/Material、实例 Shader 参数
和对象池是三个独立层次，均不得因复用而残留上一实例的 Transform、可见性或颜色。

## Camera3D / Camera2D 协同

Camera3D 负责：

- 地面透视；
- 世界脚点投影；
- 鼠标地面射线；
- RestArea 覆盖范围。

Camera2D 负责：

- 2D Canvas 坐标承载；
- 原有 Camera offset shake；
- 旧 UI 和 CanvasLayer 兼容。

长期应将以下参数归入一个视野控制器：

- Camera3D FOV；
- pitch；
- yaw；
- distance；
- world scale；
- battle/rest view multiplier；
- vision multiplier；
- shake。

当前 Debug 面板快捷键为 `Ctrl+Shift+F10`。

Debug 面板只保留允许在运行时调整的混合 Camera3D 参数：`Yaw`、`3D pitch` 和
`3D distance`。旧 Camera2D 斜视使用的 `Vertical scale`、
`Overscan`、`Rest view` 与 `Billboard scale` 不得继续出现在该面板中，因为它们
不会改变当前 3D 地面透视，容易造成错误调参判断。

`3D FOV` 固定为 `34.0`，`Ground scale` 固定为 `0.01`。二者不导出到 Inspector、
不出现在 Debug 面板，也不允许通过运行时 `configure()` 修改，以保证 2D 逻辑坐标、
3D 地面尺寸和 Billboard 脚点投影始终使用同一套稳定标定。

Camera3D Distance 的默认值统一定义在
`Visual/Oblique/hybrid_camera_defaults.gd`，当前为 `8.5`。Camera3D 初始化、Player
导出参数初始值和 Debug 面板 Reset 必须引用该常量，禁止再次复制独立数字。

## 深度与绘制顺序

建议顺序：

```text
3D Cell 地面
< 3D 地面状态贴片
< 3D AreaEffect
< 3D 阴影
< 2D Billboard
< 世界 UI CanvasLayer
< HUD / 菜单 CanvasLayer
```

需要继续处理：

- Billboard 之间的脚点排序；
- 大型敌人锚点；
- 透明 3D 贴片排序；
- 相机后方对象隐藏；
- Projectile 不必要的 z_index 抖动。

## 性能与生命周期

原型完成后应优化：

- 共享 QuadMesh、CylinderMesh 和材质；
- AreaEffect 和 Shadow Mesh 对象池；
- 使用注册/注销替代定时 `get_nodes_in_group()` 扫描；
- 避免每帧创建 Dictionary、数组和 Transform；
- 场景切换时清空 WeakRef 和 Mesh 缓存；
- 在类型转换前检查 Variant 对象是否仍有效；
- Debug 参数重建地面时清空所有旧 Mesh 引用。

## 当前已完成的基础能力

- 透视 Camera3D 和 Cell QuadMesh；
- 2D/3D/屏幕双向转换；
- 玩家、基础敌人和掉落物 Billboard；
- Weapon Sprite Directional Billboard；
- 基础 Projectile 视觉/HitBox 分离；
- Camera3D 鼠标地面射线；
- 屏幕空间武器后坐力；
- 投影后的 Muzzle Flash；
- EnemyHpBar 投影锚点；
- 金币 Billboard；
- RestArea 地面、设施和提示初步拆分；
- 基础 3D Shadow、AreaEffect 和 ActivationVisual 贴片；
- Debug 调参面板。

## 2026-07-11：优先步骤 1–4 完成状态

### 1. 核心坐标投影

已完成：

- 2D 世界点到 Camera3D 屏幕点；
- 屏幕点经地面射线返回 2D 世界点；
- 世界方向到屏幕方向；
- 屏幕移动方向到 2D 世界方向；
- Camera3D 初始化姿态和投影就绪状态；
- 相机后方点和相机平面点防护；
- 地面平行射线和相机后方交点防护；
- Camera 参数变化后的缓存清理与重建；
- 场景退出时清理玩家、RestArea 和 Mesh 缓存；
- `world.hybrid_projection` 正式回归测试。

### 2. Billboard 组件

已完成：

- Upright 和 Directional 两种核心模式；
- 逻辑脚点与视觉投影位置分离；
- HybridGroundView 引用缓存；
- 相机后方自动隐藏；
- `screen_offset` 屏幕像素偏移；
- `screen_feedback_offset` 和 `screen_feedback_rotation`；
- `set_logical_local_position()`；
- `set_screen_offset()`；
- `reset_projection_state()` 对象池重置入口；
- Projectile 获取和回收时重置投影状态。

### 3. 玩家和基础敌人

已完成：

- 玩家身体脚点投影；
- 玩家屏幕方向输入和 Camera3D 鼠标地面瞄准；
- 基础敌人 Body 脚点投影；
- 精英继承敌人场景加载与脚点回归；
- 玩家、敌人和掉落物 3D 地面阴影；
- EnemyHpBar 使用投影脚点与屏幕像素偏移；
- HitLabel 生成到 CanvasLayer，并从敌人逻辑位置投影；
- HitLabel 原有弹出和淡出保持屏幕方向。

### 4. 基础武器链路

已完成：

- 基础 Weapon Sprite Directional Billboard；
- 机枪继承基础 Sprite 投影；
- Muzzle 保持 2D 逻辑世界接口；
- Projectile Bullet 与 HitboxAnchor 分离；
- `base_displacement` 和 `projectile_displacement` 逻辑/视觉同步；
- 屏幕空间后坐力，不移动逻辑 Weapon 或 Muzzle；
- Muzzle Flash 使用投影后的屏幕位置与方向；
- Camera3D 鼠标射线作为手动武器目标；
- 自动瞄准继续使用敌人 2D 逻辑坐标；
- `weapon.hybrid_chain` 正式回归测试。

阴影实现说明：基础阴影节点使用 `HybridGroundShadow2D` 主动注册，而不是等待
`HybridGroundView3D` 周期扫描。混合模式下阴影在 `_ready()` 当帧隐藏原 2D 视觉，
注册时保存 `GroundShadow.position` 作为逻辑局部脚点，并从 Sprite 纹理尺寸或
Polygon bounds 计算 3D 椭圆大小。不得只使用角色根坐标或固定阴影尺寸。

### 新增正式测试

```text
world.hybrid_projection
weapon.hybrid_chain
```

两个测试均已加入 `tests/infrastructure/test_manifest.json`。

## 玩家手动检查清单

以下项目依赖真实画面、输入手感、纹理尺寸或动画节奏，自动化测试无法充分判断。每次修改投影、Billboard、Camera3D 或武器视觉后应人工检查。

### Camera3D 和地面

- 战斗开始后玩家脚点位于 Camera3D 目标中心；
- 远处 Cell 更密、近处 Cell 更疏；
- 地砖之间没有明显裂缝或重叠；
- 调整 FOV、pitch、distance、yaw 和 Ground scale 时不闪烁；
- 不同窗口比例下地面仍覆盖预期区域；
- 进入和离开 RestArea 时镜头范围合适；
- Camera shake 只产生预期屏幕抖动。
- 3D Cell 四边线在远近位置均清晰且没有明显 Z-fighting；
- 原 `NavigationBlockers` 的 2D Polygon 阴影不再覆盖 3D 战斗场地；

当前实现说明：`BoardCellGenerator` 生成的 blocker Polygon 会加入
`legacy_board_boundary_visual` 组。混合地面管理器周期性隐藏这些视觉节点，
但保留对应的 StaticBody2D 和 CollisionShape2D。Cell 边线由贴地 BoxMesh 显示，
参数位于 `HybridGroundView3D.cell_border_color` 和
`HybridGroundView3D.cell_border_width_2d`。

### 玩家和敌人

- 玩家 Sprite 脚底与逻辑碰撞位置一致；
- WASD 在屏幕中严格对应上下左右；
- 鼠标在玩家各方向时动画朝向正确；
- 基础敌人和精英敌人的脚点与阴影一致；
- 敌人追踪、击退和死亡位置没有视觉漂移；
- 敌人在屏幕边缘和相机后方时隐藏/恢复自然；
- Hit Flash 和 Warning Flash 与 Body 完全重合。

### Enemy UI

- EnemyHpBar 位于敌人头顶且保持水平；
- 不同尺寸敌人的 `hp_bar_vertical_offset` 合理；
- 敌人移动、击退和死亡时血条不滞后；
- HitLabel 从对应敌人上方生成；
- HitLabel 始终向屏幕上方弹出并淡出；
- 多个敌人同时受伤时 Label 不出现在错误目标上。

### 默认枪械和机枪

- 武器 Sprite 围绕玩家的位置与原逻辑轨道一致；
- 武器视觉方向、鼠标目标和实际命中点一致；
- Muzzle 视觉位置与第一帧子弹位置一致；
- 后坐力严格沿枪口反方向，不出现侧移或跳跃；
- 后坐力不改变下一发子弹的出生位置；
- Muzzle Flash 贴合枪口且方向正确；
- 连续开火时 Muzzle Flash 不在旧 Camera2D 位置生成；
- 机枪快速连射时 Sprite 不累积偏移或旋转；
- 调整 Camera3D 参数后仍保持枪口、子弹和命中对齐。

### Projectile

- 普通子弹视觉与 2D HitBox 始终重合；
- 子弹运动方向与投影后的地面方向一致；
- 动画 Projectile 正常播放；
- Projectile 大小与旧版本一致；
- 穿透、墙体碰撞和过期回收没有变化；
- 对象池复用后没有残留位置、旋转或后坐力偏移。

### 金币和掉落物

- 金币图标与拾取碰撞位置一致；
- 金币吸向玩家时沿正确的投影轨迹移动；
- 掉落物图标、阴影和 DetectArea 对齐；
- 拾取后图标立即隐藏，金币 HUD 数值正常更新。

## 未完成或需要专项迁移

- HitLabel 屏幕上浮和合并显示；
- RestArea 箭头和更复杂的多层粒子装饰（地面圆环、发光边框和动画材质已完成）；
- 贴地粒子、法线扰动和多层混合 AreaEffect（SpriteFrames 单层纹理已完成）；
- 战斗/休息 Camera3D transition 与 vision multiplier 的统一；
- 不同窗口比例和超宽屏验证；
- 手动画面回归场景。

## 2026-07-11：世界 UI、地面效果与 Projectile 扩展

### 世界空间 UI

- 新增 `ProjectedWorldUiService`，统一创建 `HybridWorldUi` CanvasLayer、查询
  HybridGroundView 和执行 screen/canvas 投影；
- EnemyHpBar、HitLabel 和玩家 FloatingStatusHint 使用统一服务；
- 新增 `ProjectedWorldHintLabel`，DropItem 与 FriendlyNPC 的 InteractHint 保留
  原 NodePath 和生命周期，但使用统一 Camera3D 锚点；
- 后续世界 UI 不应直接调用 `get_nodes_in_group("hybrid_ground_view_3d")`。

### 地面效果

- 通用 AreaEffect 继续注册为 Circle Ground Visual；
- 带动画的瞬时爆炸属于 Upright Billboard，不再同时创建 Circle Ground Visual；
- 动画爆炸必须立即关闭 `AreaEffect.draw_enabled`，避免旧 2D 范围圈在周期扫描前闪现；
- TargetWarning 注册为 Warning Circle，并隐藏原 2D Draw；
- Spike Turret AimWarningLine 注册为 Segment Ground Visual；
- Segment 使用起点/终点的 2D 逻辑坐标生成 3D BoxMesh 条带；
- Ground Effect 仍由 2D source 控制生命周期，3D Mesh 只负责显示。

### 敌人辅助光环与连接线

- Orbit Support、Repair Unit 和 Shield Core 的范围光环属于 Ground Plane；
- 光环填充使用 3D Disc，边界使用独立 TorusMesh，不能继续调用敌人根节点 `_draw()`；
- Repair Unit 治疗连线和 Shield Core 减伤连线属于连接型 Ground Visual；
- 连线起点和终点始终读取两个敌人的 2D 逻辑脚点，并实时更新 3D BoxMesh 长度和角度；
- 目标改变、死亡或离开范围后，旧连接 Mesh 必须立即回收；
- 混合模式下旧 `draw_circle`、`draw_arc` 和 `draw_line` 必须停止绘制，纯 2D 回退模式保留。

### Rolling Ball Elite 冲刺预警

- 冲刺预警属于连接型 Ground Visual，不得继续显示 Polygon2D；
- 全长危险区域使用贴地 BoxMesh，长度来自 `dash_distance`，宽度来自 `warning_half_width * 2`；
- 蓄力进度使用第二个略高的 BoxMesh，从起点沿锁定方向逐渐增长；
- 起点、锁定方向、宽度和进度继续由 `SkillWarningTelegraph` 的 2D 逻辑状态提供；
- `clear_warning()` 后两个 Mesh 必须同时隐藏；
- 纯 2D 回退模式继续保留原 Polygon2D 和 Line2D。

### Projectile

- 新增 `ProjectileVisualMode` 分类；
- 新增统一 `_reset_projectile_visual_state()`；
- 基础 Projectile、SniperProjectile 和 PlasmaLanceProjectile 均具有
  `HitboxAnchor` 与 Directional Billboard Bullet；
- EnemySpikeProjectile 的 Sprite 已成为 Directional Billboard，Area2D 与
  CollisionShape2D 保持逻辑权威；
- 专项测试会验证派生 Projectile 场景没有继续保留旧节点结构。

## 2026-07-12：复杂战斗视觉迁移

### Beam、Laser 与电弧

- Laser Beam 和 Charged Beam 保留 RayCast、HitBoxDot 和命中逻辑；
- Line2D 只作为 2D 起终点数据源；普通连线使用 3D BoxMesh，Beam 使用带 UV 的 QuadMesh；
- Beam 的 Shader 沿 U 轴连续流动并在 V 轴边缘衰减，起点和终点各有独立贴地光斑；
- Pistol Arc 与 Lightning Chain 使用短生命周期 `GroundConnectionEffect2D`；
- Plasma Lance Rift 的主裂隙和 Spark Line 均注册为 3D Segment；
- Line2D 的 `modulate.a` 会同步到 3D Material，保留淡出；端点光效跟随同一显隐状态。

### 喷火锥和冰冻锥

- ConeSprayVfx 在混合模式关闭旧 2D AnimatedSprite 拉伸；
- 使用单个三角扇 ArrayMesh 表示锥形范围，并随射程、半角和瞄准方向更新；
- 扇形 UV 以起点到锥尖为 U、左右边缘为 V，Shader 提供连续火焰流动、尖端淡出和侧边衰减；
- 纯 2D 回退仍使用原动画 Sprite。

### 非圆形 AreaEffect

- `AreaEffect.VisualShape` 支持 `CIRCLE`、`RECTANGLE`、`CONE`；
- Rectangle 和 Cone 使用动态 ArrayMesh 地面多边形；
- Rectangle 使用 RectangleShape2D，Cone 使用 CollisionPolygon2D，视觉和伤害检测共享尺寸参数；
- 瞬时动画爆炸仍分类为 Upright Billboard；设置 `animated_visual_is_ground = true` 的贴地动画 AreaEffect 会把 AnimatedSprite2D 当前帧纹理同步到 3D Material；
- Rectangle 与 Cone ArrayMesh 现在生成归一化 UV，可承载 SpriteFrames 纹理；粒子型地面效果仍需单独迁移。

### Fuse 与复杂武器子视觉

- FuseSprites 仅保存纹理资源，不接受投影 Transform；
- Fuse 纹理应用到 Weapon 主 Sprite，自动继承 Directional Billboard；
- DashBlade 的 BladeSprite 单独使用 Directional Billboard，BladeAnchor、HitBox 和运动逻辑保持 2D 权威；
- 自动测试枚举所有 `Player/Weapons/Instances/*.tscn`，验证主 Sprite 与 Fuse 容器职责。

### Projectile 分类矩阵

| 场景 | 分类 | 美术前向 |
|---|---|---|
| `projectile.tscn` | Directional | Up / `-90°` |
| `sniper_projectile.tscn` | Directional | Up / `-90°` |
| `plasma_lance_projectile.tscn` | Upright | 无方向能量球 |
| `enemy_spike_projectile.tscn` | Directional | Up / `-90°` |

测试会动态枚举 Projectile 目录，所有 `Projectile` 派生场景必须保留逻辑
`HitboxAnchor`，并为 `Bullet` 声明 Billboard 分类。Enemy Spike 使用显式速度方向更新。

## 2026-07-12：敌人继承场景视觉矩阵

新增正式测试 `enemy.hybrid_visual_matrix`，逐个加载全部 17 个 `BaseEnemy` 继承场景，
覆盖 Base、Elite、Dummy、Bomber、Interceptor Heavy、Mine/Tar Mine Crawler、
Mirror Caster/Clone、Mortar/Spike Turret、Orbit Support、Repair Unit、Rolling Ball/Elite、
Shield Core 和 Wheel Cart。

每个场景必须满足：

- `Body` 保留兼容 NodePath，并使用 `BillboardVisual2D`；
- Body 的作者脚点投影到正确 Canvas 位置；
- `GroundShadow` 注册为 3D Mesh，并使用自身局部脚点而非敌人根节点硬编码位置；
- `EnemyHpBar` 使用敌人逻辑脚点加屏幕像素偏移，且保持水平；
- HitFlash 和 WarningFlash 的 texture、flip、offset、centered 与 Body 一致；
- 敌人移动后 Flash 仍与 Body 重合。

Camera3D 投影服务使用较早的 `process_priority = -100`，确保玩家和敌人 Billboard
读取当前帧相机，避免玩家移动时使用上一帧投影产生抖动。Cell、Shadow、AreaEffect 等
地面附属视觉由独立的 `LateGroundVisualSync` 使用 `process_priority = 100` 更新，确保
敌人的 2D 移动完成后再读取脚点。Flash Overlay 作为 Body 子视觉存在，继承同一
Billboard 投影 Transform；不得重新复制投影后的世界位置。

新注册的 3D Shadow Mesh 在第一次脚点同步前必须保持隐藏。敌人生成与战斗倒计时使用
同一个秒级 Timer 节奏时，若 Mesh 以默认原点立即可见，会表现为倒计时每秒在地图上
生成一个椭圆阴影。

## 测试门禁

每次改动至少运行：

```powershell
& 'E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path . --check-only --quit

pwsh -NoProfile -File tests/infrastructure/run_selected_tests.ps1 `
  -BaseRef origin/master `
  -GodotPath 'E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'

git diff --check
```

涉及 World 时还应运行数帧场景：

```powershell
& 'E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path . --quit-after 300 res://World/world.tscn
```

检查输出中不得存在：

- parser/compile error；
- invalid call；
- Node not found；
- freed object cast；
- Camera3D projection denominator error；
- scene inheritance error；
- runtime error。

Godot 强制提前退出产生的已知 shutdown RID diagnostics 应与实际运行错误分开记录。

## 禁止事项

- 不将碰撞和 AI 迁移到 3D；
- 不让 Billboard 修改父级逻辑 Transform；
- 不把投影结果写回逻辑坐标；
- 不将 HitBox 放在投影视觉节点下；
- 不改变 Muzzle 世界接口语义；
- 不在多个脚本复制投影数学；
- 不使用逐 Cell 非线性缩放模拟透视；
- 不让普通 HUD 接受 Camera3D 投影；
- 不使用强制 Git reset、clean 或 force push；
- 未经要求不提交、不推送。

## 后续 Agent 推荐顺序

## 2026-07-12：自动化收尾计划

当前阶段不再新增 2.5D 架构层。后续工作按以下顺序收口，直到只剩真实画面验收：

1. 世界 UI：保证同一敌人的连续 HitLabel 在可见期内合并，合并后刷新颜色、缩放和生命周期；弹出方向必须始终为屏幕向上。
2. RestArea：验证地面、五个区域 Shader、服务设施和引导箭头的生成幂等；同步 hover、selected、hold、淡入淡出与整体显隐。
3. 复杂地面效果：为需要多层表现的 AreaEffect 提供可选基础纹理、细节纹理、UV 流动和扰动；未配置细节纹理的资源继续使用兼容单层路径。
4. 生命周期：注册、注销和源节点释放后必须立即清理 Mesh 缓存；场景重建不得重复生成 RestArea 设施或区域 Mesh。
5. 自动门禁：执行 Godot check-only、所有受影响测试、World 300 帧检查和 `git diff --check`。
6. 人工门禁：只保留窗口比例、超宽屏、纹理观感、动画节奏、透明排序、锚点手感和战斗/休息镜头过渡检查。

本轮自动化完成状态：

- HitLabel 屏幕向上弹出与同目标可见期合并：已完成；
- RestArea 地面箭头、扫描纹、发光边框、进度环和状态同步：已完成；
- AreaEffect 可选多层纹理、流动与 UV 扰动：已完成；
- 上述行为的 Headless 回归覆盖：已加入 `world.hybrid_projection`；
- 完整自动门禁：已通过（Godot check-only、5 个受影响测试、World 300 帧检查和 `git diff --check`）；
- 剩余工作：仅保留无法由 Headless 判断的人工画面与手感检查。

1. 先复现并记录视觉问题对应的逻辑点和屏幕点。
2. 判断对象属于 Ground、Upright、Directional、Connected Effect 或 Canvas UI。
3. 保留逻辑节点，单独修改视觉子树。
4. 使用 `HybridGroundView3D` 做坐标转换。
5. 检查投影位置是否被错误回写。
6. 检查碰撞是否意外挂在 Billboard 下。
7. 运行 Godot check-only。
8. 运行受影响测试。
9. 运行 World 场景帧检查。
10. 在最终报告中列出尚未迁移的复杂视觉。

核心原则：

```text
2D 决定对象在哪里以及命中了什么。
3D 决定地面如何透视显示。
Billboard 决定立式视觉在屏幕哪里、朝向哪里。
CanvasLayer 决定 UI 如何稳定显示。
```

## Board 2D/3D 同步契约

`BoardCellGenerator` 仍是战斗场地状态的唯一权威来源。3D Cell 不保存独立的关卡状态，
只缓存对应 2D Cell 的 Mesh 和 Material，并遵守以下同步入口：

- `board_visual_active_changed`：阶段切换时同时隐藏或显示 3D 战斗地面；
- `board_recentered`：Board 重定位时将同一位移同步到 Cell、边线和 ActivationVisual 的 3D Mesh；
- `active_cells_changed`：有效 Cell 集合改变后重建轻量的 3D Cell 视觉；
- `terrain_visual_changed`：Cell 地形纹理改变时立即更新对应 3D Material。

此外，`HybridGroundView3D` 每帧校验少量 Cell 的世界脚点、可用状态和当前纹理。
这是防止遗漏生命周期信号的安全网，不替代上述事件。禁止只在 `_ready()` 中生成一次
3D Board 快照；否则 Board 在战斗结束后移动或隐藏时会留下旧场地，并在下一场战斗沿用旧纹理。
