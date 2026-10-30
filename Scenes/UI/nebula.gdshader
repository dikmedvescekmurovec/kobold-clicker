// The transcension's sky (`TranscendPage`): a nebula of ENDESGA 64's purples drifting slowly, cut into the
// interface's pixels (`pixel`, the window's ui_scale) and stepped through an ordered dither so it reads as
// pixel art, under stars that twinkle. Multiplies by COLOR, which carries the node's modulate: the fade in.
shader_type canvas_item;

// Window pixels to one interface pixel.
uniform float pixel = 1.0;
// 0 holds it still (animations off).
uniform float speed = 1.0;

// Night to lilac: 0e071b, 1a1932, 3b1443, 622461, 93388f.
const vec3 RAMP[5] = vec3[5](vec3(0.055, 0.027, 0.106), vec3(0.102, 0.098, 0.196), vec3(0.231, 0.078, 0.263),
		vec3(0.384, 0.141, 0.380), vec3(0.576, 0.220, 0.561));
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0,
		13.0, 5.0);
// f9e6cf and ca52c9.
const vec3 STAR = vec3(0.976, 0.902, 0.812);
const vec3 STAR_DIM = vec3(0.792, 0.322, 0.788);

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// An integer hash of a whole-numbered point: fract(sin(...)) ran out of precision across a window and laid
// the stars out in diagonal rows.
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + 65536);
	return float(pcg(q.x + pcg(q.y))) / 4294967295.0;
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	// Each octave turned against the last: value noise left square shows its grid once it is stepped.
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		sum += amp * noise(p);
		p = turn * p * 2.03 + vec2(17.0, 9.0);
		amp *= 0.5;
	}
	return sum;
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / pixel);
	vec2 screen = 1.0 / SCREEN_PIXEL_SIZE / pixel;
	float t = TIME * speed;
	// Warped once by a slower field of its own, so the clouds roll rather than slide.
	vec2 p = cell / 90.0;
	vec2 warp = vec2(fbm(p + vec2(t * 0.011, 0.0)), fbm(p + vec2(5.2, 1.3) - vec2(0.0, t * 0.009)));
	float cloud = fbm(p + 1.8 * warp + vec2(t * 0.006, t * 0.004));
	// Brightest towards the middle, where the chart stands; night at the edges.
	float edge = length((cell / screen - 0.5) * vec2(1.0, 0.8));
	float level = clamp((cloud - 0.28) * 5.0 - edge * 2.5, 0.0, 4.0);
	ivec2 b = ivec2(mod(cell, 4.0));
	level = clamp(floor(level + BAYER[b.y * 4 + b.x] / 16.0), 0.0, 4.0);
	vec3 sky = RAMP[int(level)];
	float star = hash(cell + 7.0);
	if (star > 0.996) {
		float own = hash(cell + 3.0);
		sky = sin(t * (1.5 + 3.0 * own) + own * 40.0) > -0.4 ? STAR : STAR_DIM;
	}
	COLOR = vec4(sky, 1.0) * COLOR;
}
