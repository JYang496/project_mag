extends RefCounted
class_name DashSpeedProfile

## Creates the default normalized-time velocity profile used by player dashes.
## The movement system normalizes its area, so editing the shape does not change
## the requested dash distance.
static func create_default_curve() -> Curve:
	return create_curve(0.0, 0.40, 2.50, 1.0)


static func create_curve(
	start_multiplier: float,
	peak_time: float,
	peak_multiplier: float,
	end_multiplier: float
) -> Curve:
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = maxf(2.5, peak_multiplier + 0.25)
	var peak_x := clampf(peak_time, 0.25, 0.75)
	curve.add_point(Vector2(0.0, maxf(start_multiplier, 0.0)))
	curve.add_point(Vector2(maxf(peak_x - 0.34, 0.08), maxf(start_multiplier * 1.35, 0.05)))
	curve.add_point(Vector2(peak_x, maxf(peak_multiplier, 0.05)))
	curve.add_point(Vector2(minf(peak_x + 0.14, 0.92), maxf(end_multiplier * 1.45, 0.08)))
	curve.add_point(Vector2(1.0, maxf(end_multiplier, 0.0)))
	curve.bake_resolution = 128
	return curve
