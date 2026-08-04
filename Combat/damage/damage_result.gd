extends RefCounted
class_name DamageResult

const REASON_NONE := &"none"
const REASON_INVALID := &"invalid"
const REASON_PHASE_BLOCKED := &"phase_blocked"
const REASON_DUPLICATE := &"duplicate"
const REASON_DEAD := &"dead"
const REASON_INVULNERABLE := &"invulnerable"
const REASON_ZERO_DAMAGE := &"zero_damage"

var applied: bool = false
var accepted: bool = false
var rejection_reason: StringName = REASON_NONE
# Damage after mitigation, intentionally not capped by the target's remaining HP.
var final_damage: int = 0
# The portion of final_damage that consumed remaining HP.
var health_damage: int = 0
# The portion of final_damage beyond the target's remaining HP.
var overkill_damage: int = 0
var damage_type: StringName = Attack.TYPE_PHYSICAL
var killed: bool = false
var is_periodic: bool = false
var triggered_invuln: bool = false
var triggered_energy_burst: bool = false
var damage_kind: StringName = DamageData.KIND_DIRECT
var is_critical: bool = false
