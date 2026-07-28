extends RefCounted
class_name CombatVisualPalette

## Shared ownership and semantic colors for world-space combat visuals.
##
## Ownership colors answer "whose effect is this?" and should be used for
## outlines, brackets, and outer telegraph edges. Semantic colors answer
## "what does this effect do?" and belong in fills, particles, and inner lines.

const PLAYER_PRIMARY := Color("#35D7FF")
const PLAYER_CORE := Color("#EAFBFF")
const PLAYER_DARK := Color("#123746")

const ENEMY_PRIMARY := Color("#FF4D5E")
const ENEMY_SECONDARY := Color("#FF8A3D")
const ENEMY_DARK := Color("#481821")

const FRIENDLY_PRIMARY := Color("#62E6A5")
const NEUTRAL_PRIMARY := Color("#708895")

const FIRE := Color("#FF762E")
const FREEZE := Color("#72DDF7")
const ENERGY := Color("#A875FF")
const HEAL := Color("#62DF91")
const SHIELD := Color("#55BCEB")
const SPEED := Color("#F2B84B")
const REWARD := Color("#F4C542")

const FIELD_BOUNDARY := Color("#708895")
const FIELD_INACTIVE := Color("#31414C")
const FIELD_TASK := Color("#E5B94F")


static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
