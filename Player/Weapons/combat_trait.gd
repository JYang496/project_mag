extends RefCounted
class_name CombatTrait

const MOVEMENT := &"movement"
const DEBUFF := &"debuff"
const BUFF := &"buff"
const DOT := &"dot"
const DURATION := &"duration"
const RANGE := &"range"
const MELEE := &"melee"
const STACKING := &"stacking"
const TRIGGER := &"trigger"
const CHARGE := &"charge"
const PROJECTILE := &"projectile"
const SUMMON := &"summon"
const PHYSICAL := &"physical"
const ENERGY := &"energy"
const EXPLOSIVE := &"explosive"
const FIRE := &"fire"
const FREEZE := &"freeze"

const ALL: Array[StringName] = [
	MOVEMENT,
	DEBUFF,
	BUFF,
	DOT,
	DURATION,
	RANGE,
	MELEE,
	STACKING,
	TRIGGER,
	CHARGE,
	PROJECTILE,
	SUMMON,
	PHYSICAL,
	ENERGY,
	EXPLOSIVE,
	FIRE,
	FREEZE,
]

const FLAG_ORDER: Array[StringName] = ALL

const ALIASES: Dictionary = {
	"位移": MOVEMENT,
	"减益": DEBUFF,
	"增益": BUFF,
	"持续伤害": DOT,
	"持续时间": DURATION,
	"范围": RANGE,
	"近战": MELEE,
	"叠层": STACKING,
	"触发": TRIGGER,
	"蓄力": CHARGE,
	"投射物": PROJECTILE,
	"召唤物": SUMMON,
	"物理": PHYSICAL,
	"能量": ENERGY,
	"爆炸": EXPLOSIVE,
	"火焰": FIRE,
	"冻结": FREEZE,
}

static func normalize(value: Variant) -> StringName:
	if value == null:
		return StringName()
	var key := str(value).strip_edges().to_lower()
	if key == "":
		return StringName()
	if ALIASES.has(key):
		return ALIASES[key]
	return StringName(key)

static func normalize_array(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values == null:
		return result
	for value in values:
		var normalized := normalize(value)
		if normalized == StringName():
			continue
		if not result.has(normalized):
			result.append(normalized)
	return result

static func traits_to_flags(values: Array) -> int:
	var normalized_values := normalize_array(values)
	var mask := 0
	for i in range(FLAG_ORDER.size()):
		if normalized_values.has(FLAG_ORDER[i]):
			mask |= (1 << i)
	return mask

static func flags_to_traits(mask: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for i in range(FLAG_ORDER.size()):
		if (mask & (1 << i)) != 0:
			result.append(FLAG_ORDER[i])
	return result
