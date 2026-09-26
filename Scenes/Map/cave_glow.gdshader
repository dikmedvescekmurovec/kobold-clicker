shader_type canvas_item;
render_mode blend_add;
// The dark red light out of the Gollux cave's pit, added over the map: a pool of it over the hole and a
// plume climbing out of it that narrows and fades as it rises, breathing slowly with a faint flicker.
// Dithered between a few steps one per world pixel, as the fog is, so it is as coarse as the tiles.
// Drawn on a Polygon2D whose origin is the middle of the hole (`HexMap.set_cave`); the picture under it
// is `AI-sprites-generator/caves.py`'s, which leaves the light out.

uniform vec4 glow : source_color = vec4(0.62, 0.07, 0.05, 1.0);
// The pool's half-width and half-height, in world pixels, and how far below the hole's middle its heart
// lies: on the dark floor, where the light comes up from.
uniform vec2 pool = vec2(24.0, 13.0);
uniform float heart = 3.0;
// How far above the hole the plume climbs, and how wide it is where it leaves it.
uniform float rise = 32.0;
uniform float plume_width = 15.0;
// Breaths a second, how deep a breath is and how much it flickers: all 0 hold the light still, which is
// what `HexMap` sets when the player has turned animations off.
uniform float breath = 0.25;
uniform float depth = 0.3;
uniform float flicker = 0.08;
// The light's brightness at its heart, in steps of the dither (it has `STEPS` of them).
uniform float strength = 1.0;

const float STEPS = 4.0;
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 px = floor(local) + 0.5;
	// The pool: brightest on the floor of the hole, where the light comes up from.
	float held = 1.0 - length((px - vec2(0.0, heart)) / pool);
	// The plume: over the hole only, narrowing to nothing at `rise`.
	float up = clamp(-px.y / rise, 0.0, 1.0);
	float wide = plume_width * (1.0 - up * 0.7);
	float plume = px.y < 0.0 ? (1.0 - up) * (1.0 - abs(px.x) / wide) * 0.85 : 0.0;
	float light = clamp(max(held, plume), 0.0, 1.0);
	float breathe = 1.0 - depth * 0.5 * (1.0 - sin(TIME * 6.2831853 * breath));
	float flickered = 1.0 - flicker + flicker * hash(floor(TIME * 7.0));
	float b = BAYER[int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0))] / 16.0 - 0.5;
	float level = clamp(floor(light * breathe * flickered * STEPS * strength + b), 0.0, STEPS);
	if (level < 0.5) {
		discard;
	}
	COLOR = vec4(glow.rgb * level / STEPS, 1.0);
}
