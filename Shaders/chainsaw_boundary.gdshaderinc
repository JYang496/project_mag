// Shared logical-pixel pattern for the ground plane and 2D fallback.
vec4 chainsaw_boundary(vec2 pixel, float time, float width) {
	vec2 p = floor(pixel / 2.0) * 2.0;
	float y = abs(p.y);
	float travel = floor(time * 16.0) * 4.0;
	float link = mod(p.x - travel, 20.0);
	vec4 result = vec4(0.0);
	// Sparse amber hatching marks the full damaging width without a solid fill.
	if (y > 18.0 && mod(p.x + p.y - travel, 40.0) < 2.0) {
		result = vec4(0.66, 0.29, 0.08, 0.22);
	}
	if (y >= width * 0.5 - 2.0 && mod(p.x, 16.0) < 8.0) {
		result = vec4(0.95, 0.43, 0.10, 0.48);
	}
	// Dark chain bed, alternating plates, rivets and outward-facing teeth.
	if (y < 10.0) result = vec4(0.12, 0.15, 0.18, 0.95);
	if (y < 6.0 && link < 16.0) result = vec4(0.34, 0.39, 0.43, 1.0);
	if (y < 2.0 && link > 4.0 && link < 8.0) result = vec4(0.72, 0.77, 0.79, 1.0);
	if (y >= 8.0 && y < 18.0 - link * 0.6 && link < 14.0) {
		result = vec4(vec3(0.52, 0.58, 0.62) + vec3(step(14.0, y) * 0.22), 1.0);
	}
	// Deterministic moving spark clusters, constrained to the damage band.
	float cell = floor(p.x / 64.0);
	float phase = mod(floor(time * 16.0) + cell * 3.0, 12.0);
	float sx = mod(p.x, 64.0) - 12.0 - phase * 2.0;
	float sy = y - 18.0 - phase * 2.0;
	if (phase < 9.0 && abs(sx) < 3.0 && abs(sy) < 3.0) {
		result = vec4(1.0, 0.40 + (1.0 - phase / 9.0) * 0.43, 0.10, 1.0);
	}
	return result;
}
