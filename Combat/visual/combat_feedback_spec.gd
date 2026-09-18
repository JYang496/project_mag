extends RefCounted
class_name CombatFeedbackSpec

## Shared presentation contract for combat feedback. These values affect only
## readability and never alter damage, collision, cooldown, or spawn behavior.

enum Priority {
	SECONDARY = 0,
	STANDARD = 1,
	IMPORTANT = 2,
	SURVIVAL = 3,
}

enum FeedbackKind {
	DAMAGE = 0,
	CRITICAL = 1,
	HEAL = 2,
	SHIELD_GAIN = 3,
	SHIELD_ABSORB = 4,
	STATUS_POSITIVE = 5,
	STATUS_NEGATIVE = 6,
}

enum DangerLevel {
	CAUTION = 0,
	DANGER = 1,
	LETHAL = 2,
}

const ENEMY_WARNING_DURATION_SEC := 1.25
const ENEMY_WARNING_MIN_DURATION_SEC := 0.75
const ENEMY_WARNING_MAX_DURATION_SEC := 1.50
const WARNING_CONFIRM_PHASE := 0.18
const WARNING_URGENT_PHASE := 0.72

const HP_WARNING_RATIO := 0.35
const HP_CRITICAL_RATIO := 0.18
const HP_WARNING_PULSE_HZ := 1.8
const HP_CRITICAL_PULSE_HZ := 3.0

const COLOR_DAMAGE := Color("#FF5948")
const COLOR_CRITICAL := Color("#FFD34D")
const COLOR_HEAL := Color("#62DF91")
const COLOR_SHIELD := Color("#55BCEB")
const COLOR_STATUS_POSITIVE := Color("#A8E85C")
const COLOR_STATUS_NEGATIVE := Color("#C88BFF")
const COLOR_WARNING := Color("#FF762E")
const COLOR_DANGER := Color("#FF4D5E")
const COLOR_LETHAL := Color("#FFF0D8")
const COLOR_OUTLINE := Color(0.035, 0.045, 0.060, 0.96)

# CanvasItem order inside the projected-world UI layer.
const WORLD_UI_STATUS_Z := 120
const WORLD_UI_DAMAGE_Z := 160
const WORLD_UI_CRITICAL_Z := 180
const WORLD_UI_SURVIVAL_Z := 220

# CanvasLayer order. World feedback stays below the fixed HUD and survival veil.
const PROJECTED_WORLD_UI_LAYER := 30
const SURVIVAL_OVERLAY_LAYER := 80
const BOSS_HUD_LAYER := 85
const FIXED_HUD_LAYER := 90


static func clamp_enemy_warning_duration(seconds: float) -> float:
	return clampf(seconds, ENEMY_WARNING_MIN_DURATION_SEC, ENEMY_WARNING_MAX_DURATION_SEC)


static func danger_color(level: DangerLevel) -> Color:
	match level:
		DangerLevel.CAUTION:
			return COLOR_WARNING
		DangerLevel.LETHAL:
			return COLOR_LETHAL
		_:
			return COLOR_DANGER


static func feedback_color(kind: FeedbackKind) -> Color:
	match kind:
		FeedbackKind.CRITICAL:
			return COLOR_CRITICAL
		FeedbackKind.HEAL:
			return COLOR_HEAL
		FeedbackKind.SHIELD_GAIN, FeedbackKind.SHIELD_ABSORB:
			return COLOR_SHIELD
		FeedbackKind.STATUS_POSITIVE:
			return COLOR_STATUS_POSITIVE
		FeedbackKind.STATUS_NEGATIVE:
			return COLOR_STATUS_NEGATIVE
		_:
			return COLOR_DAMAGE


static func world_ui_z(priority: Priority) -> int:
	match priority:
		Priority.SECONDARY:
			return WORLD_UI_STATUS_Z
		Priority.IMPORTANT:
			return WORLD_UI_CRITICAL_Z
		Priority.SURVIVAL:
			return WORLD_UI_SURVIVAL_Z
		_:
			return WORLD_UI_DAMAGE_Z
