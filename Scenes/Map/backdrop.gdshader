shader_type canvas_item;
// The thick fog behind the map: banks of grey mist, dithered between four shades one step per world pixel so it
// is as coarse as the tiles at every zoom. Two layers drift against each other so it churns, not slides.

uniform vec4 shade0 : source_color = vec4(0.302, 0.290, 0.361, 1.0);
uniform vec4 shade1 : source_color = vec4(0.357, 0.345, 0.420, 1.0);
uniform vec4 shade2 : source_color = vec4(0.416, 0.404, 0.478, 1.0);
uniform vec4 shade3 : source_color = vec4(0.478, 0.467, 0.537, 1.0);
// World pixels across one bank, how much wider than tall a bank lies, and how far the fog moves a second.
uniform float scale = 300.0;
uniform float stretch = 2.5;
uniform vec2 drift = vec2(4.0, 0.5);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

varying vec2 world;

void vertex() {
	world = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Gradient noise, about -0.7..0.7. Value noise flattens along its grid lines, and the bands then run in boxes.
float corner(vec2 i, vec2 p) {
	float a = hash(i) * 6.2831853;
	return dot(vec2(cos(a), sin(a)), p - i);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(corner(i, p), corner(i + vec2(1.0, 0.0), p), u.x),
			mix(corner(i + vec2(0.0, 1.0), p), corner(i + vec2(1.0, 1.0), p), u.x), u.y);
}

// Each octave turned against the last, or value noise's square grid shows through as boxes.
const mat2 TURN = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

float cloud(vec2 p) {
	float n = noise(p) * 0.55;
	p = TURN * p * 2.1 + 5.3;
	n += noise(p) * 0.3;
	p = TURN * p * 2.1 + 9.1;
	return n + noise(p) * 0.15;
}

void fragment() {
	vec2 px = floor(world);
	vec2 bank = vec2(scale * stretch, scale);
	float n = cloud((px + TIME * drift) / bank) * 0.65 + cloud((px - TIME * drift * 0.6) / (bank * 0.5) + 17.0) * 0.35;
	float b = BAYER[int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0))] / 16.0 - 0.5;
	float level = clamp(floor(n * 9.0 + 1.5 + b), 0.0, 3.0);
	// EdgeFog's bands: vertex alpha is how much fog, 1 at a tile's edge to 0 inside, dithered and wobbled.
	if (COLOR.a < 1.0) {
		float wobble = noise((px + TIME * drift * 2.0) / 7.0) * 0.6;
		if (COLOR.a * 1.4 - 0.2 + wobble < b + 0.5) {
			discard;
		}
	}
	COLOR = level < 0.5 ? shade0 : level < 1.5 ? shade1 : level < 2.5 ? shade2 : shade3;
}
