# 武器核心奖励卡分阶段修改提示词

建议依次执行以下五个阶段。每一阶段完成并验证后，再进入下一阶段。

## 阶段 1：拆分武器与武器核心语义

```text
请修改 MagArena 奖励卡的数据模型，使“武器核心”不再被当作武器奖励展示。

目标：
1. 检查 UI/scripts/presentation/reward_card_data_assembler.gd、
   UI/scripts/presentation/reward_card_model.gd 和
   UI/scripts/reward_selection_panel.gd。
2. 将以下奖励类型明确区分：
   - new_weapon
   - weapon_upgrade
   - weapon_core
   - module
   - generic
3. weapon_core 不应继续依赖统一的 is_weapon_visual_reward 判断。
4. 为 weapon_core 准备独立的展示字段：
   - source_weapon_name
   - source_weapon_icon
   - core_amount
   - current_core_count
   - resulting_core_count
   - core_tags
   - usable_branches
5. 当结果为 dismantled_to_core 时，清空或不生成以下武器展示信息：
   - summary_text
   - role_summary
   - feature_lines
   - core_stat_lines
   - comparison_lines
6. 不改变新武器和武器升级卡的现有表现。
7. 保留当前未提交改动，不覆盖无关修改。

本阶段只完成数据语义和类型分离，暂时不要大幅修改视觉布局。

验证要求：
- 复用现有 reward.weapon_fusion_card_semantics 测试。
- 不新增活动测试项。
- 运行 Godot headless check-only。
- 报告修改文件、字段变化和测试结果。
```

## 阶段 2：建立专用武器核心卡

```text
请为 MagArena 的 weapon_core 奖励建立专用卡片内容，不再复用武器卡主体。

目标：
1. 在 UI/scripts/reward_selection_panel.gd 中新增职责清晰的核心卡构建函数，例如：
   _build_weapon_core_content(card_data)
2. weapon_core 卡按以下顺序展示：
   - 类型标题：武器核心
   - 核心素材图标
   - 来源：{source_weapon_name}
   - 重复武器已分解为 {core_amount} 个核心
   - 库存：{current_core_count} → {resulting_core_count}
   - 核心继承标签
   - 标签 chip
   - 可用于
   - 匹配的融合分支
3. weapon_core 卡必须移除：
   - 武器战斗描述
   - 武器定位文本
   - 伤害、射击间隔、弹匣容量
   - 武器等级
   - 武器伤害类型图标
   - 兼容模组条件
   - 原武器分支预览
4. 新武器和武器升级卡保持原样。
5. 核心卡保持在现有奖励选择视口内，不增加纵向滚动条。
6. 使用整数像素尺寸并维持现有科幻像素 UI 风格。
7. 不启动 Godot 图形窗口。

验证要求：
- 扩展已有 reward.weapon_fusion_card_semantics 测试，确认上述武器节点不会出现在核心卡中。
- 确认核心卡仍显示全部标签。
- 运行相关测试及 Godot headless check-only。
```

## 阶段 3：强化来源与素材身份

```text
请进一步优化 MagArena 武器核心卡的视觉身份，使玩家第一眼就知道获得的是强化素材，而不是武器。

目标：
1. 卡片主标题使用“武器核心”，不要继续以来源武器名称作为主标题。
2. 来源武器名称改为次级信息：
   “来源：{weapon_name}”
3. 使用通用武器核心视觉作为主图：
   - 保留清晰的 C 标识。
   - 可以在核心图标内部或旁边显示较小的来源武器缩略图。
   - 来源武器缩略图不能比核心图标更突出。
4. 不显示武器等级或武器稀有度。
5. 强化素材使用稳定的素材色彩语义，与“新武器”奖励颜色明显区分。
6. 选中态、数字快捷键和长按确认反馈继续沿用现有奖励卡行为。
7. 不修改核心的库存和融合运行时逻辑。

本地化文案至少包括：
- Weapon Core / 武器核心
- Source: {name} / 来源：{name}
- Duplicate weapon dismantled into {amount} core(s).
  / 重复武器已分解为 {amount} 个核心。
- Inventory: {current} → {resulting}
  / 库存：{current} → {resulting}

验证要求：
- 重新导入 ui_texts.csv 生成的翻译资源。
- 验证英文和简体中文。
- 运行已有相关测试和 headless 编译门禁。
```

## 阶段 4：优化“可用于”融合信息

```text
请优化 MagArena 武器核心卡中的“可用于”区域，让玩家能理解核心的实际用途。

目标：
1. 使用运行时返回的 usable_branches，而不是展示来源武器自身的分支预览。
2. 标题使用：
   “可用于”
3. 每个匹配项显示：
   “{weapon_name} · {branch_name}”
4. 卡片内最多显示两个匹配项。
5. 超过两个时追加：
   “另有 {count} 项”
6. 没有匹配融合配方时显示：
   “暂未发现可用融合配方”
   这不应被表现为错误或禁用状态。
7. 不显示被锁住的分支说明、分支伤害数字或原武器战斗描述。
8. 如果 usable_branches 数据存在无效 weapon_id 或 branch_id，应安全跳过，不产生运行时错误。
9. 完整用途可以保留在详情层，但奖励卡主体必须保持简洁。

新增或调整中英文翻译，并重新导入翻译资源。

验证要求：
- 在现有测试中覆盖 0、1、2、3 个可用分支。
- 验证无效分支数据会被安全忽略。
- 不新增活动测试文件或清单项。
- 运行相关测试与 headless check-only。
```

## 阶段 5：最终回归与收尾

```text
请对 MagArena 武器核心奖励卡修改进行最终回归审查和必要修复。

检查范围：
1. weapon_core 卡只表达强化素材语义。
2. 核心卡不包含：
   - WeaponDescriptionSlot
   - WeaponRoleSummary
   - CoreWeaponStats
   - WeaponBuildPreview
   - ModuleInstallationRequirements
   - BranchPreviewRow
   - WeaponLevelLabel
   - 武器伤害类型图标
3. 核心卡必须包含：
   - Weapon Core 标题
   - 来源武器
   - 分解数量
   - 库存变化
   - 完整继承标签
   - 标签来源与融合用途说明
   - 可用融合分支或空状态
4. 新武器、武器升级、模组和普通奖励卡不能发生回归。
5. 在 1280×720 的固定奖励选择区域内不产生纵向滚动。
6. 检查最长合理中文和英文文案，避免截断、重叠和越界。
7. 保留工作区中所有无关未提交改动。

验证：
- 运行 reward.weapon_fusion_card_semantics。
- 使用测试选择器运行受影响测试。
- 运行 Godot headless check-only。
- 检查翻译资源已经从 CSV 更新。
- 检查 git diff --check。
- 不启动图形窗口，除非我另行明确授权。

最终报告：
- 修改文件。
- 武器核心卡修改前后的信息结构。
- 测试结果。
- 尚未进行图形化视觉验证所带来的剩余风险。
```

