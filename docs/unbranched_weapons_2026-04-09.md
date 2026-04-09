# 无分支武器清单与战斗数据（2026-04-09）

当前仓库中，可独立出现且仍未接分支的武器有 `10` 把（已排除已分支武器与已关闭独立投放武器）。

| 武器 | 攻击方式 | 伤害类型 | 攻击频率（约） | 其他关键数据 |
|---|---|---|---|---|
| Charged Blaster | 蓄力后发射持续 Beam（非普通单发） | Energy | 主循环 `reload=5s`（0.2次/秒）；Beam 内 tick `hit_cd=0.2~0.15s` | `duration=3.0~3.9s`，`max_charge=2~3`，`beam_range=450` |
| Spear | 直线投射 + 到时回返 | Physical | `reload=0.6~0.3s`（1.67~3.33次/秒） | `speed=900~800`，`hp(穿透)=4~6`，回返模块（停0.5s后回1.0s） |
| Orbit | 生成环绕卫星持续接触伤害（常驻） | Physical | 非传统“每发冷却”，主手切入时一次性生成卫星 | 卫星数 `1~6`，`spin_speed=3~4`，卫星 `hp=99999`、超长存在 |
| Laser | 短持续射线（RayCast） | Energy | `reload=2.0~0.6s`（0.5~1.67次/秒） | 单次 Beam 持续约 `0.2s`；射线每物理帧判定命中 |
| Chainsaw Launcher | 旋转锯片投射，DOT 命中箱 | Physical | `reload=1.0~0.75s`（1.0~1.33次/秒） | `dot_cd=0.1s`，`speed=200`，`hp=15~30`，持续贴身磨血 |
| Hammer | 近战突进命中（自动找近敌） | Physical | `reload=1.3~0.85s`（0.77~1.18次/秒） | `range=130~190`，`dash_speed=780~1040`，`return_speed=620~780` |
| Heat Sink Burst | 高频能量弹 + 过热触发火爆 | Energy（主弹）+ Fire（过热爆） | `reload=0.20~0.15s`（5.0~6.67次/秒） | `range=680~790`；过热爆：`radius=170`，伤害基值 `90 + 14*(lv-1)` |
| Plasma Lance | 慢频重型穿透弹 | Energy | `reload=1.5~1.2s`（0.67~0.83次/秒） | `range=900~1080`，`hp(穿透)=4~8`，每次穿透追加 `+3` 伤害 |
| Glacier Projector | 近中距扇形持续压制（按冷却脉冲） | Freeze | `reload=0.22~0.18s`（4.55~5.56次/秒） | `range=260~330`，半角 `38°`，持续接触触发 Cold Snap（阈值1.2s） |
| Pulse Sidearm | 高频直射能量手枪 | Energy | `reload=0.25~0.222s`（4.0~4.5次/秒） | `range=760~860`，每第4发共振增伤（`+25%`） |

## 备注
- 不在上表统计内、且已关闭独立投放的武器：
  - `Thermal Cannon (14)`、`Zero Cannon (24)`、`Cryo Carbine (18)`、`Arc Coil (23)`、`Frost Dash Blade (20)`、`Shatter Buckshot (19)`。
- 本文用于“初级武器 -> 2分支武器”的整合规划输入，不包含平衡性数值结论。
