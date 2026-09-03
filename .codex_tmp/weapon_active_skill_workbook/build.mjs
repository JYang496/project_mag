import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const rows = [
  ["spear", "Spear Launcher / 长矛发射器", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次积满 10 层长矛充能并开始换弹后解锁", "Blade Recall / 万刃归流", "召回或引爆场上的长矛；按已标记目标数量追加八方向刀舞，并立即保留一部分长矛充能。"],
  ["cannon", "Cannon / 加农炮", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次完成 5 秒副手蓄力后解锁", "Siege Breach / 攻城破口", "立即准备一发强化破口炮；命中造成高冲击伤害，并扩大易伤影响范围或延长易伤时间。"],
  ["chainsaw_launcher", "Chainsaw Launcher / 链锯发射器", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次达成 10 次连续命中后解锁", "Predator Chain / 猎杀链锯", "短时间强化追踪和反弹能力，并立即进入减速、易伤武装状态；连续命中可延长持续时间。"],
  ["charged_blaster", "Charged Blaster / 蓄能爆能枪", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次完成一次满武器能量释放后解锁", "Resonance Lance / 共振长束", "释放可转向的持续共振光束；对同一目标连续命中时快速提高倍率，转移目标后倍率逐步回落。"],
  ["dash_blade", "Dash Blade / 冲刺刃", "被动已实装；不可选为主武器；当前仍可通过槽位长按请求通用主动技能", "拟定：武器达到 Lv.3，且本局首次达成 6 次连续冲刺刃命中后解锁", "Return Execution / 往返处决", "补充一次冲刺并执行往返斩击；去程聚怪或控制，回程对低生命目标造成处决收益。"],
  ["flamethrower", "Flamethrower / 火焰喷射器", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次消耗完整四个弹匣阶段后解锁", "Thermal Overflow / 热流溢出", "进入过热喷射状态，扩大喷射锥和射程，并将 Heat Prepared 临时提升至最大层数。"],
  ["glacier_projector", "Glacier Projector / 冰川投射器", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次消费 Cold Snap 后解锁", "Whiteout Field / 白障领域", "在目标区域生成持续寒霜场；周期冻结普通敌人，并对 Boss 叠加更强减速与寒冷易伤。"],
  ["laser", "Laser / 激光器", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次完成一次满能量 Focus Channel 后解锁", "Perfect Focus / 完美聚焦", "立即进入稳定聚焦，短时间取消预热和能量爬升要求；光束变宽，并获得追踪或分束能力。"],
  ["machine_gun", "Machine Gun / 机枪", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次以 4 层充能开始换弹后解锁", "Belt-Fed Suppression / 弹链压制", "短时间显著降低或暂停弹药消耗，提高压制射速；期间弹匣阶段会持续强化 Thermal Amplification。"],
  ["orbit", "Orbit / 轨道卫星", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次完成武器入场强化部署后解锁", "Orbital Recall / 轨道召回", "召回现有卫星并造成环形冲击，随后重新部署强化卫星；召回数量决定新部署的规模和持续时间。"],
  ["pistol", "Auto Pistol / 自动手枪", "被动已实装；不可选为主武器；当前仍可通过槽位长按请求通用主动技能", "拟定：武器达到 Lv.3，且本局首次达成 6 次连续命中并开启标记窗口后解锁", "Arc Designation / 电弧标定", "开启快速锁定窗口，自动标记附近多个目标；窗口结束时结算标记，并在目标之间产生电弧连锁。"],
  ["plasma_lance", "Plasma Lance / 等离子长矛", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次完成满能量 Plasma Discharge 后解锁", "Rift Impalement / 裂隙贯穿", "发射强化贯穿长矛并沿路径留下等离子裂隙；消耗的共享热量越多，裂隙越大、持续越久。"],
  ["rocket_launcher", "Rocket Launcher / 火箭发射器", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次由该武器完成 3 次击杀后解锁", "Cluster Barrage / 集束弹幕", "锁定一个区域连续齐射；主弹命中或击杀时派生小型集束弹，击杀链可追加最后一轮轰炸。"],
  ["shotgun", "Shotgun / 霰弹枪", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次完成一次 Crossfire 破防后解锁", "Breach Volley / 突破齐射", "下一轮变为高冲击齐射；近距离集中弹丸造成强破防，外围弹丸可继承交叉火力收益。"],
  ["sniper", "Sniper / 狙击枪", "被动已实装；当前使用通用主动技能占位", "拟定：武器达到 Lv.3，且本局首次消费 5 秒副手蓄力或 Crossfire 蓄势后解锁", "Deadeye Protocol / 死眼协议", "短暂进入精确瞄准；下一枪固定获得最大距离倍率、额外穿透，并在首个命中点产生冲击爆发。"],
];

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("主动技能设计");
sheet.showGridLines = false;
sheet.freezePanes.freezeRows(5);
sheet.freezePanes.freezeColumns(2);

sheet.getRange("A1:F1").merge();
sheet.getRange("A1").values = [["MagArena 武器主动技能设计清单"]];
sheet.getRange("A2:F2").merge();
sheet.getRange("A2").values = [["代码现状：15 把武器尚未绑定独立 WeaponSkillDefinition，当前统一回退为武器超载（50 技能能量 / 10 秒冷却 / 4 秒 / 伤害 ×2 / 攻速 ×1.35）。"]];
sheet.getRange("A3:F3").merge();
sheet.getRange("A3").values = [["说明：解锁条件与专属主动技能均为拟定设计，尚未实装；解锁条件采用“武器 Lv.3 + 本局首次完成核心被动循环”的统一原则。"]];

const headers = [["武器 ID", "武器名字", "当前状态", "满足什么条件解锁主动技能（拟定）", "主动技能名（拟定）", "主动技能描述（拟定）"]];
sheet.getRange("A5:F5").values = headers;
sheet.getRange(`A6:F${5 + rows.length}`).values = rows;

sheet.getRange("A1:F1").format = {
  fill: "#17233C",
  font: { bold: true, color: "#FFFFFF", size: 18 },
  horizontalAlignment: "center",
  verticalAlignment: "center",
};
sheet.getRange("A1:F1").format.rowHeight = 32;
sheet.getRange("A2:F3").format = {
  fill: "#E8EEF8",
  font: { color: "#263550", size: 10 },
  wrapText: true,
  verticalAlignment: "center",
};
sheet.getRange("A2:F3").format.rowHeight = 31;
sheet.getRange("A5:F5").format = {
  fill: "#2D5B88",
  font: { bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "outside", style: "medium", color: "#1D3D5E" },
};
sheet.getRange("A5:F5").format.rowHeight = 34;
sheet.getRange(`A6:F${5 + rows.length}`).format = {
  font: { color: "#202938", size: 10 },
  verticalAlignment: "center",
  wrapText: true,
  borders: {
    insideHorizontal: { style: "thin", color: "#D8E0EA" },
    bottom: { style: "medium", color: "#A9B7C8" },
  },
};
sheet.getRange(`A6:A${5 + rows.length}`).format = { fill: "#F2F5F9", font: { bold: true, color: "#244868" }, verticalAlignment: "center" };
sheet.getRange(`E6:E${5 + rows.length}`).format = { fill: "#EDF7F4", font: { bold: true, color: "#176452" }, wrapText: true, verticalAlignment: "center" };
sheet.getRange(`A6:F${5 + rows.length}`).format.rowHeight = 54;

sheet.getRange("A:A").format.columnWidth = 20;
sheet.getRange("B:B").format.columnWidth = 29;
sheet.getRange("C:C").format.columnWidth = 34;
sheet.getRange("D:D").format.columnWidth = 52;
sheet.getRange("E:E").format.columnWidth = 32;
sheet.getRange("F:F").format.columnWidth = 64;

const table = sheet.tables.add(`A5:F${5 + rows.length}`, true, "WeaponActiveSkillDesign");
table.style = "TableStyleMedium2";
table.showFilterButton = true;

const outputPath = "E:/Godot Projects/project_mag/docs/weapon_active_skill_design.xlsx";
const previewPath = "E:/Godot Projects/project_mag/.codex_tmp/weapon_active_skill_workbook/preview.png";
const inspectPath = "E:/Godot Projects/project_mag/.codex_tmp/weapon_active_skill_workbook/inspect.txt";

const check = await workbook.inspect({
  kind: "table",
  range: "主动技能设计!A1:F20",
  include: "values,formulas",
  tableMaxRows: 22,
  tableMaxCols: 6,
});
const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
await fs.writeFile(inspectPath, `${check.ndjson}\n${errors.ndjson}\n`, "utf8");

const preview = await workbook.render({ sheetName: "主动技能设计", range: "A1:F20", scale: 1, format: "png" });
await fs.writeFile(previewPath, new Uint8Array(await preview.arrayBuffer()));

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(JSON.stringify({ outputPath, previewPath, rowCount: rows.length }));
