extends SceneTree

const MODULE_DIR := "res://Player/Weapons/Modules/"
const WEAPON_DIR := "res://data/weapons/"
const BRANCH_DIR := "res://data/weapon_branches/"
const OUTPUT_PATH := "res://docs/weapon_module_audit.html"
const MODULE_MAX_LEVEL := 3
const BASE_PARAMETER_ORDER: PackedStringArray = [
	"required_weapon_traits",
	"required_delivery_types",
	"required_weapon_capabilities",
	"required_hooks",
	"module_tags",
	"level_effects",
	"rarity",
	"drop_weight",
	"cost",
	"stat_multipliers",
	"stat_additives",
]
const CHINESE_EFFECT_SUMMARIES := {
	"wmod_area_expander": "扩大范围伤害类武器的作用半径。",
	"wmod_battle_focus_buff": "连续命中同一目标会叠加临时暴击率；更换目标或超过连击时限后清空层数。",
	"wmod_bleed_edge_physical": "命中时施加流血；流血目标移动距离达到阈值后会周期性受到物理伤害。",
	"wmod_brittle_trigger_freeze": "命中霜冻层数达到要求的目标时，按武器伤害比例追加物理伤害，并受单目标触发间隔限制。",
	"wmod_bullet_size_stat": "提高投射物的视觉尺寸与碰撞体尺寸。",
	"wmod_chill_chain_freeze": "命中后将短时减速扩散给范围内最近的另一名敌人。",
	"wmod_corrosive_touch_energy": "命中时叠加腐蚀，短时间降低目标护甲并提高其受到的伤害。",
	"wmod_crit_amplifier": "装备武器处于主手时，提高玩家的暴击伤害。",
	"wmod_crit_calibrator": "装备武器处于主手时，提高玩家的暴击率。",
	"wmod_crossfire": "命中近期被另一把武器击中过的敌人时，使当前武器短时间获得伤害加成。",
	"wmod_cryo_infuser_freeze": "命中时追加冻结伤害，用于为目标建立霜冻层数。",
	"wmod_damage_up_stat": "提高武器的基础输出伤害。",
	"wmod_dash_cooler": "装备武器处于主手时，缩短玩家的冲刺冷却时间。",
	"wmod_diffusion_nozzle": "扩大锥形攻击的夹角，使攻击覆盖更宽的区域。",
	"wmod_dot_on_hit": "命中时施加可叠加的持续伤害效果；持续次数与单次伤害可随聚变等级成长。",
	"wmod_ember_mark_fire": "命中时积累余烬标记；达到标记阈值后触发小范围火焰爆发。",
	"wmod_expanded_magazine": "提高弹匣容量。",
	"wmod_fast_reload": "缩短武器的装填时间。",
	"wmod_firepower_diffusion": "短时间内命中多个不同目标时，按额外目标数量获得可叠加的临时伤害加成。",
	"wmod_heat_capacity_heat": "提高热能武器的最大热容量，使其更晚进入过热。",
	"wmod_heat_concentration_heat": "热量越高，武器造成的伤害越高；满热时达到最大伤害加成。",
	"wmod_heat_throttle": "降低热能武器每次攻击产生的热量。",
	"wmod_heat_vent_heat": "提高热能武器的冷却速率，并在高热量时获得更强冷却效果。",
	"wmod_ice_prison_freeze": "命中高霜冻层数目标时，有概率短暂定身目标，并受单目标触发间隔限制。",
	"wmod_impact_coil": "提高武器攻击造成的击退强度。",
	"wmod_inertial_aim": "玩家静止时提高装备武器伤害；移动时提高其攻击速度。",
	"wmod_kill_endurance": "装备武器击杀敌人时，有概率返还一发弹药。",
	"wmod_lifesteal_on_hit": "攻击命中时按武器伤害比例恢复玩家生命，且至少恢复最低治疗量。",
	"wmod_lightning_chain_on_hit": "命中时向附近敌人传导额外闪电伤害；传导数量可随聚变等级增加。",
	"wmod_magazine_pressure": "弹匣越接近打空，武器伤害越高。",
	"wmod_molten_splash_fire": "命中后沿目标后方的短条形区域溅射熔火伤害。",
	"wmod_momentum_haste": "每次命中都会叠加短时移动速度与攻击速度加成，直到层数上限。",
	"wmod_multi_launcher": "增加投射物武器每次攻击发射的投射物数量。",
	"wmod_overheat_boost_heat": "热能武器过热后仍可继续开火，但过热期间伤害会降低。",
	"wmod_overkill_recovery": "将击杀时的过量伤害转化为短时间武器伤害加成，加成受等级上限限制。",
	"wmod_penetration_momentum": "快速连续命中不同目标时叠加短时伤害加成；持续命中同一目标不会增加连锁层数。",
	"wmod_permafrost_field_freeze": "击杀带有霜冻的敌人时生成持续造成冻结伤害的领域，同时存在数量受限。",
	"wmod_pierce_stat": "提高投射物每次射击可穿透的目标数量。",
	"wmod_plague_seed_dot": "命中时施加瘟疫种子持续伤害；带种子的敌人死亡后会向附近敌人传播持续伤害。",
	"wmod_projectile_speed_stat": "提高投射物的飞行速度。",
	"wmod_quick_cycle": "缩短武器的攻击间隔。",
	"wmod_recovery_magnet": "装备武器处于主手时，提高玩家拾取范围。",
	"wmod_reload_blast_damage": "开始装填时在玩家周围造成一次范围伤害，伤害随本次已消耗弹药比例提高。",
	"wmod_reload_blast_knockback": "开始装填时击退玩家周围的敌人，击退强度随本次已消耗弹药比例提高。",
	"wmod_reload_damage_boost": "开始装填时使当前武器暂时获得伤害加成，加成随本次已消耗弹药比例提高。",
	"wmod_reload_move_boost": "开始装填时暂时提高玩家移动速度，加成随本次已消耗弹药比例提高。",
	"wmod_reload_offhand_boost": "开始装填时暂时提高其他武器的伤害，加成随本次已消耗弹药比例提高。",
	"wmod_reload_shield_boost": "开始装填时获得临时护盾，护盾量随本次已消耗弹药比例提高。",
	"wmod_reload_speed_link": "当另一把武器正在装填时，缩短当前武器的装填时间。",
	"wmod_rhythm_converter": "停止攻击一段时间后，将此前积累的命中次数转化为短时伤害加成。",
	"wmod_shatter_strike_freeze": "命中带有霜冻的目标时，按当前霜冻层数追加碎裂物理伤害，并受单目标触发间隔限制。",
	"wmod_stun_on_hit": "命中时有概率短暂眩晕目标；概率与眩晕时间可随聚变等级提高。",
	"wmod_subzero_extension_freeze": "命中带有霜冻的目标时延长霜冻持续时间，并强化霜冻层数产生的减速。",
	"wmod_trail_aoe_freeze": "投射物飞行时沿路径留下冻结伤害区域；轨迹会按间隔采样并限制同时存在的区域数量。",
	"wmod_vampiric_surge": "将击杀时超出目标剩余生命的过量伤害转化为临时护盾。",
	"wmod_weakness_relay": "命中带有减益效果的敌人时，使当前武器短时间获得伤害加成。",
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var weapons := _load_weapons()
	var modules := _load_modules()
	var branch_deltas := _load_branch_deltas()
	if weapons.is_empty() or modules.is_empty():
		push_error("Cannot generate module report: weapons=%d modules=%d" % [weapons.size(), modules.size()])
		_cleanup(weapons, modules)
		quit(1)
		return
	if not _validate_module_level_effects(modules):
		_cleanup(weapons, modules)
		quit(1)
		return

	var html := _build_html(weapons, modules, branch_deltas)
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open report output: %s" % OUTPUT_PATH)
		_cleanup(weapons, modules)
		quit(1)
		return
	file.store_string(html)
	file.close()
	print("PASS: generated %s with %d modules and %d weapons" % [OUTPUT_PATH, modules.size(), weapons.size()])
	_cleanup(weapons, modules)
	quit(0)

func _load_weapons() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for path in _list_files(WEAPON_DIR, ".tres"):
		var definition := load(path)
		if definition == null or definition.get("scene") == null:
			push_warning("Skipping invalid weapon definition: %s" % path)
			continue
		var scene := definition.get("scene") as PackedScene
		var instance := scene.instantiate()
		if instance == null or not instance.has_method("get_explicit_weapon_traits"):
			push_warning("Skipping weapon scene that is not Weapon: %s" % definition.scene.resource_path)
			continue
		output.append({
			"id": definition.get("weapon_id"),
			"name": definition.get("display_name"),
			"hidden": bool(definition.get("is_hidden")),
			"definition_path": path,
			"scene_path": scene.resource_path,
			"instance": instance,
			"traits": instance.get_explicit_weapon_traits(),
			"runtime_traits": instance.get_normalized_weapon_traits(),
			"delivery_types": instance.get_explicit_delivery_types(),
			"runtime_delivery_types": instance.get_weapon_delivery_types(),
			"capabilities": instance.get_explicit_weapon_capabilities(),
			"runtime_capabilities": instance.get_weapon_capabilities(),
		})
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return output

func _load_branch_deltas() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for path in _list_files(BRANCH_DIR, ".tres"):
		var definition := load(path)
		if definition == null or definition.behavior_scene == null or definition.weapon_scene == null:
			continue
		var behavior: Node = definition.behavior_scene.instantiate()
		if behavior == null:
			continue
		output.append({
			"id": definition.branch_id,
			"name": definition.display_name,
			"weapon_scene": definition.weapon_scene.resource_path,
			"add_traits": behavior.get_added_weapon_traits(),
			"suppress_traits": behavior.get_suppressed_weapon_traits(),
			"add_delivery": behavior.get_added_delivery_types(),
			"suppress_delivery": behavior.get_suppressed_delivery_types(),
			"add_capabilities": behavior.get_added_weapon_capabilities(),
		})
		behavior.free()
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id).naturalnocasecmp_to(str(b.id)) < 0)
	return output

func _load_modules() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for path in _list_files(MODULE_DIR, ".tscn"):
		if path.ends_with("/wmod_base.tscn"):
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			push_warning("Skipping invalid module scene: %s" % path)
			continue
		var instance := scene.instantiate()
		if instance == null or not instance.has_method("can_apply_to_weapon"):
			push_warning("Skipping scene that is not Module: %s" % path)
			continue
		if instance.has_method("get_unknown_module_tags"):
			var unknown_tags: Array = instance.call("get_unknown_module_tags")
			if not unknown_tags.is_empty():
				push_warning("Module uses extension tags %s: %s" % [unknown_tags, path])
		output.append({
			"id": path.get_file().get_basename(),
			"name": instance.get_module_display_name(),
			"scene_path": path,
			"script_path": instance.get_script().resource_path if instance.get_script() != null else "",
			"instance": instance,
			"parameters": _get_exported_parameters(instance),
			"effect_summary": _get_chinese_effect_summary(path.get_file().get_basename()),
			"level_effects": _get_level_effect_descriptions(instance),
		})
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return output

func _get_exported_parameters(instance: Node) -> Array[Dictionary]:
	var parameters: Array[Dictionary] = []
	for property in instance.get_property_list():
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_EDITOR) == 0 or (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name := str(property.get("name", ""))
		if property_name == "" or property_name == "module_level":
			continue
		parameters.append({
			"name": property_name,
			"value": _format_parameter_value(instance, property_name, instance.get(property_name)),
			"common": BASE_PARAMETER_ORDER.has(property_name),
		})
	parameters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_index := BASE_PARAMETER_ORDER.find(str(a.name))
		var b_index := BASE_PARAMETER_ORDER.find(str(b.name))
		if a_index >= 0 or b_index >= 0:
			if a_index < 0:
				return false
			if b_index < 0:
				return true
			return a_index < b_index
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0
	)
	return parameters

func _get_chinese_effect_summary(module_id: String) -> PackedStringArray:
	var summary := str(CHINESE_EFFECT_SUMMARIES.get(module_id, "")).strip_edges()
	if summary == "":
		return PackedStringArray(["根据当前代码未能可靠推断该模组效果。"])
	return PackedStringArray([summary])

func _get_level_effect_descriptions(instance: Node) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not instance.has_method("get_effect_descriptions") or not instance.has_method("set_module_level"):
		return output
	for level in range(1, 4):
		instance.call("set_module_level", level)
		var raw_descriptions: PackedStringArray = instance.call("get_effect_descriptions")
		var descriptions := PackedStringArray()
		for description in raw_descriptions:
			descriptions.append(_translate_effect_description(description))
		output.append({
			"level": level,
			"descriptions": descriptions,
		})
	instance.call("set_module_level", 1)
	return output

func _validate_module_level_effects(modules: Array[Dictionary]) -> bool:
	var valid := true
	for module_data in modules:
		var instance: Node = module_data.instance
		if instance == null or not instance.has_method("get_level_effect_description"):
			push_error("%s: missing level effect API" % str(module_data.scene_path))
			valid = false
			continue
		var level_effects: PackedStringArray = instance.get("level_effects")
		if level_effects.size() != MODULE_MAX_LEVEL:
			push_error(
				"%s: expected %d level effects, got %d" %
				[module_data.scene_path, MODULE_MAX_LEVEL, level_effects.size()]
			)
			valid = false
			continue
		for level in range(1, MODULE_MAX_LEVEL + 1):
			var description := str(instance.call("get_level_effect_description", level)).strip_edges()
			if description == "":
				push_error("%s: level %d effect is empty" % [module_data.scene_path, level])
				valid = false
	return valid

func _translate_effect_description(description: String) -> String:
	var exact_translations := {
		"Reload burst damages nearby enemies": "装填时对附近敌人造成范围伤害",
		"Damage scales with spent ammo": "伤害随本次已消耗弹药比例提高",
		"Reload shockwave knocks back nearby enemies": "装填时击退附近敌人",
		"Knockback scales with spent ammo": "击退强度随本次已消耗弹药比例提高",
		"Reload grants temporary weapon damage": "装填时使当前武器暂时获得伤害加成",
		"Bonus scales with spent ammo": "加成随本次已消耗弹药比例提高",
		"Reload grants temporary move speed": "装填时暂时提高玩家移动速度",
		"Reload grants temporary damage to other weapons": "装填时暂时提高其他武器的伤害",
		"Reload grants temporary shield": "装填时获得临时护盾",
		"Shield scales with spent ammo": "护盾量随本次已消耗弹药比例提高",
		"Reloads faster while another weapon is reloading": "另一把武器正在装填时，当前武器装填更快",
		"Projectiles leave freeze AoE trails": "投射物会留下冻结范围伤害轨迹",
	}
	if exact_translations.has(description):
		return str(exact_translations[description])
	if description.begins_with("Trail duration "):
		return description.replace("Trail duration ", "轨迹持续时间 ")
	var translated := description
	var stat_labels := {
		"Projectile Hits": "投射物穿透数",
		"Heat Max Value": "最大热容量",
		"Heat Cool Rate": "热量冷却速率",
		"Attack Cooldown": "攻击冷却",
		"Damage": "伤害",
		"Speed": "速度",
		"Size": "尺寸",
	}
	for english_label in stat_labels:
		if translated.begins_with(english_label + " "):
			return translated.replace(english_label, str(stat_labels[english_label]))
	return translated

func _format_parameter_value(instance: Node, property_name: String, value: Variant) -> String:
	if property_name == "required_weapon_traits":
		return _join_names(instance.get_normalized_required_weapon_traits(), "无")
	if property_name == "required_delivery_types":
		return _join_names(instance.get_normalized_required_delivery_types(), "无")
	if property_name == "required_weapon_capabilities":
		return _join_names(instance.get_normalized_required_weapon_capabilities(), "无")
	if property_name == "required_hooks":
		return _join_names(instance.get_normalized_required_hooks(), "无")
	if property_name == "module_tags":
		return _join_names(instance.get_normalized_module_tags(), "无")
	if value is float:
		return _format_float(float(value))
	if value is Color:
		return str(value.to_html(true))
	if value is Dictionary:
		return "无" if value.is_empty() else JSON.stringify(value)
	if value is Array or value is PackedStringArray:
		return _join_names(value, "无")
	if value == null:
		return "无"
	return str(value)

func _build_html(weapons: Array[Dictionary], modules: Array[Dictionary], branch_deltas: Array[Dictionary]) -> String:
	var compatible_pair_count := 0
	var total_pair_count := weapons.size() * modules.size()
	var unrestricted_count := 0
	for module_data in modules:
		var module: Node = module_data.instance
		if module.get_normalized_required_weapon_traits().is_empty() \
				and module.get_normalized_required_delivery_types().is_empty() \
				and module.get_normalized_required_weapon_capabilities().is_empty():
			unrestricted_count += 1
		for weapon_data in weapons:
			if module.can_apply_to_weapon(weapon_data.instance):
				compatible_pair_count += 1

	var generated_at := Time.get_datetime_string_from_system(false, true)
	var body := PackedStringArray()
	body.append("""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>武器模组系统检查报告</title>
<style>
:root{--bg:#f4f6fa;--paper:#fff;--ink:#172033;--muted:#667085;--line:#d8deea;--blue:#2563eb;--green:#15803d;--red:#b42318;--chip:#eef2ff}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font-family:"Microsoft YaHei","Noto Sans SC",Arial,sans-serif;line-height:1.55}
main{max-width:1500px;margin:auto;padding:32px 22px 72px}h1,h2,h3{line-height:1.25}h1{margin:0 0 8px}h2{margin-top:34px}
.muted{color:var(--muted)}.summary{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin:22px 0}.metric,.card{background:var(--paper);border:1px solid var(--line);border-radius:10px;padding:16px}
.metric strong{display:block;font-size:26px}.toolbar{position:sticky;top:0;z-index:2;background:rgba(244,246,250,.95);padding:12px 0;display:flex;gap:10px;backdrop-filter:blur(8px)}
input{width:min(520px,100%);padding:10px 12px;border:1px solid var(--line);border-radius:8px;font:inherit}.module-card{margin:16px 0}.module-card[hidden]{display:none}
.tag{display:inline-block;background:var(--chip);color:#3730a3;border-radius:999px;padding:2px 8px;margin:2px 4px 2px 0;font-size:12px}.ok{background:#dcfce7;color:#166534}.no{background:#fee2e2;color:#991b1b}.hidden-weapon{border-style:dashed}
.path{font-family:Consolas,monospace;font-size:12px;color:var(--muted);overflow-wrap:anywhere}table{width:100%;border-collapse:collapse;margin-top:10px}th,td{padding:8px 10px;border:1px solid var(--line);text-align:left;vertical-align:top}th{background:#f8fafc}
.effect-box{background:#f8fafc;border:1px solid var(--line);border-radius:8px;padding:12px 14px;margin:12px 0}.effect-box p{margin:4px 0}.effect-levels{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-top:8px}.effect-level{background:#fff;border:1px solid var(--line);border-radius:7px;padding:9px}.effect-level strong{display:block;margin-bottom:4px}
.matrix-wrap{overflow:auto;background:var(--paper);border:1px solid var(--line);border-radius:10px}.matrix{min-width:1100px;margin:0}.matrix th:first-child,.matrix td:first-child{position:sticky;left:0;background:#fff;z-index:1}.center{text-align:center}.issues li{margin-bottom:8px}
@media(max-width:800px){.summary{grid-template-columns:repeat(2,minmax(0,1fr))}.toolbar{position:static}.effect-levels{grid-template-columns:1fr}}
</style>
</head>
<body><main>""")
	body.append("<h1>武器模组系统检查报告</h1>")
	body.append("<p class=\"muted\">基于当前运行时代码与资源生成：%s。兼容结果直接调用 <code>Module.can_apply_to_weapon()</code>。</p>" % _escape(generated_at))
	body.append("<section class=\"summary\">")
	body.append(_metric("模组", str(modules.size())))
	body.append(_metric("武器", str(weapons.size())))
	body.append(_metric("无限制模组", str(unrestricted_count)))
	body.append(_metric("兼容组合", "%d / %d" % [compatible_pair_count, total_pair_count]))
	body.append("</section>")
	body.append("<section class=\"card\"><h2>分类词表</h2>")
	body.append("<p><strong>WeaponTrait（%d）：</strong>%s</p>" % [
		WeaponTrait.ALL.size(),
		_tags(WeaponTrait.ALL),
	])
	body.append("<p><strong>DamageDeliveryType（%d）：</strong>%s</p>" % [
		DamageDeliveryType.ALL.size(),
		_tags(DamageDeliveryType.ALL),
	])
	body.append("<p><strong>WeaponCapability（%d）：</strong>%s</p>" % [WeaponCapability.ALL.size(), _tags(WeaponCapability.ALL)])
	body.append("<p><strong>EffectDeliveryType（%d）：</strong>%s</p>" % [EffectDeliveryType.ALL.size(), _tags(EffectDeliveryType.ALL)])
	body.append("<p><strong>ModuleHook（%d）：</strong>%s</p>" % [ModuleHook.ALL.size(), _tags(ModuleHook.ALL)])
	body.append("<p><strong>ModuleTag 核心词表（%d，可扩展）：</strong>%s</p>" % [ModuleTag.CORE.size(), _tags(ModuleTag.CORE)])
	body.append("</section>")
	body.append("""<section class="card issues"><h2>系统检查结论</h2><ul>
<li>战斗奖励池会自动扫描 <code>Player/Weapons/Modules/*.tscn</code>，仅排除 <code>wmod_base.tscn</code>；本报告使用同一范围。</li>
<li>兼容维度为 WeaponTrait、DamageDeliveryType、WeaponCapability；维度之间全部满足，维度内部任一命中。</li>
<li>Trait 与交付类型严格分工，不进行交付类型到 trait 的兼容映射。</li>
<li>每把武器最多安装 3 个模组；模组等级范围为 1-3。报告参数显示场景覆盖后的当前值。</li>
<li>系统不再使用永久武器背包或模组背包。武器只能存在于 4 个装备槽；同类型武器全局唯一，重复武器用于融合。</li>
<li>每种模组全局唯一。未安装模组只存在于当前运行的临时模组区；重复模组升级唯一实例，满 3 级后溢出立即出售。</li>
<li>主动模组管理只能在激活的 Rest Area 且阶段为 <code>PREPARE</code> 时进行；奖励事务允许在奖励到休整的过渡期处理。</li>
<li>武器出售或替换时，其模组进入临时区。开始战斗前剩余临时模组统一出售，并可关闭确认提示。</li>
<li>效果描述包含脚本机制说明，以及模组实际 <code>get_effect_descriptions()</code> 在 1-3 级的返回文本。</li>
<li>隐藏武器仍列入兼容性检查，因为其定义与场景仍存在，且可被保存恢复路径实例化。</li>
</ul></section>""")
	body.append("<h2>武器清单</h2><div class=\"card\"><table><thead><tr><th>武器</th><th>ID</th><th>基础 Traits</th><th>运行时 Traits</th><th>基础交付</th><th>运行时交付</th><th>基础能力</th><th>运行时能力</th><th>资源</th></tr></thead><tbody>")
	for weapon_data in weapons:
		var row_class := " class=\"hidden-weapon\"" if weapon_data.hidden else ""
		var hidden_label := " <span class=\"tag no\">隐藏</span>" if weapon_data.hidden else ""
		body.append("<tr%s><td><strong>%s</strong>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td class=\"path\">%s</td></tr>" % [
			row_class,
			_escape(str(weapon_data.name)),
			hidden_label,
			_escape(str(weapon_data.id)),
			_tags(weapon_data.traits),
			_tags(weapon_data.runtime_traits),
			_tags(weapon_data.delivery_types),
			_tags(weapon_data.runtime_delivery_types),
			_tags(weapon_data.capabilities),
			_tags(weapon_data.runtime_capabilities),
			_escape(str(weapon_data.scene_path)),
		])
	body.append("</tbody></table></div>")
	body.append("<h2>分支分类增量</h2><div class=\"card\"><table><thead><tr><th>分支</th><th>武器资源</th><th>新增 Traits</th><th>屏蔽 Traits</th><th>新增交付</th><th>屏蔽交付</th><th>新增能力</th></tr></thead><tbody>")
	for delta in branch_deltas:
		body.append("<tr><td><strong>%s</strong><br><span class=\"path\">%s</span></td><td class=\"path\">%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>" % [
			_escape(str(delta.name)), _escape(str(delta.id)), _escape(str(delta.weapon_scene)),
			_tags(delta.add_traits), _tags(delta.suppress_traits), _tags(delta.add_delivery),
			_tags(delta.suppress_delivery), _tags(delta.add_capabilities),
		])
	body.append("</tbody></table></div>")
	body.append("<h2>完整兼容矩阵</h2><div class=\"matrix-wrap\"><table class=\"matrix\"><thead><tr><th>模组</th>")
	for weapon_data in weapons:
		body.append("<th class=\"center\">%s</th>" % _escape(str(weapon_data.name)))
	body.append("</tr></thead><tbody>")
	for module_data in modules:
		body.append("<tr><td><strong>%s</strong></td>" % _escape(str(module_data.name)))
		var module: Node = module_data.instance
		for weapon_data in weapons:
			var reason: String = str(module.get_incompatibility_reason(weapon_data.instance))
			body.append("<td class=\"center\"><span class=\"tag %s\" title=\"%s\">%s</span></td>" % [
				"ok" if reason == "" else "no",
				_escape("兼容" if reason == "" else reason),
				"是" if reason == "" else "否",
			])
		body.append("</tr>")
	body.append("</tbody></table></div>")
	body.append("""<h2>模组参数与可安装武器</h2>
<div class="toolbar"><input id="search" type="search" placeholder="筛选模组、参数、trait 或武器名称"></div>
<div id="modules">""")
	for module_data in modules:
		body.append(_build_module_card(module_data, weapons))
	body.append("""</div>
<script>
const search=document.getElementById('search');
search.addEventListener('input',()=>{const q=search.value.trim().toLowerCase();document.querySelectorAll('.module-card').forEach(card=>card.hidden=q!==''&&!card.textContent.toLowerCase().includes(q));});
</script>
</main></body></html>""")
	return "\n".join(body)

func _build_module_card(module_data: Dictionary, weapons: Array[Dictionary]) -> String:
	var module: Node = module_data.instance
	var compatible: PackedStringArray = []
	var incompatible: PackedStringArray = []
	for weapon_data in weapons:
		var reason: String = str(module.get_incompatibility_reason(weapon_data.instance))
		if reason == "":
			compatible.append(str(weapon_data.name))
		else:
			incompatible.append("%s：%s" % [weapon_data.name, reason])
	var parts := PackedStringArray()
	parts.append("<article class=\"card module-card\"><h3>%s <span class=\"tag\">%s</span></h3>" % [_escape(str(module_data.name)), _escape(str(module_data.id))])
	parts.append("<p class=\"path\">%s<br>%s</p>" % [_escape(str(module_data.scene_path)), _escape(str(module_data.script_path))])
	parts.append(_build_effect_box(module_data))
	parts.append("<p><strong>可安装武器（%d）：</strong>%s</p>" % [compatible.size(), _tags(compatible, "ok")])
	if not incompatible.is_empty():
		parts.append("<details><summary>不兼容武器与原因（%d）</summary><p>%s</p></details>" % [incompatible.size(), "<br>".join(_escape_array(incompatible))])
	parts.append("<table><thead><tr><th>参数</th><th>当前值</th><th>类型</th></tr></thead><tbody>")
	for parameter in module_data.parameters:
		parts.append("<tr><td><code>%s</code></td><td>%s</td><td>%s</td></tr>" % [
			_escape(str(parameter.name)),
			_escape(str(parameter.value)),
			"通用/兼容参数" if parameter.common else "模组专用参数",
		])
	parts.append("</tbody></table></article>")
	return "\n".join(parts)

func _build_effect_box(module_data: Dictionary) -> String:
	var parts := PackedStringArray(["<section class=\"effect-box\"><strong>效果描述</strong>"])
	var summaries: PackedStringArray = module_data.effect_summary
	if summaries.is_empty():
		parts.append("<p class=\"muted\">脚本未提供机制说明。</p>")
	else:
		for summary in summaries:
			parts.append("<p>%s</p>" % _escape(summary))
	parts.append("<div class=\"effect-levels\">")
	for level_data in module_data.level_effects:
		var descriptions: PackedStringArray = level_data.descriptions
		parts.append("<div class=\"effect-level\"><strong>等级 %d</strong>" % int(level_data.level))
		if descriptions.is_empty():
			parts.append("<span class=\"muted\">未提供等级效果文本</span>")
		else:
			for description in descriptions:
				parts.append("<div>%s</div>" % _escape(description))
		parts.append("</div>")
	parts.append("</div></section>")
	return "\n".join(parts)

func _metric(label: String, value: String) -> String:
	return "<div class=\"metric\"><span class=\"muted\">%s</span><strong>%s</strong></div>" % [_escape(label), _escape(value)]

func _tags(values: Variant, extra_class: String = "") -> String:
	if values == null or values.is_empty():
		return "<span class=\"muted\">无</span>"
	var output := PackedStringArray()
	for value in values:
		output.append("<span class=\"tag %s\">%s</span>" % [extra_class, _escape(str(value))])
	return "".join(output)

func _join_names(values: Variant, empty_label: String) -> String:
	if values == null or values.is_empty():
		return empty_label
	var output := PackedStringArray()
	for value in values:
		output.append(str(value))
	return ", ".join(output)

func _format_float(value: float) -> String:
	var text := "%.4f" % value
	while text.contains(".") and text.ends_with("0"):
		text = text.left(-1)
	if text.ends_with("."):
		text = text.left(-1)
	return text

func _escape_array(values: PackedStringArray) -> PackedStringArray:
	var output := PackedStringArray()
	for value in values:
		output.append(_escape(value))
	return output

func _escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;")

func _list_files(directory_path: String, extension: String) -> PackedStringArray:
	var output := PackedStringArray()
	var dir := DirAccess.open(directory_path)
	if dir == null:
		push_error("Cannot open directory: %s" % directory_path)
		return output
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(extension):
			output.append(directory_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	output.sort()
	return output

func _cleanup(weapons: Array[Dictionary], modules: Array[Dictionary]) -> void:
	for weapon_data in weapons:
		var instance: Node = weapon_data.get("instance", null)
		if instance != null:
			instance.free()
	for module_data in modules:
		var instance: Node = module_data.get("instance", null)
		if instance != null:
			instance.free()
